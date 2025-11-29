import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config/supabase_config.dart';
import '../core/models/station_models.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());

class SupabaseService {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw const SupabaseConfigMissingException();
    }
    return Supabase.instance.client;
  }

  Future<LoadingStationProfile> fetchStationProfile(String stationId) async {
    final data = await _client
        .from('loading_stations')
        .select('id,name,ls_code,address,balance,bonus_rate,business_hubs (id,name,bh_code,municipality,bonus_rate)')
        .eq('id', stationId)
        .maybeSingle();

    if (data == null) throw Exception('Station profile not found');
    return LoadingStationProfile.fromMap(data);
  }

  Future<LoadingStationProfile?> fetchStationByLSCode(String lsCode) async {
    final trimmedCode = lsCode.trim();
    debugPrint('Fetching station by LSCODE: "$trimmedCode"');
    
    // Try exact match first (case-sensitive)
    var data = await _client
        .from('loading_stations')
        .select('id,name,ls_code,address,balance,bonus_rate,business_hubs (id,name,bh_code,municipality,bonus_rate)')
        .eq('ls_code', trimmedCode)
        .maybeSingle();

    // If not found, try case-insensitive match using ilike (PostgreSQL)
    if (data == null) {
      debugPrint('Exact match not found, trying case-insensitive...');
      final allStations = await _client
          .from('loading_stations')
          .select('id,name,ls_code,address,balance,bonus_rate,business_hubs (id,name,bh_code,municipality,bonus_rate)')
          .limit(1000); // Get all stations to filter client-side
      
      final matching = List<Map<String, dynamic>>.from(allStations)
          .where((station) {
            final dbCode = station['ls_code']?.toString().trim() ?? '';
            final match = dbCode.toUpperCase() == trimmedCode.toUpperCase();
            if (match) {
              debugPrint('Found case-insensitive match: DB="$dbCode" vs Input="$trimmedCode"');
            }
            return match;
          })
          .toList();
      
      if (matching.isNotEmpty) {
        data = matching.first;
        debugPrint('Using case-insensitive match: ${data['ls_code']}');
      }
    } else {
      debugPrint('Found exact match: ${data['ls_code']}');
    }

    if (data == null) {
      debugPrint('No station found with LSCODE: "$trimmedCode"');
      return null;
    }
    
    return LoadingStationProfile.fromMap(data);
  }

  Future<String?> getLinkedStationId(String userId) async {
    // First check if user has their own loading_station record (loading_stations.id = users.id)
    final station = await _client
        .from('loading_stations')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    
    if (station != null) {
      // User IS a loading station (their id matches a loading_station id)
      return userId;
    }
    
    // If user doesn't have their own station, check if they verified an LSCODE
    // (stored in shared preferences)
    final prefs = await SharedPreferences.getInstance();
    final verifiedStationId = prefs.getString('verified_station_id_$userId');
    
    if (verifiedStationId != null) {
      // Verify the station still exists
      final verifiedStation = await _client
          .from('loading_stations')
          .select('id')
          .eq('id', verifiedStationId)
          .maybeSingle();
      
      if (verifiedStation != null) {
        return verifiedStationId;
      } else {
        // Station no longer exists, clear the preference
        await prefs.remove('verified_station_id_$userId');
      }
    }
    
    return null;
  }

  Future<void> verifyLSCodeForUser(String userId, String lsCode) async {
    debugPrint('Verifying LSCODE: $lsCode for user: $userId');
    
    // Simply verify the LSCODE exists in loading_stations table
    // SELECT * FROM loading_stations WHERE ls_code = 'KY6949'
    final trimmedCode = lsCode.trim();
    final stationData = await _client
        .from('loading_stations')
        .select('id,ls_code,name')
        .eq('ls_code', trimmedCode)
        .maybeSingle();
    
    // If exact match not found, try case-insensitive
    var station = stationData;
    if (station == null) {
      final allStations = await _client
          .from('loading_stations')
          .select('id,ls_code,name')
          .limit(1000);
      
      final matching = List<Map<String, dynamic>>.from(allStations)
          .where((s) => (s['ls_code']?.toString().trim().toUpperCase() ?? '') == trimmedCode.toUpperCase())
          .toList();
      
      if (matching.isNotEmpty) {
        station = matching.first;
      }
    }
    
    if (station == null) {
      debugPrint('LSCODE not found: $trimmedCode');
      throw Exception('Invalid Loading Station Code. Please check your LSCODE and try again.');
    }
    
    final stationId = station['id']?.toString() ?? '';
    debugPrint('Found station: $stationId with LSCODE: ${station['ls_code']}');
    
    // Store the verified station ID in shared preferences
    // This allows the user to access this station's data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('verified_station_id_$userId', stationId);
    
    debugPrint('LSCODE verification successful: User $userId can access station $stationId');
    // Verification successful - station ID stored, user can proceed
  }

  Future<List<RiderProfile>> fetchRiders(String stationId) async {
    final result = await _client
        .from('riders')
        .select('id,status,balance,commission_rate,vehicle_type,users(full_name),merchant_rider_preferences(priority_order)')
        .eq('loading_station_id', stationId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result).map(RiderProfile.fromMap).toList();
  }

  Future<List<MerchantProfile>> fetchMerchants(String stationId) async {
    try {
      debugPrint('Fetching merchants for loading_station.id: $stationId');
      
      // First, get the loading station with its business_hub_id
      final station = await _client
          .from('loading_stations')
          .select('id,business_hub_id')
          .eq('id', stationId)
          .maybeSingle();
      
      if (station == null) {
        debugPrint('Loading station not found: $stationId');
        return [];
      }
      
      final businessHubId = station['business_hub_id'];
      debugPrint('Loading station found. business_hub_id: $businessHubId');
      
      // Get all loading stations in the same business hub
      final stationsInHub = await _client
          .from('loading_stations')
          .select('id')
          .eq('business_hub_id', businessHubId);
      
      final stationIds = stationsInHub.map((s) => s['id'].toString()).toList();
      debugPrint('Found ${stationIds.length} loading stations in business hub: $stationIds');
      
      // Query merchants where loading_station_id matches any loading station in the same business hub
      final result = await _client
          .from('merchants')
          .select('id,business_name,address,access_status,gcash_number,merchant_rider_preferences(id)')
          .inFilter('loading_station_id', stationIds)
          .order('created_at', ascending: false);
      
      debugPrint('Found ${result.length} merchants in business hub (across ${stationIds.length} loading stations)');
      
      return List<Map<String, dynamic>>.from(result).map(MerchantProfile.fromMap).toList();
    } catch (e, stack) {
      debugPrint('Error fetching merchants for stationId $stationId: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<List<DeliverySummary>> fetchDeliveries(String stationId) async {
    final result = await _client
        .from('deliveries')
        .select('id,type,status,delivery_fee,created_at,dropoff_address,pickup_address,distance_km,merchants(business_name),riders(users(full_name))')
        .eq('loading_station_id', stationId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(result).map(DeliverySummary.fromMap).toList();
  }

  Future<List<TopUpSummary>> fetchTopUps(String stationId) async {
    final result = await _client
        .from('topups')
        .select('id,amount,bonus_amount,total_credited,status,created_at,riders(users(full_name)),initiated_by_user:users!topups_initiated_by_fkey(full_name)')
        .or('loading_station_id.eq.$stationId,business_hub_id.eq.${_client.auth.currentUser?.id}')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(result).map(TopUpSummary.fromMap).toList();
  }

  Future<List<TopUpSummary>> fetchPendingTopUpRequests(String stationId) async {
    final result = await _client
        .from('topups')
        .select('id,amount,bonus_amount,total_credited,status,created_at,riders(users(full_name)),initiated_by_user:users!topups_initiated_by_fkey(full_name)')
        .eq('loading_station_id', stationId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result).map(TopUpSummary.fromMap).toList();
  }

  Future<List<TopUpSummary>> fetchPendingTopUpRequestsForHub(String hubId) async {
    final result = await _client
        .from('topups')
        .select('id,amount,bonus_amount,total_credited,status,created_at,loading_stations(name),initiated_by_user:users!topups_initiated_by_fkey(full_name)')
        .eq('business_hub_id', hubId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result).map(TopUpSummary.fromMap).toList();
  }

  Future<CommissionConfig> fetchCommissionConfig() async {
    final result = await _client.from('commission_settings').select('role,percentage');
    final map = <String, double>{};
    for (final entry in List<Map<String, dynamic>>.from(result)) {
      final role = entry['role']?.toString().toLowerCase() ?? '';
      map[role] = (entry['percentage'] as num?)?.toDouble() ?? 0;
    }
    return CommissionConfig.fromMap({
      'hub': map['hub'] ?? 50,
      'loading_station': map['loading_station'] ?? 25,
      'rider': map['rider'] ?? 20,
      'shareholder': map['shareholder'] ?? 5,
    });
  }

  Future<void> approveRider(String riderId, {required bool approved}) async {
    await _client.from('users').update({'access_status': approved ? 'approved' : 'rejected'}).eq('id', riderId);
  }

  Future<void> approveMerchant(String merchantId, {required bool approved}) async {
    await _client.from('merchants').update({'access_status': approved ? 'approved' : 'rejected'}).eq('id', merchantId);
  }

  Future<void> updateRiderPriority(String riderId, int priority) async {
    await _client.from('merchant_rider_preferences').update({'priority_order': priority}).eq('rider_id', riderId);
  }

  Future<void> updateRiderPriorityForMerchant({
    required String riderId,
    required String merchantId,
    required int priority,
  }) async {
    await _client.from('merchant_rider_preferences').upsert({
      'rider_id': riderId,
      'merchant_id': merchantId,
      'priority_order': priority,
    });
  }

  Future<List<RiderProfile>> fetchRidersForMerchant(String merchantId) async {
    final result = await _client
        .from('merchant_rider_preferences')
        .select('rider_id,priority_order,riders(id,status,balance,commission_rate,vehicle_type,users(full_name))')
        .eq('merchant_id', merchantId)
        .order('priority_order');
    return List<Map<String, dynamic>>.from(result)
        .map((map) => RiderProfile.fromMap({
              ...map['riders'] as Map<String, dynamic>,
              'priority_order': map['priority_order'],
            }))
        .toList();
  }

  Future<void> respondTopUp({
    required String topUpId,
    required bool approve,
  }) async {
    final topUp = await _client.from('topups').select('*').eq('id', topUpId).maybeSingle();
    if (topUp == null) throw Exception('Top-up request not found');

    final status = approve ? 'approved' : 'rejected';
    await _client.from('topups').update({'status': status}).eq('id', topUpId);

    if (approve) {
      final stationId = topUp['loading_station_id']?.toString();
      final riderId = topUp['rider_id']?.toString();
      final totalCredited = (topUp['total_credited'] as num?)?.toDouble() ?? 0;

      if (stationId != null) {
        try {
          await _client.rpc('increment_loading_station_balance', params: {
            'station_id': stationId,
            'credited_amount': totalCredited,
          });
        } catch (_) {
          final station = await fetchStationProfile(stationId);
          await _client.from('loading_stations').update({
            'balance': station.balance + totalCredited,
          }).eq('id', stationId);
        }
      }

      if (riderId != null && stationId != null) {
        try {
          await _client.rpc('increment_rider_balance', params: {
            'rider_id': riderId,
            'credited_amount': totalCredited,
          });
        } catch (_) {
          final rider = await _client.from('riders').select('balance').eq('id', riderId).maybeSingle();
          if (rider != null) {
            final currentBalance = (rider['balance'] as num?)?.toDouble() ?? 0;
            await _client.from('riders').update({
              'balance': currentBalance + totalCredited,
            }).eq('id', riderId);
          }
        }
      }
    }
  }

  Future<void> requestTopUpFromRider({
    required String stationId,
    required double amount,
  }) async {
    final station = await fetchStationProfile(stationId);
    final bonus = amount * station.bonusRate;

    await _client.from('topups').insert({
      'loading_station_id': stationId,
      'rider_id': _client.auth.currentUser?.id,
      'amount': amount,
      'bonus_amount': bonus,
      'total_credited': amount + bonus,
      'status': 'pending',
      'initiated_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> requestTopUpFromStation({
    required double amount,
  }) async {
    final stationId = _client.auth.currentUser?.id;
    if (stationId == null) throw Exception('Not authenticated');
    
    final station = await fetchStationProfile(stationId);
    final hub = station.businessHub;
    if (hub == null) throw Exception('Loading station not connected to a business hub');

    final bonus = amount * hub.bonusRate;

    await _client.from('topups').insert({
      'business_hub_id': hub.id,
      'loading_station_id': stationId,
      'amount': amount,
      'bonus_amount': bonus,
      'total_credited': amount + bonus,
      'status': 'pending',
      'initiated_by': stationId,
    });
  }

  Future<void> createTopUp({
    required String stationId,
    required double amount,
    double? bonusOverride,
    String? riderId,
  }) async {
    final station = await fetchStationProfile(stationId);
    final bonus = bonusOverride ?? amount * station.bonusRate;

    await _client.from('topups').insert({
      'loading_station_id': stationId,
      'rider_id': riderId,
      'amount': amount,
      'bonus_amount': bonus,
      'total_credited': amount + bonus,
      'status': 'pending',
      'initiated_by': _client.auth.currentUser?.id,
    });
  }

  Future<String> generateLoadingStationCode(String stationId, {bool persist = true}) async {
    final newCode = 'LS${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    if (persist) {
      await _client.from('loading_stations').update({'ls_code': newCode}).eq('id', stationId);
    }
    return newCode;
  }

  Future<List<String>> uploadDocuments({
    required String bucket,
    required List<PlatformFile> files,
  }) async {
    final paths = <String>[];
    for (final file in files) {
      if (file.path == null) continue;
      final filename = '${const Uuid().v4()}-${file.name}';
      final bytes = await File(file.path!).readAsBytes();
      final path = await _client.storage.from(bucket).uploadBinary(filename, bytes, fileOptions: const FileOptions(upsert: true));
      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      paths.add(publicUrl);
    }
    return paths;
  }
}

