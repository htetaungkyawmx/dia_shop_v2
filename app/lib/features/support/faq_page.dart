import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart' show MaxWidthBody;
import '../../widgets/layout.dart';

/// Answers to the questions customers ask most, readable without signing in.
class FaqPage extends ConsumerWidget {
  const FaqPage({super.key});

  static List<(String, String)> _entries(bool my) => my
      ? const [
          (
            'ပိုက်ဆံအိတ်ထဲ ဘယ်လို ငွေဖြည့်ရမလဲ?',
            'ပိုက်ဆံအိတ် → ငွေဖြည့်ရန် ကိုနှိပ်ပါ။ ငွေလွှဲနည်း ရွေးပြီး ပြထားသော အကောင့်သို့ လွှဲပါ။ ငွေလွှဲနံပါတ်နှင့် screenshot ကို တင်ပြပါ။ စစ်ဆေးပြီးသည်နှင့် ငွေဝင်ပါမည်။'
          ),
          (
            'ငွေဖြည့်တာ ဘယ်လောက်ကြာလဲ?',
            'ပုံမှန်အားဖြင့် မိနစ်ပိုင်းအတွင်း အတည်ပြုပေးပါသည်။ ညနက်ပိုင်းတွင် အနည်းငယ် ကြာနိုင်ပါသည်။ အတည်ပြုပြီးပါက အကြောင်းကြားချက် ရောက်ပါမည်။'
          ),
          (
            'ဂိမ်းစိန် ဘယ်လောက်ကြာမှ ရောက်မလဲ?',
            'အော်ဒါအများစုကို မိနစ်ပိုင်းအတွင်း ပို့ပေးပါသည်။ "ချက်ချင်း ရရှိမည်" ပါသော ပစ္စည်းများ (လက်ဆောင်ကတ်) သည် ဝယ်ပြီးသည်နှင့် ကုဒ်ကို ချက်ချင်း မြင်ရပါမည်။'
          ),
          (
            'Player ID မှားရိုက်မိရင် ဘာလုပ်ရမလဲ?',
            'အော်ဒါ "စောင့်ဆိုင်းဆဲ" အခြေအနေတွင် ရှိနေသေးလျှင် အော်ဒါကို ပယ်ဖျက်နိုင်ပြီး ငွေကို ချက်ချင်း ပြန်ရပါမည်။ ဆောင်ရွက်နေပြီဆိုလျှင် support သို့ ချက်ချင်း ဆက်သွယ်ပါ။'
          ),
          (
            'ငွေပြန်အမ်းလို့ ရလား?',
            'ပို့ပေး၍မရသော အော်ဒါများကို ငွေအပြည့် ပိုက်ဆံအိတ်ထဲသို့ ပြန်ထည့်ပေးပါသည်။ ဖော်ပြပြီးသော ကုဒ်များကိုမူ ပြန်အမ်း၍ မရပါ။'
          ),
          (
            'စကားဝှက် မေ့သွားရင်?',
            'Support သို့ စာရင်းသွင်းခဲ့သော အီးမေးလ်နှင့်အတူ ဆက်သွယ်ပါ။ ယာယီ စကားဝှက် ပေးပါမည်။ ဝင်ပြီးနောက် ကိုယ်ရေး → စကားဝှက်ပြောင်းရန် တွင် ပြောင်းပါ။'
          ),
          (
            'ကျွန်ုပ်၏ ငွေ လုံခြုံလား?',
            'ငွေအဝင်အထွက် တိုင်းကို ပိုက်ဆံအိတ် မှတ်တမ်းတွင် မှတ်ထားပြီး သင်ကိုယ်တိုင် အချိန်မရွေး စစ်ကြည့်နိုင်ပါသည်။'
          ),
        ]
      : const [
          (
            'How do I top up my wallet?',
            'Go to Wallet → Top up. Pick a payment method, transfer to the account shown, then submit the transaction reference and a screenshot. The money appears once we have checked it.'
          ),
          (
            'How long does a top-up take?',
            'Usually a few minutes. Late at night it can take a little longer. You get a notification the moment it is approved.'
          ),
          (
            'How long until my diamonds arrive?',
            'Most orders are delivered within minutes. Items marked "Instant delivery", such as gift cards, show your code as soon as you pay.'
          ),
          (
            'I typed the wrong Player ID. What now?',
            'While the order is still Pending you can cancel it and the money returns to your wallet straight away. If it is already Processing, contact support right away.'
          ),
          (
            'Can I get a refund?',
            'Orders we cannot deliver are refunded in full to your wallet. Codes that have already been revealed cannot be refunded.'
          ),
          (
            'I forgot my password.',
            'Contact support with the email you signed up with and we will give you a temporary password. After signing in, change it under Profile → Change password.'
          ),
          (
            'Is my money safe?',
            'Every movement of money is recorded in your wallet history, which you can check at any time.'
          ),
        ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final theme = Theme.of(context);
    final entries = _entries(strings.isBurmese);

    return AppPage(
      title: strings.faq,
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (question, answer) in entries) ...[
              Card(
                child: Theme(
                  // Remove the ExpansionTile's own dividers inside a card.
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(Icons.help_outline_rounded,
                        color: AppTheme.brand),
                    title: Text(question, style: theme.textTheme.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            const SupportContacts(),
          ],
        ),
      ),
    );
  }
}

/// Every way to reach the shop that is configured in the admin settings.
/// Works signed out, which matters for someone who cannot sign in.
class SupportContacts extends ConsumerWidget {
  const SupportContacts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final support =
        ref.watch(appConfigProvider).value?.support ?? const <String, String>{};
    final signedIn = ref.watch(isSignedInProvider);

    Future<void> open(String url) async {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    final buttons = <Widget>[
      if (signedIn)
        FilledButton.icon(
          onPressed: () => context.push('/support'),
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: Text(strings.contactSupport),
        ),
      if ((support['messenger'] ?? '').isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => open(support['messenger']!),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Messenger'),
        ),
      if ((support['telegram'] ?? '').isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => open(support['telegram']!),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Telegram'),
        ),
      if ((support['viber'] ?? '').isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => open(support['viber']!),
          icon: const Icon(Icons.call_rounded, size: 18),
          label: const Text('Viber'),
        ),
      if ((support['phone'] ?? '').isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => open('tel:${support['phone']}'),
          icon: const Icon(Icons.phone_outlined, size: 18),
          label: Text(support['phone']!),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }
}

/// Shown from the sign-in screen. Resets are done by support, not by e-mail.
Future<void> showForgotPassword(BuildContext context) {
  final strings = Strings.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.forgotPassword,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(strings.forgotPasswordBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.6)),
            const SizedBox(height: 18),
            const SupportContacts(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/faq');
              },
              child: Text(strings.faq),
            ),
          ],
        ),
      ),
    ),
  );
}
