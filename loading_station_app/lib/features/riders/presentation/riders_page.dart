import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/station_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/id_utils.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_providers.dart';
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
    final stationId = ref.watch(currentStationIdProvider);

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
                                if (!isPending)
                                  Text('${rider.vehicleType ?? 'Motorcycle'} • Balance ₱${rider.balance.toStringAsFixed(2)}')
                                else
                                  Text(rider.vehicleType ?? 'Motorcycle'),
                              ],
                            ),
                          ),
                          if (!isPending) _StatusChip(status: rider.status.name),
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRiderDocumentsDialog(context, rider, ref),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('View Documents'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: stationId == null
                                    ? null
                                    : () => _showRejectConfirmation(context, ref, rider, stationId!),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: stationId == null
                                    ? null
                                    : () => _showApproveConfirmation(context, ref, rider, stationId!),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRiderInfoDialog(context, rider),
                            icon: const Icon(Icons.info_outline),
                            label: const Text('View Rider Information'),
                          ),
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

  void _showApproveConfirmation(BuildContext context, WidgetRef ref, RiderProfile rider, String stationId) {
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

  void _showRejectConfirmation(BuildContext context, WidgetRef ref, RiderProfile rider, String stationId) {
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

Future<void> _showRiderLocation(BuildContext context, RiderProfile rider) async {
  if (rider.latitude == null || rider.longitude == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location not available')),
    );
    return;
  }

  final lat = rider.latitude!;
  final lng = rider.longitude!;
  
  // Create platform-specific map URLs
  final Uri mapUrl;
  if (Platform.isIOS) {
    // Apple Maps for iOS
    mapUrl = Uri.parse('https://maps.apple.com/?q=$lat,$lng&ll=$lat,$lng');
  } else {
    // For Android, try geo URI first (works with any map app)
    mapUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
  }
  
  // Fallback web URL (works in browser)
  final webUrl = Uri.parse('https://www.google.com/maps?q=$lat,$lng');

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${rider.name}\'s Location'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rider.currentAddress != null) ...[
            Text(
              'Address:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rider.currentAddress!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Coordinates:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$lat, $lng',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          if (rider.lastActive != null) ...[
            const SizedBox(height: 16),
            Text(
              'Last Updated:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy hh:mm a').format(rider.lastActive!),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              // Try platform-specific URL first
              bool launched = false;
              if (await canLaunchUrl(mapUrl)) {
                launched = await launchUrl(mapUrl, mode: LaunchMode.platformDefault);
              }
              
              // If first attempt failed, try web URL
              if (!launched && await canLaunchUrl(webUrl)) {
                launched = await launchUrl(webUrl, mode: LaunchMode.platformDefault);
              }
              
              // If still failed, show coordinates
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Coordinates: $lat, $lng'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } catch (e) {
              // If all else fails, show coordinates in snackbar
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Coordinates: $lat, $lng'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.map),
          label: const Text('Open in Maps'),
        ),
      ],
    ),
  );
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

void _showRiderInfoDialog(BuildContext context, RiderProfile rider) {
  final isPending = rider.status == RiderStatus.pending;
  
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: .15),
                  child: Text(
                    rider.name.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPending) ...[
                        const SizedBox(height: 4),
                        _StatusChip(status: rider.status.name),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _InfoRow(
              icon: Icons.pedal_bike,
              label: 'Vehicle Type',
              value: rider.vehicleType ?? 'Not specified',
            ),
            if (!isPending) ...[
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.account_balance_wallet,
                label: 'Balance',
                value: NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(rider.balance),
              ),
            ],
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.phone,
              label: 'Contact Number',
              value: rider.phone ?? 'Not provided',
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.tag,
              label: 'Rider ID',
              value: rider.id,
            ),
            if (!isPending && rider.lastActive != null) ...[
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.access_time,
                label: 'Last Active',
                value: DateFormat('MMM dd, yyyy hh:mm a').format(rider.lastActive!),
              ),
            ],
            if (!isPending) ...[
              const SizedBox(height: 24),
              if (rider.latitude != null && rider.longitude != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRiderLocation(context, rider),
                    icon: const Icon(Icons.location_on),
                    label: const Text('View Last Location'),
                  ),
                ),
              if (rider.latitude != null && rider.longitude != null) const SizedBox(height: 12),
            ],
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

Future<void> _showRiderDocumentsDialog(BuildContext context, RiderProfile rider, WidgetRef ref) async {
  // Fetch documents separately since they might not be in the main query
  final service = ref.read(supabaseServiceProvider);
  
  // Show dialog with loading state first
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<Map<String, String?>>(
          future: service.fetchRiderDocuments(rider.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final documentsMap = snapshot.data ?? {};
            final documents = <Map<String, String?>>[];
            
            if (documentsMap['profile_photo_url'] != null && documentsMap['profile_photo_url']!.isNotEmpty) {
              documents.add({'title': 'Profile Photo (2x2)', 'url': documentsMap['profile_photo_url']});
            }
            if (documentsMap['drivers_license_url'] != null && documentsMap['drivers_license_url']!.isNotEmpty) {
              documents.add({'title': "Driver's License", 'url': documentsMap['drivers_license_url']});
            }
            if (documentsMap['license_card_url'] != null && documentsMap['license_card_url']!.isNotEmpty) {
              documents.add({'title': 'License Card', 'url': documentsMap['license_card_url']});
            }
            if (documentsMap['official_receipt_url'] != null && documentsMap['official_receipt_url']!.isNotEmpty) {
              documents.add({'title': 'Official Receipt (OR)', 'url': documentsMap['official_receipt_url']});
            }
            if (documentsMap['certificate_of_registration_url'] != null && documentsMap['certificate_of_registration_url']!.isNotEmpty) {
              documents.add({'title': 'Certificate of Registration (CR)', 'url': documentsMap['certificate_of_registration_url']});
            }
            if (documentsMap['vehicle_front_url'] != null && documentsMap['vehicle_front_url']!.isNotEmpty) {
              documents.add({'title': 'Vehicle Front', 'url': documentsMap['vehicle_front_url']});
            }
            if (documentsMap['vehicle_side_url'] != null && documentsMap['vehicle_side_url']!.isNotEmpty) {
              documents.add({'title': 'Vehicle Side', 'url': documentsMap['vehicle_side_url']});
            }
            if (documentsMap['vehicle_back_url'] != null && documentsMap['vehicle_back_url']!.isNotEmpty) {
              documents.add({'title': 'Vehicle Back', 'url': documentsMap['vehicle_back_url']});
            }
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rider.name}\'s Documents',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (documents.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No documents available',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 16),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _showImageFullScreen(context, doc['title']!, doc['url']!),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc['title']!,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      doc['url']!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 150,
                                        color: AppColors.background,
                                        child: const Center(
                                          child: Icon(Icons.broken_image, size: 48, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          height: 150,
                                          color: AppColors.background,
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to view full size',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

void _showImageFullScreen(BuildContext context, String title, String imageUrl) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 64, color: Colors.white),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

