// Shared helpers for Kroger Edge Functions.
// All functions in this folder import from here to keep auth + token logic
// in one place.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const KROGER_BASE = "https://api.kroger.com/v1";
const CLIENT_ID = Deno.env.get("KROGER_CLIENT_ID") ?? "";
const CLIENT_SECRET = Deno.env.get("KROGER_CLIENT_SECRET") ?? "";

// In-memory cache for the client_credentials token (lives ~30 min on Kroger's side).
let cachedAppToken: { token: string; expiresAt: number } | null = null;

export function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
  };
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

/// Returns a Kroger application access token (client_credentials grant).
/// Cached in-process for ~25 min so we don't hammer Kroger on every request.
export async function getAppToken(scope = "product.compact"): Promise<string> {
  const now = Date.now();
  if (cachedAppToken && cachedAppToken.expiresAt > now + 30_000) {
    return cachedAppToken.token;
  }

  const auth = btoa(`${CLIENT_ID}:${CLIENT_SECRET}`);
  const response = await fetch(`${KROGER_BASE}/connect/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=client_credentials&scope=${encodeURIComponent(scope)}`,
  });

  if (!response.ok) {
    throw new Error(`Kroger token fetch failed: ${response.status}`);
  }

  const data = await response.json();
  cachedAppToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in ?? 1800) * 1000,
  };
  return cachedAppToken.token;
}

/// Returns the Supabase user from the request's JWT, or null.
export async function getAuthedUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;
  const jwt = authHeader.slice(7);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? ""
  );
  const { data, error } = await supabase.auth.getUser(jwt);
  if (error || !data.user) return null;
  return data.user;
}

/// Returns a service-role Supabase client for writing kroger_sessions
/// (bypasses RLS).
export function adminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );
}

/// Loads the user's Kroger access token, refreshing it via refresh_token if
/// it's expired. Returns null if the user isn't connected to Kroger or the
/// refresh failed (caller should prompt them to reconnect).
export async function getUserKrogerToken(userId: string): Promise<string | null> {
  const admin = adminClient();
  const { data: session } = await admin
    .from("kroger_sessions")
    .select("*")
    .eq("user_id", userId)
    .single();

  if (!session) return null;

  const expiresAt = new Date(session.expires_at).getTime();
  if (expiresAt > Date.now() + 60_000) {
    return session.access_token;
  }

  // Refresh
  const auth = btoa(`${CLIENT_ID}:${CLIENT_SECRET}`);
  const refresh = await fetch(`${KROGER_BASE}/connect/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(session.refresh_token)}`,
  });

  if (!refresh.ok) {
    await admin.from("kroger_sessions").delete().eq("user_id", userId);
    return null;
  }

  const tokens = await refresh.json();
  const newExpiresAt = new Date(Date.now() + tokens.expires_in * 1000).toISOString();
  await admin
    .from("kroger_sessions")
    .update({
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token ?? session.refresh_token,
      expires_at: newExpiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId);

  return tokens.access_token;
}

export const KROGER_API_BASE = KROGER_BASE;
export const KROGER_CLIENT_ID = CLIENT_ID;
export const KROGER_CLIENT_SECRET = CLIENT_SECRET;
