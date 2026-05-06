// GET /functions/v1/kroger-auth
// Returns a Kroger OAuth URL for the user to sign into. After they sign in,
// Kroger redirects to /kroger-callback which finalizes the session.

import { corsHeaders, jsonResponse, getAuthedUser, KROGER_API_BASE, KROGER_CLIENT_ID } from "../_shared/kroger.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });

  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const redirectUri = `${supabaseUrl}/functions/v1/kroger-callback`;
  // State carries the user id so the callback knows whose session to save.
  const state = btoa(JSON.stringify({ userId: user.id, ts: Date.now() }));

  const authUrl = new URL(`${KROGER_API_BASE}/connect/oauth2/authorize`);
  authUrl.searchParams.set("response_type", "code");
  authUrl.searchParams.set("client_id", KROGER_CLIENT_ID);
  authUrl.searchParams.set("redirect_uri", redirectUri);
  authUrl.searchParams.set("scope", "cart.basic:write product.compact profile.compact");
  authUrl.searchParams.set("state", state);

  return jsonResponse({ authUrl: authUrl.toString() });
});
