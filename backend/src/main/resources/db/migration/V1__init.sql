-- =====================================================================
-- Dia Shop core schema
-- Money is stored as BIGINT in MMK (no minor units are used in Myanmar).
-- Wallet balance is never updated directly: every change is written as a
-- ledger row in wallet_transactions and the balance is the running total.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------- users
CREATE TABLE users (
    id               BIGSERIAL PRIMARY KEY,
    public_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    email            VARCHAR(190) NOT NULL,
    password_hash    VARCHAR(100),
    display_name     VARCHAR(120) NOT NULL,
    phone            VARCHAR(30),
    photo_url        VARCHAR(500),
    role             VARCHAR(20)  NOT NULL DEFAULT 'USER',
    status           VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    email_verified   BOOLEAN      NOT NULL DEFAULT FALSE,
    google_id        VARCHAR(190),
    locale           VARCHAR(10)  NOT NULL DEFAULT 'my',
    last_login_at    TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_email     UNIQUE (email),
    CONSTRAINT uq_users_public_id UNIQUE (public_id),
    CONSTRAINT uq_users_google_id UNIQUE (google_id),
    CONSTRAINT ck_users_role   CHECK (role   IN ('USER', 'ADMIN', 'SUPER_ADMIN')),
    CONSTRAINT ck_users_status CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED'))
);
CREATE INDEX idx_users_status ON users (status);

CREATE TABLE refresh_tokens (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash  VARCHAR(100) NOT NULL,
    device_info VARCHAR(255),
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);

CREATE TABLE devices (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    fcm_token  VARCHAR(255) NOT NULL,
    platform   VARCHAR(20)  NOT NULL DEFAULT 'ANDROID',
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_devices_token UNIQUE (fcm_token)
);
CREATE INDEX idx_devices_user ON devices (user_id);

-- --------------------------------------------------------------- wallet
CREATE TABLE wallets (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    balance    BIGINT      NOT NULL DEFAULT 0,
    version    BIGINT      NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_wallets_user    UNIQUE (user_id),
    CONSTRAINT ck_wallets_balance CHECK (balance >= 0)
);

CREATE TABLE wallet_transactions (
    id             BIGSERIAL PRIMARY KEY,
    public_id      UUID        NOT NULL DEFAULT gen_random_uuid(),
    wallet_id      BIGINT      NOT NULL REFERENCES wallets (id) ON DELETE CASCADE,
    type           VARCHAR(20) NOT NULL,
    -- signed: positive credits the wallet, negative debits it
    amount         BIGINT      NOT NULL,
    balance_after  BIGINT      NOT NULL,
    description    VARCHAR(255) NOT NULL,
    reference_type VARCHAR(30),
    reference_id   BIGINT,
    created_by     BIGINT REFERENCES users (id),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_wallet_tx_public UNIQUE (public_id),
    CONSTRAINT ck_wallet_tx_type CHECK (type IN ('TOPUP', 'PURCHASE', 'REFUND', 'ADJUSTMENT', 'BONUS')),
    CONSTRAINT ck_wallet_tx_amount CHECK (amount <> 0)
);
CREATE INDEX idx_wallet_tx_wallet  ON wallet_transactions (wallet_id, created_at DESC);
CREATE INDEX idx_wallet_tx_ref     ON wallet_transactions (reference_type, reference_id);

-- ------------------------------------------------------------- catalog
CREATE TABLE categories (
    id         BIGSERIAL PRIMARY KEY,
    slug       VARCHAR(80)  NOT NULL,
    name       VARCHAR(120) NOT NULL,
    name_my    VARCHAR(120),
    icon_url   VARCHAR(500),
    sort_order INT          NOT NULL DEFAULT 0,
    active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_categories_slug UNIQUE (slug)
);

CREATE TABLE products (
    id               BIGSERIAL PRIMARY KEY,
    category_id      BIGINT       NOT NULL REFERENCES categories (id),
    slug             VARCHAR(80)  NOT NULL,
    name             VARCHAR(160) NOT NULL,
    name_my          VARCHAR(160),
    description      TEXT,
    description_my   TEXT,
    image_url        VARCHAR(500),
    banner_url       VARCHAR(500),
    -- how the order is fulfilled once paid
    fulfillment_type VARCHAR(20)  NOT NULL DEFAULT 'MANUAL',
    instructions     TEXT,
    instructions_my  TEXT,
    featured         BOOLEAN      NOT NULL DEFAULT FALSE,
    sort_order       INT          NOT NULL DEFAULT 0,
    active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_products_slug UNIQUE (slug),
    CONSTRAINT ck_products_fulfillment CHECK (fulfillment_type IN ('MANUAL', 'CODE_DELIVERY', 'AUTO_API'))
);
CREATE INDEX idx_products_category ON products (category_id, active, sort_order);

