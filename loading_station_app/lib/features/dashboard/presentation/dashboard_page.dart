import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_utils.dart';
import '../../auth/data/auth_repository.dart';
import '../../shared/widgets/section_header.dart';
import '../data/station_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(stationDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: dashboardAsync.maybeWhen(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, ${data.station.name}'),
              Text(
                'BH ${data.station.businessHub?.code ?? '--'} • LS ${data.station.lsCode}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textWhite.withValues(alpha: .9)),
              ),
            ],
          ),
          orElse: () => const Text('Lagona Loading Station'),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(stationDashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _OverviewCards(data: data),
              const SizedBox(height: 8),
              _HierarchyCard(data: data),
              const SizedBox(height: 8),
              _DeliveriesBoard(deliveries: data.deliveries),
              const SizedBox(height: 8),
              _RiderQueue(
                riders: data.riders,
                pendingCount: data.pendingRiderRequests,
                stationId: data.station.id,
              ),
              const SizedBox(height: 8),
              _MerchantDirectory(
                merchants: data.merchants,
                pendingCount: data.pendingMerchantRequests,
              ),
              const SizedBox(height: 8),
              _TopUpTimeline(
                topUps: data.topUps,
                stationId: data.station.id,
              ),
              const SizedBox(height: 12),
              Text(
                'Last synced ${DateFormat('MMM dd, hh:mm a').format(data.lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _ErrorState(message: err.toString()),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({required this.data});

  final StationDashboardData data;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 36) / 2; // 12px padding * 2 + 12px spacing = 36px total
    
    final cards = [
      _MetricCard(
        title: 'Station Balance',
        value: _formatCurrency(data.station.balance),
        subtitle: 'Including bonuses',
        icon: Icons.account_balance_wallet,
      ),
      _MetricCard(
        title: 'Active Deliveries',
        value: '${data.activeDeliveries}',
        subtitle: '${data.completedDeliveries} completed today',
        icon: Icons.local_shipping_outlined,
        iconBg: AppColors.primaryLight,
      ),
      _MetricCard(
        title: 'Riders',
        value: '${data.riders.length}',
        subtitle: '${data.pendingRiderRequests} pending approval',
        icon: Icons.pedal_bike,
        iconBg: AppColors.secondaryLight,
      ),
      _MetricCard(
        title: 'Merchants',
        value: '${data.merchants.length}',
        subtitle: '${data.pendingMerchantRequests} onboarding',
        icon: Icons.storefront,
        iconBg: AppColors.primary.withValues(alpha: .25),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
    );
  }
}

class _HierarchyCard extends ConsumerWidget {
  const _HierarchyCard({required this.data});
  final StationDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Hierarchy',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HierarchyTile(
                    label: 'Business Hub',
                    title: data.station.businessHub?.name ?? '--',
                    subtitle: data.station.businessHub?.municipality,
                    code: data.station.businessHub?.code ?? 'BH-????',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HierarchyTile(
                    label: 'Loading Station',
                    title: data.station.name,
                    subtitle: data.station.address,
                    code: data.station.lsCode,
                    action: IconButton(
                      onPressed: () => _showQRCodeDialog(context, data.station.lsCode, data.station.name),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      tooltip: 'Show QR Code',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _DeliveriesBoard extends StatelessWidget {
  const _DeliveriesBoard({required this.deliveries});

  final List<DeliverySummary> deliveries;

  @override
  Widget build(BuildContext context) {
    final active = deliveries.where((d) => !_isDone(d.status)).toList();
    final completed = deliveries.where((d) => _isDone(d.status)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SectionHeader(
              title: 'Pabili & Padala Board',
              subtitle: '${active.length} active • ${completed.length} completed today',
              actionLabel: 'View all',
              onPressed: () => context.go('/deliveries'),
            ),
            const SizedBox(height: 8),
            ...active.take(3).map((delivery) => _DeliveryTile(delivery: delivery)),
            if (active.isEmpty) const _EmptyMessage('No active deliveries. Riders are standing by.'),
          ],
        ),
      ),
    );
  }

  static bool _isDone(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('completed') || normalized.contains('delivered');
  }
}

class _RiderQueue extends ConsumerWidget {
  const _RiderQueue({
    required this.riders,
    required this.pendingCount,
    required this.stationId,
  });

