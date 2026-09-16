-- =====================================================================
-- Starter catalog. Everything here is editable from the admin panel;
-- it only exists so a fresh install is not an empty shop.
-- The admin account is created by AdminBootstrap from application config.
-- =====================================================================

INSERT INTO app_settings (key, value, description) VALUES
    ('app.name',              'Dia Shop',        'Shop name shown in the apps'),
    ('app.maintenance',       'false',           'Blocks ordering while true'),
    ('app.maintenance_message','We are upgrading. Please check back shortly.', 'Shown when maintenance is on'),
    ('topup.min_amount',      '1000',            'Minimum wallet top-up in MMK'),
    ('topup.max_amount',      '5000000',         'Maximum wallet top-up in MMK'),
    ('support.messenger',     'https://m.me/diashop',  'Messenger support link'),
    ('support.telegram',      'https://t.me/diashop',  'Telegram support link'),
    ('support.viber',         '',                'Viber support link'),
    ('support.phone',         '09-000000000',    'Support phone number'),
    ('order.auto_complete_code_delivery', 'true', 'Deliver CODE_POOL orders instantly without admin review');

INSERT INTO payment_methods (code, name, account_name, account_number, min_amount, max_amount, sort_order, instructions, instructions_my) VALUES
    ('KPAY',  'KBZPay',     'Dia Shop',   '09-000-000-001', 1000, 5000000, 1,
     'Transfer the exact amount to this KBZPay number, then upload the screenshot and the transaction reference.',
     'ဤ KBZPay နံပါတ်သို့ ပမာဏအတိအကျ လွှဲပေးပါ။ ပြီးလျှင် screenshot နှင့် ငွေလွှဲနံပါတ်ကို တင်ပေးပါ။'),
    ('WAVE',  'WavePay',    'Dia Shop',   '09-000-000-002', 1000, 5000000, 2,
     'Transfer the exact amount to this WavePay number, then upload the screenshot and the transaction reference.',
     'ဤ WavePay နံပါတ်သို့ ပမာဏအတိအကျ လွှဲပေးပါ။ ပြီးလျှင် screenshot နှင့် ငွေလွှဲနံပါတ်ကို တင်ပေးပါ။'),
    ('AYA',   'AYA Pay',    'Dia Shop',   '09-000-000-003', 1000, 5000000, 3,
     'Transfer the exact amount to this AYA Pay number, then upload the screenshot and the transaction reference.',
     'ဤ AYA Pay နံပါတ်သို့ ပမာဏအတိအကျ လွှဲပေးပါ။ ပြီးလျှင် screenshot နှင့် ငွေလွှဲနံပါတ်ကို တင်ပေးပါ။'),
    ('CBPAY', 'CB Pay',     'Dia Shop',   '09-000-000-004', 1000, 5000000, 4,
     'Transfer the exact amount to this CB Pay number, then upload the screenshot and the transaction reference.',
     'ဤ CB Pay နံပါတ်သို့ ပမာဏအတိအကျ လွှဲပေးပါ။ ပြီးလျှင် screenshot နှင့် ငွေလွှဲနံပါတ်ကို တင်ပေးပါ။');

INSERT INTO categories (slug, name, name_my, sort_order) VALUES
    ('mobile-games', 'Mobile Games',  'မိုဘိုင်းဂိမ်းများ',   1),
    ('gift-cards',   'Gift Cards',    'လက်ဆောင်ကတ်များ',    2),
    ('premium-apps', 'Premium Apps',  'Premium အက်ပ်များ',  3),
    ('vouchers',     'Vouchers',      'ဘောက်ချာများ',        4);

-- ------------------------------------------------------- mobile games
INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, featured, sort_order)
SELECT id, 'mlbb', 'Mobile Legends: Bang Bang', 'Mobile Legends',
       'Diamonds and passes for Mobile Legends. Delivered to your Player ID within minutes.',
       'Mobile Legends အတွက် စိန်နှင့် pass များ။ သင့် Player ID သို့ မိနစ်ပိုင်းအတွင်း ပေးပို့ပါသည်။',
       'MANUAL', TRUE, 1 FROM categories WHERE slug = 'mobile-games';

INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, featured, sort_order)
SELECT id, 'pubg-mobile', 'PUBG Mobile', 'PUBG Mobile',
       'UC top-up for PUBG Mobile. Enter your numeric Player ID at checkout.',
       'PUBG Mobile အတွက် UC ဖြည့်ခြင်း။ ငွေရှင်းချိန်တွင် သင့် Player ID ထည့်ပါ။',
       'MANUAL', TRUE, 2 FROM categories WHERE slug = 'mobile-games';

INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, featured, sort_order)
SELECT id, 'magic-chess', 'Magic Chess: Go Go', 'Magic Chess Go Go',
       'Magic Chess: Go Go diamond top-up.',
       'Magic Chess: Go Go စိန်ဖြည့်ခြင်း။',
       'MANUAL', TRUE, 3 FROM categories WHERE slug = 'mobile-games';

INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, featured, sort_order)
SELECT id, 'free-fire', 'Free Fire', 'Free Fire',
       'Free Fire diamond top-up delivered to your Player ID.',
       'Free Fire စိန်များကို သင့် Player ID သို့ ပေးပို့ပါသည်။',
       'MANUAL', TRUE, 4 FROM categories WHERE slug = 'mobile-games';

-- Input fields
INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, options, validation_regex, required, sort_order)
SELECT id, 'player_id', 'Player ID', 'Player ID', '123456789', 'NUMBER', NULL, '^[0-9]{5,15}$', TRUE, 1 FROM products WHERE slug = 'mlbb';
INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, options, validation_regex, required, sort_order)
SELECT id, 'server_id', 'Server ID', 'Server ID', '1234', 'NUMBER', NULL, '^[0-9]{3,6}$', TRUE, 2 FROM products WHERE slug = 'mlbb';

INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, options, validation_regex, required, sort_order)
SELECT id, 'player_id', 'Player ID', 'Player ID', '5123456789', 'NUMBER', NULL, '^[0-9]{8,15}$', TRUE, 1 FROM products WHERE slug = 'pubg-mobile';

INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, options, validation_regex, required, sort_order)
SELECT id, 'player_id', 'Player ID', 'Player ID', '123456789', 'NUMBER', NULL, '^[0-9]{5,15}$', TRUE, 1 FROM products WHERE slug = 'magic-chess';
INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, options, validation_regex, required, sort_order)
SELECT id, 'server_id', 'Server ID', 'Server ID', '1234', 'NUMBER', NULL, '^[0-9]{3,6}$', TRUE, 2 FROM products WHERE slug = 'magic-chess';

INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, options, validation_regex, required, sort_order)
SELECT id, 'player_id', 'Player ID', 'Player ID', '123456789', 'NUMBER', NULL, '^[0-9]{5,15}$', TRUE, 1 FROM products WHERE slug = 'free-fire';

-- MLBB packages
INSERT INTO product_variants (product_id, sku, name, name_my, bonus_text, price, compare_at_price, cost_price, stock_type, popularity, sort_order)
SELECT p.id, v.sku, v.name, v.name, v.bonus, v.price, v.compare_at, v.cost, 'UNLIMITED', v.pop, v.ord
FROM products p, (VALUES
    ('MLBB-11',   '11 Diamonds',    NULL,        1000::BIGINT,  NULL::BIGINT,       850::BIGINT,  40, 1),
    ('MLBB-22',   '22 Diamonds',    NULL,        1900,          2000,               1600,         55, 2),
    ('MLBB-56',   '56 Diamonds',    '+5 Bonus',  4200,          4500,               3600,         85, 3),
    ('MLBB-86',   '86 Diamonds',    '+8 Bonus',  6200,          6600,               5300,         92, 4),
    ('MLBB-172',  '172 Diamonds',   '+17 Bonus', 12000,         12800,              10300,        78, 5),
    ('MLBB-257',  '257 Diamonds',   '+25 Bonus', 18000,         19000,              15500,        70, 6),
    ('MLBB-706',  '706 Diamonds',   '+70 Bonus', 48000,         51000,              41000,        64, 7),
    ('MLBB-WP',   'Weekly Pass',    'Best value',6000,          NULL,               5100,         95, 8),
    ('MLBB-TWL',  'Twilight Pass',  'Limited',   38000,         40000,              33000,        58, 9)
) AS v(sku, name, bonus, price, compare_at, cost, pop, ord)
WHERE p.slug = 'mlbb';

-- PUBG UC packages
INSERT INTO product_variants (product_id, sku, name, name_my, bonus_text, price, compare_at_price, cost_price, stock_type, popularity, sort_order)
SELECT p.id, v.sku, v.name, v.name, v.bonus, v.price, v.compare_at, v.cost, 'UNLIMITED', v.pop, v.ord
FROM products p, (VALUES
    ('PUBG-60',   '60 UC',    NULL,         4200::BIGINT,  NULL::BIGINT,  3600::BIGINT, 80, 1),
    ('PUBG-325',  '325 UC',   '+25 Bonus',  20000,         21000,         17500,        90, 2),
    ('PUBG-660',  '660 UC',   '+60 Bonus',  39000,         41000,         34000,        86, 3),
    ('PUBG-1800', '1800 UC',  '+300 Bonus', 99000,         105000,        87000,        72, 4),
    ('PUBG-3850', '3850 UC',  '+850 Bonus', 195000,        205000,        172000,       60, 5),
    ('PUBG-8100', '8100 UC',  'Best value', 390000,        410000,        345000,       45, 6)
) AS v(sku, name, bonus, price, compare_at, cost, pop, ord)
WHERE p.slug = 'pubg-mobile';

