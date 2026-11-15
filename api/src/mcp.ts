import { UserError, type Env } from "./db";
import { tools } from "./tools";

/** The Eathat MCP server: stateless Streamable HTTP, every POST answered with plain JSON. */

const SUPPORTED_VERSIONS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];

const INSTRUCTIONS = `Eathat suit ce qu'il y a dans la cuisine de l'utilisateur (frigo, placard, congélateur) pour arrêter le
gaspillage et tenir le budget. Ces outils lisent et changent son vrai stock ; l'app iPhone affiche les changements.
Pour proposer un repas, appeler d'abord get_cooking_context et suivre ses règles : ce qui expire le plus tôt en premier,
les préférences toujours respectées, des recettes rapides, pour le foyer indiqué dans les préférences. Une recette retenue s'enregistre avec save_recipe.
Quand l'utilisateur dit avoir mangé, jeté, ouvert ou congelé quelque chose, mettre le stock à jour (consume_item,
mark_wasted, open_item, move_item). Répondre dans la langue de l'utilisateur.`;

interface Request {
  jsonrpc: "2.0";
  id?: string | number | null;
  method: string;
  params?: Record<string, unknown>;
}

const reply = (body: unknown, status = 200) =>
  new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: body === null ? {} : { "content-type": "application/json" },
  });

const result = (id: Request["id"], value: unknown) => ({ jsonrpc: "2.0", id, result: value });
const error = (id: Request["id"], code: number, message: string) => ({ jsonrpc: "2.0", id: id ?? null, error: { code, message } });

async function isAuthorized(request: globalThis.Request, env: Env, pathToken?: string): Promise<boolean> {
  const given = pathToken ?? request.headers.get("authorization")?.replace(/^Bearer /, "") ?? "";
  if (!env.EATHAT_MCP_TOKEN || !given) return false;
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([given, env.EATHAT_MCP_TOKEN].map((text) => crypto.subtle.digest("SHA-256", encoder.encode(text))));
  return crypto.subtle.timingSafeEqual(a, b);
}

async function call(env: Env, params: Record<string, unknown> = {}) {
  const tool = tools.find((t) => t.name === params.name);
  if (!tool) return null;
  const args = (params.arguments ?? {}) as Record<string, unknown>;
  try {
    const value = await tool.run(env, args);
    return { content: [{ type: "text", text: JSON.stringify(value, null, 1) }] };
  } catch (e) {
    if (e instanceof UserError) return { content: [{ type: "text", text: e.message }], isError: true };
    console.error(`MCP tool ${tool.name} failed`, e);
    return { content: [{ type: "text", text: "Eathat n'a pas pu le faire. Réessaie." }], isError: true };
  }
}

async function handle(env: Env, message: Request): Promise<object | null> {
  if (message?.jsonrpc !== "2.0" || typeof message.method !== "string") return error(message?.id, -32600, "Invalid request");
  const isNotification = message.id === undefined;
  switch (message.method) {
    case "initialize": {
      const asked = message.params?.protocolVersion;
      const protocolVersion = typeof asked === "string" && SUPPORTED_VERSIONS.includes(asked) ? asked : SUPPORTED_VERSIONS[0];
      return result(message.id, {
        protocolVersion,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "eathat", title: "Eathat", version: "1.0.0" },
        instructions: INSTRUCTIONS,
      });
    }
    case "ping":
      return isNotification ? null : result(message.id, {});
    case "tools/list":
      return result(message.id, {
        tools: tools.map(({ name, title, description, inputSchema, annotations }) => ({ name, title, description, inputSchema, annotations })),
      });
    case "tools/call": {
      const value = await call(env, message.params);
      return value ? result(message.id, value) : error(message.id, -32602, `Unknown tool: ${String(message.params?.name)}`);
    }
    default:
      return isNotification ? null : error(message.id, -32601, `Method not found: ${message.method}`);
  }
}

export async function handleMCP(request: globalThis.Request, env: Env, pathToken?: string): Promise<Response> {
  if (!(await isAuthorized(request, env, pathToken))) return reply(error(null, -32001, "Unauthorized"), 401);
  // No server-initiated stream and no sessions to end.
  if (request.method !== "POST") return new Response(null, { status: 405, headers: { allow: "POST" } });

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return reply(error(null, -32700, "Parse error"), 400);
  }
  if (Array.isArray(body)) {
    const replies = (await Promise.all(body.map((m) => handle(env, m as Request)))).filter((r) => r !== null);
    return replies.length ? reply(replies) : reply(null, 202);
  }
  const answer = await handle(env, body as Request);
  return answer ? reply(answer) : reply(null, 202);
}
