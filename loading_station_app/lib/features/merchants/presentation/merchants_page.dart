import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_utils.dart';
import '../../dashboard/data/station_repository.dart';
import '../../riders/presentation/riders_page.dart';

class MerchantsPage extends ConsumerStatefulWidget {
  const MerchantsPage({super.key});

  @override
  ConsumerState<MerchantsPage> createState() => _MerchantsPageState();
}

class _MerchantsPageState extends ConsumerState<MerchantsPage> {
  String _search = '';
  String? _expandedMerchantId;

  Future<void> _showRiderPriorityDialog(String merchantId, String merchantName) async {
    final dashboard = await ref.read(stationDashboardProvider.future);
    final allRiders = dashboard.riders.where((r) => r.status != RiderStatus.pending).toList();
    
    if (!mounted) return;
    
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<Map<String, int>>(
            future: _loadMerchantPriorities(merchantId),
            builder: (context, snapshot) {
              final merchantRiderPriorities = snapshot.data ?? <String, int>{};
              
              return AlertDialog(
                title: Text('Prioritize Riders for $merchantName'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allRiders.length,
                    itemBuilder: (context, index) {
                      final rider = allRiders[index];
                      final merchantPriority = merchantRiderPriorities[rider.id] ?? 0;
                      final isPrioritized = merchantPriority > 0;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: .15),
                          child: Text(rider.name.characters.first.toUpperCase()),
                        ),
                        title: Text(rider.name),
                        subtitle: Text(isPrioritized ? 'Priority: P$merchantPriority' : 'Not prioritized'),
                        trailing: Switch(
                          value: isPrioritized,
                          onChanged: (value) async {
                            final newPriority = value ? 1 : 0;
                            setDialogState(() {
                              merchantRiderPriorities[rider.id] = newPriority;
                            });
                            await ref.read(stationRepositoryProvider).updateRiderPriorityForMerchant(
                                  riderId: rider.id,
                                  merchantId: merchantId,
                                  priority: newPriority,
                                );
                            if (mounted) {
                              // Refresh the priorities
                              final updatedPriorities = await _loadMerchantPriorities(merchantId);
                              setDialogState(() {
                                merchantRiderPriorities.clear();
                                merchantRiderPriorities.addAll(updatedPriorities);
                              });
                              ref.invalidate(stationDashboardProvider);
                              ref.invalidate(stationMerchantsProvider);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
  
  Future<Map<String, int>> _loadMerchantPriorities(String merchantId) async {
    final merchantRiders = await ref.read(stationRepositoryProvider).fetchRidersForMerchant(merchantId);
    final priorities = <String, int>{};
    for (final mr in merchantRiders) {
      priorities[mr.id] = mr.priorityLevel;
    }
    return priorities;
  }
  

  @override
  Widget build(BuildContext context) {
    final merchantsAsync = ref.watch(stationMerchantsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Merchants & Rider Mapping'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search merchants',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.toLowerCase()),
            ),
          ),
        ),
      ),
      body: merchantsAsync.when(
        data: (merchantsData) {
          final merchants = merchantsData.where((merchant) => merchant.businessName.toLowerCase().contains(_search)).toList();
          if (merchants.isEmpty) {
            return const Center(child: Text('No merchants yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: merchants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final merchant = merchants[index];
              final status = (merchant.status ?? 'pending').toLowerCase();
              final isPending = status == 'pending';
              final statusColor = status == 'approved' ? AppColors.success : AppColors.statusPending;
              final canModerate = isValidUuid(merchant.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.secondaryLight,
                            child: Text(merchant.businessName.characters.first.toUpperCase(), style: const TextStyle(color: AppColors.textWhite)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(merchant.businessName, style: Theme.of(context).textTheme.titleMedium),
                                Text(merchant.address ?? 'No address'),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(status),
                            backgroundColor: statusColor.withValues(alpha: .15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Riders assigned: ${merchant.ridersHandled}'),
                      if (merchant.gcashNumber != null) Text('GCash: ${merchant.gcashNumber}'),
                      if (!canModerate)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Demo merchant – load live merchant records to approve or reject.'),
                        )
                      else ...[
                        if (isPending) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await ref.read(stationRepositoryProvider).approveMerchant(merchant.id, approved: false);
                                    if (mounted) {
                                      ref.invalidate(stationDashboardProvider);
                                      ref.invalidate(stationMerchantsProvider);
                                    }
                                  },
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await ref.read(stationRepositoryProvider).approveMerchant(merchant.id, approved: true);
                                    if (mounted) {
                                      ref.invalidate(stationDashboardProvider);
                                      ref.invalidate(stationMerchantsProvider);
                                    }
                                  },
                                  child: const Text('Approve'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showRiderPriorityDialog(merchant.id, merchant.businessName),
                            icon: const Icon(Icons.priority_high),
                            label: const Text('Manage Prioritized Riders'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load merchants: $err')),
      ),
    );
  }
}

