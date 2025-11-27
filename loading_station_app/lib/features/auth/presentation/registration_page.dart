import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';

class LoadingStationRegistrationPage extends ConsumerStatefulWidget {
  const LoadingStationRegistrationPage({super.key});

  @override
  ConsumerState<LoadingStationRegistrationPage> createState() => _LoadingStationRegistrationPageState();
}

class _LoadingStationRegistrationPageState extends ConsumerState<LoadingStationRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _bizNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _bhCodeCtrl = TextEditingController();

  int _currentStep = 0;
  bool _obscure = true;
  bool _isSubmitting = false;
  List<PlatformFile> _documents = [];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _bizNameCtrl.dispose();
    _addressCtrl.dispose();
    _municipalityCtrl.dispose();
    _bhCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null) {
      setState(() => _documents = result.files.take(2).toList());
    }
  }

  bool get _isDemoMode => !SupabaseConfig.isConfigured;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documents.length < 2) {
      _showSnack('Please upload both DTI Certificate and Mayor’s Permit.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(seconds: 1));
      } else {
        await ref.read(authRepositoryProvider).registerLoadingStation(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
              fullName: _fullNameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              businessName: _bizNameCtrl.text.trim(),
              address: _addressCtrl.text.trim(),
              municipality: _municipalityCtrl.text.trim(),
              bhCode: _bhCodeCtrl.text.trim().toUpperCase(),
              documents: _documents,
            );
      }
      if (mounted) {
        _showSnack('Registration submitted! Await Business Hub activation.');
        context.go('/login');
      }
    } catch (error) {
      _showSnack('Registration failed: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register Loading Station'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _currentStep,
            onStepCancel: _currentStep == 0 ? null : () => setState(() => _currentStep -= 1),
            onStepContinue: () {
              if (_currentStep == 2) {
                _submit();
              } else {
                setState(() => _currentStep += 1);
              }
            },
            controlsBuilder: (context, details) {
              return Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    child: _isSubmitting && _currentStep == 2
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_currentStep == 2 ? 'Submit' : 'Next'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              );
            },
            steps: [
              Step(
                title: const Text('Account'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: Column(
                  children: [
                    TextFormField(
                      controller: _fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Work email'),
                      validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Contact number'),
                      validator: (value) => (value == null || value.length < 10) ? 'Enter a valid number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 8) ? 'Use at least 8 characters' : null,
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Business'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: Column(
                  children: [
                    TextFormField(
                      controller: _bizNameCtrl,
                      decoration: const InputDecoration(labelText: 'Loading Station name'),
                      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Station address'),
                      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _municipalityCtrl,
                      decoration: const InputDecoration(labelText: 'Municipality / City'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bhCodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Business Hub Code (BHCODE)',
                        helperText: 'Provided by your supervising Business Hub',
                      ),
                      validator: (value) => (value == null || value.trim().length < 4) ? 'Enter the BHCODE' : null,
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Documents'),
                isActive: _currentStep >= 2,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload regulatory documents', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '• DTI Certificate\n• Mayor’s Permit\nOptional: add OR/CR, vehicle photos, etc.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _documents
                          .map((file) => Chip(
                                label: Text(file.name),
                                deleteIcon: const Icon(Icons.close),
                                onDeleted: () => setState(() => _documents.remove(file)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickDocuments,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload documents'),
                    ),
                    const SizedBox(height: 8),
                    if (_documents.length < 2)
                      Text(
                        'Upload at least two files (DTI + Mayor’s Permit).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                      ),
                    const SizedBox(height: 8),
                    if (_isDemoMode)
                      const Text(
                        'Demo mode: files stay locally. Provide Supabase credentials to upload to storage.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

