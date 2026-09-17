import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/strings.dart';
import '../../widgets/common.dart' show MaxWidthBody;
import '../../widgets/layout.dart';

/// What the shop is, what it sells and how to buy from it. A new visitor
/// usually wants this before they will hand over money.
class BlogsPage extends StatelessWidget {
  const BlogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final my = strings.isBurmese;

    final steps = my
        ? const [
            ('အကောင့်ဖွင့်ပါ', 'အီးမေးလ်နှင့် စကားဝှက်ဖြင့် မိနစ်ပိုင်းအတွင်း ဖွင့်နိုင်ပါသည်။'),
            ('ပိုက်ဆံအိတ် ငွေဖြည့်ပါ',
                'KBZPay, WavePay, AYA သို့မဟုတ် CB Pay ဖြင့် လွှဲပြီး screenshot တင်ပါ။ စစ်ဆေးပြီးသည်နှင့် ငွေဝင်ပါမည်။'),
            ('ပစ္စည်းရွေးပါ', 'ဂိမ်း၊ လက်ဆောင်ကတ် သို့မဟုတ် Premium အက်ပ် ရွေးပြီး အထုပ်ကို ရွေးပါ။'),
            ('Player ID ထည့်ပါ',
                'Mobile Legends ဆိုလျှင် User ID နှင့် Zone ID ၂ ခုလုံး လိုပါသည်။ ID Checker ဖြင့် အရင်စစ်နိုင်ပါသည်။'),
            ('လက်ခံရယူပါ', 'ပို့ပြီးသည်နှင့် အကြောင်းကြားချက် ရောက်ပါမည်။ လက်ဆောင်ကတ်များမှာ ကုဒ်ကို ချက်ချင်း မြင်ရပါမည်။'),
          ]
        : const [
            ('Create an account', 'An e-mail and a password is all it takes.'),
            ('Top up your wallet',
                'Transfer with KBZPay, WavePay, AYA or CB Pay and upload the screenshot. The money lands once we have checked it.'),
            ('Pick what you want',
                'A game top-up, a gift card or a premium app, then the package you want.'),
            ('Enter your Player ID',
                'Mobile Legends needs both a User ID and a Zone ID. You can confirm the account first with the ID Checker.'),
            ('Receive it',
                'You get a notification the moment it is delivered. Gift card codes appear straight away.'),
          ];

    final sells = my
        ? const [
            ('ဂိမ်းငွေဖြည့်', 'Mobile Legends, PUBG UC, Free Fire, Genshin, Wild Rift, Honor of Kings စသည်။'),
            ('လက်ဆောင်ကတ်', 'Google Play, Steam, Razer Gold, App Store & iTunes, PlayStation။'),
            ('Premium အက်ပ်', 'Netflix, Spotify, YouTube, Disney+, Canva Pro, Prime Video။'),
            ('ဘောက်ချာ', 'Garena Shells, UniPin voucher။'),
          ]
        : const [
            ('Game top-ups',
                'Mobile Legends, PUBG UC, Free Fire, Genshin, Wild Rift, Honor of Kings and more.'),
            ('Gift cards',
                'Google Play, Steam, Razer Gold, App Store & iTunes, PlayStation.'),
            ('Premium apps',
                'Netflix, Spotify, YouTube, Disney+, Canva Pro, Prime Video.'),
            ('Vouchers', 'Garena Shells and UniPin vouchers.'),
          ];

    return AppPage(
      title: 'Blogs',
      maxWidth: 1000,
      body: MaxWidthBody(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              my ? 'SSHGameShop အကြောင်း' : 'About SSHGameShop',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              my
                  ? 'ဂိမ်းငွေဖြည့်၊ လက်ဆောင်ကတ်နှင့် Premium အက်ပ်များကို မြန်မာကျပ်ဖြင့် '
                      'တိုက်ရိုက် ဝယ်နိုင်သော ဆိုင်ဖြစ်ပါသည်။ ငွေလွှဲပြီး စောင့်စရာမလိုဘဲ '
                      'ပိုက်ဆံအိတ်ထဲ ငွေထည့်ထားပြီး အချိန်မရွေး ဝယ်နိုင်ပါသည်။'
                  : 'A shop for game top-ups, gift cards and premium apps, paid in '
                      'Myanmar kyat. Keep a balance in your wallet and buy whenever '
                      'you like, instead of arranging a transfer for every order.',
              style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.65, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _Heading(my ? 'ဘာတွေ ရောင်းပါသလဲ' : 'What we sell'),
            const SizedBox(height: 14),
            for (final (title, body) in sells)
              _Item(title: title, body: body, icon: Icons.check_rounded),
            const SizedBox(height: 32),
            _Heading(my ? 'ဘယ်လို ဝယ်ရမလဲ' : 'How to buy'),
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++)
              _Item(title: steps[i].$1, body: steps[i].$2, number: '${i + 1}'),
            const SizedBox(height: 32),
            _Heading(my ? 'ဘာကြောင့် စိတ်ချရလဲ' : 'Why it is safe'),
            const SizedBox(height: 14),
            _Item(
              icon: Icons.account_balance_wallet_rounded,
              title: my ? 'ငွေအဝင်အထွက် မှတ်တမ်း' : 'Every kyat is tracked',
              body: my
                  ? 'ပိုက်ဆံအိတ် မှတ်တမ်းတွင် ငွေအဝင်အထွက်တိုင်းကို မြင်ရပါသည်။'
                  : 'Your wallet history shows every movement of money, in and out.',
            ),
            _Item(
              icon: Icons.badge_outlined,
              title: my ? 'Player ID အရင်စစ်နိုင်' : 'Check the ID first',
              body: my
                  ? 'ID Checker ဖြင့် အကောင့်နာမည်ကို ဝယ်မည့်ရှေ့ စစ်နိုင်ပါသည်။'
                  : 'The ID Checker confirms the account name before you pay, so a '
                      'mistyped id is caught early.',
            ),
            _Item(
              icon: Icons.undo_rounded,
              title: my ? 'ပို့မရလျှင် ငွေပြန်ရ' : 'Refunded if undelivered',
              body: my
                  ? 'ပို့၍မရသော အော်ဒါများကို ငွေအပြည့် ပိုက်ဆံအိတ်ထဲ ပြန်ထည့်ပေးပါသည်။'
                  : 'An order we cannot deliver is refunded to your wallet in full.',
            ),
            const SizedBox(height: 34),
            Center(
              child: FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: Text(my ? 'ဆိုင်ကို ကြည့်ရန်' : 'Browse the shop'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800));
}

class _Item extends StatelessWidget {
  const _Item(
      {required this.title, required this.body, this.icon, this.number});

  final String title;
  final String body;
  final IconData? icon;
  final String? number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: number != null
                  ? Text(number!,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800))
                  : Icon(icon, size: 19, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
