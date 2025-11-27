import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_utils.dart';
import '../../dashboard/data/station_repository.dart';

class RidersPage extends ConsumerStatefulWidget {
  const RidersPage({super.key});

  @override
  ConsumerState<RidersPage> createState() => _RidersPageState();
}

class _RidersPageState extends ConsumerState<RidersPage> {
  RiderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(stationDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riders & Priority Matrix'),
        actions: [
          PopupMenuButton<RiderStatus?>(
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All statuses')),
              ...RiderStatus.values.map((status) => PopupMenuItem(value: status, child: Text(status.name.toUpperCase()))),
            ],
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (data) {
          final riders = _filter == null ? data.riders : data.riders.where((rider) => rider.status == _filter).toList();
          if (riders.isEmpty) {
            return const Center(child: Text('No riders yet. Invite riders using LSCODE.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final rider = riders[index];
              final isPending = rider.status == RiderStatus.pending;
              final canModerate = isValidUuid(rider.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: .15),
                            child: Text(rider.name.characters.first.toUpperCase()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rider.name, style: Theme.of(context).textTheme.titleMedium),
                                Text('${rider.vehicleType ?? 'Motorcycle'} • Balance ₱${rider.balance.toStringAsFixed(2)}'),
                              ],
                            ),
                          ),
                          _StatusChip(status: rider.status.name),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!canModerate)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Demo data item – load real rider data to moderate here.'),
                        )
                      else if (isPending) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => ref.read(stationRepositoryProvider).approveRider(rider.id, approved: false),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => ref.read(stationRepositoryProvider).approveRider(rider.id, approved: true),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Text('Priority slot'),
                            Expanded(
                              child: Slider(
                                divisions: 5,
                                min: 0,
                                max: 5,
                                value: rider.priorityLevel.toDouble().clamp(0, 5),
                                label: 'P${rider.priorityLevel}',
                                onChanged: canModerate
                                    ? (value) async {
                                        await ref.read(stationRepositoryProvider).updateRiderPriority(rider.id, value.round());
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.percent, size: 16),
                              label: Text('Commission ${(rider.commissionRate * 100).toStringAsFixed(0)}%'),
                            ),
                            Chip(
                              avatar: const Icon(Icons.schedule, size: 16),
                              label: Text('Priority P${rider.priorityLevel}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: canModerate ? () {} : null,
                              icon: const Icon(Icons.route),
                              label: const Text('Track last location'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: canModerate ? () {} : null,
                              child: const Text('Suspend rider'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: riders.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load riders: $err')),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

