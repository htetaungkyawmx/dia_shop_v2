import 'package:flutter/widgets.dart';

/// Typed, codegen-free localisation.
///
/// English is the base class; [BurmeseStrings] overrides what differs, so a
/// string that has not been translated yet still renders in English instead of
/// showing a missing-key placeholder.
class Strings {
  const Strings();

  static const supportedLocales = [Locale('my'), Locale('en')];

  static Strings of(BuildContext context) =>
      Localizations.of<Strings>(context, Strings) ?? const Strings();

  bool get isBurmese => false;
  String get localeName => 'English';

  // --- generic
  String get appName => 'SSHGameShop';
  String get retry => 'Try again';
  String get cancel => 'Cancel';
  String get confirm => 'Confirm';
  String get save => 'Save';
  String get close => 'Close';
  String get search => 'Search';
  String get seeAll => 'See all';
  String get loading => 'Loading…';
  String get somethingWentWrong => 'Something went wrong';
  String get noConnection => 'No connection';
  String get copied => 'Copied';
  String get copy => 'Copy';
  String get optional => 'optional';

  // --- auth
  String get signIn => 'Sign in';
  String get signUp => 'Create account';
  String get signOut => 'Sign out';
  String get email => 'Email';
  String get password => 'Password';
  String get currentPassword => 'Current password';
  String get newPassword => 'New password';
  String get displayName => 'Your name';
  String get phone => 'Phone number';
  String get continueWithGoogle => 'Continue with Google';
  String get noAccountYet => "Don't have an account?";
  String get alreadyHaveAccount => 'Already have an account?';
  String get welcomeBack => 'Welcome back';
  String get signInSubtitle => 'Sign in to top up and track your orders.';
  String get signUpSubtitle => 'It takes less than a minute.';
  String get changePassword => 'Change password';
  String get passwordRule =>
      'At least 8 characters, with a letter and a number.';
  String get emailRequired => 'Enter your email';
  String get emailInvalid => 'That email does not look right';
  String get passwordRequired => 'Enter your password';
  String get nameRequired => 'Enter your name';

  // --- navigation
  String get home => 'Home';
  String get shop => 'Shop';
  String get orders => 'Orders';
  String get wallet => 'Wallet';
  String get profile => 'Profile';
  String get notifications => 'Notifications';
  String get support => 'Support';
  String get settings => 'Settings';

  // --- home
  String get featured => 'Featured';
  String get categories => 'Categories';
  String get popular => 'Popular right now';
  String get searchHint => 'Search games, gift cards, apps';
  String get maintenanceTitle => 'Under maintenance';
  String get noProducts => 'Nothing here yet';
  String get noProductsBody =>
      'New items are added often. Please check back soon.';

  // --- product
  String get choosePackage => 'Choose a package';
  String get accountDetails => 'Account details';
  String get instantDelivery => 'Instant delivery';
  String get manualDelivery => 'Delivered by our team';
  String get outOfStock => 'Out of stock';
  String get inStock => 'In stock';
  String get quantity => 'Quantity';
  String get buyNow => 'Buy now';
  String get howItWorks => 'How it works';
  String lowStock(int count) => 'Only $count left';
  String get priceFrom => 'From';

  // --- checkout
  String get checkout => 'Checkout';
  String get orderSummary => 'Order summary';
  String get subtotal => 'Subtotal';
  String get total => 'Total';
  String get walletBalance => 'Wallet balance';
  String get balanceAfter => 'Balance after';
  String get placeOrder => 'Place order';
  String get noteToSeller => 'Note for us';
  String get notEnoughBalance => 'Not enough balance';
  String shortfall(String amount) => 'You need $amount more.';
  String get topUpNow => 'Top up now';
  String get orderPlaced => 'Order placed';
  String get orderPlacedBody =>
      'We are processing your order. You will get a notification when it is done.';
  String get orderDelivered => 'Delivered!';
  String get orderDeliveredBody => 'Your code is ready below.';
  String get viewOrder => 'View order';
  String get keepShopping => 'Keep shopping';

