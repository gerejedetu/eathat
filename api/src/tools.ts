import { LOCATIONS, today, UserError, type Env, type Location } from "./db";
import { cookRecipe } from "./meals";
import { addStockItem, deleteRecipe, importOrder, removeStockItem, type NewItem } from "./orders";
import { findPhotos } from "./photos";
import { listPlan, planMeal, SLOTS, unplanMeal, type Slot } from "./plan";
import { listRecipes, preferences, rateRecipe, saveRecipe, setImage, setPreference, type IngredientInput } from "./recipes";
import { consume, expiringSoon, listStock, move, open, setBestBefore, waste, type StockLine } from "./stock";

type Args = Record<string, unknown>;

export interface Tool {
  name: string;
  title: string;
  description: string;
  inputSchema: object;
  annotations?: { readOnlyHint?: boolean; destructiveHint?: boolean; idempotentHint?: boolean; openWorldHint?: boolean };
  run: (env: Env, args: Args) => Promise<unknown>;
}

// MARK: Arguments

function number(args: Args, name: string, { optional = false, integer = false, min = 0, max = Infinity } = {}) {
  const value = args[name];
  if (value === undefined || value === null) {
    if (optional) return undefined;
    throw new UserError(`\`${name}\` est obligatoire.`);
  }
  if (typeof value !== "number" || !Number.isFinite(value) || (integer && !Number.isInteger(value)) || value < min || value > max) {
    throw new UserError(`\`${name}\` doit être un ${integer ? "entier" : "nombre"} entre ${min} et ${max}.`);
  }
  return value;
}

function text(args: Args, name: string, { optional = false, max = 10_000 } = {}) {
  const value = args[name];
  if (value === undefined || value === null || (optional && value === "")) {
    if (optional) return undefined;
    throw new UserError(`\`${name}\` est obligatoire.`);
  }
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new UserError(`\`${name}\` doit être un texte non vide de ${max} caractères au plus.`);
  }
  return value;
}

function location(args: Args, { optional = false } = {}): Location | undefined {
  const value = args.location;
  if ((value === undefined || value === null) && optional) return undefined;
  if (LOCATIONS.includes(value as Location)) return value as Location;
  throw new UserError("`location` doit être frigo, placard ou congelateur.");
}

/** An https photo URL, or undefined when not given. */
function imageUrl(args: Args): string | undefined {
  const value = text(args, "imageUrl", { optional: true, max: 500 });
  if (value === undefined) return undefined;
  if (!/^https:\/\/\S+$/.test(value.trim())) throw new UserError("`imageUrl` doit être une adresse https.");
  return value.trim();
}

const inventoryId = (args: Args) => number(args, "inventoryId", { integer: true, min: 1 }) as number;
const days = (args: Args) => number(args, "days", { optional: true, integer: true, min: 0, max: 60 }) ?? 3;

function ingredients(args: Args): IngredientInput[] {
  const value = args.ingredients;
  if (!Array.isArray(value) || value.length > 40) throw new UserError("`ingredients` doit être une liste (40 au plus).");
  return value.map((item, index) => {
    if (!item || typeof item !== "object") throw new UserError(`L'ingrédient ${index + 1} doit être un objet.`);
    const i = item as Args;
    return {
      name: text(i, "name", { max: 200 })!,
      inventoryId: number(i, "inventoryId", { optional: true, integer: true, min: 1 }),
      productId: number(i, "productId", { optional: true, integer: true, min: 1 }),
      quantity: number(i, "quantity", { optional: true, min: 0.0001 }),
      unit: text(i, "unit", { optional: true, max: 50 }),
      quantityText: text(i, "quantityText", { optional: true, max: 100 }),
      optional: i.optional === true,
    };
  });
}

