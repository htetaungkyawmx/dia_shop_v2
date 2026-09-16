-- Rebrand to "Game Store". V1/V2 are already applied in production and must
-- never be edited (Flyway would refuse to start on a checksum mismatch), so
-- the rename lives here.
UPDATE app_settings SET value = 'Game Store', updated_at = now()
 WHERE key = 'app.name' AND value = 'Dia Shop';

UPDATE payment_methods SET account_name = 'Game Store', updated_at = now()
 WHERE account_name = 'Dia Shop';

-- The seeded support links pointed at handles this shop does not own. Blank
-- them so the app hides those buttons until real ones are entered.
UPDATE app_settings SET value = '', updated_at = now()
 WHERE key IN ('support.messenger', 'support.telegram')
   AND value IN ('https://m.me/diashop', 'https://t.me/diashop');
UPDATE app_settings SET value = '', updated_at = now()
 WHERE key = 'support.phone' AND value = '09-000000000';