  // --- orders
  String get myOrders => 'My orders';
  String get allOrders => 'All';
  String get orderNumber => 'Order number';
  String get orderDate => 'Ordered';
  String get noOrders => 'No orders yet';
  String get noOrdersBody => 'When you buy something it will show up here.';
  String get cancelOrder => 'Cancel order';
  String get cancelOrderConfirm =>
      'Cancel this order? The money goes back to your wallet right away.';
  String get yourCode => 'Your code';
  String get rejectedReason => 'Reason';
  String get adminNote => 'Note from us';
  String get statusPending => 'Pending';
  String get statusProcessing => 'Processing';
  String get statusCompleted => 'Completed';
  String get statusRejected => 'Rejected';
  String get statusCancelled => 'Cancelled';
  String get statusRefunded => 'Refunded';

  // --- wallet
  String get myWallet => 'My wallet';
  String get availableBalance => 'Available balance';
  String get pendingTopup => 'Pending top-up';
  String get topUp => 'Top up';
  String get transactions => 'Transactions';
  String get noTransactions => 'No transactions yet';
  String get topUpHistory => 'Top-up requests';
  String get amount => 'Amount';
  String get choosePaymentMethod => 'Choose how you paid';
  String get transferTo => 'Transfer to';
  String get accountName => 'Account name';
  String get accountNumber => 'Account number';
  String get referenceNo => 'Transaction reference';
  String get referenceHint => 'The reference shown in your payment app';
  String get senderName => 'Sender name';
  String get senderPhone => 'Sender phone';
  String get uploadSlip => 'Upload payment screenshot';
  String get changeSlip => 'Change screenshot';
  String get submitTopup => 'Submit for review';
  String get topupSubmitted => 'Top-up submitted';
  String get topupSubmittedBody =>
      'We usually confirm within a few minutes. You will get a notification.';
  String get topupPending => 'Waiting for review';
  String get topupApproved => 'Approved';
  String get topupRejected => 'Rejected';
  String get topupCancelled => 'Cancelled';
  String minAmount(String amount) => 'Minimum $amount';
  String maxAmount(String amount) => 'Maximum $amount';

  // --- profile
  String get editProfile => 'Edit profile';
  String get language => 'Language';
  String get theme => 'Appearance';
  String get themeSystem => 'System';
  String get themeLight => 'Light';
  String get themeDark => 'Dark';
  String get contactSupport => 'Contact support';
  String get signOutConfirm => 'Sign out of this device?';
  String get profileUpdated => 'Profile updated';
  String get passwordUpdated => 'Password updated';

  // --- notifications
  String get markAllRead => 'Mark all read';
  String get noNotifications => 'No notifications';
  String get noNotificationsBody =>
      'Order updates and offers will appear here.';

  // --- support
  String get newTicket => 'New message';
  String get subject => 'Subject';
  String get message => 'Message';
  String get sendMessage => 'Send';
  String get ticketSent => 'Message sent';
  String get noTickets => 'No messages yet';
  String get ourReply => 'Our reply';

  // --- website layout
  String get tagline =>
      'Game top-ups, gift cards and premium apps — fast and safe.';
  String get popularGames => 'Popular games';
  String get giftCardsAndApps => 'Gift cards & premium apps';
  String get whyChooseUs => 'Why SSHGameShop';
  String get featureInstantTitle => 'Fast delivery';
  String get featureInstantBody => 'Most orders are done within minutes.';
  String get featureSecureTitle => 'Safe wallet';
  String get featureSecureBody =>
      'Every kyat is tracked in your wallet history.';
  String get featureSupportTitle => 'Real support';
  String get featureSupportBody => 'Message us any time an order needs help.';
  String get featurePriceTitle => 'Fair prices';
  String get featurePriceBody => 'Bonus packages and regular deals.';
  String get howToBuy => 'How to buy';
  String get stepTopUpTitle => 'Top up your wallet';
  String get stepTopUpBody =>
      'Transfer with KBZPay, Wave or AYA and upload the screenshot.';
  String get stepChooseTitle => 'Choose a package';
  String get stepChooseBody => 'Pick your game and the amount you want.';
  String get stepIdTitle => 'Enter your Player ID';
  String get stepIdBody => 'Double-check it — that is where we send it.';
  String get stepDoneTitle => 'Receive it';
  String get stepDoneBody => 'We notify you the moment it is delivered.';
  String get footerShop => 'Shop';
  String get footerAccount => 'Account';
  String get footerHelp => 'Help';
  String get footerPayments => 'We accept';
  String get allRightsReserved => 'All rights reserved.';
  String get deals => 'Deals';
  String get viewAll => 'View all';
  String get buyAgain => 'Buy again';
  String get recentOrders => 'Your recent orders';
  String get faq => 'FAQ';
  String get forgotPassword => 'Forgot password?';
  String get forgotPasswordBody =>
      'For your security, passwords are reset by our support team. Send us a message with the email you signed up with.';
  String get memberSince => 'Member since';
  String get totalSpent => 'Total spent';
  String get completedOrders => 'Completed orders';
  String get changePhoto => 'Change photo';
  String get popularBadge => 'Popular';
  String get savedIds => 'Use a saved ID';
}

