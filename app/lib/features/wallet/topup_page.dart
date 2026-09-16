import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../models/wallet.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';

/// Manual transfer flow: pick a method, copy the account, transfer in the
/// banking app, then send us the reference and a screenshot to verify.
class TopupPage extends ConsumerStatefulWidget {
  const TopupPage({super.key});

  @override
  ConsumerState<TopupPage> createState() => _TopupPageState();
}

class _TopupPageState extends ConsumerState<TopupPage> {
  static const _quickAmounts = [5000, 10000, 20000, 50000, 100000, 200000];

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();

  PaymentMethod? _method;
  String? _slipUrl;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _senderName.dispose();
    _senderPhone.dispose();
    super.dispose();
  }

  Future<void> _pickSlip() async {
    final strings = Strings.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final url = await ref.read(walletRepositoryProvider).uploadSlip(
            bytes: bytes,
            fileName: picked.name,
          );
      if (mounted) {
        setState(() => _slipUrl = url);
        AppSnack.success(context, strings.uploadSlip);
      }
    } catch (error) {
      if (mounted) AppSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final strings = Strings.of(context);
    final method = _method;
    if (method == null) {
      AppSnack.info(context, strings.choosePaymentMethod);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(walletRepositoryProvider).createTopup(
            paymentMethodId: method.id,
            amount: int.parse(_amount.text.trim()),
            referenceNo: _reference.text.trim(),
            senderName: _senderName.text.trim(),
            senderPhone: _senderPhone.text.trim(),
            screenshotUrl: _slipUrl,
          );
      ref.invalidate(topupsProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      if (mounted) _showSubmitted();
    } catch (error) {
      if (mounted) AppSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSubmitted() {
    final strings = Strings.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_rounded,
            size: 40, color: AppTheme.success),
        title: Text(strings.topupSubmitted),
        content: Text(strings.topupSubmittedBody, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (this.context.mounted) this.context.pop();
            },
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final methods = ref.watch(paymentMethodsProvider);

    return AppPage(
      title: strings.topUp,
      body: MaxWidthBody(
        child: methods.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ShimmerBox(height: 90),
              SizedBox(height: 12),
              ShimmerBox(height: 200),
            ],
          ),
          error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(paymentMethodsProvider)),
          data: (list) {
            // Default to the first method so the form is usable immediately.
            _method ??= list.isNotEmpty ? list.first : null;
            final active = _method;

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionHeader(title: strings.choosePaymentMethod),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in list)
                        ChoiceChip(
                          label: Text(m.name),
                          selected: active?.id == m.id,
                          onSelected: (_) => setState(() => _method = m),
                        ),
                    ],
                  ),
                  if (active != null) ...[
                    const SizedBox(height: 16),
                    _AccountCard(method: active),
                  ],
                  const SizedBox(height: 24),
                  SectionHeader(title: strings.amount),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in _quickAmounts)
                        ActionChip(
                          label: Text(Format.number(value)),
                          onPressed: () =>
                              setState(() => _amount.text = '$value'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: strings.amount,
                      suffixText: 'Ks',
                      helperText: active == null
                          ? null
                          : '${strings.minAmount(Format.money(active.minAmount))} · '
                              '${strings.maxAmount(Format.money(active.maxAmount))}',
                    ),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null || parsed <= 0) return strings.amount;
                      if (active != null && parsed < active.minAmount) {
                        return strings
                            .minAmount(Format.money(active.minAmount));
                      }
                      if (active != null && parsed > active.maxAmount) {
                        return strings
                            .maxAmount(Format.money(active.maxAmount));
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reference,
                    decoration: InputDecoration(
                      labelText: strings.referenceNo,
                      helperText: strings.referenceHint,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? strings.referenceNo
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _senderName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: '${strings.senderName} (${strings.optional})',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _senderPhone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '${strings.senderPhone} (${strings.optional})',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SlipPicker(
                    url: _slipUrl,
                    uploading: _uploading,
                    onPick: _pickSlip,
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: _submitting || _uploading ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(strings.submitTopup),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.topupSubmittedBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.transferTo,
                          style: theme.textTheme.bodySmall),
                      Text(method.name, style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CopyRow(label: strings.accountName, value: method.accountName),
            const SizedBox(height: 8),
            _CopyRow(label: strings.accountNumber, value: method.accountNumber),
            if (method.localisedInstructions(strings.isBurmese) != null) ...[
              const SizedBox(height: 14),
              Text(
                method.localisedInstructions(strings.isBurmese)!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              SelectableText(value, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        IconButton(
          tooltip: strings.copy,
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) AppSnack.success(context, strings.copied);
          },
        ),
      ],
    );
  }
}

class _SlipPicker extends StatelessWidget {
  const _SlipPicker(
      {required this.url, required this.uploading, required this.onPick});

  final String? url;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    if (uploading) {
      return const ShimmerBox(height: 120);
    }

    if (url != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppImage(url: url, height: 180, fit: BoxFit.contain),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(strings.changeSlip),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
          border:
              Border.all(color: theme.dividerColor, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 28, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(strings.uploadSlip, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
