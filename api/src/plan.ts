import { addDays, isDay, nowISO, today, UserError, type Env } from "./db";

/** The meal plan: recipes planned for a day, at noon or in the evening. Shared by the MCP server and the app. */

export type Slot = "midi" | "soir";
export const SLOTS: Slot[] = ["midi", "soir"];

export interface PlannedMeal {
  id: number;
  day: string;
  slot: Slot;
  recipeId: number;
  title: string;
  imageUrl: string | null;
  prepMinutes: number | null;
}

interface Row {
  id: number;
  day: string;
  slot: Slot;
  recipe_id: number;
  title: string;
  image_url: string | null;
  prep_minutes: number | null;
}

const SELECT = `SELECT m.id, m.day, m.slot, m.recipe_id, r.title, r.image_url, r.prep_minutes
  FROM meal_plan m JOIN recipes r ON r.id = m.recipe_id`;

const meal = (row: Row): PlannedMeal => ({
  id: row.id,
  day: row.day,
  slot: row.slot,
  recipeId: row.recipe_id,
  title: row.title,
  imageUrl: row.image_url,
  prepMinutes: row.prep_minutes,
});

/** The meals from `from` (today by default) for `days` days, by day, noon before evening. */
export async function listPlan(env: Env, from = today(), days = 7): Promise<PlannedMeal[]> {
  if (!isDay(from)) throw new UserError("`from` doit être une date AAAA-MM-JJ.");
  const { results } = await env.DB.prepare(`${SELECT} WHERE m.day >= ?1 AND m.day < ?2
    ORDER BY m.day, m.slot = 'soir', m.id`).bind(from, addDays(from, days)).all<Row>();
  return results.map(meal);
}

/** Plans `recipeId` for `day`, at noon or in the evening. */
export async function planMeal(env: Env, day: string, slot: Slot, recipeId: number): Promise<PlannedMeal> {
  if (!isDay(day)) throw new UserError("`day` doit être une date AAAA-MM-JJ.");
  if (!SLOTS.includes(slot)) throw new UserError("`slot` doit être midi ou soir.");
  const recipe = await env.DB.prepare("SELECT id FROM recipes WHERE id = ?").bind(recipeId).first();
  if (!recipe) throw new UserError(`Aucune recette ${recipeId}.`);
  const created = await env.DB.prepare("INSERT INTO meal_plan (day, slot, recipe_id, created_at) VALUES (?, ?, ?, ?) RETURNING id")
    .bind(day, slot, recipeId, nowISO()).first<{ id: number }>();
  const row = await env.DB.prepare(`${SELECT} WHERE m.id = ?`).bind(created!.id).first<Row>();
  return meal(row!);
}

/** Takes a planned meal off the plan. */
export async function unplanMeal(env: Env, id: number): Promise<{ id: number; removed: true }> {
  const { meta } = await env.DB.prepare("DELETE FROM meal_plan WHERE id = ?").bind(id).run();
  if (!meta.changes) throw new UserError(`Aucun repas planifié ${id}.`);
  return { id, removed: true };
}