  final List<RiderProfile> riders;
  final int pendingCount;
  final String stationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = riders.where((r) => r.status == RiderStatus.pending).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Rider Registration',
              subtitle: '$pendingCount waiting for approval',
              actionLabel: 'View riders',
              onPressed: () => context.go('/riders'),
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty) const _EmptyMessage('All riders activated.'),
            ...pending.take(2).map((rider) {
              final canModerate = isValidUuid(rider.id);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: .2),
                  child: Text(
                    rider.name.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                title: Text(
                  rider.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
                subtitle: const Text(
                  'Pending approval',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: canModerate
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Reject',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                            onPressed: () => _showRejectConfirmation(context, ref, rider, stationId),
                            icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _showApproveConfirmation(context, ref, rider, stationId),
                            child: const Text('Approve', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      )
                    : Text(
                        'Demo data',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static void _showApproveConfirmation(BuildContext context, WidgetRef ref, RiderProfile rider, String stationId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Rider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${rider.name}'),
            if (rider.phone != null) Text('Phone: ${rider.phone}'),
            if (rider.vehicleType != null) Text('Vehicle: ${rider.vehicleType}'),
            const SizedBox(height: 16),
            const Text('The rider will gain full access to the system.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(stationRepositoryProvider).approveRider(rider.id, approved: true, stationId: stationId);
                if (context.mounted) {
                  // Invalidate and refresh the provider to force update
                  ref.invalidate(stationDashboardProvider);
                  ref.refresh(stationDashboardProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rider approved successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  static void _showRejectConfirmation(BuildContext context, WidgetRef ref, RiderProfile rider, String stationId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Rider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${rider.name}'),
            if (rider.phone != null) Text('Phone: ${rider.phone}'),
            const SizedBox(height: 16),
            const Text('The rider will not be able to access the system.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(stationRepositoryProvider).approveRider(rider.id, approved: false, stationId: stationId);
                if (context.mounted) {
                  // Invalidate and refresh the provider to force update
                  ref.invalidate(stationDashboardProvider);
                  ref.refresh(stationDashboardProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rider rejected')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _MerchantDirectory extends StatelessWidget {
  const _MerchantDirectory({
    required this.merchants,
    required this.pendingCount,
  });

  final List<MerchantProfile> merchants;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final subtitle = pendingCount > 0 ? '$pendingCount pending access' : 'All merchants synced';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Merchants & Priority Riders',
              subtitle: subtitle,
              actionLabel: 'Assign riders',
              onPressed: () => context.go('/merchants'),
            ),
            const SizedBox(height: 8),
            if (merchants.isEmpty) const _EmptyMessage('No merchants yet. Invite partners from your Business Hub.'),
            ...merchants.take(3).map((merchant) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.secondaryLight,
                    child: const Icon(Icons.storefront, color: AppColors.textWhite, size: 18),
                  ),
                  title: Text(
                    merchant.businessName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${merchant.ridersHandled} riders • Status: ${merchant.status ?? 'pending'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.go('/merchants'),
                )),
          ],
        ),
      ),
    );
  }
}

class _TopUpTimeline extends ConsumerStatefulWidget {
  const _TopUpTimeline({required this.topUps, required this.stationId});

  final List<TopUpSummary> topUps;
  final String stationId;

  @override
  ConsumerState<_TopUpTimeline> createState() => _TopUpTimelineState();
}

class _TopUpTimelineState extends ConsumerState<_TopUpTimeline> {
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTopUpSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top-Up Loading Station', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_amountCtrl.text);
                  if (amount == null) return;
                  await ref.read(stationRepositoryProvider).createTopUp(
                        stationId: widget.stationId,
                        amount: amount,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Submit Top-Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Top-Up Timeline',
              subtitle: 'Track dynamic bonuses & rider requests',
              actionLabel: 'Add top-up',
              onPressed: _openTopUpSheet,
            ),
            const SizedBox(height: 8),
            if (widget.topUps.isEmpty) const _EmptyMessage('No top-ups yet.'),
            ...widget.topUps.take(3).map((topUp) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: .2),
                    child: const Icon(Icons.trending_up, color: AppColors.primary, size: 18),
                  ),
                  title: Text(
                    '${_formatCurrency(topUp.totalCredited)} credited',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${topUp.requestorName ?? 'Loading Station'} → ${topUp.forRiderName ?? 'Station Wallet'} • Bonus ${_formatCurrency(topUp.bonus)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    DateFormat('MMM dd\nhh:mm a').format(topUp.createdAt ?? DateTime.now()),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.iconBg,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? iconBg;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg ?? AppColors.primary.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HierarchyTile extends StatelessWidget {
  const _HierarchyTile({
    required this.label,
    required this.title,
    this.subtitle,
    this.code,
    this.action,
  });

  final String label;
  final String title;
  final String? subtitle;
  final String? code;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          if (code != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Code: $code',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: action,
            ),
        ],
      ),
    );
  }
}


class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.delivery});

  final DeliverySummary delivery;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary.withValues(alpha: .2),
        child: Icon(
          delivery.type == DeliveryType.pabili ? Icons.shopping_bag : Icons.local_shipping,
          color: AppColors.primary,
          size: 18,
        ),
      ),
      title: Text(
        '${delivery.merchantName} • ${delivery.riderName ?? 'Unassigned'}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      ),
      subtitle: Text(
        '${delivery.pickupAddress ?? '--'} → ${delivery.dropoffAddress ?? '--'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusChip(status: delivery.status),
          const SizedBox(height: 2),
          Text(
            _formatCurrency(delivery.total),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _statusColor(status),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatCurrency(double value) => NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(value);

void _showQRCodeDialog(BuildContext context, String lsCode, String stationName) {
  if (lsCode.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LSCODE is not available')),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LSCODE QR Code',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stationName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: QrImageView(
                data: lsCode,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lsCode,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this QR code with riders to connect them to your loading station',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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

