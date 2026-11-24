import { ACTIVE, addDays, nowISO, round, today, UserError, type Env } from "./db";
import { recipe } from "./recipes";
import { consume } from "./stock";

/** "Je l'ai cuisinée": a meal in the log, and its ingredients off the stock. */

export interface CookedMeal {
  mealId: number;
  recipeId: number;
  /** What came off the stock, line by line. */
  taken: { inventoryId: number; name: string; quantity: number; unit: string }[];
  /** Ingredients not taken: not linked to the stock, optional, or not enough left. */
  skipped: { name: string; reason: string }[];
}

interface Candidate {
  id: number;
  name: string;
  quantity: number;
  unit: string;
}

/**
 * Logs a meal of a saved recipe and takes each linked ingredient off the stock, from the line that expires first.
 * Optional ingredients and those without a product or a quantity are left alone.
 */
export async function cookRecipe(env: Env, recipeId: number, note: string | null = null): Promise<CookedMeal> {
  const cooked = await recipe(env, recipeId);
  if (!cooked) throw new UserError(`Aucune recette ${recipeId}.`);
  const meal = await env.DB.prepare("INSERT INTO meals_log (recipe_id, eaten_at, servings, note) VALUES (?, ?, ?, ?) RETURNING id")
    .bind(recipeId, nowISO(), cooked.servings, note).first<{ id: number }>();
  const mealId = meal!.id;
  const result: CookedMeal = { mealId, recipeId, taken: [], skipped: [] };

  for (const ingredient of cooked.ingredients) {
    if (ingredient.optional) {
      result.skipped.push({ name: ingredient.name, reason: "facultatif" });
      continue;
    }
    if (ingredient.productId == null || ingredient.quantity == null) {
      result.skipped.push({ name: ingredient.name, reason: "pas lié au stock" });
      continue;
    }
    const { results: lines } = await env.DB.prepare(`SELECT i.id, p.name, i.quantity, i.unit FROM inventory i
      JOIN products p ON p.id = i.product_id WHERE i.product_id = ? AND ${ACTIVE}
      ORDER BY i.best_before IS NULL, i.best_before, i.id`).bind(ingredient.productId).all<Candidate>();
    let wanted = ingredient.quantity;
    for (const line of lines) {
      if (wanted <= 1e-9) break;
      const amount = Math.min(wanted, line.quantity);
      await consume(env, line.id, amount, mealId);
      result.taken.push({ inventoryId: line.id, name: line.name, quantity: round(amount), unit: line.unit });
      wanted = round(wanted - amount, 6);
    }
    if (wanted > 1e-9) result.skipped.push({ name: ingredient.name, reason: `il manquait ${round(wanted)}` });
  }
  return result;
}

/** A meal in the log, as the journal shows it. */
export interface EatenMeal {
  id: number;
  /** The kitchen day it was eaten, 'YYYY-MM-DD' in Paris. */
  day: string;
  eatenAt: string;
  /** Null once the recipe is deleted. */
  recipeId: number | null;
  title: string | null;
  imageUrl: string | null;
  servings: number | null;
  note: string | null;
}

interface MealRow {
  id: number;
  eaten_at: string;
  recipe_id: number | null;
  title: string | null;
  image_url: string | null;
  servings: number | null;
  note: string | null;
}

/**
 * The meals eaten newest first: over the last `days` kitchen days (today included), or from `from` to `to`
 * (Paris days, both included).
 */
export async function listMeals(env: Env, range: number | { from: string; to: string } = 60): Promise<EatenMeal[]> {
  const window = typeof range === "number" ? { from: addDays(today(), -range), to: null } : range;
  // A day early and late in UTC, then each meal is kept by its Paris day.
  const since = new Date(`${addDays(window.from, -1)}T00:00:00Z`).toISOString();
  const until = window.to ? new Date(`${addDays(window.to, 2)}T00:00:00Z`).toISOString() : null;
  const { results } = await env.DB.prepare(`SELECT m.id, m.eaten_at, m.recipe_id, r.title, r.image_url, m.servings, m.note
    FROM meals_log m LEFT JOIN recipes r ON r.id = m.recipe_id WHERE m.eaten_at >= ?1 AND (?2 IS NULL OR m.eaten_at < ?2)
    ORDER BY m.eaten_at DESC, m.id DESC`).bind(since, until).all<MealRow>();
  const inRange = (day: string) => day >= window.from && (window.to === null || day <= window.to);
  return results.map((row) => ({
    id: row.id,
    day: today(new Date(row.eaten_at)),
    eatenAt: row.eaten_at,
    recipeId: row.recipe_id,
    title: row.title,
    imageUrl: row.image_url,
    servings: row.servings,
    note: row.note,
  })).filter((meal) => inRange(meal.day));
}
