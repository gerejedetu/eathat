import { ACTIVE, addDays, isDay, LOCATIONS, nowISO, round, today, UserError, type Env, type Location } from "./db";

/**
 * The kitchen's stock: what is left, what goes first, and every change to it. Shared by the MCP server and,
 * later, the app's REST API, so both change the stock the same way.
 */

export interface StockLine {
  id: number;
  productId: number;
  name: string;
  brand: string | null;
  category: string;
  tags: string | null;
  /** The product's photo, when it has one. */
  imageUrl: string | null;
  quantity: number;
  initialQuantity: number;
  unit: string;
  location: Location;
  bestBefore: string | null;
  bestBeforeIsEstimate: boolean;
  /** Days until the best-before date, negative once it is past; null without a date. */
  daysLeft: number | null;
  openedAt: string | null;
  frozenAt: string | null;
  status: "dispo" | "entame" | "fini" | "jete";
}

interface Row {
  id: number;
  product_id: number;
  name: string;
  brand: string | null;
  category: string;
  tags: string | null;
  image_url: string | null;
  quantity: number;
  initial_quantity: number;
  unit: string;
  unit_weight_g: number | null;
  unit_cost_cents: number | null;
  location: Location;
  best_before: string | null;
  best_before_is_estimate: number;
  opened_at: string | null;
  frozen_at: string | null;
  status: StockLine["status"];
  shelf_life_opened_days: number | null;
  shelf_life_frozen_days: number | null;
  days_left: number | null;
}

const SELECT = `SELECT i.id, i.product_id, p.name, p.brand, p.category, p.tags, p.image_url, i.quantity, i.initial_quantity, i.unit,
  i.unit_weight_g, i.unit_cost_cents, i.location, i.best_before, i.best_before_is_estimate, i.opened_at, i.frozen_at,
  i.status, p.shelf_life_opened_days, p.shelf_life_frozen_days,
  CAST(julianday(i.best_before) - julianday(?1) AS INTEGER) AS days_left
  FROM inventory i JOIN products p ON p.id = i.product_id`;

const ORDER = "ORDER BY i.best_before IS NULL, i.best_before, p.name";

const line = (row: Row): StockLine => ({
  id: row.id,
  productId: row.product_id,
  name: row.name,
  brand: row.brand,
  category: row.category,
  tags: row.tags,
  imageUrl: row.image_url,
  quantity: round(row.quantity),
  initialQuantity: round(row.initial_quantity),
  unit: row.unit,
  location: row.location,
  bestBefore: row.best_before,
  bestBeforeIsEstimate: row.best_before_is_estimate === 1,
  daysLeft: row.days_left,
  openedAt: row.opened_at,
  frozenAt: row.frozen_at,
  status: row.status,
});

// MARK: Reading

export interface StockFilter {
  location?: Location;
  category?: string;
  /** Lines that are finished or thrown away too. */
  includeGone?: boolean;
}

export async function listStock(env: Env, filter: StockFilter = {}): Promise<StockLine[]> {
  const where = [filter.includeGone ? "1 = 1" : ACTIVE];
  const binds: unknown[] = [today()];
  if (filter.location) {
    binds.push(filter.location);
    where.push(`i.location = ?${binds.length}`);
  }
  if (filter.category) {
    binds.push(filter.category);
    where.push(`p.category = ?${binds.length} COLLATE NOCASE`);
  }
  const { results } = await env.DB.prepare(`${SELECT} WHERE ${where.join(" AND ")} ${ORDER}`).bind(...binds).all<Row>();
  return results.map(line);
}

/** Lines still in the kitchen whose date is within `days` days, past ones included, most urgent first. */
export async function expiringSoon(env: Env, days: number): Promise<StockLine[]> {
  const { results } = await env.DB.prepare(`${SELECT} WHERE ${ACTIVE} AND i.best_before IS NOT NULL
    AND i.best_before <= ?2 ${ORDER}`).bind(today(), addDays(today(), days)).all<Row>();
  return results.map(line);
}

async function row(env: Env, id: number): Promise<Row> {
  const found = await env.DB.prepare(`${SELECT} WHERE i.id = ?2`).bind(today(), id).first<Row>();
  if (!found) throw new UserError(`Aucune ligne de stock ${id}. Les ids viennent de list_inventory ou get_cooking_context.`);
  return found;
}

export async function stockLine(env: Env, id: number): Promise<StockLine> {
  return line(await row(env, id));
}

function active(found: Row): Row {
  if (found.status === "fini" || found.status === "jete") {
    throw new UserError(`« ${found.name} » (ligne ${found.id}) n'est plus en stock : ${found.status === "fini" ? "fini" : "jeté"}.`);
  }
  return found;
}

// MARK: Changing

