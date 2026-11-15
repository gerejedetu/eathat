import { nowISO, UserError, type Env } from "./db";

/** Recipes Claude saved, and the user's preferences they must respect. */

export interface IngredientInput {
  name: string;
  /** The stock line it comes from (its product is kept), from get_cooking_context. */
  inventoryId?: number;
  productId?: number;
  quantity?: number;
  unit?: string;
  quantityText?: string;
  optional?: boolean;
}

export interface RecipeInput {
  title: string;
  servings?: number;
  prepMinutes?: number;
  steps: string;
  tags?: string[];
  notes?: string;
  /** A photo of the dish (https). */
  imageUrl?: string;
  ingredients: IngredientInput[];
}

export interface Recipe {
  id: number;
  title: string;
  servings: number;
  prepMinutes: number | null;
  steps: string;
  tags: string[];
  rating: number | null;
  notes: string | null;
  imageUrl: string | null;
  createdAt: string;
  updatedAt: string;
  ingredients: {
    name: string;
    productId: number | null;
    quantity: number | null;
    unit: string | null;
    quantityText: string | null;
    optional: boolean;
  }[];
}

interface RecipeRow {
  id: number;
  title: string;
  servings: number;
  prep_minutes: number | null;
  steps: string;
  tags: string | null;
  rating: number | null;
  notes: string | null;
  image_url: string | null;
  created_at: string;
  updated_at: string;
}

interface IngredientRow {
  recipe_id: number;
  ingredient_name: string;
  product_id: number | null;
  quantity: number | null;
  unit: string | null;
  quantity_text: string | null;
  optional: number;
}

const tagText = (tags: string[] | undefined) => {
  const clean = (tags ?? []).map((t) => t.trim().toLowerCase()).filter(Boolean);
  return clean.length ? [...new Set(clean)].join(",") : null;
};

/** The product behind an ingredient: given, or the one of the stock line it names. */
async function productOf(env: Env, ingredient: IngredientInput): Promise<number | null> {
  if (ingredient.productId !== undefined) {
    const found = await env.DB.prepare("SELECT id FROM products WHERE id = ?").bind(ingredient.productId).first();
    if (!found) throw new UserError(`Aucun produit ${ingredient.productId} (ingrédient « ${ingredient.name} »).`);
    return ingredient.productId;
  }
  if (ingredient.inventoryId !== undefined) {
    const found = await env.DB.prepare("SELECT product_id FROM inventory WHERE id = ?").bind(ingredient.inventoryId)
      .first<{ product_id: number }>();
    if (!found) throw new UserError(`Aucune ligne de stock ${ingredient.inventoryId} (ingrédient « ${ingredient.name} »).`);
    return found.product_id;
  }
  return null;
}

export async function saveRecipe(env: Env, input: RecipeInput): Promise<Recipe> {
  const products = await Promise.all(input.ingredients.map((i) => productOf(env, i)));
  const now = nowISO();
  const created = await env.DB.prepare(`INSERT INTO recipes (title, servings, prep_minutes, steps, tags, notes, image_url,
    created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`).bind(input.title.trim(), input.servings ?? 2,
    input.prepMinutes ?? null, input.steps.trim(), tagText(input.tags), input.notes?.trim() || null, input.imageUrl ?? null, now, now).first<{ id: number }>();
  const id = created!.id;
  if (input.ingredients.length) {
    await env.DB.batch(input.ingredients.map((i, index) =>
      env.DB.prepare(`INSERT INTO recipe_ingredients (recipe_id, product_id, ingredient_name, quantity, unit, quantity_text, optional)
        VALUES (?, ?, ?, ?, ?, ?, ?)`).bind(id, products[index], i.name.trim(), i.quantity ?? null, i.unit?.trim() || null,
        i.quantityText?.trim() || null, i.optional ? 1 : 0)));
  }
  return (await recipe(env, id))!;
}

export async function rateRecipe(env: Env, id: number, rating: number, notes?: string): Promise<Recipe> {
  const { meta } = await env.DB.prepare("UPDATE recipes SET rating = ?, notes = coalesce(?, notes), updated_at = ? WHERE id = ?")
    .bind(rating, notes?.trim() || null, nowISO(), id).run();
  if (!meta.changes) throw new UserError(`Aucune recette ${id}.`);
  return (await recipe(env, id))!;
}

/** Sets the photo of a recipe or of a product (null takes it away). */
export async function setImage(env: Env, target: "recipe" | "product", id: number, imageUrl: string | null) {
  const table = target === "recipe" ? "recipes" : "products";
  const stamp = target === "recipe" ? ", updated_at = ?3" : "";
  const statement = env.DB.prepare(`UPDATE ${table} SET image_url = ?1${stamp} WHERE id = ?2`);
  const { meta } = await (target === "recipe" ? statement.bind(imageUrl, id, nowISO()) : statement.bind(imageUrl, id)).run();
  if (!meta.changes) throw new UserError(`Aucun ${target === "recipe" ? "recette" : "produit"} ${id}.`);
  return { target, id, imageUrl };
}

function assemble(rows: RecipeRow[], ingredients: IngredientRow[]): Recipe[] {
  return rows.map((r) => ({
    id: r.id,
    title: r.title,
    servings: r.servings,
    prepMinutes: r.prep_minutes,
    steps: r.steps,
    tags: r.tags ? r.tags.split(",") : [],
    rating: r.rating,
    notes: r.notes,
    imageUrl: r.image_url,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
    ingredients: ingredients.filter((i) => i.recipe_id === r.id).map((i) => ({
      name: i.ingredient_name,
      productId: i.product_id,
      quantity: i.quantity,
      unit: i.unit,
      quantityText: i.quantity_text,
      optional: i.optional === 1,
    })),
  }));
}

export async function recipe(env: Env, id: number): Promise<Recipe | null> {
  const [rows, ingredients] = await env.DB.batch([
    env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id),
    env.DB.prepare("SELECT * FROM recipe_ingredients WHERE recipe_id = ? ORDER BY id").bind(id),
  ]);
  return assemble(rows.results as RecipeRow[], ingredients.results as IngredientRow[])[0] ?? null;
}

/** The newest recipes first, with their ingredients. */
export async function listRecipes(env: Env, limit = 20): Promise<Recipe[]> {
  const [rows, ingredients] = await env.DB.batch([
    env.DB.prepare("SELECT * FROM recipes ORDER BY created_at DESC, id DESC LIMIT ?").bind(limit),
    env.DB.prepare(`SELECT * FROM recipe_ingredients WHERE recipe_id IN
      (SELECT id FROM recipes ORDER BY created_at DESC, id DESC LIMIT ?) ORDER BY id`).bind(limit),
  ]);
  return assemble(rows.results as RecipeRow[], ingredients.results as IngredientRow[]);
}

// MARK: Preferences

export async function preferences(env: Env): Promise<Record<string, string>> {
  const { results } = await env.DB.prepare("SELECT key, value FROM preferences ORDER BY key").all<{ key: string; value: string }>();
  return Object.fromEntries(results.map((p) => [p.key, p.value]));
}

/** Sets a preference, or removes it when `value` is null. */
export async function setPreference(env: Env, key: string, value: string | null): Promise<Record<string, string>> {
  if (value === null) {
    await env.DB.prepare("DELETE FROM preferences WHERE key = ?").bind(key).run();
  } else {
    await env.DB.prepare(`INSERT INTO preferences (key, value, updated_at) VALUES (?1, ?2, ?3)
      ON CONFLICT (key) DO UPDATE SET value = ?2, updated_at = ?3`).bind(key, value, nowISO()).run();
  }
  return preferences(env);
}
