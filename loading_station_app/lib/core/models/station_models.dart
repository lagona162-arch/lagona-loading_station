import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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

  factory LoadingStationProfile.fromMap(Map<String, dynamic> map) {
    // Handle both 'business_hubs' (from Supabase relationship) and direct object
    dynamic businessHubsData = map['business_hubs'];
    
    debugPrint('LoadingStationProfile.fromMap - business_hubs data type: ${businessHubsData.runtimeType}');
    debugPrint('LoadingStationProfile.fromMap - business_hubs data: $businessHubsData');
    
    // If business_hubs is a list (Supabase sometimes returns arrays), take first item
    if (businessHubsData is List && businessHubsData.isNotEmpty) {
      businessHubsData = businessHubsData.first;
      debugPrint('LoadingStationProfile.fromMap - extracted from list: $businessHubsData');
    }
    
    // If still null but business_hub_id exists, we'll handle it in the service layer
    BusinessHubProfile? businessHub;
    if (businessHubsData != null && businessHubsData is Map) {
      try {
        businessHub = BusinessHubProfile.fromMap(businessHubsData as Map<String, dynamic>);
        debugPrint('LoadingStationProfile.fromMap - successfully parsed business hub: ${businessHub.name}');
      } catch (e, stack) {
        debugPrint('Error parsing business hub: $e');
        debugPrintStack(stackTrace: stack);
      }
    } else {
      debugPrint('LoadingStationProfile.fromMap - business_hubs is null or not a Map');
    }
    
    return LoadingStationProfile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Loading Station',
      lsCode: map['ls_code']?.toString() ?? '--',
      address: map['address']?.toString(),
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      bonusRate: (map['bonus_rate'] as num?)?.toDouble() ?? 0,
      businessHub: businessHub,
    );
  }

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
    this.phone,
    this.latitude,
    this.longitude,
    this.currentAddress,
    this.lastActive,
    this.profilePhotoUrl,
    this.driversLicenseUrl,
    this.licenseCardUrl,
    this.officialReceiptUrl,
    this.certificateOfRegistrationUrl,
    this.vehicleFrontUrl,
    this.vehicleSideUrl,
    this.vehicleBackUrl,
  });

  final String id;
  final String name;
  final RiderStatus status;
  final double balance;
  final double commissionRate;
  final int priorityLevel;
  final String? vehicleType;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? currentAddress;
  final DateTime? lastActive;
  
  // Document URLs (for pending riders/applicants)
  final String? profilePhotoUrl;
  final String? driversLicenseUrl;
  final String? licenseCardUrl;
  final String? officialReceiptUrl; // OR
  final String? certificateOfRegistrationUrl; // CR
  final String? vehicleFrontUrl;
  final String? vehicleSideUrl;
  final String? vehicleBackUrl;
  
  // Helper to check if rider application is still pending approval
  bool get isApplicationPending => status == RiderStatus.pending;

  factory RiderProfile.fromMap(Map<String, dynamic> map) {
    // Determine application status based on access_status and is_active (as per admin guide)
    // Priority: 1. Check access_status, 2. Fall back to is_active
    final usersData = map['users'];
    final accessStatus = usersData?['access_status']?.toString().toLowerCase();
    final isActive = usersData?['is_active'] as bool?;
    final operationalStatus = map['status']?.toString().toLowerCase() ?? '';
    
    // Determine status: First check access_status, then fall back to is_active
    // If approved, use the operational status from riders table
    RiderStatus status;
    
    // Check if rider is approved based on admin guide logic:
    // 1. First check access_status field
    // 2. If access_status is null, fall back to is_active
    //    - is_active = true → approved
    //    - is_active = false → pending
    final isApproved = accessStatus == 'approved' || 
                       (accessStatus == null && isActive == true) ||
                       (accessStatus != 'rejected' && accessStatus != 'pending' && isActive == true);
    
    if (isApproved) {
      // Rider is approved, use operational status from riders table (available/busy/offline)
      switch (operationalStatus) {
        case 'available':
          status = RiderStatus.available;
          break;
        case 'busy':
          status = RiderStatus.busy;
          break;
        case 'offline':
          status = RiderStatus.offline;
          break;
        default:
          // If no operational status is set but rider is approved, default to offline
          status = RiderStatus.offline;
      }
    } else {
      // Rider is pending approval or rejected - show as pending (for application review)
      status = RiderStatus.pending;
    }
    
    return RiderProfile(
      id: map['id']?.toString() ?? '',
      name: usersData?['full_name']?.toString() ?? map['full_name']?.toString() ?? 'Rider',
      status: status,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 0,
      priorityLevel: (map['priority_order'] as num?)?.toInt() ?? 0,
      vehicleType: map['vehicle_type']?.toString(),
      phone: usersData?['phone']?.toString() ?? map['phone']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      currentAddress: map['current_address']?.toString(),
      lastActive: map['last_active'] != null ? DateTime.tryParse(map['last_active'].toString()) : null,
      profilePhotoUrl: map['profile_photo_url']?.toString() ?? map['profile_picture_url']?.toString(),
      driversLicenseUrl: map['drivers_license_url']?.toString() ?? map['license_url']?.toString(),
      licenseCardUrl: map['license_card_url']?.toString(),
      officialReceiptUrl: map['official_receipt_url']?.toString() ?? map['or_url']?.toString(),
      certificateOfRegistrationUrl: map['certificate_of_registration_url']?.toString() ?? map['cr_url']?.toString(),
      vehicleFrontUrl: map['vehicle_front_url']?.toString(),
      vehicleSideUrl: map['vehicle_side_url']?.toString(),
      vehicleBackUrl: map['vehicle_back_url']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    id, name, status, balance, commissionRate, priorityLevel, vehicleType, phone, 
    latitude, longitude, currentAddress, lastActive,
    profilePhotoUrl, driversLicenseUrl, licenseCardUrl, officialReceiptUrl, 
    certificateOfRegistrationUrl, vehicleFrontUrl, vehicleSideUrl, vehicleBackUrl
  ];
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

enum TopUpStatus { pending, approved, rejected }

class TopUpSummary extends Equatable {
  const TopUpSummary({
    required this.id,
    required this.amount,
    required this.bonus,
    required this.totalCredited,
    required this.status,
    required this.createdAt,
    this.forRiderName,
    this.requestorName,
    this.riderId,
    this.businessHubId,
    this.isFromTopupRequests = false,
  });

  final String id;
  final double amount;
  final double bonus;
  final double totalCredited;
  final TopUpStatus status;
  final DateTime? createdAt;
  final String? forRiderName;
  final String? requestorName;
  final String? riderId;
  final String? businessHubId;
  final bool isFromTopupRequests; // Flag to identify if this came from topup_requests table

  factory TopUpSummary.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status']?.toString().toLowerCase() ?? 'pending';
    TopUpStatus status;
    switch (statusStr) {
      case 'approved':
        status = TopUpStatus.approved;
        break;
      case 'rejected':
        status = TopUpStatus.rejected;
        break;
      default:
        status = TopUpStatus.pending;
    }
    
    return TopUpSummary(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      bonus: (map['bonus_amount'] as num?)?.toDouble() ?? 0,
      totalCredited: (map['total_credited'] as num?)?.toDouble() ?? 0,
      status: status,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      forRiderName: map['riders']?['users']?['full_name']?.toString(),
      requestorName: map['initiated_by_user']?['full_name']?.toString(),
      riderId: map['rider_id']?.toString().isEmpty == true ? null : map['rider_id']?.toString(),
      businessHubId: map['business_hub_id']?.toString().isEmpty == true ? null : map['business_hub_id']?.toString(),
      isFromTopupRequests: map['_isFromTopupRequests'] == true, // Internal flag set during mapping
    );
  }

  // Check if this is a request FROM a rider (loading station can approve)
  // Rider requests are in 'topups' table with rider_id set and no business_hub_id
  bool get isFromRider {
    final hasRider = riderId != null && riderId!.isNotEmpty;
    final noBusinessHub = businessHubId == null || businessHubId!.isEmpty;
    return hasRider && noBusinessHub;
  }
  
  // Check if this is a request FROM loading station TO business hub (only business hub can approve)
  // Station-to-hub requests are in 'topup_requests' table with business_hub_id set and no rider_id
  bool get isToBusinessHub {
    final hasBusinessHub = businessHubId != null && businessHubId!.isNotEmpty;
    final noRider = riderId == null || riderId!.isEmpty;
    return hasBusinessHub && noRider;
  }

  @override
  List<Object?> get props => [id, amount, bonus, totalCredited, status, createdAt, forRiderName, riderId, businessHubId, isFromTopupRequests];
}

class StationDashboardData extends Equatable {
  const StationDashboardData({
    required this.station,
    required this.riders,
    required this.merchants,
    required this.deliveries,
    required this.topUps,
    required this.pendingRiderRequests,
    required this.pendingMerchantRequests,
    required this.lastUpdated,
  });

  final LoadingStationProfile station;
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
        status: TopUpStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        requestorName: 'Business Hub',
      ),
      TopUpSummary(
        id: 't-2',
        amount: 1200,
        bonus: 300,
        totalCredited: 1500,
        status: TopUpStatus.approved,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        forRiderName: 'Rider 3',
      ),
    ];
    return StationDashboardData(
      station: station,
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
        riders,
        merchants,
        deliveries,
        topUps,
        pendingRiderRequests,
        pendingMerchantRequests,
        lastUpdated,
      ];
}

