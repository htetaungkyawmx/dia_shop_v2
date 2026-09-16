import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/wallet.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

/// Review queue for manual wallet transfers: check the screenshot and the
/// reference against the bank app, then approve or reject.
class TopupsPage extends ConsumerStatefulWidget {
  const TopupsPage({super.key});

  @override
  ConsumerState<TopupsPage> createState() => _TopupsPageState();
}

class _TopupsPageState extends ConsumerState<TopupsPage> {
  TopupFilter _filter = const TopupFilter(status: TopupStatus.pending);
  int? _busyId;

  void _refresh() {
    ref.invalidate(topupsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _approve(TopupRequest topup) async {
    final amountController = TextEditingController(text: '${topup.amount}');
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve top-up'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${topup.userName ?? ''} · ${topup.userEmail ?? ''}'),
              const SizedBox(height: 4),
              Text('Reference ${topup.referenceNo} via ${topup.paymentMethodName}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amount to credit',
                  // Lets staff correct a figure that does not match the slip.
                  helperText: 'Change this if the slip shows a different amount',
                  suffixText: 'Ks',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminTheme.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve and credit'),
          ),
        ],
      ),
    );

    final amount = int.tryParse(amountController.text.trim());
    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();

    if (confirmed != true || amount == null || amount <= 0) return;

    setState(() => _busyId = topup.id);
    try {
      await ref.read(apiProvider).approveTopup(
            topup.id,
            note: note.isEmpty ? null : note,
            approvedAmount: amount == topup.amount ? null : amount,
          );
      _refresh();
      if (mounted) {
        AdminSnack.success(context, '${Format.money(amount)} credited to ${topup.userEmail}');
      }
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(TopupRequest topup) async {
    final note = await promptForNote(
      context,
      title: 'Reject top-up',
      message: 'Tell the customer why this transfer could not be confirmed.',
      confirmLabel: 'Reject',
      noteLabel: 'Reason shown to the customer',
      noteRequired: true,
      confirmColor: AdminTheme.danger,
    );
    if (note == null) return;

    setState(() => _busyId = topup.id);
    try {
      await ref.read(apiProvider).rejectTopup(topup.id, note: note);
      _refresh();
      if (mounted) AdminSnack.info(context, 'Top-up rejected');
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topups = ref.watch(topupsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top-ups'),
        actions: [
          SearchField(
            hint: 'Request no, reference or email',
            onChanged: (value) =>
                setState(() => _filter = TopupFilter(status: _filter.status, query: value)),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _chip(null, 'All'),
                for (final status in TopupStatus.values)
                  _chip(status, prettyStatus(status.name.toUpperCase())),
              ],
            ),
          ),
          Expanded(
            child: AsyncSection(
              value: topups,
              onRetry: _refresh,
              loadingHeight: 420,
              builder: (page) {
                if (page.items.isEmpty) {
                  return const AdminEmpty(
                    icon: Icons.inbox_rounded,
                    title: 'Nothing to review',
                    message: 'New transfers will appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final topup = page.items[index];
                    return _TopupCard(
                      topup: topup,
                      busy: _busyId == topup.id,
                      onApprove: () => _approve(topup),
                      onReject: () => _reject(topup),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(TopupStatus? status, String label) => ChoiceChip(
        label: Text(label),
        selected: _filter.status == status,
        onSelected: (_) =>
            setState(() => _filter = TopupFilter(status: status, query: _filter.query)),
      );
}

class _TopupCard extends StatelessWidget {
  const _TopupCard({
    required this.topup,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final TopupRequest topup;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = topup.status == TopupStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topup.screenshotUrl != null)
              GestureDetector(
                onTap: () => _viewSlip(context, topup.screenshotUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: topup.screenshotUrl!,
                    width: 90,
                    height: 110,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 90,
                      height: 110,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 90,
                height: 110,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(Format.money(topup.amount), style: theme.textTheme.titleLarge),
                      const SizedBox(width: 12),
                      StatusBadge(status: topup.status.name.toUpperCase()),
                      const Spacer(),
                      Text(
                        Format.dateTime(topup.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _Field(label: 'Request', value: topup.requestNo),
                      _Field(label: 'Method', value: topup.paymentMethodName),
                      _Field(label: 'Reference', value: topup.referenceNo, copyable: true),
                      _Field(label: 'Customer', value: topup.userEmail ?? '—'),
                      if ((topup.senderName ?? '').isNotEmpty)
                        _Field(label: 'Sender', value: topup.senderName!),
                      if ((topup.senderPhone ?? '').isNotEmpty)
                        _Field(label: 'Sender phone', value: topup.senderPhone!, copyable: true),
                    ],
                  ),
                  if ((topup.adminNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Note: ${topup.adminNote}', style: theme.textTheme.bodySmall),
                  ],
                  if (pending) ...[
                    const SizedBox(height: 16),
                    busy
                        ? const SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            children: [
                              FilledButton.icon(
                                style:
                                    FilledButton.styleFrom(backgroundColor: AdminTheme.success),
                                onPressed: onApprove,
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Approve'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: onReject,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AdminTheme.danger),
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewSlip(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(value, style: theme.textTheme.bodyMedium),
            if (copyable)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.copy_rounded, size: 14),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) AdminSnack.success(context, 'Copied');
                },
              ),
          ],
        ),
      ],
    );
  }
}
