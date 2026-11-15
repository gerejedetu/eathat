import { ACTIVE, nowISO, round, UserError, type Env } from "./db";
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
