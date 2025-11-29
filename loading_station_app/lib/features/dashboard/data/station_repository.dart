import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/station_models.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_providers.dart';

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return StationRepository(service);
});

final stationDashboardProvider = FutureProvider<StationDashboardData>((ref) async {
  final stationId = ref.watch(currentStationIdProvider);
  final repository = ref.watch(stationRepositoryProvider);

  if (!SupabaseConfig.isConfigured || stationId == null) {
    return StationDashboardData.demo();
  }
  return repository.fetchDashboard(stationId);
});

final stationMerchantsProvider = FutureProvider<List<MerchantProfile>>((ref) async {
  final stationId = ref.watch(currentStationIdProvider);
  final repository = ref.watch(stationRepositoryProvider);

  if (!SupabaseConfig.isConfigured || stationId == null) {
    return StationDashboardData.demo().merchants;
  }

  return repository.fetchStationMerchants(stationId);
});

class StationRepository {
  StationRepository(this._service);

  final SupabaseService _service;

  Future<StationDashboardData> fetchDashboard(String stationId) async {
    try {
      final results = await Future.wait([
        _service.fetchStationProfile(stationId),
        _service.fetchRiders(stationId),
        _service.fetchMerchants(stationId),
        _service.fetchDeliveries(stationId),
        _service.fetchTopUps(stationId),
      ]);

      final riders = List<RiderProfile>.from(results[1] as List<RiderProfile>);
      final merchants = List<MerchantProfile>.from(results[2] as List<MerchantProfile>);

      return StationDashboardData(
        station: results[0] as LoadingStationProfile,
        riders: riders,
        merchants: merchants,
        deliveries: List<DeliverySummary>.from(results[3] as List<DeliverySummary>),
        topUps: List<TopUpSummary>.from(results[4] as List<TopUpSummary>),
        pendingRiderRequests: riders.where((r) => r.status == RiderStatus.pending).length,
        pendingMerchantRequests: merchants.where((m) => (m.status ?? '').toLowerCase() == 'pending').length,
        lastUpdated: DateTime.now(),
      );
    } catch (error, stack) {
      debugPrint('StationRepository.fetchDashboard error: $error');
      debugPrintStack(stackTrace: stack);
      return StationDashboardData.demo();
    }
  }

  Future<List<MerchantProfile>> fetchStationMerchants(String stationId) async {
    try {
      return await _service.fetchMerchants(stationId);
    } catch (error, stack) {
      debugPrint('StationRepository.fetchStationMerchants error: $error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> approveRider(String riderId, {required bool approved}) => _service.approveRider(riderId, approved: approved);

  Future<void> approveMerchant(String merchantId, {required bool approved}) => _service.approveMerchant(merchantId, approved: approved);

  Future<void> updateRiderPriority(String riderId, int priority) => _service.updateRiderPriority(riderId, priority);

  Future<void> updateRiderPriorityForMerchant({
    required String riderId,
    required String merchantId,
    required int priority,
  }) => _service.updateRiderPriorityForMerchant(
        riderId: riderId,
        merchantId: merchantId,
        priority: priority,
      );

  Future<String> regenerateLsCode(String stationId) => _service.generateLoadingStationCode(stationId);

  Future<void> createTopUp({
    required String stationId,
    required double amount,
    double? bonusOverride,
    String? riderId,
  }) =>
      _service.createTopUp(
        stationId: stationId,
        amount: amount,
        bonusOverride: bonusOverride,
        riderId: riderId,
      );

  Future<void> requestTopUpFromStation({required double amount}) => _service.requestTopUpFromStation(amount: amount);

  Future<void> respondTopUp({required String topUpId, required bool approve}) => _service.respondTopUp(
        topUpId: topUpId,
        approve: approve,
      );

  Future<List<TopUpSummary>> fetchPendingTopUpRequests(String stationId) => _service.fetchPendingTopUpRequests(stationId);
}

