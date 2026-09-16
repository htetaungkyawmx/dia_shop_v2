import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/misc.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final tickets = ref.watch(ticketsProvider);

    return AppPage(
      title: strings.support,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.newTicket),
      ),
      body: MaxWidthBody(
        child: tickets.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => const ShimmerBox(height: 96),
          ),
          error: (error, _) => ErrorView(
              error: error, onRetry: () => ref.invalidate(ticketsProvider)),
          data: (page) {
            if (page.items.isEmpty) {
              return EmptyView(
                icon: Icons.support_agent_rounded,
                title: strings.noTickets,
                message: strings.signInSubtitle,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _TicketCard(ticket: page.items[index]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final strings = Strings.of(context);
    final subject = TextEditingController();
    final message = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.newTicket,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: subject,
                decoration: InputDecoration(labelText: strings.subject),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? strings.subject : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: message,
                maxLines: 4,
                decoration: InputDecoration(labelText: strings.message),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? strings.message : null,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await ref.read(miscRepositoryProvider).createTicket(
                          subject: subject.text.trim(),
                          message: message.text.trim(),
                        );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (error) {
                    if (context.mounted) AppSnack.error(context, error);
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(strings.sendMessage),
              ),
            ],
          ),
        ),
      ),
    );

    subject.dispose();
    message.dispose();

    if (sent == true) {
      ref.invalidate(ticketsProvider);
      if (context.mounted) AppSnack.success(context, strings.ticketSent);
    }
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(ticket.subject,
                        style: theme.textTheme.titleSmall)),
                StatusChip(
                  label: ticket.status,
                  color: ticket.answered ? AppTheme.success : AppTheme.warning,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              Format.relative(ticket.createdAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (ticket.answered) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.ourReply,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: AppTheme.success)),
                    const SizedBox(height: 4),
                    Text(ticket.adminReply!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
