import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/data/station_repository.dart';

// Provider to fetch commission rate for loading_station role
final _loadingStationCommissionRateProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getCommissionRateForRole('loading_station');
});

class TopUpPage extends ConsumerStatefulWidget {
  const TopUpPage({super.key});

  @override
  ConsumerState<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends ConsumerState<TopUpPage> {
  final _amountController = TextEditingController();
  final _riderController = TextEditingController();
  bool _showPendingRequests = false;

  @override
  void dispose() {
    _amountController.dispose();
    _riderController.dispose();
    super.dispose();
  }

  Future<void> _showRequestTopUpToHubSheet() async {
    _amountController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Request Top-Up from Business Hub', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }
                  try {
                    final stationId = ref.read(currentStationIdProvider);
                    if (stationId == null) {
                      throw Exception('Station ID not found. Please verify your loading station code.');
                    }
                    await ref.read(stationRepositoryProvider).requestTopUpFromStation(
                      stationId: stationId,
                      amount: amount,
                    );
                    if (!context.mounted) return;
                    // Get scaffold messenger before popping
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    ref.invalidate(stationDashboardProvider);
                    // Show snackbar using the messenger we got before popping
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Top-up request submitted')),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to submit request: $error')),
                    );
                  }
                },
                child: const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRiderTopUpBreakdownModal(TopUpSummary topUp, bool isApproval) async {
    final formatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final bonusRate = topUp.bonus > 0 && topUp.amount > 0 
        ? (topUp.bonus / topUp.amount * 100).toStringAsFixed(1)
        : '0.0';
    
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproval ? 'Approve Top-Up Request' : 'Reject Top-Up Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request from: ${topUp.forRiderName ?? 'Rider'}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top-Up Breakdown', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Requested Amount:', style: Theme.of(context).textTheme.bodyMedium),
                      Text(formatter.format(topUp.amount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bonus Rate ($bonusRate%):', style: Theme.of(context).textTheme.bodyMedium),
                      Text(formatter.format(topUp.bonus), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total to Credit:', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text(formatter.format(topUp.totalCredited), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Don't close modal yet - wait for operation to complete
              final stationId = ref.read(currentStationIdProvider);
              if (stationId == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Station ID not found')),
                );
                return;
              }
              
              // Show loading indicator
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                // Use respondTopUpRequest if it's from topup_requests table, otherwise use respondTopUp
                if (topUp.isFromTopupRequests) {
                  await ref.read(stationRepositoryProvider).respondTopUpRequest(
                        requestId: topUp.id,
                        approve: isApproval,
                        stationId: stationId,
                      );
                } else {
                  await ref.read(stationRepositoryProvider).respondTopUp(
                        topUpId: topUp.id,
                        approve: isApproval,
                        stationId: stationId,
                      );
                }
                
                // Close modal after operation completes
                navigator.pop();
                
                if (context.mounted) {
                  // Refresh the provider to update UI immediately
                  ref.invalidate(stationDashboardProvider);
                  // Force a refresh to get new data
                  ref.refresh(stationDashboardProvider);
                  
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(isApproval ? 'Top-up request approved successfully' : 'Top-up request rejected'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (error, stackTrace) {
                // Close modal even on error
                if (navigator.canPop()) {
                  navigator.pop();
                }
                
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to ${isApproval ? 'approve' : 'reject'} request: $error'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? AppColors.primary : AppColors.error,
              foregroundColor: AppColors.textWhite,
            ),
            child: Text(isApproval ? 'Confirm Approve' : 'Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTopUpSheet(String stationId) async {
    _amountController.clear();
    _riderController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Credit top-up', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _riderController,
                decoration: const InputDecoration(labelText: 'Rider ID (optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_amountController.text);
                  if (amount == null) return;
                  final navigator = Navigator.of(context);
                  await ref.read(stationRepositoryProvider).createTopUp(
                        stationId: stationId,
                        amount: amount,
                        riderId: _riderController.text.trim().isEmpty ? null : _riderController.text.trim(),
                      );
                  ref.invalidate(stationDashboardProvider);
                  navigator.pop();
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(stationDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet & Top-Ups'),
        actions: [
          IconButton(
            icon: Icon(_showPendingRequests ? Icons.list : Icons.pending_actions),
            onPressed: () => setState(() => _showPendingRequests = !_showPendingRequests),
            tooltip: _showPendingRequests ? 'Show all top-ups' : 'Show pending requests',
          ),
        ],
      ),
      floatingActionButton: dashboardAsync.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () => _showRequestTopUpToHubSheet(),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          icon: const Icon(Icons.add),
          label: const Text('Request Top-Up'),
        ),
        orElse: () => null,
      ),
      body: dashboardAsync.when(
        data: (data) {
          final formatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
          final topUps = _showPendingRequests
              ? data.topUps.where((t) => t.status == TopUpStatus.pending).toList()
              : data.topUps;
          final pendingCount = data.topUps.where((t) => t.status == TopUpStatus.pending).length;

          // Fetch commission rate from commission_settings for loading_station role
          final commissionRateAsync = ref.watch(_loadingStationCommissionRateProvider);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Station Wallet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(formatter.format(data.station.balance), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      commissionRateAsync.when(
                        data: (rate) => Text('Bonus rate ${(rate * 100).toStringAsFixed(0)}%'),
                        loading: () => const Text('Bonus rate ...'),
                        error: (_, __) => Text('Bonus rate ${(data.station.bonusRate * 100).toStringAsFixed(0)}%'), // Fallback to stored rate
                      ),
                      if (data.station.businessHub != null) ...[
                        const SizedBox(height: 8),
                        Text('Business Hub: ${data.station.businessHub!.name}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _showPendingRequests ? 'Pending Requests' : 'Recent top-ups',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (pendingCount > 0 && !_showPendingRequests)
                            Chip(
                              label: Text('$pendingCount pending'),
                              backgroundColor: AppColors.statusPending.withValues(alpha: .2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (topUps.isEmpty)
                        Text(_showPendingRequests ? 'No pending requests.' : 'No top-ups yet.')
                      else
                        ...topUps.map((topUp) {
                          final isPending = topUp.status == TopUpStatus.pending;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isPending ? AppColors.statusPending.withValues(alpha: .1) : null,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              dense: false,
                              leading: Icon(
                                isPending ? Icons.pending : Icons.check_circle,
                                color: isPending ? AppColors.statusPending : AppColors.success,
                                size: 24,
                              ),
                              title: Text(formatter.format(topUp.totalCredited)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    topUp.isFromRider 
                                      ? '${topUp.forRiderName ?? 'Rider'} → Station Wallet'
                                      : topUp.isToBusinessHub
                                        ? 'Station → Business Hub'
                                        : '${topUp.requestorName ?? 'Station'} → ${topUp.forRiderName ?? 'Wallet'}',
                                  ),
                                  Text('Bonus ${formatter.format(topUp.bonus)}'),
                                  if (isPending)
                                    Text(
                                      'Status: ${topUp.status.name.toUpperCase()}',
                                      style: TextStyle(color: AppColors.statusPending, fontWeight: FontWeight.bold),
                                    ),
                                  if (isPending && topUp.isToBusinessHub)
                                    Text(
                                      'Waiting for Business Hub approval',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  if (isPending && topUp.isFromRider) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            side: BorderSide(color: AppColors.error),
                                          ),
                                          icon: Icon(Icons.close, size: 16, color: AppColors.error),
                                          label: Text('Reject', style: TextStyle(fontSize: 12, color: AppColors.error)),
                                          onPressed: () => _showRiderTopUpBreakdownModal(topUp, false),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: AppColors.textWhite,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showRiderTopUpBreakdownModal(topUp, true),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Text(
                                DateFormat('MMM dd\nhh:mm a').format(topUp.createdAt ?? DateTime.now()),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load wallet: $err')),
      ),
    );
  }
}

