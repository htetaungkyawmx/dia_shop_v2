-- Auto-fulfillment: map a package to an external supplier (Smile.one for now)
-- so a paid order can be delivered by calling the supplier's API instead of by
-- hand. Everything here is additive and optional; a NULL supplier means the
-- package is still fulfilled manually, exactly as before.

-- Which supplier "game" this product maps to on the provider side,
-- e.g. Smile.one uses 'mobilelegends', 'freefire', 'pubgmobile'.
ALTER TABLE products ADD COLUMN supplier_game VARCHAR(60);

-- Per-package supplier link. supplier is the provider code ('SMILEONE'),
-- supplier_product_id is that provider's package id for this exact package.
ALTER TABLE product_variants ADD COLUMN supplier VARCHAR(30);
ALTER TABLE product_variants ADD COLUMN supplier_product_id VARCHAR(80);

-- The provider's order id, kept for tracing a delivered order back to the API.
ALTER TABLE order_items ADD COLUMN supplier_order_id VARCHAR(120);

-- Smile.one credentials and switches. Blank by default: auto-fulfillment stays
-- OFF until staff paste in their reseller key and turn it on, so the manual
-- flow is untouched on upgrade.
INSERT INTO app_settings (key, value, description) VALUES
    ('smileone.enabled',  'false', 'Master switch for Smile.one auto-fulfillment'),
    ('smileone.base_url', 'https://www.smile.one', 'Smile.one API base URL'),
    ('smileone.region',   'br', 'Smile.one region path segment (br, ph, ...)'),
    ('smileone.uid',      '', 'Smile.one merchant UID (from the Smile.one team)'),
    ('smileone.email',    '', 'Smile.one account e-mail used for the API'),
    ('smileone.key',      '', 'Smile.one API secret key (keep private)')
ON CONFLICT (key) DO NOTHING;
