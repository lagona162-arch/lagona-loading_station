import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

class AuthRepository {
  AuthRepository(this._service);

  final SupabaseService _service;

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw const SupabaseConfigMissingException();
    }
    return Supabase.instance.client;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async => _client.auth.signOut();

  Future<void> registerLoadingStation({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String businessName,
    required String address,
    required String municipality,
    required String bhCode,
    required List<PlatformFile> documents,
    double? bonusRate,
  }) async {
    final signUpResponse = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': 'loading_station', 'full_name': fullName},
    );

    final userId = signUpResponse.user?.id;
    if (userId == null) {
      throw Exception('Unable to create account');
    }

    final hub = await _client.from('business_hubs').select('id').eq('bh_code', bhCode).maybeSingle();
    if (hub == null) {
      throw Exception('Invalid Business Hub code');
    }

    final documentUrls = documents.isNotEmpty ? await _service.uploadDocuments(bucket: 'loading-station-documents', files: documents) : <String>[];

    await _client.from('users').upsert({
      'id': userId,
      'full_name': fullName,
      'email': email,
      'role': 'loading_station',
      'phone': phone,
      'address': address,
      'access_status': 'pending',
    });

    final newCode = await _service.generateLoadingStationCode(userId, persist: false);

    await _client.from('loading_stations').insert({
      'id': userId,
      'name': businessName,
      'business_hub_id': hub['id'],
      'ls_code': newCode,
      'address': address,
      'bonus_rate': bonusRate ?? 0.25,
    });

    // Persist the supporting documents for Business Hub review.
    try {
      if (documentUrls.length >= 2) {
        await _client.from('pending_merchant_registrations').upsert({
          'user_id': userId,
          'business_name': businessName,
          'address': address,
          'municipality': municipality,
          'contact_number': phone,
          'owner_name': fullName,
          'owner_contact': phone,
          'latitude': 0,
          'longitude': 0,
          'dti_certificate_url': documentUrls.first,
          'mayor_permit_url': documentUrls[1],
        });
      }
    } catch (error, stack) {
      debugPrint('Registration document upsert failed: $error');
      log('Registration document error', error: error, stackTrace: stack);
    }
  }
}

