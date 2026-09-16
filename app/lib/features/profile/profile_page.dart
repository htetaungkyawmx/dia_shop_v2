import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final user = ref.watch(authProvider).value;
    final balance =
        ref.watch(walletProvider).value?.balance ?? user?.balance ?? 0;
    final config = ref.watch(appConfigProvider).value;
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    if (user == null) {
      return AppPage(
        showBack: false,
        title: strings.profile,
        body: EmptyView(
          icon: Icons.person_outline_rounded,
          title: strings.signIn,
          message: strings.signInSubtitle,
          action: FilledButton(
            onPressed: () => pushLogin(context),
            child: Text(strings.signIn),
          ),
        ),
      );
    }

    return AppPage(
      showBack: false,
      title: strings.profile,
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const _Avatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: theme.textTheme.titleLarge),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${strings.walletBalance}: ${Format.money(balance)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _StatsRow(),
            const SizedBox(height: 24),
            _Group(
              children: [
                _Tile(
                  icon: Icons.edit_outlined,
                  label: strings.editProfile,
                  onTap: () => context.push('/profile/edit'),
                ),
                _Tile(
                  icon: Icons.lock_outline_rounded,
                  label: strings.changePassword,
                  onTap: () => context.push('/profile/password'),
                ),
                _Tile(
                  icon: Icons.notifications_none_rounded,
                  label: strings.notifications,
                  trailing: unread > 0 ? Badge(label: Text('$unread')) : null,
                  onTap: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Group(
              children: [
                _Tile(
                  icon: Icons.translate_rounded,
                  label: strings.language,
                  trailing: Text(strings.localeName,
                      style: theme.textTheme.bodyMedium),
                  onTap: () => _pickLanguage(context, ref),
                ),
                _Tile(
                  icon: Icons.brightness_6_outlined,
                  label: strings.theme,
                  trailing: Text(
                    switch (ref.watch(settingsProvider).themeMode) {
                      ThemeMode.light => strings.themeLight,
                      ThemeMode.dark => strings.themeDark,
                      ThemeMode.system => strings.themeSystem,
                    },
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () => _pickTheme(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Group(
              children: [
                _Tile(
                  icon: Icons.support_agent_rounded,
                  label: strings.support,
                  onTap: () => context.push('/support'),
                ),
                _Tile(
                  icon: Icons.help_outline_rounded,
                  label: strings.faq,
                  onTap: () => context.push('/faq'),
                ),
                if ((config?.support['messenger'] ?? '').isNotEmpty)
                  _Tile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messenger',
                    onTap: () => _open(config!.support['messenger']!),
                  ),
                if ((config?.support['telegram'] ?? '').isNotEmpty)
                  _Tile(
                    icon: Icons.send_rounded,
                    label: 'Telegram',
                    onTap: () => _open(config!.support['telegram']!),
                  ),
                if ((config?.support['phone'] ?? '').isNotEmpty)
                  _Tile(
                    icon: Icons.phone_outlined,
                    label: config!.support['phone']!,
                    onTap: () => _open('tel:${config.support['phone']}'),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(strings.signOut),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).locale.languageCode;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) => Navigator.pop(context, value),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(value: 'my', title: Text('မြန်မာ')),
              RadioListTile<String>(value: 'en', title: Text('English')),
            ],
          ),
        ),
      ),
    );
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setLocale(Locale(choice));
    }
  }

  static Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final strings = Strings.of(context);
    final current = ref.read(settingsProvider).themeMode;
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(switch (mode) {
                    ThemeMode.light => strings.themeLight,
                    ThemeMode.dark => strings.themeDark,
                    ThemeMode.system => strings.themeSystem,
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setThemeMode(choice);
    }
  }

  static Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final strings = Strings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.signOut),
        content: Text(strings.signOutConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.icon, required this.label, this.trailing, this.onTap});

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _Avatar extends ConsumerStatefulWidget {
  const _Avatar();

  @override
  ConsumerState<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends ConsumerState<_Avatar> {
  bool _uploading = false;

  Future<void> _change() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(authProvider.notifier).uploadPhoto(
            bytes: await picked.readAsBytes(),
            fileName: picked.name,
          );
      if (mounted) {
        AppSnack.success(context, Strings.of(context).profileUpdated);
      }
    } catch (error) {
      if (mounted) AppSnack.error(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Tooltip(
      message: Strings.of(context).changePhoto,
      child: InkWell(
        onTap: _uploading ? null : _change,
        customBorder: const CircleBorder(),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.16),
              backgroundImage:
                  user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
              child: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : user.photoUrl != null
                      ? null
                      : Text(
                          user.initials,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor, width: 2),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final stats = ref.watch(accountStatsProvider).value;
    final items = [
      (
        strings.totalSpent,
        stats == null ? '—' : Format.money(stats.totalSpent),
        Icons.payments_rounded
      ),
      (
        strings.completedOrders,
        stats == null ? '—' : '${stats.completedOrders}',
        Icons.check_circle_rounded
      ),
      (
        strings.memberSince,
        stats?.memberSince == null ? '—' : Format.date(stats!.memberSince!),
        Icons.event_available_rounded,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
                  label: items[i].$1,
                  value: items[i].$2,
                  icon: items[i].$3,
                  color: accentFor(i))),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