function newItem(i: Args, where = ""): NewItem {
  if (!i || typeof i !== "object") throw new UserError(`L'article${where} doit être un objet.`);
  const loc = i.location === undefined || i.location === null ? undefined : location(i);
  return {
    name: text(i, "name", { max: 200 })!,
    brand: text(i, "brand", { optional: true, max: 100 }),
    category: text(i, "category", { max: 50 })!,
    location: loc,
    quantity: number(i, "quantity", { min: 0.0001 }) as number,
    unit: text(i, "unit", { max: 50 })!,
    unitWeightG: number(i, "unitWeightG", { optional: true, min: 0.0001 }),
    bestBefore: text(i, "bestBefore", { optional: true, max: 10 }),
    shelfLifeDays: number(i, "shelfLifeDays", { optional: true, integer: true, min: 1, max: 3650 }),
    shelfLifeFrozenDays: number(i, "shelfLifeFrozenDays", { optional: true, integer: true, min: 1, max: 3650 }),
    shelfLifeOpenedDays: number(i, "shelfLifeOpenedDays", { optional: true, integer: true, min: 1, max: 3650 }),
    tags: text(i, "tags", { optional: true, max: 200 }),
    imageUrl: imageUrl(i),
    priceCents: number(i, "priceCents", { optional: true, integer: true, min: 0 }),
    packs: number(i, "packs", { optional: true, integer: true, min: 1, max: 1000 }),
    label: text(i, "label", { optional: true, max: 300 }),
  };
}

function tags(args: Args): string[] | undefined {
  const value = args.tags;
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value) || !value.every((t) => typeof t === "string")) throw new UserError("`tags` doit être une liste de textes.");
  return value;
}

// MARK: Shapes sent to Claude

/** A stock line as Claude needs it: short, so the whole kitchen fits in one answer. */
const compact = (l: StockLine) => ({
  inventoryId: l.id,
  name: l.brand ? `${l.name} (${l.brand})` : l.name,
  category: l.category,
  ...(l.tags ? { tags: l.tags } : {}),
  quantity: l.quantity,
  unit: l.unit,
  location: l.location,
  bestBefore: l.bestBefore,
  ...(l.bestBeforeIsEstimate && l.bestBefore ? { dateIsEstimate: true } : {}),
  daysLeft: l.daysLeft,
  ...(l.openedAt ? { opened: true } : {}),
  ...(l.status === "fini" || l.status === "jete" ? { status: l.status } : {}),
});

const RECIPE_RULES = [
  "Utiliser d'abord ce qui expire le plus tôt (expiringSoon, daysLeft le plus petit).",
  "Respecter toutes les préférences ; un produit dont les tags vont contre elles est exclu.",
  "Privilégier les recettes rapides, pour le nombre de personnes du foyer (préférence foyer).",
  "Une date avec dateIsEstimate est une estimation : en cas de doute, demander la vraie date et la corriger avec update_best_before.",
  "Après avoir proposé une recette retenue, l'enregistrer avec save_recipe en liant chaque ingrédient du stock par son inventoryId.",
  "Quand l'utilisateur choisit quoi manger un jour donné, mettre la recette au planning avec plan_meal (« Ma semaine »).",
  "Avant save_recipe, appeler find_photos avec le nom du plat en anglais et passer la photo la plus proche en imageUrl ; " +
    "sans photo, la recette n'a qu'un emoji dans l'app.",
];

