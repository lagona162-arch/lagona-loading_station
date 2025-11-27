import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
            padding: const EdgeInsets.all(16),
            children: [
              _OverviewCards(data: data),
              const SizedBox(height: 16),
              _HierarchyCard(data: data),
              const SizedBox(height: 16),
              _CommissionCard(data: data),
              const SizedBox(height: 16),
              _DeliveriesBoard(deliveries: data.deliveries),
              const SizedBox(height: 16),
              _RiderQueue(
                riders: data.riders,
                pendingCount: data.pendingRiderRequests,
                stationId: data.station.id,
              ),
              const SizedBox(height: 16),
              _MerchantDirectory(
                merchants: data.merchants,
                pendingCount: data.pendingMerchantRequests,
              ),
              const SizedBox(height: 16),
              _TopUpTimeline(
                topUps: data.topUps,
                stationId: data.station.id,
              ),
              const SizedBox(height: 24),
              Text(
                'Last synced ${DateFormat('MMM dd, hh:mm a').format(data.lastUpdated)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
      children: cards.map((card) => SizedBox(width: MediaQuery.of(context).size.width > 800 ? (MediaQuery.of(context).size.width - 64) / 2 : double.infinity, child: card)).toList(),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Business Hierarchy',
              subtitle: 'Business Hub → Loading Station → Riders → Merchants',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _HierarchyTile(
                  label: 'Business Hub',
                  title: data.station.businessHub?.name ?? '--',
                  subtitle: data.station.businessHub?.municipality,
                  code: data.station.businessHub?.code ?? 'BH-????',
                ),
                _HierarchyTile(
                  label: 'Loading Station',
                  title: data.station.name,
                  subtitle: data.station.address,
                  code: data.station.lsCode,
                  action: TextButton.icon(
                    onPressed: () async {
                      final newCode = await ref.read(stationRepositoryProvider).regenerateLsCode(data.station.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New LSCODE generated: $newCode')));
                      }
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Generate new code'),
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

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.data});

  final StationDashboardData data;

  @override
  Widget build(BuildContext context) {
    final commission = data.commission;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Dynamic Commission',
              subtitle: 'Configured from Supabase • Admin adjustable',
              actionLabel: 'Manage',
              onPressed: () {},
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CommissionPill(label: 'Business Hub', value: commission.hubPercentage),
                _CommissionPill(label: 'Loading Station', value: commission.stationPercentage),
                _CommissionPill(label: 'Rider', value: commission.riderPercentage),
                _CommissionPill(label: 'Shareholder', value: commission.shareholderPercentage),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '₱5,000 top-up → ₱${(5000 * (1 + commission.hubPercentage / 100)).toStringAsFixed(0)} credited for Business Hub.\n'
                      '₱1,000 top-up → ₱${(1000 * (1 + commission.stationPercentage / 100)).toStringAsFixed(0)} credited for Loading Station.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                    ),
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

class _DeliveriesBoard extends StatelessWidget {
  const _DeliveriesBoard({required this.deliveries});

  final List<DeliverySummary> deliveries;

  @override
  Widget build(BuildContext context) {
    final active = deliveries.where((d) => !_isDone(d.status)).toList();
    final completed = deliveries.where((d) => _isDone(d.status)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SectionHeader(
              title: 'Pabili & Padala Board',
              subtitle: '${active.length} active • ${completed.length} completed today',
              actionLabel: 'View all',
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            ...active.take(4).map((delivery) => _DeliveryTile(delivery: delivery)),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Rider Registration',
              subtitle: '$pendingCount waiting for approval',
              actionLabel: 'View riders',
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty) const _EmptyMessage('All riders activated.'),
            ...pending.map((rider) {
              final canModerate = isValidUuid(rider.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: .2),
                  child: Text(rider.name.characters.first.toUpperCase()),
                ),
                title: Text(rider.name),
                subtitle: Text('Commission ${(rider.commissionRate * 100).toStringAsFixed(0)}% • Balance ${_formatCurrency(rider.balance)}'),
                trailing: canModerate
                    ? Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Reject',
                            onPressed: () => ref.read(stationRepositoryProvider).approveRider(rider.id, approved: false),
                            icon: const Icon(Icons.close, color: AppColors.error),
                          ),
                          ElevatedButton(
                            onPressed: () => ref.read(stationRepositoryProvider).approveRider(rider.id, approved: true),
                            child: const Text('Approve'),
                          ),
                        ],
                      )
                    : const Text('Demo data item\n(no actions)', textAlign: TextAlign.right),
              );
            }),
          ],
        ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Merchants & Priority Riders',
              subtitle: subtitle,
              actionLabel: 'Assign riders',
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            if (merchants.isEmpty) const _EmptyMessage('No merchants yet. Invite partners from your Business Hub.'),
            ...merchants.map((merchant) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondaryLight,
                    child: const Icon(Icons.storefront, color: Colors.white),
                  ),
                  title: Text(merchant.businessName),
                  subtitle: Text('${merchant.ridersHandled} riders • Status: ${merchant.status ?? 'pending'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {},
                  ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Top-Up Timeline',
              subtitle: 'Track dynamic bonuses & rider requests',
              actionLabel: 'Add top-up',
              onPressed: _openTopUpSheet,
            ),
            const SizedBox(height: 12),
            if (widget.topUps.isEmpty) const _EmptyMessage('No top-ups yet.'),
            ...widget.topUps.take(5).map((topUp) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: .2),
                    child: const Icon(Icons.trending_up, color: AppColors.primary),
                  ),
                  title: Text('${_formatCurrency(topUp.totalCredited)} credited'),
                  subtitle: Text(
                    '${topUp.requestorName ?? 'Loading Station'} → ${topUp.forRiderName ?? 'Station Wallet'}\n'
                    'Bonus ${_formatCurrency(topUp.bonus)}',
                  ),
                  trailing: Text(DateFormat('MMM dd\nhh:mm a').format(topUp.createdAt ?? DateTime.now()), textAlign: TextAlign.right),
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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg ?? AppColors.primary.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (code != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text('Code: $code'),
              ),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: action),
          ],
        ),
      ),
    );
  }
}

class _CommissionPill extends StatelessWidget {
  const _CommissionPill({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
          Chip(
            label: Text('${value.toStringAsFixed(0)}%'),
            backgroundColor: AppColors.primary.withValues(alpha: .15),
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
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: .2),
        child: Icon(delivery.type == DeliveryType.pabili ? Icons.shopping_bag : Icons.local_shipping, color: AppColors.primary),
      ),
      title: Text('${delivery.merchantName} • ${delivery.riderName ?? 'Unassigned'}'),
      subtitle: Text('${delivery.pickupAddress ?? '--'} → ${delivery.dropoffAddress ?? '--'}'),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _StatusChip(status: delivery.status),
          Text(_formatCurrency(delivery.total), style: Theme.of(context).textTheme.titleMedium),
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

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
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

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return AppColors.statusPending;
    case 'accepted':
    case 'assigned':
      return Colors.blue;
    case 'picked_up':
    case 'in_transit':
      return Colors.purple;
    case 'delivered':
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

