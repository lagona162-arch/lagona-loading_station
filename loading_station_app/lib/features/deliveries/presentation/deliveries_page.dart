import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/data/station_repository.dart';

class DeliveriesPage extends ConsumerStatefulWidget {
  const DeliveriesPage({super.key});

  @override
  ConsumerState<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends ConsumerState<DeliveriesPage> {
  String _filter = 'active';

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(stationDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Deliveries')),
      body: dashboardAsync.when(
        data: (data) {
          final filtered = data.deliveries.where((delivery) {
            switch (_filter) {
              case 'completed':
                return _isDone(delivery.status);
              case 'pabili':
                return delivery.type == DeliveryType.pabili;
              case 'padala':
                return delivery.type == DeliveryType.padala;
              default:
                return !_isDone(delivery.status);
            }
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'active', label: Text('Active')),
                    ButtonSegment(value: 'completed', label: Text('Completed')),
                    ButtonSegment(value: 'pabili', label: Text('Pabili')),
                    ButtonSegment(value: 'padala', label: Text('Padala')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) => setState(() => _filter = value.first),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No deliveries yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final delivery = filtered[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: delivery.type == DeliveryType.pabili
                                    ? AppColors.primary.withValues(alpha: .2)
                                    : AppColors.secondary.withValues(alpha: .2),
                                child: Icon(
                                  delivery.type == DeliveryType.pabili ? Icons.shopping_basket : Icons.local_shipping,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text('${delivery.merchantName} • ${delivery.riderName ?? 'Unassigned'}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${delivery.pickupAddress ?? '--'} → ${delivery.dropoffAddress ?? '--'}'),
                                  Text(DateFormat('MMM dd, hh:mm a').format(delivery.createdAt ?? DateTime.now())),
                                ],
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(delivery.total)),
                                  const SizedBox(height: 4),
                                  _StatusChip(status: delivery.status),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemCount: filtered.length,
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load deliveries: $err')),
      ),
    );
  }

  static bool _isDone(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('completed') || normalized.contains('delivered');
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
        color: _statusColor(status).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return AppColors.statusPending;
    case 'accepted':
    case 'assigned':
      return AppColors.primary;
    case 'picked_up':
    case 'in_transit':
      return AppColors.primaryDark;
    case 'delivered':
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

