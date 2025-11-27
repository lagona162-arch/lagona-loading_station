import 'package:equatable/equatable.dart';

enum DeliveryType { pabili, padala }

class BusinessHubProfile extends Equatable {
  const BusinessHubProfile({
    required this.id,
    required this.name,
    required this.code,
    required this.municipality,
    required this.bonusRate,
  });

  final String id;
  final String name;
  final String code;
  final String? municipality;
  final double bonusRate;

  factory BusinessHubProfile.fromMap(Map<String, dynamic> map) => BusinessHubProfile(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Business Hub',
        code: map['bh_code']?.toString() ?? '--',
        municipality: map['municipality']?.toString(),
        bonusRate: (map['bonus_rate'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [id, name, code, municipality, bonusRate];
}

class LoadingStationProfile extends Equatable {
  const LoadingStationProfile({
    required this.id,
    required this.name,
    required this.lsCode,
    required this.address,
    required this.balance,
    required this.bonusRate,
    this.businessHub,
    this.documents,
  });

  final String id;
  final String name;
  final String lsCode;
  final String? address;
  final double balance;
  final double bonusRate;
  final BusinessHubProfile? businessHub;
  final List<String>? documents;

  factory LoadingStationProfile.fromMap(Map<String, dynamic> map) => LoadingStationProfile(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Loading Station',
        lsCode: map['ls_code']?.toString() ?? '--',
        address: map['address']?.toString(),
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        bonusRate: (map['bonus_rate'] as num?)?.toDouble() ?? 0,
        businessHub: map['business_hubs'] != null ? BusinessHubProfile.fromMap(map['business_hubs'] as Map<String, dynamic>) : null,
      );

  LoadingStationProfile copyWith({
    double? balance,
    double? bonusRate,
    String? lsCode,
  }) =>
      LoadingStationProfile(
        id: id,
        name: name,
        lsCode: lsCode ?? this.lsCode,
        address: address,
        balance: balance ?? this.balance,
        bonusRate: bonusRate ?? this.bonusRate,
        businessHub: businessHub,
        documents: documents,
      );

  @override
  List<Object?> get props => [id, name, lsCode, balance, bonusRate, businessHub];
}

class CommissionConfig extends Equatable {
  const CommissionConfig({
    required this.hubPercentage,
    required this.stationPercentage,
    required this.riderPercentage,
    required this.shareholderPercentage,
  });

  final double hubPercentage;
  final double stationPercentage;
  final double riderPercentage;
  final double shareholderPercentage;

  factory CommissionConfig.fromMap(Map<String, dynamic> map) => CommissionConfig(
        hubPercentage: (map['hub'] as num?)?.toDouble() ?? 50,
        stationPercentage: (map['loading_station'] as num?)?.toDouble() ?? 25,
        riderPercentage: (map['rider'] as num?)?.toDouble() ?? 20,
        shareholderPercentage: (map['shareholder'] as num?)?.toDouble() ?? 5,
      );

  CommissionConfig copyWith({
    double? hub,
    double? station,
    double? rider,
    double? shareholder,
  }) =>
      CommissionConfig(
        hubPercentage: hub ?? hubPercentage,
        stationPercentage: station ?? stationPercentage,
        riderPercentage: rider ?? riderPercentage,
        shareholderPercentage: shareholder ?? shareholderPercentage,
      );

  @override
  List<Object?> get props => [hubPercentage, stationPercentage, riderPercentage, shareholderPercentage];
}

enum RiderStatus { pending, available, busy, offline }

class RiderProfile extends Equatable {
  const RiderProfile({
    required this.id,
    required this.name,
    required this.status,
    required this.balance,
    required this.commissionRate,
    required this.priorityLevel,
    this.vehicleType,
  });

  final String id;
  final String name;
  final RiderStatus status;
  final double balance;
  final double commissionRate;
  final int priorityLevel;
  final String? vehicleType;

  factory RiderProfile.fromMap(Map<String, dynamic> map) => RiderProfile(
        id: map['id']?.toString() ?? '',
        name: map['users']?['full_name']?.toString() ?? map['full_name']?.toString() ?? 'Rider',
        status: _parseStatus(map['status']),
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
        priorityLevel: (map['priority_order'] as num?)?.toInt() ?? 0,
        vehicleType: map['vehicle_type']?.toString(),
      );

  static RiderStatus _parseStatus(dynamic raw) {
    final value = raw?.toString().toLowerCase() ?? '';
    switch (value) {
      case 'available':
        return RiderStatus.available;
      case 'busy':
        return RiderStatus.busy;
      case 'offline':
        return RiderStatus.offline;
      default:
        return RiderStatus.pending;
    }
  }

  @override
  List<Object?> get props => [id, name, status, balance, commissionRate, priorityLevel, vehicleType];
}

class MerchantProfile extends Equatable {
  const MerchantProfile({
    required this.id,
    required this.businessName,
    required this.address,
    required this.ridersHandled,
    this.status,
    this.gcashNumber,
  });

  final String id;
  final String businessName;
  final String? address;
  final int ridersHandled;
  final String? status;
  final String? gcashNumber;

  factory MerchantProfile.fromMap(Map<String, dynamic> map) => MerchantProfile(
        id: map['id']?.toString() ?? '',
        businessName: map['business_name']?.toString() ?? 'Merchant',
        address: map['address']?.toString(),
        status: map['access_status']?.toString(),
        gcashNumber: map['gcash_number']?.toString(),
        ridersHandled: (map['riders_count'] as num?)?.toInt() ??
            (map['riders'] as List<dynamic>?)?.length ??
            (map['merchant_rider_preferences'] as List<dynamic>?)?.length ??
            0,
      );

  @override
  List<Object?> get props => [id, businessName, address, ridersHandled, status, gcashNumber];
}

class DeliverySummary extends Equatable {
  const DeliverySummary({
    required this.id,
    required this.type,
    required this.status,
    required this.merchantName,
    required this.riderName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.total,
    required this.createdAt,
    this.distanceKm,
  });

  final String id;
  final DeliveryType type;
  final String status;
  final String merchantName;
  final String? riderName;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double total;
  final DateTime? createdAt;
  final double? distanceKm;

  factory DeliverySummary.fromMap(Map<String, dynamic> map) => DeliverySummary(
        id: map['id']?.toString() ?? '',
        type: _parseType(map['type']),
        status: map['status']?.toString() ?? 'pending',
        merchantName: map['merchants']?['business_name']?.toString() ?? 'Merchant',
        riderName: map['riders']?['users']?['full_name']?.toString() ?? map['riders']?['full_name']?.toString(),
        pickupAddress: map['pickup_address']?.toString(),
        dropoffAddress: map['dropoff_address']?.toString(),
        total: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
        createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
        distanceKm: (map['distance_km'] as num?)?.toDouble(),
      );

  static DeliveryType _parseType(dynamic raw) {
    final value = raw?.toString().toLowerCase() ?? '';
    return value == 'padala' ? DeliveryType.padala : DeliveryType.pabili;
  }

  @override
  List<Object?> get props => [id, type, status, merchantName, riderName, total, createdAt];
}

class TopUpSummary extends Equatable {
  const TopUpSummary({
    required this.id,
    required this.amount,
    required this.bonus,
    required this.totalCredited,
    required this.createdAt,
    this.forRiderName,
    this.requestorName,
  });

  final String id;
  final double amount;
  final double bonus;
  final double totalCredited;
  final DateTime? createdAt;
  final String? forRiderName;
  final String? requestorName;

  factory TopUpSummary.fromMap(Map<String, dynamic> map) => TopUpSummary(
        id: map['id']?.toString() ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        bonus: (map['bonus_amount'] as num?)?.toDouble() ?? 0,
        totalCredited: (map['total_credited'] as num?)?.toDouble() ?? 0,
        createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
        forRiderName: map['riders']?['users']?['full_name']?.toString(),
        requestorName: map['initiated_by_user']?['full_name']?.toString(),
      );

  @override
  List<Object?> get props => [id, amount, bonus, totalCredited, createdAt, forRiderName];
}

class StationDashboardData extends Equatable {
  const StationDashboardData({
    required this.station,
    required this.commission,
    required this.riders,
    required this.merchants,
    required this.deliveries,
    required this.topUps,
    required this.pendingRiderRequests,
    required this.pendingMerchantRequests,
    required this.lastUpdated,
  });

  final LoadingStationProfile station;
  final CommissionConfig commission;
  final List<RiderProfile> riders;
  final List<MerchantProfile> merchants;
  final List<DeliverySummary> deliveries;
  final List<TopUpSummary> topUps;
  final int pendingRiderRequests;
  final int pendingMerchantRequests;
  final DateTime lastUpdated;

  int get activeDeliveries => deliveries.where((d) => !_completedStatuses.contains(d.status.toLowerCase())).length;
  int get completedDeliveries => deliveries.where((d) => _completedStatuses.contains(d.status.toLowerCase())).length;
  double get outstandingTopUps => topUps.fold(0, (prev, element) => prev + element.amount);

  static const _completedStatuses = {'completed', 'delivered', 'done'};

  factory StationDashboardData.demo() {
    final hub = BusinessHubProfile(
      id: 'hub-demo',
      name: 'Lagona Business Hub',
      code: 'BH-ALABANG',
      municipality: 'Muntinlupa',
      bonusRate: 0.5,
    );
    final station = LoadingStationProfile(
      id: 'station-demo',
      name: 'Alabang Loading Station',
      lsCode: 'LS-ALB-001',
      address: 'Muntinlupa City',
      balance: 12500,
      bonusRate: 0.25,
      businessHub: hub,
    );
    final riders = List.generate(
      4,
      (index) => RiderProfile(
        id: 'rider-$index',
        name: 'Rider ${index + 1}',
        status: index == 0 ? RiderStatus.busy : RiderStatus.available,
        balance: 500 - index * 25,
        commissionRate: 0.2,
        priorityLevel: index,
        vehicleType: 'Motorcycle',
      ),
    );
    final merchants = [
      const MerchantProfile(id: 'm-1', businessName: 'Lagona Mart', address: 'Commerce Ave', ridersHandled: 2, status: 'approved'),
      const MerchantProfile(id: 'm-2', businessName: 'Fresh Produce', address: 'Festival Mall', ridersHandled: 1, status: 'pending'),
    ];
    final deliveries = [
      DeliverySummary(
        id: 'd-1',
        type: DeliveryType.pabili,
        status: 'pending',
        merchantName: 'Lagona Mart',
        riderName: 'Rider 1',
        pickupAddress: 'Lagona Mart, Commerce Ave',
        dropoffAddress: 'Blk 3 Lot 1',
        total: 350,
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        distanceKm: 2.1,
      ),
      DeliverySummary(
        id: 'd-2',
        type: DeliveryType.padala,
        status: 'completed',
        merchantName: 'BPI Corporate',
        riderName: 'Rider 2',
        pickupAddress: 'BGC',
        dropoffAddress: 'Alabang',
        total: 520,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        distanceKm: 6.4,
      ),
    ];
    final topUps = [
      TopUpSummary(
        id: 't-1',
        amount: 5000,
        bonus: 2500,
        totalCredited: 7500,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        requestorName: 'Business Hub',
      ),
      TopUpSummary(
        id: 't-2',
        amount: 1200,
        bonus: 300,
        totalCredited: 1500,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        forRiderName: 'Rider 3',
      ),
    ];
    return StationDashboardData(
      station: station,
      commission: const CommissionConfig(hubPercentage: 50, stationPercentage: 25, riderPercentage: 20, shareholderPercentage: 5),
      riders: riders,
      merchants: merchants,
      deliveries: deliveries,
      topUps: topUps,
      pendingRiderRequests: 2,
      pendingMerchantRequests: 1,
      lastUpdated: DateTime.now(),
    );
  }

  StationDashboardData copyWith({
    LoadingStationProfile? station,
    CommissionConfig? commission,
    List<RiderProfile>? riders,
    List<MerchantProfile>? merchants,
    List<DeliverySummary>? deliveries,
    List<TopUpSummary>? topUps,
    int? pendingRiderRequests,
    int? pendingMerchantRequests,
    DateTime? lastUpdated,
  }) =>
      StationDashboardData(
        station: station ?? this.station,
        commission: commission ?? this.commission,
        riders: riders ?? this.riders,
        merchants: merchants ?? this.merchants,
        deliveries: deliveries ?? this.deliveries,
        topUps: topUps ?? this.topUps,
        pendingRiderRequests: pendingRiderRequests ?? this.pendingRiderRequests,
        pendingMerchantRequests: pendingMerchantRequests ?? this.pendingMerchantRequests,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  @override
  List<Object?> get props => [
        station,
        commission,
        riders,
        merchants,
        deliveries,
        topUps,
        pendingRiderRequests,
        pendingMerchantRequests,
        lastUpdated,
      ];
}