-- Per-product input fields the buyer must fill (Player ID, Server, Email...).
CREATE TABLE product_fields (
    id           BIGSERIAL PRIMARY KEY,
    product_id   BIGINT       NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    field_key    VARCHAR(50)  NOT NULL,
    label        VARCHAR(120) NOT NULL,
    label_my     VARCHAR(120),
    placeholder  VARCHAR(160),
    help_text    VARCHAR(255),
    input_type   VARCHAR(20)  NOT NULL DEFAULT 'TEXT',
    options      TEXT,                       -- JSON array for SELECT inputs
    validation_regex VARCHAR(255),
    required     BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order   INT          NOT NULL DEFAULT 0,
    CONSTRAINT uq_product_field UNIQUE (product_id, field_key),
    CONSTRAINT ck_product_field_type CHECK (input_type IN ('TEXT', 'NUMBER', 'EMAIL', 'SELECT'))
);

-- A buyable package: "86 Diamonds", "60 UC", "Netflix 1 Month"...
CREATE TABLE product_variants (
    id             BIGSERIAL PRIMARY KEY,
    product_id     BIGINT       NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    sku            VARCHAR(80)  NOT NULL,
    name           VARCHAR(160) NOT NULL,
    name_my        VARCHAR(160),
    bonus_text     VARCHAR(80),
    description    VARCHAR(255),
    price          BIGINT       NOT NULL,
    compare_at_price BIGINT,                 -- shown struck through when higher
    cost_price     BIGINT       NOT NULL DEFAULT 0,   -- admin-only, for profit report
    image_url      VARCHAR(500),
    stock_type     VARCHAR(20)  NOT NULL DEFAULT 'UNLIMITED',
    stock_quantity INT          NOT NULL DEFAULT 0,
    low_stock_threshold INT     NOT NULL DEFAULT 5,
    max_per_order  INT          NOT NULL DEFAULT 10,
    popularity     INT          NOT NULL DEFAULT 0,
    sort_order     INT          NOT NULL DEFAULT 0,
    active         BOOLEAN      NOT NULL DEFAULT TRUE,
    version        BIGINT       NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_variant_sku UNIQUE (sku),
    CONSTRAINT ck_variant_price CHECK (price >= 0),
    CONSTRAINT ck_variant_stock CHECK (stock_quantity >= 0),
    CONSTRAINT ck_variant_stock_type CHECK (stock_type IN ('UNLIMITED', 'LIMITED', 'CODE_POOL'))
);
CREATE INDEX idx_variants_product ON product_variants (product_id, active, sort_order);

-- Pre-generated codes/keys for CODE_POOL variants (gift cards, premium keys).
CREATE TABLE stock_codes (
    id            BIGSERIAL PRIMARY KEY,
    variant_id    BIGINT       NOT NULL REFERENCES product_variants (id) ON DELETE CASCADE,
    code          VARCHAR(255) NOT NULL,
    secret        VARCHAR(255),              -- optional PIN / password
    status        VARCHAR(20)  NOT NULL DEFAULT 'AVAILABLE',
    order_item_id BIGINT,
    assigned_at   TIMESTAMPTZ,
    created_by    BIGINT REFERENCES users (id),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_stock_code UNIQUE (variant_id, code),
    CONSTRAINT ck_stock_code_status CHECK (status IN ('AVAILABLE', 'RESERVED', 'SOLD', 'VOID'))
);
CREATE INDEX idx_stock_codes_pick ON stock_codes (variant_id, status);

CREATE TABLE stock_movements (
    id           BIGSERIAL PRIMARY KEY,
    variant_id   BIGINT       NOT NULL REFERENCES product_variants (id) ON DELETE CASCADE,
    delta        INT          NOT NULL,
    quantity_before INT       NOT NULL,
    quantity_after  INT       NOT NULL,
    reason       VARCHAR(30)  NOT NULL,
    note         VARCHAR(255),
    reference_id BIGINT,
    created_by   BIGINT REFERENCES users (id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_stock_move_reason CHECK (reason IN ('RESTOCK', 'SALE', 'REFUND', 'MANUAL_ADJUST', 'CORRECTION', 'DAMAGE'))
);
CREATE INDEX idx_stock_moves_variant ON stock_movements (variant_id, created_at DESC);

-- --------------------------------------------------------------- orders
CREATE TABLE orders (
    id            BIGSERIAL PRIMARY KEY,
    order_no      VARCHAR(30)  NOT NULL,
    user_id       BIGINT       NOT NULL REFERENCES users (id),
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    subtotal      BIGINT       NOT NULL,
    discount      BIGINT       NOT NULL DEFAULT 0,
    total         BIGINT       NOT NULL,
    customer_note VARCHAR(500),
    admin_note    VARCHAR(500),
    reject_reason VARCHAR(255),
    processed_by  BIGINT REFERENCES users (id),
    processed_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_orders_no UNIQUE (order_no),
    CONSTRAINT ck_orders_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'REJECTED', 'CANCELLED', 'REFUNDED'))
);
CREATE INDEX idx_orders_user   ON orders (user_id, created_at DESC);
CREATE INDEX idx_orders_status ON orders (status, created_at DESC);

