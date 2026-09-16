import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/misc.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_widgets.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  String? _status = 'OPEN';

  void _refresh() {
    ref.invalidate(ticketsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _reply(SupportTicket ticket) async {
    final reply = await promptForNote(
      context,
      title: 'Reply to ${ticket.userName ?? ticket.userEmail ?? 'customer'}',
      message: ticket.message,
      confirmLabel: 'Send reply',
      noteLabel: 'Your reply',
      noteRequired: true,
    );
    if (reply == null || reply.isEmpty) return;

    try {
      await ref
          .read(apiProvider)
          .replyTicket(ticket.id, reply: reply, status: 'ANSWERED');
      _refresh();
      if (mounted) AdminSnack.success(context, 'Reply sent');
    } catch (error) {
      if (mounted) AdminSnack.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tickets = ref.watch(ticketsProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        actions: [
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
                for (final entry in {
                  null: 'All',
                  'OPEN': 'Open',
                  'ANSWERED': 'Answered',
                  'CLOSED': 'Closed'
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _status == entry.key,
                    onSelected: (_) => setState(() => _status = entry.key),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncSection(
              value: tickets,
              onRetry: _refresh,
              loadingHeight: 420,
              builder: (page) {
                if (page.items.isEmpty) {
                  return const AdminEmpty(
                    icon: Icons.mark_email_read_rounded,
                    title: 'Inbox zero',
                    message: 'No messages waiting for a reply.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ticket = page.items[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(ticket.subject,
                                      style: theme.textTheme.titleSmall),
                                ),
                                StatusBadge(status: ticket.status),
                                const SizedBox(width: 12),
                                Text(
                                  Format.relative(ticket.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${ticket.userName ?? ''} · ${ticket.userEmail ?? ''}'
                              '${ticket.orderNo == null ? '' : ' · ${ticket.orderNo}'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Text(ticket.message),
                            if (ticket.answered) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AdminTheme.success
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AdminTheme.success
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Our reply',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                                color: AdminTheme.success)),
                                    const SizedBox(height: 4),
                                    Text(ticket.adminReply!),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () => _reply(ticket),
                                icon: const Icon(Icons.reply_rounded, size: 18),
                                label: Text(
                                    ticket.answered ? 'Reply again' : 'Reply'),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