class BurmeseStrings extends Strings {
  const BurmeseStrings();

  @override
  bool get isBurmese => true;
  @override
  String get localeName => 'မြန်မာ';

  @override
  String get retry => 'ထပ်စမ်းပါ';
  @override
  String get cancel => 'မလုပ်တော့ပါ';
  @override
  String get confirm => 'အတည်ပြုမည်';
  @override
  String get save => 'သိမ်းမည်';
  @override
  String get close => 'ပိတ်မည်';
  @override
  String get search => 'ရှာဖွေရန်';
  @override
  String get seeAll => 'အားလုံးကြည့်ရန်';
  @override
  String get loading => 'ခေတ္တစောင့်ပါ…';
  @override
  String get somethingWentWrong => 'တစ်ခုခုမှားယွင်းနေပါသည်';
  @override
  String get noConnection => 'အင်တာနက် မရပါ';
  @override
  String get copied => 'ကူးယူပြီးပါပြီ';
  @override
  String get copy => 'ကူးယူရန်';
  @override
  String get optional => 'ဖြည့်စရာမလို';

  @override
  String get signIn => 'ဝင်ရောက်ရန်';
  @override
  String get signUp => 'အကောင့်ဖွင့်ရန်';
  @override
  String get signOut => 'ထွက်ရန်';
  @override
  String get email => 'အီးမေးလ်';
  @override
  String get password => 'စကားဝှက်';
  @override
  String get currentPassword => 'လက်ရှိ စကားဝှက်';
  @override
  String get newPassword => 'စကားဝှက် အသစ်';
  @override
  String get displayName => 'သင့်နာမည်';
  @override
  String get phone => 'ဖုန်းနံပါတ်';
  @override
  String get continueWithGoogle => 'Google ဖြင့် ဆက်လက်လုပ်ဆောင်ရန်';
  @override
  String get noAccountYet => 'အကောင့်မရှိသေးဘူးလား?';
  @override
  String get alreadyHaveAccount => 'အကောင့်ရှိပြီးသားလား?';
  @override
  String get welcomeBack => 'ပြန်လည်ကြိုဆိုပါသည်';
  @override
  String get signInSubtitle => 'ငွေဖြည့်ရန်နှင့် အော်ဒါစစ်ရန် ဝင်ရောက်ပါ။';
  @override
  String get signUpSubtitle => 'တစ်မိနစ်တောင် မကြာပါဘူး။';
  @override
  String get changePassword => 'စကားဝှက် ပြောင်းရန်';
  @override
  String get passwordRule => 'အနည်းဆုံး ၈ လုံး၊ စာလုံးနှင့် ဂဏန်း ပါရမည်။';
  @override
  String get emailRequired => 'အီးမေးလ် ဖြည့်ပါ';
  @override
  String get emailInvalid => 'အီးမေးလ် မမှန်ကန်ပါ';
  @override
  String get passwordRequired => 'စကားဝှက် ဖြည့်ပါ';
  @override
  String get nameRequired => 'နာမည် ဖြည့်ပါ';

  @override
  String get home => 'ပင်မ';
  @override
  String get shop => 'ဈေးဆိုင်';
  @override
  String get orders => 'အော်ဒါများ';
  @override
  String get wallet => 'ပိုက်ဆံအိတ်';
  @override
  String get profile => 'ကိုယ်ရေး';
  @override
  String get notifications => 'အကြောင်းကြားချက်';
  @override
  String get support => 'အကူအညီ';
  @override
  String get settings => 'ဆက်တင်';

  @override
  String get featured => 'အထူးရွေးချယ်ထားသော';
  @override
  String get categories => 'အမျိုးအစားများ';
  @override
  String get popular => 'လူကြိုက်များနေသော';
  @override
  String get searchHint => 'ဂိမ်း၊ လက်ဆောင်ကတ်၊ အက်ပ် ရှာရန်';
  @override
  String get maintenanceTitle => 'ပြုပြင်နေဆဲ';
  @override
  String get noProducts => 'ဘာမှ မရှိသေးပါ';
  @override
  String get noProductsBody =>
      'ပစ္စည်းအသစ်များ မကြာခဏ ထည့်ပါသည်။ ခဏနေ ပြန်ကြည့်ပါ။';

