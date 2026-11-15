-- Données d'exemple, fictives : quelques préférences, une commande et le stock qu'elle donne.
-- Pour essayer l'app et le MCP sur une base vide (de préférence en local) :
--   npx wrangler d1 execute cuisine --local --file seed.example.sql
-- Les dates limites sont estimées (best_before_is_estimate = 1). Argent en centimes.

-- ---------- Préférences ----------
INSERT INTO preferences (key, value, updated_at) VALUES
  ('foyer', '3 personnes', '2026-01-10T12:00:00Z'),
  ('regime', 'Végétarien', '2026-01-10T12:00:00Z'),
  ('aime', 'Riz, soupes, fromage', '2026-01-10T12:00:00Z'),
  ('evite', 'Coriandre', '2026-01-10T12:00:00Z'),
  ('objectif', 'Zéro gaspillage', '2026-01-10T12:00:00Z');

-- ---------- Produits ----------
INSERT INTO products (id, name, brand, category, unit_format, default_storage, shelf_life_days, shelf_life_opened_days,
  shelf_life_frozen_days, tags, notes, created_at) VALUES
  (1, 'Lait demi-écrémé',  NULL, 'frais',     'pack 6 x 1 L', 'placard', 90,  4,    NULL, 'lactose', 'UHT : frigo une fois ouvert', '2026-01-10T12:00:00Z'),
  (2, 'Œufs',              NULL, 'frais',     'boîte de 6',   'frigo',   28,  NULL, NULL, 'oeuf',    NULL, '2026-01-10T12:00:00Z'),
  (3, 'Comté râpé',        NULL, 'frais',     '200 g',        'frigo',   21,  7,    90,   'lactose', NULL, '2026-01-10T12:00:00Z'),
  (4, 'Riz basmati',       NULL, 'feculents', '1 kg',         'placard', 365, NULL, NULL, NULL,      NULL, '2026-01-10T12:00:00Z'),
  (5, 'Lentilles corail',  NULL, 'epicerie',  '500 g',        'placard', 365, NULL, NULL, NULL,      NULL, '2026-01-10T12:00:00Z'),
  (6, 'Carottes',          NULL, 'legumes',   '1 kg',         'frigo',   21,  NULL, 180,  NULL,      NULL, '2026-01-10T12:00:00Z'),
  (7, 'Épinards frais',    NULL, 'legumes',   '300 g',        'frigo',   4,   NULL, 180,  NULL,      'À manger vite', '2026-01-10T12:00:00Z'),
  (8, 'Pain complet',      NULL, 'pain',      '500 g',        'placard', 5,   NULL, 90,   'gluten',  'Se congèle en tranches', '2026-01-10T12:00:00Z');

-- ---------- Commande ----------
INSERT INTO orders (id, store, status, ordered_at, delivered_at, total_cents, delivery_fee_cents, discount_cents, notes,
  created_at, updated_at) VALUES
  (1, 'Supermarché exemple', 'livree', '2026-01-09', '2026-01-10', 2190, 0, 0, NULL,
   '2026-01-10T12:00:00Z', '2026-01-10T12:00:00Z');

INSERT INTO order_items (id, order_id, product_id, quantity, line_price_cents) VALUES
  (1, 1, 1, 1, 590),
  (2, 1, 2, 1, 250),
  (3, 1, 3, 1, 320),
  (4, 1, 4, 1, 260),
  (5, 1, 5, 1, 190),
  (6, 1, 6, 1, 150),
  (7, 1, 7, 1, 230),
  (8, 1, 8, 1, 200);

-- ---------- Stock ----------
WITH s (product_id, order_item_id, quantity, unit, unit_weight_g, location, best_before) AS (VALUES
  (1, 1, 6,    'bouteille 1 L', 1000, 'placard', '2026-04-10'),
  (2, 2, 6,    'œuf',           60,   'frigo',   '2026-02-07'),
  (3, 3, 200,  'g',             1,    'frigo',   '2026-01-31'),
  (4, 4, 1000, 'g',             1,    'placard', '2027-01-10'),
  (5, 5, 500,  'g',             1,    'placard', '2027-01-10'),
  (6, 6, 1000, 'g',             1,    'frigo',   '2026-01-31'),
  (7, 7, 300,  'g',             1,    'frigo',   '2026-01-14'),
  (8, 8, 1,    'paquet 500 g',  500,  'placard', '2026-01-15'))
INSERT INTO inventory (product_id, order_item_id, quantity, initial_quantity, unit, unit_weight_g, unit_cost_cents, location,
  added_at, best_before, best_before_is_estimate, status, updated_at)
SELECT s.product_id, s.order_item_id, s.quantity, s.quantity, s.unit, s.unit_weight_g,
  oi.line_price_cents * 1.0 / s.quantity, s.location, '2026-01-10T12:00:00Z', s.best_before, 1, 'dispo', '2026-01-10T12:00:00Z'
FROM s JOIN order_items oi ON oi.id = s.order_item_id;
