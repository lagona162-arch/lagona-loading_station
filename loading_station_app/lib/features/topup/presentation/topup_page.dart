import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/data/station_repository.dart';

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
                    await ref.read(stationRepositoryProvider).requestTopUpFromStation(amount: amount);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ref.invalidate(stationDashboardProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Top-up request submitted')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit request: $error')),
                      );
                    }
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
                      Text('Bonus rate ${(data.station.bonusRate * 100).toStringAsFixed(0)}%'),
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
                              leading: Icon(
                                isPending ? Icons.pending : Icons.check_circle,
                                color: isPending ? AppColors.statusPending : AppColors.success,
                              ),
                              title: Text(formatter.format(topUp.totalCredited)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${topUp.requestorName ?? 'Station'} → ${topUp.forRiderName ?? 'Wallet'}',
                                  ),
                                  Text('Bonus ${formatter.format(topUp.bonus)}'),
                                  if (isPending)
                                    Text(
                                      'Status: ${topUp.status.name.toUpperCase()}',
                                      style: TextStyle(color: AppColors.statusPending, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(DateFormat('MMM dd\nhh:mm a').format(topUp.createdAt ?? DateTime.now())),
                                  if (isPending) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          color: AppColors.error,
                                          onPressed: () async {
                                            await ref.read(stationRepositoryProvider).respondTopUp(
                                                  topUpId: topUp.id,
                                                  approve: false,
                                                );
                                            if (context.mounted) {
                                              ref.invalidate(stationDashboardProvider);
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.check, size: 18),
                                          color: AppColors.success,
                                          onPressed: () async {
                                            await ref.read(stationRepositoryProvider).respondTopUp(
                                                  topUpId: topUp.id,
                                                  approve: true,
                                                );
                                            if (context.mounted) {
                                              ref.invalidate(stationDashboardProvider);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
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