const itemProperties = {
  name: { type: "string", description: "Nom du produit, sans la marque : « Lait demi-écrémé »." },
  brand: { type: "string" },
  category: { type: "string", description: "feculents, frais, legumes, fruits, epicerie, pain, boissons, petit_dej, viande, poisson, surgeles." },
  location: { type: "string", enum: LOCATIONS, description: "Où il va ; le lieu habituel du produit sinon (placard pour un nouveau)." },
  quantity: { type: "number", exclusiveMinimum: 0, description: "Combien, dans `unit` : 500 (g), 12 (œuf), 6 (bouteille 1 L)." },
  unit: { type: "string", description: "g, œuf, pot, bouteille 1 L, boîte 400 g…" },
  unitWeightG: { type: "number", exclusiveMinimum: 0, description: "Grammes dans une `unit`, pour le gaspillage en kg." },
  bestBefore: { type: "string", description: "Date imprimée AAAA-MM-JJ ; estimée d'après la durée de conservation sinon." },
  shelfLifeDays: { type: "integer", minimum: 1, description: "Nouveau produit : jours de conservation fermé, à sa place." },
  shelfLifeFrozenDays: { type: "integer", minimum: 1, description: "Nouveau produit : jours au congélateur." },
  shelfLifeOpenedDays: { type: "integer", minimum: 1, description: "Nouveau produit : jours une fois ouvert." },
  tags: { type: "string", description: "Ce que filtrent les préférences : « lactose,gluten,arachide »." },
  imageUrl: { type: "string", description: "Photo détourée (https), ex. TheMealDB images/ingredients/{Nom}-Small.png." },
  priceCents: { type: "integer", minimum: 0, description: "Prix payé pour la ligne, en centimes." },
  packs: { type: "integer", minimum: 1, description: "Paquets achetés (1 par défaut)." },
  label: { type: "string", description: "La ligne telle que le ticket l'écrit." },
};

const locationSchema = { type: "string", enum: LOCATIONS, description: "frigo, placard ou congelateur." };
const inventoryIdSchema = { type: "integer", description: "Id de la ligne de stock (inventoryId), donné par get_cooking_context ou list_inventory." };
const daysSchema = { type: "integer", minimum: 0, maximum: 60, description: "Horizon en jours (3 par défaut)." };

// MARK: Tools