  @override
  String get choosePackage => 'အထုပ် ရွေးပါ';
  @override
  String get accountDetails => 'အကောင့် အချက်အလက်';
  @override
  String get instantDelivery => 'ချက်ချင်း ရရှိမည်';
  @override
  String get manualDelivery => 'ကျွန်ုပ်တို့ဘက်မှ ပို့ပေးမည်';
  @override
  String get outOfStock => 'ကုန်သွားပါပြီ';
  @override
  String get inStock => 'ရရှိနိုင်သည်';
  @override
  String get quantity => 'အရေအတွက်';
  @override
  String get buyNow => 'ယခု ဝယ်မည်';
  @override
  String get howItWorks => 'အသုံးပြုပုံ';
  @override
  String lowStock(int count) => '$count ခုသာ ကျန်တော့သည်';
  @override
  String get priceFrom => 'စတင်စျေး';

  @override
  String get checkout => 'ငွေရှင်းရန်';
  @override
  String get orderSummary => 'အော်ဒါ အနှစ်ချုပ်';
  @override
  String get subtotal => 'စုစုပေါင်း';
  @override
  String get total => 'ကျသင့်ငွေ';
  @override
  String get walletBalance => 'လက်ကျန်ငွေ';
  @override
  String get balanceAfter => 'ကျန်ရှိမည့်ငွေ';
  @override
  String get placeOrder => 'အော်ဒါတင်မည်';
  @override
  String get noteToSeller => 'မှတ်ချက်';
  @override
  String get notEnoughBalance => 'လက်ကျန်ငွေ မလုံလောက်ပါ';
  @override
  String shortfall(String amount) => '$amount ထပ်လိုအပ်ပါသည်။';
  @override
  String get topUpNow => 'ယခု ငွေဖြည့်မည်';
  @override
  String get orderPlaced => 'အော်ဒါ တင်ပြီးပါပြီ';
  @override
  String get orderPlacedBody =>
      'ဆောင်ရွက်နေပါသည်။ ပြီးစီးလျှင် အကြောင်းကြားပါမည်။';
  @override
  String get orderDelivered => 'ပေးပို့ပြီးပါပြီ!';
  @override
  String get orderDeliveredBody => 'သင့်ကုဒ်ကို အောက်တွင် ကြည့်ပါ။';
  @override
  String get viewOrder => 'အော်ဒါ ကြည့်ရန်';
  @override
  String get keepShopping => 'ဆက်လက် ဝယ်ယူရန်';

  @override
  String get myOrders => 'ကျွန်ုပ်၏ အော်ဒါများ';
  @override
  String get allOrders => 'အားလုံး';
  @override
  String get orderNumber => 'အော်ဒါနံပါတ်';
  @override
  String get orderDate => 'မှာယူသည့်ရက်';
  @override
  String get noOrders => 'အော်ဒါ မရှိသေးပါ';
  @override
  String get noOrdersBody => 'ဝယ်ယူပြီးပါက ဤနေရာတွင် ပေါ်ပါမည်။';
  @override
  String get cancelOrder => 'အော်ဒါ ပယ်ဖျက်ရန်';
  @override
  String get cancelOrderConfirm =>
      'ဤအော်ဒါကို ပယ်ဖျက်မလား? ငွေကို ချက်ချင်း ပြန်ထည့်ပေးပါမည်။';
  @override
  String get yourCode => 'သင့်ကုဒ်';
  @override
  String get rejectedReason => 'အကြောင်းပြချက်';
  @override
  String get adminNote => 'ကျွန်ုပ်တို့၏ မှတ်ချက်';
  @override
  String get statusPending => 'စောင့်ဆိုင်းဆဲ';
  @override
  String get statusProcessing => 'ဆောင်ရွက်နေဆဲ';
  @override
  String get statusCompleted => 'ပြီးစီး';
  @override
  String get statusRejected => 'ငြင်းပယ်';
  @override
  String get statusCancelled => 'ပယ်ဖျက်';
  @override
  String get statusRefunded => 'ငွေပြန်အမ်း';

