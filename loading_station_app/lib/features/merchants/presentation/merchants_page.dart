import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_utils.dart';
import '../../dashboard/data/station_repository.dart';

class MerchantsPage extends ConsumerStatefulWidget {
  const MerchantsPage({super.key});

  @override
  ConsumerState<MerchantsPage> createState() => _MerchantsPageState();
}

class _MerchantsPageState extends ConsumerState<MerchantsPage> {
  String _search = '';

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
                            child: Text(merchant.businessName.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white)),
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
                      else if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => ref.read(stationRepositoryProvider).approveMerchant(merchant.id, approved: false),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => ref.read(stationRepositoryProvider).approveMerchant(merchant.id, approved: true),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
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

