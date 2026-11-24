import { isDay, LOCATIONS, today, UserError, type Env, type Location } from "./db";
import { cookRecipe, listMeals } from "./meals";
import { handleMCP } from "./mcp";
import { listPlan, planMeal, unplanMeal, type Slot } from "./plan";
import { listRecipes, preferences } from "./recipes";
import { consume, listStock, move, open, setBestBefore, waste } from "./stock";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

async function isAuthorized(request: Request, env: Env): Promise<boolean> {
  const given = request.headers.get("authorization")?.replace(/^Bearer /, "") ?? "";
  if (!env.EATHAT_API_KEY || !given) return false;
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([given, env.EATHAT_API_KEY].map((text) => crypto.subtle.digest("SHA-256", encoder.encode(text))));
  return crypto.subtle.timingSafeEqual(a, b);
}

async function body(request: Request): Promise<Record<string, unknown>> {
  try {
    const value = await request.json();
    return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function quantity(value: unknown): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "number" || !(value > 0)) throw new UserError("`quantity` doit être un nombre positif.");
  return value;
}

/** POST /v1/stock/{id}/{action}: the app's quick actions, each answered with the updated line. */
async function stockAction(env: Env, id: number, action: string, args: Record<string, unknown>) {
  switch (action) {
    case "consume":
      return consume(env, id, quantity(args.quantity));
    case "waste":
      return waste(env, id, quantity(args.quantity), typeof args.reason === "string" && args.reason.trim() ? args.reason.trim() : null);
    case "open":
      return open(env, id);
    case "move":
      if (!LOCATIONS.includes(args.location as Location)) throw new UserError("`location` doit être frigo, placard ou congelateur.");
      return move(env, id, args.location as Location);
    case "best-before":
      if (!isDay(args.bestBefore)) throw new UserError("`bestBefore` doit être une date AAAA-MM-JJ.");
      return setBestBefore(env, id, args.bestBefore);
    default:
      return null;
  }
}

/** The app's REST API, under /v1, behind its own key. */
async function handleAPI(request: Request, env: Env, pathname: string): Promise<Response> {
  if (!(await isAuthorized(request, env))) return json({ error: "unauthorized" }, 401);
  const method = request.method;
  try {
    if (method === "GET" && pathname === "/v1/stock") return json({ today: today(), items: await listStock(env) });
    if (method === "GET" && pathname === "/v1/recipes") return json({ recipes: await listRecipes(env, 100) });
    if (method === "GET" && pathname === "/v1/preferences") return json({ preferences: await preferences(env) });
    if (method === "GET" && pathname === "/v1/meals") {
      // ?from=YYYY-MM-DD&to=YYYY-MM-DD (Paris days, `to` defaults to `from`), or the last 60 days.
      const params = new URL(request.url).searchParams;
      const from = params.get("from");
      if (from === null) return json({ today: today(), meals: await listMeals(env) });
      const to = params.get("to") ?? from;
      if (!isDay(from) || !isDay(to) || from > to) throw new UserError("`from` et `to` doivent être des dates AAAA-MM-JJ, `from` d'abord.");
      return json({ today: today(), meals: await listMeals(env, { from, to }) });
    }

    if (method === "GET" && pathname === "/v1/plan") return json({ today: today(), meals: await listPlan(env) });
    if (method === "POST" && pathname === "/v1/plan") {
      const args = await body(request);
      if (typeof args.recipeId !== "number") throw new UserError("`recipeId` doit être un nombre.");
      return json(await planMeal(env, String(args.day), (args.slot ?? "soir") as Slot, args.recipeId));
    }
    const planned = pathname.match(/^\/v1\/plan\/(\d+)$/);
    if (method === "DELETE" && planned) return json(await unplanMeal(env, Number(planned[1])));

    const action = pathname.match(/^\/v1\/stock\/(\d+)\/([a-z-]+)$/);
    if (method === "POST" && action) {
      const line = await stockAction(env, Number(action[1]), action[2], await body(request));
      return line ? json(line) : json({ error: "not_found" }, 404);
    }

    const cooked = pathname.match(/^\/v1\/recipes\/(\d+)\/cooked$/);
    if (method === "POST" && cooked) return json(await cookRecipe(env, Number(cooked[1])));
  } catch (e) {
    if (e instanceof UserError) return json({ error: "invalid", message: e.message }, 400);
    throw e;
  }
  return json({ error: "not_found" }, 404);
}

export default {
  async fetch(request, env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (request.method === "GET" && pathname === "/health") {
      const row = await env.DB.prepare("SELECT count(*) AS tables FROM sqlite_master WHERE type = 'table'").first();
      return json({ ok: true, tables: row?.tables ?? 0 });
    }

    // /mcp (Bearer key) or /mcp/{key}, for clients that only take a URL, like claude.ai's connectors.
    const mcp = pathname.match(/^\/mcp(?:\/([^/]+))?\/?$/);
    if (mcp) return handleMCP(request, env, mcp[1]);

    if (pathname.startsWith("/v1/")) return handleAPI(request, env, pathname);

    // Anything else, OAuth discovery (/.well-known/…, /register) included, is a plain 404: a 401 there makes
    // connector clients like claude.ai insist on signing in, while the MCP key is in its URL.
    return json({ error: "not_found" }, 404);
  },
} satisfies ExportedHandler<Env>;
