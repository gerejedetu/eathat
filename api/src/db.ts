/** The Worker's bindings, and the small helpers every query shares. */

export interface Env {
  DB: D1Database;
  /** The MCP server's key, for /mcp. */
  EATHAT_MCP_TOKEN: string;
  /** The iPhone app's key, for /v1: kept apart so either can be rotated alone. */
  EATHAT_API_KEY: string;
}

/** A mistake in the arguments or the request, reported to the caller as something it can act on. */
export class UserError extends Error {}

export type Location = "frigo" | "placard" | "congelateur";
export const LOCATIONS: Location[] = ["frigo", "placard", "congelateur"];

/** Statuses of a stock line still in the kitchen. */
export const ACTIVE = "i.status IN ('dispo', 'entame')";

export const nowISO = () => new Date().toISOString();

const parisDay = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Paris", year: "numeric", month: "2-digit", day: "2-digit" });

/** Today in Paris, as 'YYYY-MM-DD': best-before dates are kitchen days, not UTC ones. */
export const today = (date = new Date()) => parisDay.format(date);

/** `day` ('YYYY-MM-DD') moved by `days`. */
export function addDays(day: string, days: number): string {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export const DAY = /^\d{4}-\d{2}-\d{2}$/;

export function isDay(value: unknown): value is string {
  return typeof value === "string" && DAY.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`)) &&
    new Date(`${value}T00:00:00Z`).toISOString().startsWith(value);
}

/** Rounds away float noise, so 1 - 0.7 shows as 0.3. */
export const round = (value: number, digits = 3) => Math.round(value * 10 ** digits) / 10 ** digits;
