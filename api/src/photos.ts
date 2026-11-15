import { UserError } from "./db";

/** Dish photos from TheMealDB (free, no key needed for its test key "1"), for recipes Claude saves. */

export interface Photo {
  dish: string;
  imageUrl: string;
}

interface Meal {
  strMeal: string;
  strMealThumb: string;
}

async function meals(path: string): Promise<Meal[]> {
  const answer = await fetch(`https://www.themealdb.com/api/json/v1/1/${path}`, { headers: { "user-agent": "eathat-api" } });
  if (!answer.ok) return [];
  const body = (await answer.json()) as { meals: Meal[] | null | string };
  return Array.isArray(body.meals) ? body.meals : [];
}

/**
 * Photos of dishes close to `query` (English words: "ratatouille", "lentil soup"): dishes whose name matches first,
 * then dishes made with that ingredient. At most `limit`.
 */
export async function findPhotos(query: string, limit = 8): Promise<Photo[]> {
  const words = query.trim();
  if (!words) throw new UserError("`query` est vide.");
  const encoded = encodeURIComponent(words);
  const [byName, byIngredient] = await Promise.all([
    meals(`search.php?s=${encoded}`),
    meals(`filter.php?i=${encodeURIComponent(words.replace(/\s+/g, "_"))}`),
  ]);
  const seen = new Set<string>();
  return [...byName, ...byIngredient]
    .filter((m) => !seen.has(m.strMealThumb) && seen.add(m.strMealThumb))
    .slice(0, limit)
    .map((m) => ({ dish: m.strMeal, imageUrl: m.strMealThumb }));
}