  @override
  String get myWallet => 'ကျွန်ုပ်၏ ပိုက်ဆံအိတ်';
  @override
  String get availableBalance => 'သုံးစွဲနိုင်သော ငွေ';
  @override
  String get pendingTopup => 'စစ်ဆေးဆဲ ငွေဖြည့်';
  @override
  String get topUp => 'ငွေဖြည့်ရန်';
  @override
  String get transactions => 'ငွေစာရင်း';
  @override
  String get noTransactions => 'ငွေစာရင်း မရှိသေးပါ';
  @override
  String get topUpHistory => 'ငွေဖြည့် တောင်းဆိုမှုများ';
  @override
  String get amount => 'ပမာဏ';
  @override
  String get choosePaymentMethod => 'ငွေလွှဲသည့် နည်းလမ်း ရွေးပါ';
  @override
  String get transferTo => 'လွှဲရမည့် အကောင့်';
  @override
  String get accountName => 'အကောင့်အမည်';
  @override
  String get accountNumber => 'အကောင့်နံပါတ်';
  @override
  String get referenceNo => 'ငွေလွှဲနံပါတ်';
  @override
  String get referenceHint => 'ငွေလွှဲအက်ပ်တွင် ပြသည့် နံပါတ်';
  @override
  String get senderName => 'ပို့သူအမည်';
  @override
  String get senderPhone => 'ပို့သူဖုန်း';
  @override
  String get uploadSlip => 'ငွေလွှဲ screenshot တင်ရန်';
  @override
  String get changeSlip => 'screenshot ပြောင်းရန်';
  @override
  String get submitTopup => 'စစ်ဆေးရန် တင်ပြမည်';
  @override
  String get topupSubmitted => 'တင်ပြပြီးပါပြီ';
  @override
  String get topupSubmittedBody =>
      'မိနစ်ပိုင်းအတွင်း အတည်ပြုပေးပါမည်။ အကြောင်းကြားပါမည်။';
  @override
  String get topupPending => 'စစ်ဆေးနေဆဲ';
  @override
  String get topupApproved => 'အတည်ပြုပြီး';
  @override
  String get topupRejected => 'ငြင်းပယ်';
  @override
  String get topupCancelled => 'ပယ်ဖျက်';
  @override
  String minAmount(String amount) => 'အနည်းဆုံး $amount';
  @override
  String maxAmount(String amount) => 'အများဆုံး $amount';

  @override
  String get editProfile => 'ကိုယ်ရေးအချက်အလက် ပြင်ရန်';
  @override
  String get language => 'ဘာသာစကား';
  @override
  String get theme => 'အသွင်အပြင်';
  @override
  String get themeSystem => 'စက်အတိုင်း';
  @override
  String get themeLight => 'အလင်း';
  @override
  String get themeDark => 'အမှောင်';
  @override
  String get contactSupport => 'အကူအညီ ဆက်သွယ်ရန်';
  @override
  String get signOutConfirm => 'ဤစက်မှ ထွက်မလား?';
  @override
  String get profileUpdated => 'ပြင်ဆင်ပြီးပါပြီ';
  @override
  String get passwordUpdated => 'စကားဝှက် ပြောင်းပြီးပါပြီ';

  @override
  String get markAllRead => 'အားလုံး ဖတ်ပြီးအဖြစ် မှတ်ရန်';
  @override
  String get noNotifications => 'အကြောင်းကြားချက် မရှိပါ';
  @override
  String get noNotificationsBody =>
      'အော်ဒါ အခြေအနေနှင့် အထူးကမ်းလှမ်းချက်များ ဤနေရာတွင် ပေါ်ပါမည်။';

  @override
  String get newTicket => 'စာအသစ်';
  @override
  String get subject => 'ခေါင်းစဉ်';
  @override
  String get message => 'စာ';
  @override
  String get sendMessage => 'ပို့မည်';
  @override
  String get ticketSent => 'ပို့ပြီးပါပြီ';
  @override
  String get noTickets => 'စာ မရှိသေးပါ';
  @override
  String get ourReply => 'ကျွန်ုပ်တို့၏ အဖြေ';

