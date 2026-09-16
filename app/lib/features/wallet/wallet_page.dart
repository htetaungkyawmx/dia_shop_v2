import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/wallet.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final wallet = ref.watch(walletProvider);
    final transactions = ref.watch(walletTransactionsProvider);
    final topups = ref.watch(topupsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.myWallet)),
      body: MaxWidthBody(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletProvider);
            ref.invalidate(walletTransactionsProvider);
            ref.invalidate(topupsProvider);
            await ref.read(walletProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(
                balance: wallet.value?.balance ?? 0,
                pending: wallet.value?.pendingTopupAmount ?? 0,
                loading: wallet.isLoading,
                onTopUp: () => context.push('/wallet/topup'),
              ),
              const SizedBox(height: 24),
              topups.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (page) {
                  final pending =
                      page.items.where((t) => t.status == TopupStatus.pending).toList();
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: strings.topUpHistory),
                      const SizedBox(height: 10),
                      for (final topup in pending) ...[
                        _TopupTile(topup: topup),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
              SectionHeader(title: strings.transactions),
              const SizedBox(height: 10),
              transactions.when(
                loading: () => Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(height: 66),
                    ),
                  ),
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  compact: true,
                  onRetry: () => ref.invalidate(walletTransactionsProvider),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: EmptyView(
                        icon: Icons.receipt_outlined,
                        title: strings.noTransactions,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final tx in page.items) ...[
                        _TransactionTile(transaction: tx),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.pending,
    required this.loading,
    required this.onTopUp,
  });

  final int balance;
  final int pending;
  final bool loading;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                strings.availableBalance,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            Text(
              Format.money(balance),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (pending > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${strings.pendingTopup}: ${Format.money(pending)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTopUp,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.brandDeep,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(strings.topUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = transaction.isCredit;
    final color = credit ? AppTheme.success : theme.colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (credit ? AppTheme.success : AppTheme.brand).withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                switch (transaction.type) {
                  'TOPUP' => Icons.add_rounded,
                  'PURCHASE' => Icons.shopping_bag_rounded,
                  'REFUND' => Icons.replay_rounded,
                  'ADJUSTMENT' => Icons.tune_rounded,
                  _ => Icons.card_giftcard_rounded,
                },
                size: 19,
                color: credit ? AppTheme.success : AppTheme.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Format.relative(transaction.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Format.signedMoney(transaction.amount),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
                Text(
                  Format.money(transaction.balanceAfter),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupTile extends ConsumerWidget {
  const _TopupTile({required this.topup});

  final TopupRequest topup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: AppTheme.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${Format.money(topup.amount)} · ${topup.paymentMethodName}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${topup.requestNo} · ${strings.topupPending}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(walletRepositoryProvider).cancelTopup(topup.id);
                  ref.invalidate(topupsProvider);
                  ref.invalidate(walletProvider);
                } catch (error) {
                  if (context.mounted) AppSnack.error(context, error);
                }
              },
              child: Text(strings.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
