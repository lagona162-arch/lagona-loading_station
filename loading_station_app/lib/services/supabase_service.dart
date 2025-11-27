import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        .select('id,amount,bonus_amount,total_credited,created_at,riders(users(full_name)),initiated_by_user:users!topups_initiated_by_fkey(full_name)')
        .or('loading_station_id.eq.$stationId,business_hub_id.eq.${_client.auth.currentUser?.id}')
        .order('created_at', ascending: false)
        .limit(50);
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

  Future<void> respondTopUp({
    required String topUpId,
    required bool approve,
  }) async {
    final status = approve ? 'approved' : 'rejected';
    await _client.from('topups').update({'status': status}).eq('id', topUpId);
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
      'initiated_by': _client.auth.currentUser?.id,
    });

    try {
      await _client.rpc('increment_loading_station_balance', params: {
        'station_id': stationId,
        'credited_amount': amount + bonus,
      });
    } catch (_) {
      await _client.from('loading_stations').update({
        'balance': station.balance + amount + bonus,
      }).eq('id', stationId);
    }
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