  @override
  String get tagline =>
      'ဂိမ်းငွေဖြည့်၊ လက်ဆောင်ကတ်နှင့် Premium အက်ပ်များ — မြန်ဆန်၊ စိတ်ချရ။';
  @override
  String get popularGames => 'လူကြိုက်များသော ဂိမ်းများ';
  @override
  String get giftCardsAndApps => 'လက်ဆောင်ကတ်နှင့် Premium အက်ပ်များ';
  @override
  String get whyChooseUs => 'SSHGameShop ကို ဘာကြောင့် ရွေးသင့်လဲ';
  @override
  String get featureInstantTitle => 'မြန်ဆန်စွာ ပို့ပေး';
  @override
  String get featureInstantBody =>
      'အော်ဒါအများစုကို မိနစ်ပိုင်းအတွင်း ပြီးစီးပါသည်။';
  @override
  String get featureSecureTitle => 'စိတ်ချရသော ပိုက်ဆံအိတ်';
  @override
  String get featureSecureBody => 'ငွေအဝင်အထွက် တိုင်းကို မှတ်တမ်းတင်ထားပါသည်။';
  @override
  String get featureSupportTitle => 'အမြဲကူညီပေး';
  @override
  String get featureSupportBody =>
      'အော်ဒါနှင့်ပတ်သက်၍ အချိန်မရွေး ဆက်သွယ်နိုင်ပါသည်။';
  @override
  String get featurePriceTitle => 'သင့်တင့်သော ဈေးနှုန်း';
  @override
  String get featurePriceBody => 'Bonus အထုပ်များနှင့် အထူးလျှော့ဈေးများ။';
  @override
  String get howToBuy => 'ဝယ်ယူနည်း';
  @override
  String get stepTopUpTitle => 'ပိုက်ဆံအိတ်ထဲ ငွေဖြည့်ပါ';
  @override
  String get stepTopUpBody =>
      'KBZPay၊ Wave သို့မဟုတ် AYA နှင့် လွှဲပြီး screenshot တင်ပါ။';
  @override
  String get stepChooseTitle => 'အထုပ် ရွေးပါ';
  @override
  String get stepChooseBody => 'ဂိမ်းနှင့် လိုချင်သည့် ပမာဏကို ရွေးပါ။';
  @override
  String get stepIdTitle => 'Player ID ထည့်ပါ';
  @override
  String get stepIdBody =>
      'မှန်မမှန် ပြန်စစ်ပါ — ထို ID သို့ ပို့ပေးမည်ဖြစ်သည်။';
  @override
  String get stepDoneTitle => 'လက်ခံရယူပါ';
  @override
  String get stepDoneBody => 'ပို့ပြီးသည်နှင့် ချက်ချင်း အကြောင်းကြားပါမည်။';
  @override
  String get footerShop => 'ဈေးဆိုင်';
  @override
  String get footerAccount => 'အကောင့်';
  @override
  String get footerHelp => 'အကူအညီ';
  @override
  String get footerPayments => 'လက်ခံသော ငွေပေးချေမှု';
  @override
  String get allRightsReserved => 'မူပိုင်ခွင့်အားလုံး ရယူထားသည်။';
  @override
  String get deals => 'အထူးလျှော့ဈေး';
  @override
  String get viewAll => 'အားလုံးကြည့်ရန်';
  @override
  String get buyAgain => 'ထပ်ဝယ်မည်';
  @override
  String get recentOrders => 'မကြာသေးမီက အော်ဒါများ';
  @override
  String get faq => 'မေးလေ့ရှိသော မေးခွန်းများ';
  @override
  String get forgotPassword => 'စကားဝှက် မေ့နေပါသလား?';
  @override
  String get forgotPasswordBody =>
      'လုံခြုံရေးအတွက် စကားဝှက်ကို ကျွန်ုပ်တို့၏ support အဖွဲ့မှ ပြန်သတ်မှတ်ပေးပါသည်။ စာရင်းသွင်းခဲ့သော အီးမေးလ်နှင့်အတူ ဆက်သွယ်ပါ။';
  @override
  String get memberSince => 'အဖွဲ့ဝင်ဖြစ်သည့်နေ့';
  @override
  String get totalSpent => 'စုစုပေါင်း သုံးစွဲငွေ';
  @override
  String get completedOrders => 'ပြီးစီးသော အော်ဒါ';
  @override
  String get changePhoto => 'ဓာတ်ပုံ ပြောင်းရန်';
  @override
  String get popularBadge => 'လူကြိုက်များ';
  @override
  String get savedIds => 'သိမ်းထားသော ID သုံးရန်';
}

class StringsDelegate extends LocalizationsDelegate<Strings> {
  const StringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'my' || locale.languageCode == 'en';

  @override
  Future<Strings> load(Locale locale) async =>
      locale.languageCode == 'my' ? const BurmeseStrings() : const Strings();

  @override
  bool shouldReload(StringsDelegate old) => false;
}
