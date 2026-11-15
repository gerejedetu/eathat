-- Cuisine anti-gaspi: Cloudflare D1 (SQLite).
-- Money is in cents (INTEGER), dates are 'YYYY-MM-DD' (Paris day), times are ISO 8601 UTC.
-- D1 always enforces foreign keys, so no PRAGMA is needed.

CREATE TABLE products (
  id                       INTEGER PRIMARY KEY,
  name                     TEXT NOT NULL,
  brand                    TEXT,
  category                 TEXT NOT NULL,          -- feculents, frais, legumes, fruits, epicerie, pain, boissons, petit_dej, viande, poisson, surgeles
  unit_format              TEXT,                   -- as sold: "1 kg", "pack 10 x 1 L"
  default_storage          TEXT NOT NULL CHECK (default_storage IN ('frigo', 'placard', 'congelateur')),
  shelf_life_days          INTEGER CHECK (shelf_life_days > 0),         -- closed, in its default place
  shelf_life_opened_days   INTEGER CHECK (shelf_life_opened_days > 0),  -- once opened
  shelf_life_frozen_days   INTEGER CHECK (shelf_life_frozen_days > 0),  -- once frozen
  tags                     TEXT,                   -- comma separated facts the preferences filter on: "lactose,gluten,arachide,alcool"
  ean                      TEXT UNIQUE,            -- barcode, for a later scan
  notes                    TEXT,
  created_at               TEXT NOT NULL
) STRICT;

-- One product per name and brand, so an import finds the one already known.
CREATE UNIQUE INDEX products_identity ON products (name COLLATE NOCASE, coalesce(brand, '') COLLATE NOCASE);

CREATE TABLE orders (
  id                 INTEGER PRIMARY KEY,
  store              TEXT NOT NULL,
  external_ref       TEXT UNIQUE,                  -- the store's order number: importing it twice is refused
  status             TEXT NOT NULL DEFAULT 'validee' CHECK (status IN ('panier', 'validee', 'livree', 'annulee')),
  ordered_at         TEXT NOT NULL,
  delivered_at       TEXT,
  total_cents        INTEGER,
  delivery_fee_cents INTEGER,
  discount_cents     INTEGER,
  notes              TEXT,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
) STRICT;

CREATE INDEX orders_by_date ON orders (ordered_at);

CREATE TABLE order_items (
  id               INTEGER PRIMARY KEY,
  order_id         INTEGER NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  product_id       INTEGER NOT NULL REFERENCES products (id),
  label            TEXT,                           -- the line as the receipt words it
  quantity         INTEGER NOT NULL CHECK (quantity > 0),   -- items bought (packs, bags…)
  line_price_cents INTEGER NOT NULL CHECK (line_price_cents >= 0)  -- paid for the line, discounts included
) STRICT;

CREATE INDEX order_items_by_order ON order_items (order_id);
CREATE INDEX order_items_by_product ON order_items (product_id);  -- price history of a product

CREATE TABLE inventory (
  id                      INTEGER PRIMARY KEY,
  product_id              INTEGER NOT NULL REFERENCES products (id),
  order_item_id           INTEGER REFERENCES order_items (id) ON DELETE SET NULL,
  quantity                REAL NOT NULL CHECK (quantity >= 0),   -- left, in `unit`
  initial_quantity        REAL NOT NULL CHECK (initial_quantity > 0),
  unit                    TEXT NOT NULL,          -- "œuf", "g", "pot", "bouteille 1 L"
  unit_weight_g           REAL CHECK (unit_weight_g > 0),         -- grams in one `unit`, for the waste in kg
  unit_cost_cents         REAL CHECK (unit_cost_cents >= 0),      -- paid for one `unit`, for the waste in €
  location                TEXT NOT NULL CHECK (location IN ('frigo', 'placard', 'congelateur')),
  added_at                TEXT NOT NULL,
  best_before             TEXT CHECK (best_before GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  best_before_is_estimate INTEGER NOT NULL DEFAULT 1 CHECK (best_before_is_estimate IN (0, 1)),
  opened_at               TEXT,
  frozen_at               TEXT,
  status                  TEXT NOT NULL DEFAULT 'dispo' CHECK (status IN ('dispo', 'entame', 'fini', 'jete')),
  updated_at              TEXT NOT NULL
) STRICT;

-- What is still in the kitchen, most urgent first: the query behind nearly every screen and tool.
CREATE INDEX inventory_active ON inventory (best_before, location) WHERE status IN ('dispo', 'entame');
CREATE INDEX inventory_by_product ON inventory (product_id);
CREATE INDEX inventory_by_order_item ON inventory (order_item_id);

CREATE TABLE meals_log (
  id        INTEGER PRIMARY KEY,
  recipe_id INTEGER REFERENCES recipes (id) ON DELETE SET NULL,
  eaten_at  TEXT NOT NULL,
  servings  INTEGER CHECK (servings > 0),
  note      TEXT
) STRICT;

CREATE INDEX meals_by_date ON meals_log (eaten_at);

-- The stock's history. Value and weight are copied in when the event happens, so the waste stats
-- stay right even if the line is changed later.
CREATE TABLE inventory_events (
  id           INTEGER PRIMARY KEY,
  inventory_id INTEGER NOT NULL REFERENCES inventory (id),
  event        TEXT NOT NULL CHECK (event IN ('consomme', 'jete', 'congele', 'decongele', 'ouvert', 'ajuste', 'date_corrigee')),
  quantity     REAL,
  value_cents  REAL,
  weight_g     REAL,
  meal_id      INTEGER REFERENCES meals_log (id) ON DELETE SET NULL,
  reason       TEXT,                              -- why it was thrown away, what was corrected
  at           TEXT NOT NULL
) STRICT;

CREATE INDEX events_by_kind_date ON inventory_events (event, at);
CREATE INDEX events_by_line ON inventory_events (inventory_id);

CREATE TABLE recipes (
  id           INTEGER PRIMARY KEY,
  title        TEXT NOT NULL,
  servings     INTEGER NOT NULL DEFAULT 2 CHECK (servings > 0),
  prep_minutes INTEGER CHECK (prep_minutes > 0),
  steps        TEXT NOT NULL,                     -- markdown
  tags         TEXT,                              -- "rapide,sans-viande,anti-gaspi"
  rating       INTEGER CHECK (rating BETWEEN 1 AND 5),
  notes        TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
) STRICT;

CREATE TABLE recipe_ingredients (
  id              INTEGER PRIMARY KEY,
  recipe_id       INTEGER NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
  product_id      INTEGER REFERENCES products (id) ON DELETE SET NULL,
  ingredient_name TEXT NOT NULL,
  quantity        REAL CHECK (quantity > 0),      -- in `unit`, what "Je l'ai cuisinée" takes off the stock
  unit            TEXT,
  quantity_text   TEXT,                           -- as a cook says it: "1 pincée", "un filet"
  optional        INTEGER NOT NULL DEFAULT 0 CHECK (optional IN (0, 1))
) STRICT;

CREATE INDEX recipe_ingredients_by_recipe ON recipe_ingredients (recipe_id);

CREATE TABLE preferences (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TEXT NOT NULL
) STRICT;
