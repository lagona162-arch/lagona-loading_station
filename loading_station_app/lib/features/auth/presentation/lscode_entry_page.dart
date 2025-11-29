import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';

class LSCodeEntryPage extends ConsumerStatefulWidget {
  const LSCodeEntryPage({super.key});

  @override
  ConsumerState<LSCodeEntryPage> createState() => _LSCodeEntryPageState();
}

class _LSCodeEntryPageState extends ConsumerState<LSCodeEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _lsCodeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _lsCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!SupabaseConfig.isConfigured) {
      _showError('Supabase credentials missing.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) {
        _showError('Not authenticated. Please log in again.');
        context.go('/login');
        return;
      }

      final service = ref.read(supabaseServiceProvider);
      // Verify LSCODE matches user's loading station (preserve original case for lookup)
      await service.verifyLSCodeForUser(userId, _lsCodeCtrl.text.trim());

      // Invalidate the linked station provider to refresh
      ref.invalidate(linkedStationIdProvider);

      if (mounted) {
        context.go('/');
      }
    } catch (error) {
      _showError('Failed to link Loading Station: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Verify Loading Station',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your Loading Station Code (LSCODE) to verify access to your station\'s dashboard. This code was provided by your Business Hub administrator.',
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _lsCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Loading Station Code (LSCODE)',
                            hintText: 'LS-XXXXX',
                            prefixIcon: Icon(Icons.store),
                            helperText: 'Enter the LSCODE provided by your admin',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your Loading Station Code';
                            }
                            if (value.trim().length < 3) {
                              return 'LSCODE must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Verify & Continue'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.read(authRepositoryProvider).signOut(),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