const event = (env: Env, inventoryId: number, kind: string, fields: {
  quantity?: number | null; valueCents?: number | null; weightG?: number | null; mealId?: number | null; reason?: string | null;
} = {}) =>
  env.DB.prepare(`INSERT INTO inventory_events (inventory_id, event, quantity, value_cents, weight_g, meal_id, reason, at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).bind(inventoryId, kind, fields.quantity ?? null, fields.valueCents ?? null,
    fields.weightG ?? null, fields.mealId ?? null, fields.reason ?? null, nowISO());

/** The best-before date once opened: the opened shelf life, unless the closed date comes first. */
function openedBestBefore(found: Row): string | null {
  if (!found.shelf_life_opened_days || found.location === "congelateur") return found.best_before;
  const opened = addDays(today(), found.shelf_life_opened_days);
  return found.best_before && found.best_before < opened ? found.best_before : opened;
}

/** How much to take: all that is left when `quantity` is missing, never more than that. */
function taken(found: Row, quantity: number | undefined): number {
  if (quantity === undefined) return found.quantity;
  if (quantity > found.quantity + 1e-9) {
    throw new UserError(`Il ne reste que ${round(found.quantity)} ${found.unit} de « ${found.name} » (ligne ${found.id}).`);
  }
  return Math.min(quantity, found.quantity);
}

const cost = (found: Row, quantity: number) => found.unit_cost_cents == null ? null : round(quantity * found.unit_cost_cents, 2);
const weight = (found: Row, quantity: number) => found.unit_weight_g == null ? null : round(quantity * found.unit_weight_g, 1);

/**
 * Takes `quantity` off a line, eaten or thrown away. What is left of a closed line counts as opened, and its date
 * follows. An empty line becomes `fini` (eaten) or `jete` (thrown away).
 */
async function take(env: Env, id: number, kind: "consomme" | "jete", quantity: number | undefined,
  extra: { reason?: string | null; mealId?: number | null } = {}): Promise<StockLine> {
  const found = active(await row(env, id));
  const amount = taken(found, quantity);
  const left = round(found.quantity - amount, 6);
  const empty = left <= 1e-9;
  const opensNow = !empty && !found.opened_at;
  const status = empty ? (kind === "consomme" ? "fini" : "jete") : "entame";
  const bestBefore = opensNow ? openedBestBefore(found) : found.best_before;
  const now = nowISO();

  await env.DB.batch([
    env.DB.prepare(`UPDATE inventory SET quantity = ?, status = ?, opened_at = coalesce(opened_at, ?), best_before = ?,
      updated_at = ? WHERE id = ?`).bind(empty ? 0 : left, status, opensNow ? now : null, bestBefore, now, id),
    event(env, id, kind, { quantity: amount, valueCents: cost(found, amount), weightG: weight(found, amount), ...extra }),
    ...(opensNow ? [event(env, id, "ouvert")] : []),
  ]);
  return stockLine(env, id);
}

export const consume = (env: Env, id: number, quantity?: number, mealId?: number | null) =>
  take(env, id, "consomme", quantity, { mealId });

export const waste = (env: Env, id: number, quantity: number | undefined, reason: string | null) =>
  take(env, id, "jete", quantity, { reason });

/** Marks a line as opened; its date shortens to the opened shelf life. */
export async function open(env: Env, id: number): Promise<StockLine> {
  const found = active(await row(env, id));
  if (found.opened_at) return line(found);
  const now = nowISO();
  await env.DB.batch([
    env.DB.prepare("UPDATE inventory SET status = 'entame', opened_at = ?, best_before = ?, updated_at = ? WHERE id = ?")
      .bind(now, openedBestBefore(found), now, id),
    event(env, id, "ouvert"),
  ]);
  return stockLine(env, id);
}

/** Frozen food keeps ~3 months when the product doesn't say; thawed food, 2 days. */
const FROZEN_DAYS = 90;
const THAWED_DAYS = 2;

/** Moves a line, and recomputes its date when it goes into or out of the freezer. */
export async function move(env: Env, id: number, location: Location): Promise<StockLine> {
  if (!LOCATIONS.includes(location)) throw new UserError("`location` doit être frigo, placard ou congelateur.");
  const found = active(await row(env, id));
  if (found.location === location) return line(found);
  const now = nowISO();

  let update: D1PreparedStatement;
  let record: D1PreparedStatement;
  if (location === "congelateur") {
    const bestBefore = addDays(today(), found.shelf_life_frozen_days ?? FROZEN_DAYS);
    update = env.DB.prepare(`UPDATE inventory SET location = ?, frozen_at = ?, best_before = ?, best_before_is_estimate = 1,
      updated_at = ? WHERE id = ?`).bind(location, now, bestBefore, now, id);
    record = event(env, id, "congele");
  } else if (found.location === "congelateur") {
    const bestBefore = addDays(today(), Math.min(found.shelf_life_opened_days ?? THAWED_DAYS, THAWED_DAYS));
    update = env.DB.prepare(`UPDATE inventory SET location = ?, frozen_at = NULL, best_before = ?, best_before_is_estimate = 1,
      updated_at = ? WHERE id = ?`).bind(location, bestBefore, now, id);
    record = event(env, id, "decongele", { reason: `vers ${location}` });
  } else {
    update = env.DB.prepare("UPDATE inventory SET location = ?, updated_at = ? WHERE id = ?").bind(location, now, id);
    record = event(env, id, "ajuste", { reason: `déplacé de ${found.location} vers ${location}` });
  }
  await env.DB.batch([update, record]);
  return stockLine(env, id);
}

/** Sets the real date read on the pack; it is no longer an estimate. */
export async function setBestBefore(env: Env, id: number, day: string): Promise<StockLine> {
  if (!isDay(day)) throw new UserError("`bestBefore` doit être une date AAAA-MM-JJ.");
  const found = active(await row(env, id));
  const now = nowISO();
  await env.DB.batch([
    env.DB.prepare("UPDATE inventory SET best_before = ?, best_before_is_estimate = 0, updated_at = ? WHERE id = ?")
      .bind(day, now, id),
    event(env, id, "date_corrigee", { reason: `${found.best_before ?? "aucune"} → ${day}` }),
  ]);
  return stockLine(env, id);
}
