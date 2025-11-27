import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

final sessionStreamProvider = StreamProvider<Session?>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const Stream.empty();
  }
  return Supabase.instance.client.auth.onAuthStateChange.map((data) => data.session);
});

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(sessionStreamProvider).valueOrNull?.user,
);

final currentStationIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider)?.id,
);