CREATE TABLE order_items (
    id             BIGSERIAL PRIMARY KEY,
    order_id       BIGINT       NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    variant_id     BIGINT       NOT NULL REFERENCES product_variants (id),
    -- snapshots so history stays correct after the catalog changes
    product_name   VARCHAR(160) NOT NULL,
    variant_name   VARCHAR(160) NOT NULL,
    image_url      VARCHAR(500),
    unit_price     BIGINT       NOT NULL,
    quantity       INT          NOT NULL,
    line_total     BIGINT       NOT NULL,
    field_values   TEXT,                    -- JSON object of product_fields answers
    delivered_code VARCHAR(255),
    delivered_secret VARCHAR(255),
    CONSTRAINT ck_order_item_qty CHECK (quantity > 0)
);
CREATE INDEX idx_order_items_order ON order_items (order_id);

-- ------------------------------------------------------- wallet top-ups
CREATE TABLE payment_methods (
    id             BIGSERIAL PRIMARY KEY,
    code           VARCHAR(40)  NOT NULL,
    name           VARCHAR(120) NOT NULL,
    account_name   VARCHAR(120) NOT NULL,
    account_number VARCHAR(80)  NOT NULL,
    logo_url       VARCHAR(500),
    instructions   TEXT,
    instructions_my TEXT,
    min_amount     BIGINT       NOT NULL DEFAULT 1000,
    max_amount     BIGINT       NOT NULL DEFAULT 5000000,
    sort_order     INT          NOT NULL DEFAULT 0,
    active         BOOLEAN      NOT NULL DEFAULT TRUE,
    -- set when an online gateway backs this method instead of a manual transfer
    gateway        VARCHAR(30),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_method_code UNIQUE (code)
);

CREATE TABLE topup_requests (
    id                BIGSERIAL PRIMARY KEY,
    request_no        VARCHAR(30)  NOT NULL,
    user_id           BIGINT       NOT NULL REFERENCES users (id),
    payment_method_id BIGINT       NOT NULL REFERENCES payment_methods (id),
    amount            BIGINT       NOT NULL,
    sender_name       VARCHAR(120),
    sender_phone      VARCHAR(30),
    reference_no      VARCHAR(80)  NOT NULL,
    screenshot_url    VARCHAR(500),
    status            VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    admin_note        VARCHAR(500),
    reviewed_by       BIGINT REFERENCES users (id),
    reviewed_at       TIMESTAMPTZ,
    -- gateway fields, unused for manual transfers
    gateway           VARCHAR(30),
    gateway_ref       VARCHAR(120),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_topup_no UNIQUE (request_no),
    CONSTRAINT ck_topup_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
    CONSTRAINT ck_topup_amount CHECK (amount > 0)
);
CREATE INDEX idx_topups_user   ON topup_requests (user_id, created_at DESC);
CREATE INDEX idx_topups_status ON topup_requests (status, created_at DESC);
-- one open request per reference number, so a screenshot cannot be replayed
CREATE UNIQUE INDEX uq_topup_reference_active
    ON topup_requests (payment_method_id, reference_no)
    WHERE status IN ('PENDING', 'APPROVED');

-- ------------------------------------------------------------ content
CREATE TABLE banners (
    id         BIGSERIAL PRIMARY KEY,
    title      VARCHAR(160),
    image_url  VARCHAR(500) NOT NULL,
    link_type  VARCHAR(20)  NOT NULL DEFAULT 'NONE',
    link_value VARCHAR(255),
    sort_order INT          NOT NULL DEFAULT 0,
    active     BOOLEAN      NOT NULL DEFAULT TRUE,
    starts_at  TIMESTAMPTZ,
    ends_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_banner_link CHECK (link_type IN ('NONE', 'PRODUCT', 'CATEGORY', 'URL'))
);

CREATE TABLE notifications (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT REFERENCES users (id) ON DELETE CASCADE,  -- NULL = broadcast
    title      VARCHAR(160) NOT NULL,
    body       VARCHAR(500) NOT NULL,
    type       VARCHAR(30)  NOT NULL DEFAULT 'GENERAL',
    data       TEXT,
    read_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user ON notifications (user_id, created_at DESC);

CREATE TABLE support_tickets (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    subject    VARCHAR(160) NOT NULL,
    message    TEXT         NOT NULL,
    order_id   BIGINT REFERENCES orders (id),
    status     VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    admin_reply TEXT,
    replied_by BIGINT REFERENCES users (id),
    replied_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_ticket_status CHECK (status IN ('OPEN', 'ANSWERED', 'CLOSED'))
);
CREATE INDEX idx_tickets_status ON support_tickets (status, created_at DESC);

CREATE TABLE app_settings (
    key         VARCHAR(80) PRIMARY KEY,
    value       TEXT        NOT NULL,
    description VARCHAR(255),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
    id           BIGSERIAL PRIMARY KEY,
    actor_id     BIGINT REFERENCES users (id),
    action       VARCHAR(80)  NOT NULL,
    entity_type  VARCHAR(50)  NOT NULL,
    entity_id    VARCHAR(50),
    detail       TEXT,
    ip_address   VARCHAR(45),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_entity ON audit_logs (entity_type, entity_id, created_at DESC);
