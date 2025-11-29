import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../services/supabase_service.dart';

final sessionStreamProvider = StreamProvider<Session?>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const Stream.empty();
  }
  return Supabase.instance.client.auth.onAuthStateChange.map((data) => data.session);
});

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(sessionStreamProvider).valueOrNull?.user,
);

final linkedStationIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null || !SupabaseConfig.isConfigured) return null;
  
  final service = ref.watch(supabaseServiceProvider);
  return await service.getLinkedStationId(userId);
});

final currentStationIdProvider = Provider<String?>((ref) {
  // Use the linked station ID if available, otherwise use user ID
  // Since loading_stations.id = users.id, the user ID IS the station ID
  final linkedStation = ref.watch(linkedStationIdProvider).valueOrNull;
  return linkedStation ?? ref.watch(currentUserProvider)?.id;
});