-- Magic Chess packages
INSERT INTO product_variants (product_id, sku, name, name_my, bonus_text, price, compare_at_price, cost_price, stock_type, popularity, sort_order)
SELECT p.id, v.sku, v.name, v.name, v.bonus, v.price, NULL, v.cost, 'UNLIMITED', v.pop, v.ord
FROM products p, (VALUES
    ('MCGG-50',   '50 Diamonds',  NULL,       3400::BIGINT, 2900::BIGINT, 70, 1),
    ('MCGG-78',   '78 Diamonds',  '+8 Bonus', 5200,         4400,         82, 2),
    ('MCGG-150',  '150 Diamonds', '+15 Bonus',10000,        8600,         76, 3),
    ('MCGG-355',  '355 Diamonds', '+35 Bonus',23000,        19800,        62, 4),
    ('MCGG-WP',   'Weekly Pass',  NULL,       6000,         5100,         88, 5)
) AS v(sku, name, bonus, price, cost, pop, ord)
WHERE p.slug = 'magic-chess';

-- Free Fire packages
INSERT INTO product_variants (product_id, sku, name, name_my, bonus_text, price, compare_at_price, cost_price, stock_type, popularity, sort_order)
SELECT p.id, v.sku, v.name, v.name, v.bonus, v.price, NULL, v.cost, 'UNLIMITED', v.pop, v.ord
FROM products p, (VALUES
    ('FF-100',    '100 Diamonds',  NULL,        4500::BIGINT,  3900::BIGINT,  75, 1),
    ('FF-310',    '310 Diamonds',  '+10 Bonus', 13000,         11200,         84, 2),
    ('FF-520',    '520 Diamonds',  '+20 Bonus', 21000,         18100,         79, 3),
    ('FF-1060',   '1060 Diamonds', '+60 Bonus', 42000,         36500,         66, 4),
    ('FF-WEEKLY', 'Weekly Membership', NULL,    7500,          6400,          90, 5)
) AS v(sku, name, bonus, price, cost, pop, ord)
WHERE p.slug = 'free-fire';

-- --------------------------------------------------------- gift cards
INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, instructions, instructions_my, featured, sort_order)
SELECT id, 'google-play-gift', 'Google Play Gift Card', 'Google Play လက်ဆောင်ကတ်',
       'Region-locked Google Play codes, delivered instantly to your order screen.',
       'Google Play ကုဒ်များကို order စာမျက်နှာတွင် ချက်ချင်း ရရှိပါမည်။',
       'CODE_DELIVERY',
       'Redeem at play.google.com/redeem. Codes are single-use and non-refundable once revealed.',
       'play.google.com/redeem တွင် အသုံးပြုပါ။ ကုဒ်ကို တစ်ကြိမ်သာ အသုံးပြုနိုင်ပြီး ဖော်ပြပြီးပါက ပြန်အမ်းမရပါ။',
       TRUE, 1 FROM categories WHERE slug = 'gift-cards';

INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, instructions, instructions_my, sort_order)
SELECT id, 'steam-wallet', 'Steam Wallet Code', 'Steam Wallet ကုဒ်',
       'Top up your Steam wallet instantly.',
       'သင့် Steam wallet ကို ချက်ချင်း ဖြည့်ပါ။',
       'CODE_DELIVERY',
       'Redeem in the Steam client under Games > Redeem a Steam Wallet Code.',
       'Steam client ရှိ Games > Redeem a Steam Wallet Code တွင် အသုံးပြုပါ။',
       2 FROM categories WHERE slug = 'gift-cards';

INSERT INTO product_variants (product_id, sku, name, bonus_text, price, cost_price, stock_type, stock_quantity, popularity, sort_order)
SELECT p.id, v.sku, v.name, NULL, v.price, v.cost, 'CODE_POOL', 0, v.pop, v.ord
FROM products p, (VALUES
    ('GPLAY-10', 'Google Play $10', 48000::BIGINT, 44000::BIGINT, 80, 1),
    ('GPLAY-25', 'Google Play $25', 118000,        109000,        70, 2),
    ('GPLAY-50', 'Google Play $50', 232000,        215000,        55, 3)
) AS v(sku, name, price, cost, pop, ord)
WHERE p.slug = 'google-play-gift';

