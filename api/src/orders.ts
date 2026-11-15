import { addDays, isDay, LOCATIONS, nowISO, today, UserError, type Env, type Location } from "./db";
import { stockLine, type StockLine } from "./stock";

/**
 * What comes into the kitchen: one product added by hand, or a whole order (a supermarket delivery) with its lines.
 * Products are found by name and brand, or created; each item becomes a stock line.
 */

export interface NewItem {
  name: string;
  brand?: string;
  /** feculents, frais, legumes, fruits, epicerie, pain, boissons, petit_dej, viande, poisson, surgeles. */
  category: string;
  /** Where it goes; the product's usual place when left out. */
  location?: Location;
  /** How much, in `unit`: 250 (g), 6 (œuf), 2 (bouteille 1 L). */
  quantity: number;
  unit: string;
  /** Grams in one `unit`, for the waste in kg. */
  unitWeightG?: number;
  /** The date printed on the pack; estimated from the product's shelf life when left out. */
  bestBefore?: string;
  /** Days a new product keeps closed in its place, frozen, and once opened. */
  shelfLifeDays?: number;
  shelfLifeFrozenDays?: number;
  shelfLifeOpenedDays?: number;
  /** "lactose,gluten,arachide", what the preferences filter on. */
  tags?: string;
  imageUrl?: string;
  /** Paid for the whole line, in cents. */
  priceCents?: number;
  /** Packs bought, for the order line (1 by default). */
  packs?: number;
  /** The line as the receipt words it. */
  label?: string;
}

export interface OrderInput {
  store: string;
  externalRef?: string;
  orderedAt: string;
  deliveredAt?: string;
  totalCents?: number;
  deliveryFeeCents?: number;
  discountCents?: number;
  notes?: string;
  items: NewItem[];
}

interface ProductRow {
  id: number;
  default_storage: Location;
  shelf_life_days: number | null;
  shelf_life_frozen_days: number | null;
  image_url: string | null;
}

/** Checks an item before anything is written, so an order goes in whole or not at all. */
export function checkItem(item: NewItem, index?: number) {
  const where = index === undefined ? "" : ` (article ${index + 1}, « ${item.name} »)`;
  if (!item.name.trim()) throw new UserError(`Le nom est obligatoire${where}.`);
  if (!(item.quantity > 0)) throw new UserError(`La quantité doit être positive${where}.`);
  if (!item.unit.trim()) throw new UserError(`L'unité est obligatoire${where}.`);
  if (item.location && !LOCATIONS.includes(item.location)) throw new UserError(`Lieu inconnu${where}.`);
  if (item.bestBefore !== undefined && !isDay(item.bestBefore)) throw new UserError(`\`bestBefore\` doit être AAAA-MM-JJ${where}.`);
}

/** The product with this name and brand, created (with what the item says about it) when it is new. */
async function product(env: Env, item: NewItem): Promise<ProductRow> {
  const columns = "id, default_storage, shelf_life_days, shelf_life_frozen_days, image_url";
  const known = await env.DB.prepare(`SELECT ${columns} FROM products
    WHERE name = ?1 COLLATE NOCASE AND coalesce(brand, '') = coalesce(?2, '') COLLATE NOCASE`)
    .bind(item.name.trim(), item.brand?.trim() || null).first<ProductRow>();
  if (known) {
    if (item.imageUrl && !known.image_url) {
      await env.DB.prepare("UPDATE products SET image_url = ? WHERE id = ?").bind(item.imageUrl, known.id).run();
    }
    return known;
  }
  return (await env.DB.prepare(`INSERT INTO products (name, brand, category, default_storage, shelf_life_days,
      shelf_life_opened_days, shelf_life_frozen_days, tags, image_url, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING ${columns}`).bind(item.name.trim(), item.brand?.trim() || null,
    item.category.trim().toLowerCase(), item.location ?? "placard", item.shelfLifeDays ?? null, item.shelfLifeOpenedDays ?? null,
    item.shelfLifeFrozenDays ?? null, item.tags?.trim() || null, item.imageUrl ?? null, nowISO()).first<ProductRow>())!;
}

/** The item's date: the printed one, else today plus the product's shelf life in that place. */
function bestBefore(item: NewItem, found: ProductRow, location: Location): { day: string | null; estimate: boolean } {
  if (item.bestBefore) return { day: item.bestBefore, estimate: false };
  const days = location === "congelateur" ? found.shelf_life_frozen_days ?? found.shelf_life_days : found.shelf_life_days;
  return { day: days ? addDays(today(), days) : null, estimate: true };
}