export const tools: Tool[] = [
  {
    name: "get_cooking_context",
    title: "Contexte cuisine",
    description: "Tout ce qu'il faut pour proposer un repas, en un appel : ce qui expire bientôt (périmé compris), le reste du stock " +
      "par lieu, les préférences de l'utilisateur, les règles à suivre et les dernières recettes enregistrées. À appeler en premier " +
      "pour « qu'est-ce que je cuisine ? ».",
    inputSchema: { type: "object", properties: { days: daysSchema }, additionalProperties: false },
    annotations: { readOnlyHint: true },
    async run(env, args) {
      const horizon = days(args);
      const [stock, prefs, recent, plan] = await Promise.all([listStock(env), preferences(env), listRecipes(env, 10), listPlan(env)]);
      const soon = stock.filter((l) => l.daysLeft !== null && l.daysLeft <= horizon);
      const rest = stock.filter((l) => !soon.includes(l));
      return {
        today: today(),
        horizonDays: horizon,
        preferences: prefs,
        rules: RECIPE_RULES,
        expiringSoon: soon.map(compact),
        otherStock: Object.fromEntries(LOCATIONS.map((loc) => [loc, rest.filter((l) => l.location === loc).map(compact)])),
        recentRecipes: recent.map((r) => ({ id: r.id, title: r.title, rating: r.rating, createdAt: r.createdAt.slice(0, 10) })),
        mealPlan: plan.map((m) => ({ id: m.id, day: m.day, slot: m.slot, recipeId: m.recipeId, title: m.title })),
      };
    },
  },
  {
    name: "list_inventory",
    title: "Lister le stock",
    description: "Le stock, du plus urgent au moins urgent, avec des filtres facultatifs.",
    inputSchema: {
      type: "object",
      properties: {
        location: locationSchema,
        category: { type: "string", description: "feculents, frais, legumes, fruits, epicerie, pain, boissons, petit_dej…" },
        includeGone: { type: "boolean", description: "Inclure aussi les lignes finies ou jetées." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true },
    async run(env, args) {
      const lines = await listStock(env, {
        location: location(args, { optional: true }),
        category: text(args, "category", { optional: true, max: 50 }),
        includeGone: args.includeGone === true,
      });
      return { today: today(), count: lines.length, items: lines.map(compact) };
    },
  },
  {
    name: "get_expiring_soon",
    title: "Bientôt périmé",
    description: "Ce qui expire dans les N jours (déjà périmé compris), le plus urgent en premier.",
    inputSchema: { type: "object", properties: { days: daysSchema }, additionalProperties: false },
    annotations: { readOnlyHint: true },
    async run(env, args) {
      const lines = await expiringSoon(env, days(args));
      return { today: today(), items: lines.map(compact) };
    },
  },
  {
    name: "consume_item",
    title: "Consommer",
    description: "Retire une quantité mangée ou utilisée d'une ligne de stock (tout ce qui reste si `quantity` manque). " +
      "Une ligne fermée entamée passe en « entamé » et sa date se raccourcit.",
    inputSchema: {
      type: "object",
      properties: {
        inventoryId: inventoryIdSchema,
        quantity: { type: "number", exclusiveMinimum: 0, description: "Dans l'unité de la ligne (`unit`). Absent : tout." },
      },
      required: ["inventoryId"],
      additionalProperties: false,
    },
    annotations: { destructiveHint: false },
    run: (env, args) => consume(env, inventoryId(args), number(args, "quantity", { optional: true, min: 0.0001 })).then(compact),
  },
  {
    name: "mark_wasted",
    title: "Jeter",
    description: "Enregistre qu'une quantité a été jetée (tout ce qui reste si `quantity` manque), avec la raison. " +
      "Alimente les stats de gaspillage en kg et en €.",
    inputSchema: {
      type: "object",
      properties: {
        inventoryId: inventoryIdSchema,
        quantity: { type: "number", exclusiveMinimum: 0, description: "Dans l'unité de la ligne. Absent : tout." },
        reason: { type: "string", description: "Ex. « périmé », « moisi », « oublié au fond du frigo »." },
      },
      required: ["inventoryId"],
      additionalProperties: false,
    },
    annotations: { destructiveHint: false },
    run: (env, args) => waste(env, inventoryId(args), number(args, "quantity", { optional: true, min: 0.0001 }),
      text(args, "reason", { optional: true, max: 300 }) ?? null).then(compact),
  },
  {
    name: "open_item",
    title: "Ouvrir",
    description: "Marque une ligne comme ouverte ; sa date passe à la durée de conservation une fois ouvert.",
    inputSchema: { type: "object", properties: { inventoryId: inventoryIdSchema }, required: ["inventoryId"], additionalProperties: false },
    annotations: { idempotentHint: true },
    run: (env, args) => open(env, inventoryId(args)).then(compact),
  },
  {
    name: "move_item",
    title: "Déplacer",
    description: "Change le lieu d'une ligne (ex. baguette → congelateur). Entrer au congélateur ou en sortir recalcule la date.",
    inputSchema: {
      type: "object",
      properties: { inventoryId: inventoryIdSchema, location: locationSchema },
      required: ["inventoryId", "location"],
      additionalProperties: false,
    },
    annotations: { idempotentHint: true },
    run: (env, args) => move(env, inventoryId(args), location(args)!).then(compact),
  },
  {
    name: "update_best_before",
    title: "Corriger la date",
    description: "Remplace une date limite estimée par la vraie date lue sur l'emballage.",
    inputSchema: {
      type: "object",
      properties: { inventoryId: inventoryIdSchema, bestBefore: { type: "string", description: "AAAA-MM-JJ." } },
      required: ["inventoryId", "bestBefore"],
      additionalProperties: false,
    },
    annotations: { idempotentHint: true },
    run: (env, args) => setBestBefore(env, inventoryId(args), text(args, "bestBefore", { max: 10 })!).then(compact),
  },
  {
    name: "save_recipe",
    title: "Enregistrer une recette",
    description: "Enregistre une recette retenue avec l'utilisateur ; elle apparaît dans l'app. Liez chaque ingrédient du stock " +
      "par son inventoryId, avec une quantité dans l'unité de la ligne, pour que « Je l'ai cuisinée » puisse décompter le stock. " +
      "Ne retire rien du stock.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        servings: { type: "integer", minimum: 1, description: "2 par défaut." },
        prepMinutes: { type: "integer", minimum: 1 },
        steps: { type: "string", description: "Les étapes, en markdown." },
        tags: { type: "array", items: { type: "string" }, description: "Ex. rapide, anti-gaspi, sans-viande." },
        notes: { type: "string" },
        imageUrl: { type: "string", description: "Photo du plat (https), affichée dans l'app : en choisir une avec find_photos." },
        ingredients: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              inventoryId: { type: "integer", description: "La ligne de stock utilisée, si l'ingrédient vient du stock." },
              quantity: { type: "number", exclusiveMinimum: 0, description: "Dans l'unité de la ligne de stock." },
              unit: { type: "string" },
              quantityText: { type: "string", description: "Comme on le dit : « 1 pincée », « un filet »." },
              optional: { type: "boolean" },
            },
            required: ["name"],
            additionalProperties: false,
          },
        },
      },
      required: ["title", "steps", "ingredients"],
      additionalProperties: false,
    },
    run: (env, args) => saveRecipe(env, {
      title: text(args, "title", { max: 200 })!,
      servings: number(args, "servings", { optional: true, integer: true, min: 1, max: 20 }),
      prepMinutes: number(args, "prepMinutes", { optional: true, integer: true, min: 1, max: 1440 }),
      steps: text(args, "steps", { max: 20_000 })!,
      tags: tags(args),
      notes: text(args, "notes", { optional: true, max: 2000 }),
      imageUrl: imageUrl(args),
      ingredients: ingredients(args),
    }),
  },
  {
    name: "add_stock_item",
    title: "Ajouter au stock",
    description: "Ajoute un produit au stock hors commande (marché, cadeau, oubli). Le produit est retrouvé par nom et marque, " +
      "ou créé. Sans date imprimée, elle est estimée d'après la durée de conservation. Pour une livraison, utiliser import_order.",
    inputSchema: { type: "object", properties: itemProperties, required: ["name", "category", "quantity", "unit"], additionalProperties: false },
    run: (env, args) => addStockItem(env, newItem(args)).then(compact),
  },
  {
    name: "import_order",
    title: "Importer une commande",
    description: "Enregistre une commande (ex. une livraison de supermarché) et met chaque article au stock. Un numéro de commande déjà " +
      "importé est refusé. Un pack se décrit dans l'unité du stock : « 6 × bouteille 1 L » = quantity 6, unit « bouteille 1 L ».",
    inputSchema: {
      type: "object",
      properties: {
        store: { type: "string", description: "Ex. Supermarché du coin, drive." },
        externalRef: { type: "string", description: "Numéro de commande du magasin." },
        orderedAt: { type: "string", description: "AAAA-MM-JJ." },
        deliveredAt: { type: "string", description: "AAAA-MM-JJ, si déjà livrée." },
        totalCents: { type: "integer", minimum: 0 },
        deliveryFeeCents: { type: "integer", minimum: 0 },
        discountCents: { type: "integer", minimum: 0, description: "Montant économisé, en positif." },
        notes: { type: "string" },
        items: {
          type: "array",
          items: { type: "object", properties: itemProperties, required: ["name", "category", "quantity", "unit"], additionalProperties: false },
        },
      },
      required: ["store", "orderedAt", "items"],
      additionalProperties: false,
    },
    async run(env, args) {
      const items = args.items;
      if (!Array.isArray(items) || items.length > 150) throw new UserError("`items` doit être une liste (150 au plus).");
      const order = await importOrder(env, {
        store: text(args, "store", { max: 100 })!,
        externalRef: text(args, "externalRef", { optional: true, max: 100 }),
        orderedAt: text(args, "orderedAt", { max: 10 })!,
        deliveredAt: text(args, "deliveredAt", { optional: true, max: 10 }),
        totalCents: number(args, "totalCents", { optional: true, integer: true, min: 0 }),
        deliveryFeeCents: number(args, "deliveryFeeCents", { optional: true, integer: true, min: 0 }),
        discountCents: number(args, "discountCents", { optional: true, integer: true, min: 0 }),
        notes: text(args, "notes", { optional: true, max: 2000 }),
        items: items.map((item, index) => newItem(item as Args, ` ${index + 1}`)),
      });
      return { orderId: order.orderId, count: order.items.length, items: order.items.map(compact) };
    },
  },
  {
    name: "remove_stock_item",
    title: "Supprimer une ligne de stock",
    description: "Supprime une ligne de stock saisie par erreur, avec son historique. Pour ce qui a été mangé ou jeté, utiliser " +
      "consume_item ou mark_wasted : eux gardent la trace pour les stats anti-gaspi.",
    inputSchema: { type: "object", properties: { inventoryId: inventoryIdSchema }, required: ["inventoryId"], additionalProperties: false },
    annotations: { destructiveHint: true },
    run: (env, args) => removeStockItem(env, inventoryId(args)),
  },
  {
    name: "delete_recipe",
    title: "Supprimer une recette",
    description: "Supprime une recette enregistrée, ses ingrédients et sa place dans le planning. Les repas déjà notés restent.",
    inputSchema: { type: "object", properties: { id: { type: "integer", minimum: 1 } }, required: ["id"], additionalProperties: false },
    annotations: { destructiveHint: true },
    run: (env, args) => deleteRecipe(env, number(args, "id", { integer: true, min: 1 }) as number),
  },
  {
    name: "get_meal_plan",
    title: "Voir le planning des repas",
    description: "Les repas planifiés (« Ma semaine » dans l'app), par jour, midi puis soir.",
    inputSchema: {
      type: "object",
      properties: {
        from: { type: "string", description: "Premier jour, AAAA-MM-JJ ; aujourd'hui par défaut." },
        days: { type: "integer", minimum: 1, maximum: 31, description: "7 par défaut." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true },
    async run(env, args) {
      const from = text(args, "from", { optional: true, max: 10 }) ?? today();
      const meals = await listPlan(env, from, number(args, "days", { optional: true, integer: true, min: 1, max: 31 }) ?? 7);
      return { today: today(), from, meals };
    },
  },
  {
    name: "plan_meal",
    title: "Planifier un repas",
    description: "Met une recette enregistrée au planning d'un jour, le midi ou le soir ; elle apparaît dans « Ma semaine ».",
    inputSchema: {
      type: "object",
      properties: {
        day: { type: "string", description: "AAAA-MM-JJ." },
        slot: { type: "string", enum: SLOTS, description: "soir par défaut." },
        recipeId: { type: "integer", minimum: 1 },
      },
      required: ["day", "recipeId"],
      additionalProperties: false,
    },
    run(env, args) {
      const slot = (args.slot ?? "soir") as Slot;
      return planMeal(env, text(args, "day", { max: 10 })!, slot, number(args, "recipeId", { integer: true, min: 1 }) as number);
    },
  },
  {
    name: "unplan_meal",
    title: "Retirer un repas du planning",
    description: "Retire un repas planifié (son id, donné par get_meal_plan).",
    inputSchema: { type: "object", properties: { id: { type: "integer", minimum: 1 } }, required: ["id"], additionalProperties: false },
    run: (env, args) => unplanMeal(env, number(args, "id", { integer: true, min: 1 }) as number),
  },
  {
    name: "find_photos",
    title: "Chercher une photo de plat",
    description: "Cherche des photos de plats proches (TheMealDB) pour l'imageUrl d'une recette. La requête est en anglais : le " +
      "nom du plat (« ratatouille », « lentil soup ») ou son ingrédient principal (« courgette », « potatoes »). Renvoie des " +
      "URL réelles : ne jamais inventer d'URL de photo.",
    inputSchema: {
      type: "object",
      properties: { query: { type: "string", description: "En anglais." }, limit: { type: "integer", minimum: 1, maximum: 20 } },
      required: ["query"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, openWorldHint: true },
    async run(_env, args) {
      const query = text(args, "query", { max: 100 })!;
      const photos = await findPhotos(query, number(args, "limit", { optional: true, integer: true, min: 1, max: 20 }) ?? 8);
      return { query, photos, ...(photos.length ? {} : { hint: "Rien trouvé : essayer un autre mot anglais, plus simple." }) };
    },
  },
  {
    name: "set_image",
    title: "Changer une photo",
    description: "Donne une photo (https) à une recette ou à un produit du stock, pour l'app. Sans imageUrl, retire la photo.",
    inputSchema: {
      type: "object",
      properties: {
        target: { type: "string", enum: ["recipe", "product"] },
        id: { type: "integer", minimum: 1, description: "Id de la recette, ou productId du produit." },
        imageUrl: { type: "string" },
      },
      required: ["target", "id"],
      additionalProperties: false,
    },
    run(env, args) {
      if (args.target !== "recipe" && args.target !== "product") throw new UserError("`target` doit être recipe ou product.");
      return setImage(env, args.target, number(args, "id", { integer: true, min: 1 }) as number, imageUrl(args) ?? null);
    },
  },
  {
    name: "rate_recipe",
    title: "Noter une recette",
    description: "Donne une note de 1 à 5 à une recette enregistrée, avec un commentaire facultatif.",
    inputSchema: {
      type: "object",
      properties: {
        recipeId: { type: "integer" },
        rating: { type: "integer", minimum: 1, maximum: 5 },
        notes: { type: "string", description: "Remplace le commentaire existant." },
      },
      required: ["recipeId", "rating"],
      additionalProperties: false,
    },
    annotations: { idempotentHint: true },
    run: (env, args) => rateRecipe(env, number(args, "recipeId", { integer: true, min: 1 })!,
      number(args, "rating", { integer: true, min: 1, max: 5 })!, text(args, "notes", { optional: true, max: 2000 })),
  },
  {
    name: "log_meal",
    title: "Repas cuisiné",
    description: "L'utilisateur a cuisiné une recette enregistrée : enregistre le repas et retire du stock chaque ingrédient " +
      "lié (quantité de la recette, en prenant d'abord la ligne qui expire en premier). Les ingrédients facultatifs ou non liés " +
      "au stock ne sont pas retirés ; la réponse les liste.",
    inputSchema: {
      type: "object",
      properties: { recipeId: { type: "integer" }, note: { type: "string" } },
      required: ["recipeId"],
      additionalProperties: false,
    },
    run: (env, args) => cookRecipe(env, number(args, "recipeId", { integer: true, min: 1 })!,
      text(args, "note", { optional: true, max: 500 }) ?? null),
  },
  {
    name: "list_recipes",
    title: "Recettes enregistrées",
    description: "Les recettes enregistrées, les plus récentes d'abord, avec leurs ingrédients.",
    inputSchema: { type: "object", properties: { limit: { type: "integer", minimum: 1, maximum: 100 } }, additionalProperties: false },
    annotations: { readOnlyHint: true },
    run: (env, args) => listRecipes(env, number(args, "limit", { optional: true, integer: true, min: 1, max: 100 }) ?? 20),
  },
  {
    name: "get_preferences",
    title: "Préférences",
    description: "Les règles de l'utilisateur (régime, aliments aimés ou évités, consignes de cuisson), clé → valeur.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: { readOnlyHint: true },
    run: (env) => preferences(env),
  },
  {
    name: "set_preference",
    title: "Changer une préférence",
    description: "Crée ou remplace une préférence ; `value` null la supprime. Uniquement quand l'utilisateur le demande.",
    inputSchema: {
      type: "object",
      properties: {
        key: { type: "string", description: "Ex. regime, evite, aime, cuisson_oignons." },
        value: { type: ["string", "null"] },
      },
      required: ["key", "value"],
      additionalProperties: false,
    },
    annotations: { idempotentHint: true },
    run: (env, args) => setPreference(env, text(args, "key", { max: 100 })!.trim(),
      args.value === null ? null : text(args, "value", { max: 2000 })!.trim()),
  },
];
