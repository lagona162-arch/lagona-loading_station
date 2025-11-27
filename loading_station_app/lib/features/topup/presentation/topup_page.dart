import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  @override
  void dispose() {
    _amountController.dispose();
    _riderController.dispose();
    super.dispose();
  }

  Future<void> _showTopUpSheet(String stationId) async {
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
      appBar: AppBar(title: const Text('Wallet & Top-Ups')),
      floatingActionButton: dashboardAsync.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () => _showTopUpSheet(data.station.id),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New top-up'),
        ),
        orElse: () => null,
      ),
      body: dashboardAsync.when(
        data: (data) {
          final formatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
          final topUps = data.topUps;
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
                      Text('Recent top-ups', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (topUps.isEmpty)
                        const Text('No top-ups yet.')
                      else
                        ...topUps.map((topUp) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.trending_up),
                              title: Text(formatter.format(topUp.totalCredited)),
                              subtitle: Text(
                                '${topUp.requestorName ?? 'Station'} → ${topUp.forRiderName ?? 'Wallet'}\n'
                                'Bonus ${formatter.format(topUp.bonus)}',
                              ),
                              trailing: Text(DateFormat('MMM dd\nhh:mm a').format(topUp.createdAt ?? DateTime.now())),
                            )),
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