INSERT INTO product_variants (product_id, sku, name, bonus_text, price, cost_price, stock_type, stock_quantity, popularity, sort_order)
SELECT p.id, v.sku, v.name, NULL, v.price, v.cost, 'CODE_POOL', 0, v.pop, v.ord
FROM products p, (VALUES
    ('STEAM-10', 'Steam $10', 49000::BIGINT, 45000::BIGINT, 65, 1),
    ('STEAM-20', 'Steam $20', 96000,         89000,         60, 2),
    ('STEAM-50', 'Steam $50', 238000,        221000,        45, 3)
) AS v(sku, name, price, cost, pop, ord)
WHERE p.slug = 'steam-wallet';

-- ------------------------------------------------------- premium apps
INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, featured, sort_order)
SELECT id, 'netflix', 'Netflix Premium', 'Netflix Premium',
       'Shared or private Netflix Premium plans with warranty for the full period.',
       'အာမခံပါဝင်သော Netflix Premium အစီအစဉ်များ။',
       'MANUAL', TRUE, 1 FROM categories WHERE slug = 'premium-apps';

INSERT INTO products (category_id, slug, name, name_my, description, description_my, fulfillment_type, sort_order)
SELECT id, 'spotify', 'Spotify Premium', 'Spotify Premium',
       'Spotify Premium upgrade for your own account.',
       'သင့်ကိုယ်ပိုင် account အတွက် Spotify Premium အဆင့်မြှင့်ခြင်း။',
       'MANUAL', 2 FROM categories WHERE slug = 'premium-apps';

INSERT INTO product_fields (product_id, field_key, label, label_my, placeholder, input_type, required, sort_order)
SELECT id, 'account_email', 'Account Email', 'အကောင့် အီးမေးလ်', 'you@example.com', 'EMAIL', TRUE, 1
FROM products WHERE slug IN ('netflix', 'spotify');

INSERT INTO product_variants (product_id, sku, name, bonus_text, price, cost_price, stock_type, stock_quantity, popularity, sort_order)
SELECT p.id, v.sku, v.name, v.bonus, v.price, v.cost, 'LIMITED', v.qty, v.pop, v.ord
FROM products p, (VALUES
    ('NFLX-1M', 'Netflix Premium 1 Month',  NULL,          18000::BIGINT, 14000::BIGINT, 40, 88, 1),
    ('NFLX-3M', 'Netflix Premium 3 Months', 'Save 10%',    49000,         38000,         25, 72, 2),
    ('NFLX-6M', 'Netflix Premium 6 Months', 'Save 18%',    92000,         71000,         12, 58, 3)
) AS v(sku, name, bonus, price, cost, qty, pop, ord)
WHERE p.slug = 'netflix';

INSERT INTO product_variants (product_id, sku, name, bonus_text, price, cost_price, stock_type, stock_quantity, popularity, sort_order)
SELECT p.id, v.sku, v.name, v.bonus, v.price, v.cost, 'LIMITED', v.qty, v.pop, v.ord
FROM products p, (VALUES
    ('SPOT-1M', 'Spotify Premium 1 Month',  NULL,       12000::BIGINT, 9000::BIGINT, 50, 80, 1),
    ('SPOT-3M', 'Spotify Premium 3 Months', 'Save 12%', 32000,         24000,        30, 66, 2)
) AS v(sku, name, bonus, price, cost, qty, pop, ord)
WHERE p.slug = 'spotify';

-- Stock movement history for the seeded LIMITED stock, so the ledger is complete.
INSERT INTO stock_movements (variant_id, delta, quantity_before, quantity_after, reason, note)
SELECT id, stock_quantity, 0, stock_quantity, 'RESTOCK', 'Initial seed stock'
FROM product_variants WHERE stock_type = 'LIMITED' AND stock_quantity > 0;

INSERT INTO banners (title, image_url, link_type, link_value, sort_order) VALUES
    ('Mobile Legends instant top-up', 'https://placehold.co/900x420/6D28D9/FFFFFF/png?text=MLBB+Diamonds', 'PRODUCT', 'mlbb', 1),
    ('PUBG UC best price',            'https://placehold.co/900x420/B45309/FFFFFF/png?text=PUBG+UC',       'PRODUCT', 'pubg-mobile', 2),
    ('Gift cards in stock',           'https://placehold.co/900x420/047857/FFFFFF/png?text=Gift+Cards',    'CATEGORY', 'gift-cards', 3);
