import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_exception.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart' show MaxWidthBody;
import '../../widgets/layout.dart';

/// Looks a player up by account id before they buy, so a mistyped id is caught
/// here rather than after the diamonds have gone to a stranger.
class IdCheckPage extends ConsumerStatefulWidget {
  const IdCheckPage({super.key});

  @override
  ConsumerState<IdCheckPage> createState() => _IdCheckPageState();
}

class _IdCheckPageState extends ConsumerState<IdCheckPage> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _zoneId = TextEditingController();
  bool _busy = false;
  String? _name;
  String? _message;

  @override
  void dispose() {
    _userId.dispose();
    _zoneId.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _name = null;
      _message = null;
    });
    try {
      final result = await ref.read(catalogRepositoryProvider).checkId(
            game: 'mobilelegends',
            userId: _userId.text.trim(),
            zoneId: _zoneId.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _name = result.found ? result.playerName : null;
        _message = result.found ? null : (result.message ?? 'No account found.');
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not check that id.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);

    return AppPage(
      title: 'ID Checker',
      maxWidth: 560,
      body: MaxWidthBody(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            const Center(child: AppLogo(size: 76)),
            const SizedBox(height: 18),
            Text(
              'Mobile Legends Region Checker',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              strings.isBurmese
                  ? 'User ID နှင့် Zone ID ထည့်ပြီး သင့်အကောင့်ကို စစ်ဆေးပါ။'
                  : 'Enter your User ID and Zone ID to confirm the account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _userId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'User ID', hintText: '123456789'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter your User ID' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _zoneId,
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (_) => _check(),
                    decoration: const InputDecoration(
                        labelText: 'Zone ID', hintText: '2005'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter your Zone ID' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _check,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Check account'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => context.go('/shop'),
                    child: Text(strings.shop),
                  ),
                ],
              ),
            ),
            if (_name != null) ...[
              const SizedBox(height: 24),
              _ResultCard(
                icon: Icons.check_circle_rounded,
                color: AppTheme.success,
                title: _name!,
                body: strings.isBurmese
                    ? 'ဤအကောင့် တွေ့ပါသည်။'
                    : 'Account found.',
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 24),
              _ResultCard(
                icon: Icons.info_outline_rounded,
                color: AppTheme.warning,
                title: strings.isBurmese ? 'မတွေ့ပါ' : 'Not found',
                body: _message!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
