// GET /functions/v1/kroger-callback?code=...&state=...
// Kroger redirects here after the user signs in. We exchange the code for
// tokens, save them to kroger_sessions, then redirect back to the iOS app
// via the custom URL scheme.

import { corsHeaders, KROGER_API_BASE, KROGER_CLIENT_ID, KROGER_CLIENT_SECRET, adminClient } from "../_shared/kroger.ts";

const APP_REDIRECT = "com.trevorgoodwill.scantocart://kroger-callback";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });

  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const stateParam = url.searchParams.get("state");

  if (!code || !stateParam) {
    return Response.redirect(`${APP_REDIRECT}?error=missing_params`, 302);
  }

  let userId: string;
  try {
    const decoded = JSON.parse(atob(stateParam));
    userId = decoded.userId;
  } catch {
    return Response.redirect(`${APP_REDIRECT}?error=bad_state`, 302);
  }

  // Exchange code for tokens
  const auth = btoa(`${KROGER_CLIENT_ID}:${KROGER_CLIENT_SECRET}`);
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const redirectUri = `${supabaseUrl}/functions/v1/kroger-callback`;

  const tokenResponse = await fetch(`${KROGER_API_BASE}/connect/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri,
    }).toString(),
  });

  if (!tokenResponse.ok) {
    return Response.redirect(`${APP_REDIRECT}?error=token_exchange_failed`, 302);
  }

  const tokens = await tokenResponse.json();
  const expiresAt = new Date(Date.now() + tokens.expires_in * 1000).toISOString();

  const admin = adminClient();
  const { error } = await admin
    .from("kroger_sessions")
    .upsert({
      user_id: userId,
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    });

  if (error) {
    return Response.redirect(`${APP_REDIRECT}?error=db_save_failed`, 302);
  }

  return Response.redirect(`${APP_REDIRECT}?connected=1`, 302);
});
