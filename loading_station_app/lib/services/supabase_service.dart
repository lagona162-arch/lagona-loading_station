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
        .select('id,name,ls_code,address,balance,bonus_rate,business_hub_id,business_hubs (id,name,bh_code,municipality,bonus_rate)')
        .eq('id', stationId)
        .maybeSingle();

    if (data == null) throw Exception('Station profile not found');
    
    // If business_hubs is null but business_hub_id exists, fetch it separately
    if (data['business_hubs'] == null && data['business_hub_id'] != null) {
      final hubId = data['business_hub_id'].toString();
      final hubData = await _client
          .from('business_hubs')
          .select('id,name,bh_code,municipality,bonus_rate')
          .eq('id', hubId)
          .maybeSingle();
      
      if (hubData != null) {
        data['business_hubs'] = hubData;
      }
    }
    
    return LoadingStationProfile.fromMap(data);
  }

  Future<LoadingStationProfile?> fetchStationByLSCode(String lsCode) async {
    final trimmedCode = lsCode.trim();
    
    // Try exact match first (case-sensitive)
    var data = await _client
        .from('loading_stations')
        .select('id,name,ls_code,address,balance,bonus_rate,business_hubs (id,name,bh_code,municipality,bonus_rate)')
        .eq('ls_code', trimmedCode)
        .maybeSingle();

    // If not found, try case-insensitive match using ilike (PostgreSQL)
    if (data == null) {
      final allStations = await _client
          .from('loading_stations')
          .select('id,name,ls_code,address,balance,bonus_rate,business_hubs (id,name,bh_code,municipality,bonus_rate)')
          .limit(1000); // Get all stations to filter client-side
      
      final matching = List<Map<String, dynamic>>.from(allStations)
          .where((station) {
            final dbCode = station['ls_code']?.toString().trim() ?? '';
            final match = dbCode.toUpperCase() == trimmedCode.toUpperCase();
            if (match) {
            }
            return match;
          })
          .toList();
      
      if (matching.isNotEmpty) {
        data = matching.first;
      }
    } else {
    }

    if (data == null) {
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
      throw Exception('Invalid Loading Station Code. Please check your LSCODE and try again.');
    }
    
    final stationId = station['id']?.toString() ?? '';
    
    // Store the verified station ID in shared preferences
    // This allows the user to access this station's data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('verified_station_id_$userId', stationId);
    
    // Verification successful - station ID stored, user can proceed
  }

  Future<List<RiderProfile>> fetchRiders(String stationId) async {
    final result = await _client
        .from('riders')
        .select('id,status,balance,commission_rate,vehicle_type,latitude,longitude,current_address,last_active,users(full_name,phone,access_status,is_active),merchant_rider_preferences(priority_order)')
        .eq('loading_station_id', stationId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result).map(RiderProfile.fromMap).toList();
  }
  
  /// Fetch rider documents for a specific rider by ID
  /// Handles various field name variations for document and vehicle photo URLs
  Future<Map<String, String?>> fetchRiderDocuments(String riderId) async {
    try {
      final result = await _client
          .from('riders')
          .select('*')
          .eq('id', riderId)
          .maybeSingle();
      
      if (result == null) return {};
      
      // Debug: Log all keys to see what fields are actually available
      debugPrint('Available rider fields: ${result.keys.toList()}');
      
      // Try multiple possible field name variations
      final docs = {
        // Profile photo - try multiple variations
        'profile_photo_url': result['profile_photo_url']?.toString() ?? 
                           result['profile_picture_url']?.toString() ?? 
                           result['profile_photo']?.toString(),
        // Driver's license
        'drivers_license_url': result['drivers_license_url']?.toString() ?? 
                             result['driver_license_url']?.toString() ?? 
                             result['license_url']?.toString() ??
                             result['drivers_license']?.toString(),
        // License card
        'license_card_url': result['license_card_url']?.toString() ?? 
                          result['license_card']?.toString(),
        // Official Receipt (OR) - try multiple variations
        'official_receipt_url': result['official_receipt_url']?.toString() ?? 
                              result['or_url']?.toString() ?? 
                              result['or']?.toString() ??
                              result['official_receipt']?.toString(),
        // Certificate of Registration (CR) - try multiple variations
        'certificate_of_registration_url': result['certificate_of_registration_url']?.toString() ?? 
                                         result['cr_url']?.toString() ?? 
                                         result['cr']?.toString() ??
                                         result['certificate_of_registration']?.toString(),
        // Vehicle/Motor photos - try multiple naming conventions including all variations
        'vehicle_front_url': _getFieldValue(result, [
          'vehicle_front_picture_url', // Actual field name from database
          'vehicle_front_url', 'motor_front_url', 'vehicle_front_photo', 'motor_front_photo',
          'vehicle_front', 'motor_front', 'front_photo_url', 'front_photo',
          'vehicle_front_image', 'motor_front_image', 'front_image_url'
        ]),
        'vehicle_side_url': _getFieldValue(result, [
          'vehicle_side_picture_url', // Actual field name from database
          'vehicle_side_url', 'motor_side_url', 'vehicle_side_photo', 'motor_side_photo',
          'vehicle_side', 'motor_side', 'side_photo_url', 'side_photo',
          'vehicle_side_image', 'motor_side_image', 'side_image_url'
        ]),
        'vehicle_back_url': _getFieldValue(result, [
          'vehicle_back_picture_url', // Actual field name from database
          'vehicle_back_url', 'motor_back_url', 'vehicle_back_photo', 'motor_back_photo',
          'vehicle_back', 'motor_back', 'back_photo_url', 'back_photo',
          'vehicle_back_image', 'motor_back_image', 'back_image_url'
        ]),
      };
      
      // Debug: Log what we found
      debugPrint('Found vehicle photos - Front: ${docs['vehicle_front_url'] != null}, Side: ${docs['vehicle_side_url'] != null}, Back: ${docs['vehicle_back_url'] != null}');
      
      return docs;
    } catch (e) {
      // If columns don't exist, return empty map
      debugPrint('Error fetching rider documents: $e');
      return {};
    }
  }
  
  /// Helper method to get field value trying multiple possible field names
  String? _getFieldValue(Map<String, dynamic> data, List<String> possibleNames) {
    for (final name in possibleNames) {
      final value = data[name]?.toString();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<List<MerchantProfile>> fetchMerchants(String stationId) async {
    try {
      
      // First, get the loading station with its business_hub_id
      final station = await _client
          .from('loading_stations')
          .select('id,business_hub_id')
          .eq('id', stationId)
          .maybeSingle();
      
      if (station == null) {
        return [];
      }
      
      final businessHubId = station['business_hub_id'];
      
      // Get all loading stations in the same business hub
      final stationsInHub = await _client
          .from('loading_stations')
          .select('id')
          .eq('business_hub_id', businessHubId);
      
      final stationIds = stationsInHub.map((s) => s['id'].toString()).toList();
      
      // Query merchants where loading_station_id matches any loading station in the same business hub
      final result = await _client
          .from('merchants')
          .select('id,business_name,address,access_status,gcash_number,merchant_rider_preferences(id)')
          .inFilter('loading_station_id', stationIds)
          .order('created_at', ascending: false);
      
      
      return List<Map<String, dynamic>>.from(result).map(MerchantProfile.fromMap).toList();
    } catch (e, stack) {
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
    // Fetch topups where loading_station_id matches this station
    // This includes:
    // 1. Rider top-up requests (rider_id is set, loading_station_id = stationId)
    // 2. Station top-ups (no rider_id, loading_station_id = stationId)
    final topupsResult = await _client
        .from('topups')
        .select('id,amount,bonus_amount,total_credited,status,created_at,rider_id,business_hub_id,loading_station_id,riders(users(full_name)),initiated_by_user:users!topups_initiated_by_fkey(full_name)')
        .eq('loading_station_id', stationId)
        .order('created_at', ascending: false)
        .limit(50);
    
    final topups = List<Map<String, dynamic>>.from(topupsResult).map((map) {
      // Debug: Log the data to see what we're getting
      final summary = TopUpSummary.fromMap(map);
      return summary;
    }).toList();
    
    // Also fetch topup_requests where loading_station_id matches this station
    // These could be:
    // 1. Requests FROM this station TO business hub (requested_by = station user)
    // 2. Requests FROM riders TO this station (requested_by = rider user)
    final currentUserId = _client.auth.currentUser?.id;
    final requestsResult = await _client
        .from('topup_requests')
        .select('id,requested_amount,bonus_amount,total_credited,status,created_at,business_hub_id,loading_station_id,requested_by,loading_stations(name),users!requested_by(full_name,role)')
        .eq('loading_station_id', stationId)
        .order('created_at', ascending: false)
        .limit(50);
    
    // Transform topup_requests to TopUpSummary format
    // Check requested_by to determine if it's from the logged-in user (station-to-hub) or a rider (rider-to-station)
    final requests = await Future.wait(
      List<Map<String, dynamic>>.from(requestsResult).map((map) async {
        final requestedBy = map['requested_by']?.toString();
        final businessHubId = map['business_hub_id']?.toString();
        final loadingStationId = map['loading_station_id']?.toString();
        final requestedByUser = map['users'];
        final requestedByRole = requestedByUser?['role']?.toString();
        final requestedAmount = (map['requested_amount'] as num?)?.toDouble() ?? 0;
        final bonusRate = (map['bonus_rate'] as num?)?.toDouble() ?? 0;
        var bonusAmount = (map['bonus_amount'] as num?)?.toDouble();
        var totalCredited = (map['total_credited'] as num?)?.toDouble();
        
        
        String? riderId;
        bool isFromStation = false;
        
        // If requested_by is the current logged-in user, it's a station-to-hub request
        if (requestedBy == currentUserId) {
          isFromStation = true;
        } 
        // If requested_by is a rider, check if that rider belongs to this station
        else if (requestedByRole == 'rider' && requestedBy != null) {
          final rider = await _client
              .from('riders')
              .select('id,loading_station_id')
              .eq('id', requestedBy)
              .maybeSingle();
          
          if (rider != null && rider['loading_station_id']?.toString() == stationId) {
            riderId = requestedBy;
            
            // Calculate bonus_amount and total_credited if they're null (for rider requests)
            // Always use commission_settings rate for riders, not the stored bonus_rate
            bool needsUpdate = false;
            if (bonusAmount == null && requestedAmount > 0) {
              // Always fetch the correct rate from commission_settings for riders
              final riderBonusRate = await getCommissionRateForRole('rider');
              bonusAmount = requestedAmount * riderBonusRate;
              needsUpdate = true;
            }
            
            if (totalCredited == null && requestedAmount > 0) {
              totalCredited = requestedAmount + (bonusAmount ?? 0);
              needsUpdate = true;
            }
            
            // Update the database record if we calculated missing values
            if (needsUpdate && map['status']?.toString() == 'pending') {
              try {
                // Get the correct bonus_rate for riders from commission_settings
                final riderBonusRate = await getCommissionRateForRole('rider');
                await _client.from('topup_requests').update({
                  'bonus_rate': riderBonusRate, // Update bonus_rate to match commission_settings
                  if (bonusAmount != null) 'bonus_amount': bonusAmount,
                  if (totalCredited != null) 'total_credited': totalCredited,
                }).eq('id', map['id']);
              } catch (e) {
                // Continue anyway - we'll use the calculated values for display
              }
            }
          }
        }
        
        return {
          'id': map['id'],
          'amount': requestedAmount,
          'bonus_amount': bonusAmount,
          'total_credited': totalCredited,
          'status': map['status'],
          'created_at': map['created_at'],
          'loading_stations': map['loading_stations'],
          'initiated_by_user': requestedByUser,
          'rider_id': riderId, // Set if requested_by is a rider from this station
          'business_hub_id': isFromStation ? businessHubId : null, // Only set if it's a station-to-hub request
          '_isFromTopupRequests': true, // Flag to identify this came from topup_requests table
        };
      }),
    );
    
    final requestSummaries = requests.map((map) {
      final summary = TopUpSummary.fromMap(map);
      return summary;
    }).toList();
    
    // Combine and sort by created_at
    final all = [...topups, ...requestSummaries];
    all.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    
    return all.take(50).toList();
  }

  Future<List<TopUpSummary>> fetchPendingTopUpRequests(String stationId) async {
    final result = await _client
        .from('topups')
        .select('id,amount,bonus_amount,total_credited,status,created_at,rider_id,business_hub_id,riders(users(full_name)),initiated_by_user:users!topups_initiated_by_fkey(full_name)')
        .eq('loading_station_id', stationId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result).map(TopUpSummary.fromMap).toList();
  }

  Future<List<TopUpSummary>> fetchPendingTopUpRequestsForHub(String hubId) async {
    // Fetch requests directly by business_hub_id since it's now populated
    final result = await _client
        .from('topup_requests')
        .select('id,requested_amount,bonus_amount,total_credited,status,created_at,loading_stations(name),users!requested_by(full_name)')
        .eq('business_hub_id', hubId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result).map((map) {
      // Transform topup_requests format to TopUpSummary format
      return {
        'id': map['id'],
        'amount': map['requested_amount'],
        'bonus_amount': map['bonus_amount'],
        'total_credited': map['total_credited'],
        'status': map['status'],
        'created_at': map['created_at'],
        'loading_stations': map['loading_stations'],
        'initiated_by_user': map['users'],
        'rider_id': null,
        'business_hub_id': hubId,
      };
    }).map(TopUpSummary.fromMap).toList();
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

  Future<void> approveRider(String riderId, {required bool approved, required String stationId}) async {
    // Verify that the rider belongs to this loading station
    final rider = await _client
        .from('riders')
        .select('loading_station_id')
        .eq('id', riderId)
        .maybeSingle();
    
    if (rider == null) {
      throw Exception('Rider not found');
    }
    
    final riderStationId = rider['loading_station_id']?.toString();
    if (riderStationId != stationId) {
      throw Exception('This rider does not belong to your loading station. You can only approve riders with your LSCODE.');
    }
    
    // Update both access_status and is_active fields as per the admin guide
    await _client
        .from('users')
        .update({
          'access_status': approved ? 'approved' : 'rejected',
          'is_active': approved,
        })
        .eq('id', riderId);
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
    // Check if the record already exists
    final existing = await _client
        .from('merchant_rider_preferences')
        .select('id')
        .eq('rider_id', riderId)
        .eq('merchant_id', merchantId)
        .maybeSingle();

    if (existing != null) {
      // Update existing record
      await _client
          .from('merchant_rider_preferences')
          .update({'priority_order': priority})
          .eq('rider_id', riderId)
          .eq('merchant_id', merchantId);
    } else {
      // Insert new record
      await _client.from('merchant_rider_preferences').insert({
        'rider_id': riderId,
        'merchant_id': merchantId,
        'priority_order': priority,
      });
    }
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
    String? stationId, // Current station ID to verify ownership
  }) async {
    final topUp = await _client
        .from('topups')
        .select('*,riders(loading_station_id)')
        .eq('id', topUpId)
        .maybeSingle();
    
    if (topUp == null) throw Exception('Top-up request not found');

    // Verify this is a rider top-up request that belongs to the current station
    final riderId = topUp['rider_id']?.toString();
    final topUpStationId = topUp['loading_station_id']?.toString();
    
    if (riderId == null) {
      throw Exception('This top-up is not from a rider. Only rider top-ups can be approved by loading stations.');
    }
    
    // Verify the rider belongs to this station
    if (stationId != null) {
      final rider = topUp['riders'];
      String? riderStationId;
      
      if (rider is Map && rider['loading_station_id'] != null) {
        riderStationId = rider['loading_station_id'].toString();
      } else {
        // Fallback: check if topup's loading_station_id matches
        riderStationId = topUpStationId;
      }
      
      if (riderStationId != stationId) {
        throw Exception('This top-up request does not belong to your loading station. You can only approve requests from your own riders.');
      }
    }

    final status = approve ? 'approved' : 'rejected';
    await _client.from('topups').update({'status': status}).eq('id', topUpId);

    if (approve) {
      final totalCredited = (topUp['total_credited'] as num?)?.toDouble() ?? 0;

      // Credit the rider's balance
      if (riderId != null) {
        try {
          await _client.rpc('increment_rider_balance', params: {
            'rider_id': riderId,
            'credited_amount': totalCredited,
          });
        } catch (e) {
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

  Future<void> respondTopUpRequest({
    required String requestId,
    required bool approve,
    String? rejectionReason,
    String? stationId, // Current station ID to verify ownership for rider requests
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    final request = await _client
        .from('topup_requests')
        .select('*,users!requested_by(role)')
        .eq('id', requestId)
        .maybeSingle();
    if (request == null) throw Exception('Top-up request not found');

    final requestedBy = request['requested_by']?.toString();
    final businessHubId = request['business_hub_id']?.toString();
    final loadingStationId = request['loading_station_id']?.toString();
    final requestedByUser = request['users'];
    final requestedByRole = requestedByUser?['role']?.toString();
    
    
    // Check if this is a rider request (requested_by is a rider) or station-to-hub request (requested_by is the logged-in user)
    bool isRiderRequest = false;
    bool isStationToHubRequest = false;
    String? riderId;
    
    // If requested_by is the current logged-in user, it's a station-to-hub request
    if (requestedBy == currentUserId) {
      isStationToHubRequest = true;
    } 
    // If requested_by is a rider, verify it belongs to this station
    else if (requestedByRole == 'rider' && requestedBy != null && stationId != null) {
      final rider = await _client
          .from('riders')
          .select('id,loading_station_id')
          .eq('id', requestedBy)
          .maybeSingle();
      
      if (rider != null && rider['loading_station_id']?.toString() == stationId) {
        isRiderRequest = true;
        riderId = requestedBy;
      } else {
        throw Exception('This top-up request does not belong to your loading station. You can only approve requests from your own riders.');
      }
    } else if (requestedByRole == 'rider' && stationId == null) {
      // If stationId is not provided, we can't verify, but still treat as rider request
      isRiderRequest = true;
      riderId = requestedBy;
    }

    final status = approve ? 'approved' : 'rejected';
    
    // Verify currentUserId exists in users table before setting processed_by
    // If not, try using loading_station_id (which should be a valid user ID for loading stations)
    String? validProcessedBy;
    if (currentUserId != null) {
      try {
        final user = await _client
            .from('users')
            .select('id')
            .eq('id', currentUserId)
            .maybeSingle();
        if (user != null) {
          validProcessedBy = currentUserId;
        } else {
          // Try using loading_station_id if it's a valid user ID
          if (loadingStationId != null) {
            final stationUser = await _client
                .from('users')
                .select('id')
                .eq('id', loadingStationId)
                .maybeSingle();
            if (stationUser != null) {
              validProcessedBy = loadingStationId;
            } else {
              validProcessedBy = null; // Will be omitted from update if null
            }
          }
        }
      } catch (e) {
        // Try loading_station_id as fallback
        if (loadingStationId != null) {
          try {
            final stationUser = await _client
                .from('users')
                .select('id')
                .eq('id', loadingStationId)
                .maybeSingle();
            if (stationUser != null) {
              validProcessedBy = loadingStationId;
            }
          } catch (_) {
            // Ignore, will be null
          }
        }
      }
    } else if (loadingStationId != null) {
      // If no current user, try using loading_station_id
      try {
        final stationUser = await _client
            .from('users')
            .select('id')
            .eq('id', loadingStationId)
            .maybeSingle();
        if (stationUser != null) {
          validProcessedBy = loadingStationId;
        }
      } catch (_) {
        // Ignore
      }
    }
    
    // Update the request status and set processed_by and processed_at
    await _client.from('topup_requests').update({
      'status': status,
      if (validProcessedBy != null) 'processed_by': validProcessedBy,
      'processed_at': DateTime.now().toIso8601String(),
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    }).eq('id', requestId);

    if (approve) {
      final totalCredited = (request['total_credited'] as num?)?.toDouble() ?? 0;

      if (isRiderRequest && riderId != null) {
        // Credit the rider's balance and deduct from loading station's balance
        
        // Credit rider's balance
        try {
          await _client.rpc('increment_rider_balance', params: {
            'rider_id': riderId,
            'credited_amount': totalCredited,
          });
        } catch (e) {
          final rider = await _client.from('riders').select('balance').eq('id', riderId).maybeSingle();
          if (rider != null) {
            final currentBalance = (rider['balance'] as num?)?.toDouble() ?? 0;
            await _client.from('riders').update({
              'balance': currentBalance + totalCredited,
            }).eq('id', riderId);
          }
        }
        
        // Deduct from loading station's balance
        if (loadingStationId != null) {
          try {
            // Use RPC to decrement station balance (if available) or direct update
            final station = await fetchStationProfile(loadingStationId);
            final currentStationBalance = station.balance;
            if (currentStationBalance < totalCredited) {
              throw Exception('Insufficient station balance. Current: $currentStationBalance, Required: $totalCredited');
            }
            final newStationBalance = currentStationBalance - totalCredited;
            await _client.from('loading_stations').update({
              'balance': newStationBalance,
            }).eq('id', loadingStationId);
          } catch (e) {
            // Revert rider balance if station deduction fails
            try {
              final rider = await _client.from('riders').select('balance').eq('id', riderId).maybeSingle();
              if (rider != null) {
                final riderBalance = (rider['balance'] as num?)?.toDouble() ?? 0;
                await _client.from('riders').update({
                  'balance': riderBalance - totalCredited,
                }).eq('id', riderId);
              }
            } catch (revertError) {
            }
            rethrow;
          }
        }
      } else if (isStationToHubRequest && loadingStationId != null && totalCredited > 0) {
        // Credit the loading station's balance (station-to-hub request)
        // Note: This should only be called by business hub, not loading station
        try {
          await _client.rpc('increment_loading_station_balance', params: {
            'station_id': loadingStationId,
            'credited_amount': totalCredited,
          });
        } catch (e) {
          final station = await fetchStationProfile(loadingStationId);
          final newBalance = station.balance + totalCredited;
          await _client.from('loading_stations').update({
            'balance': newBalance,
          }).eq('id', loadingStationId);
        }
      }
    }
  }

  Future<void> requestTopUpFromRider({
    required String stationId,
    required double amount,
  }) async {
    final station = await fetchStationProfile(stationId);
    
    // Get commission rate from commission_settings for rider role
    final bonusRate = await getCommissionRateForRole('rider');
    final bonus = amount * bonusRate;

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

  Future<double> getCommissionRateForRole(String role) async {
    // Fetch commission rate from commission_settings table based on role
    final result = await _client
        .from('commission_settings')
        .select('percentage')
        .eq('role', role)
        .maybeSingle();
    
    if (result == null || result['percentage'] == null) {
      return 0.0;
    }
    
    final percentage = (result['percentage'] as num).toDouble();
    // Convert percentage to decimal (e.g., 10% -> 0.10)
    return percentage / 100.0;
  }

  Future<void> requestTopUpFromStation({
    required double amount,
    required String stationId,
  }) async {
    if (stationId.isEmpty) throw Exception('Station ID is required');
    
    // Use fetchStationProfile to get the station with business hub info
    final station = await fetchStationProfile(stationId);
    final hub = station.businessHub;
    
    if (hub == null) {
      throw Exception('Loading station not connected to a business hub');
    }
    
    // Get commission rate from commission_settings for loading_station role
    final bonusRate = await getCommissionRateForRole('loading_station');
    final bonus = amount * bonusRate;
    final totalCredited = amount + bonus;


    // Insert into topup_requests table so business hub can see and approve it
    // Both business_hub_id and loading_station_id are set to identify both the hub and the requesting station
    await _client.from('topup_requests').insert({
      'requested_by': stationId,
      'business_hub_id': hub.id, // Set to the business hub ID so it can query requests
      'loading_station_id': stationId, // Set to identify the requesting loading station
      'requested_amount': amount,
      'bonus_rate': bonusRate,
      'bonus_amount': bonus,
      'total_credited': totalCredited,
      'status': 'pending',
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