async function addLine(env: Env, item: NewItem, orderItemId: number | null, found: ProductRow): Promise<StockLine> {
  const location = item.location ?? found.default_storage;
  const date = bestBefore(item, found, location);
  const now = nowISO();
  const unitCost = item.priceCents !== undefined ? item.priceCents / item.quantity : null;
  const created = await env.DB.prepare(`INSERT INTO inventory (product_id, order_item_id, quantity, initial_quantity, unit,
      unit_weight_g, unit_cost_cents, location, added_at, best_before, best_before_is_estimate, frozen_at, status, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'dispo', ?) RETURNING id`).bind(found.id, orderItemId, item.quantity,
    item.quantity, item.unit.trim(), item.unitWeightG ?? null, unitCost, location, now, date.day, date.estimate ? 1 : 0,
    location === "congelateur" ? now : null, now).first<{ id: number }>();
  return stockLine(env, created!.id);
}

/** Adds one product to the stock, outside any order (a gift, a market, a forgotten line). */
export async function addStockItem(env: Env, item: NewItem): Promise<StockLine> {
  checkItem(item);
  return addLine(env, item, null, await product(env, item));
}

/** Records an order and puts every item in the stock; an order number already imported is refused. */
export async function importOrder(env: Env, order: OrderInput): Promise<{ orderId: number; items: StockLine[] }> {
  if (!order.items.length) throw new UserError("La commande n'a aucun article.");
  if (!isDay(order.orderedAt)) throw new UserError("`orderedAt` doit être une date AAAA-MM-JJ.");
  if (order.deliveredAt !== undefined && !isDay(order.deliveredAt)) throw new UserError("`deliveredAt` doit être AAAA-MM-JJ.");
  order.items.forEach(checkItem);
  if (order.externalRef) {
    const seen = await env.DB.prepare("SELECT id FROM orders WHERE external_ref = ?").bind(order.externalRef).first<{ id: number }>();
    if (seen) throw new UserError(`La commande ${order.externalRef} est déjà importée (commande ${seen.id}).`);
  }
  const now = nowISO();
  const created = await env.DB.prepare(`INSERT INTO orders (store, external_ref, status, ordered_at, delivered_at, total_cents,
      delivery_fee_cents, discount_cents, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`)
    .bind(order.store.trim(), order.externalRef ?? null, order.deliveredAt ? "livree" : "validee", order.orderedAt,
      order.deliveredAt ?? null, order.totalCents ?? null, order.deliveryFeeCents ?? null, order.discountCents ?? null,
      order.notes?.trim() || null, now, now).first<{ id: number }>();
  const orderId = created!.id;
  const items: StockLine[] = [];
  for (const item of order.items) {
    const found = await product(env, item);
    const line = await env.DB.prepare(`INSERT INTO order_items (order_id, product_id, label, quantity, line_price_cents)
      VALUES (?, ?, ?, ?, ?) RETURNING id`).bind(orderId, found.id, item.label?.trim() || null, item.packs ?? 1,
      item.priceCents ?? 0).first<{ id: number }>();
    items.push(await addLine(env, item, line!.id, found));
  }
  return { orderId, items };
}

/** Deletes a stock line entered by mistake, with its history. Food eaten or thrown away is consume or waste, not this. */
export async function removeStockItem(env: Env, id: number): Promise<{ id: number; name: string; removed: true }> {
  const line = await stockLine(env, id);
  await env.DB.batch([
    env.DB.prepare("DELETE FROM inventory_events WHERE inventory_id = ?").bind(id),
    env.DB.prepare("DELETE FROM inventory WHERE id = ?").bind(id),
  ]);
  return { id, name: line.name, removed: true };
}

/** Deletes a recipe, its ingredients and its place in the meal plan; meals already logged keep their date. */
export async function deleteRecipe(env: Env, id: number): Promise<{ id: number; title: string; removed: true }> {
  const found = await env.DB.prepare("SELECT title FROM recipes WHERE id = ?").bind(id).first<{ title: string }>();
  if (!found) throw new UserError(`Aucune recette ${id}.`);
  await env.DB.prepare("DELETE FROM recipes WHERE id = ?").bind(id).run();
  return { id, title: found.title, removed: true };
}
