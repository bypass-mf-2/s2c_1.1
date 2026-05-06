// GET /functions/v1/kroger-locations?lat=...&lng=...
// Finds Kroger stores within ~10mi of a coordinate.

import { corsHeaders, jsonResponse, getAuthedUser, getAppToken, KROGER_API_BASE } from "../_shared/kroger.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });

  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  const url = new URL(req.url);
  const lat = url.searchParams.get("lat");
  const lng = url.searchParams.get("lng");
  if (!lat || !lng) return jsonResponse({ error: "Missing lat/lng" }, 400);

  try {
    const token = await getAppToken();
    const krogerUrl = new URL(`${KROGER_API_BASE}/locations`);
    krogerUrl.searchParams.set("filter.latLong.near", `${lat},${lng}`);
    krogerUrl.searchParams.set("filter.radiusInMiles", "25");
    krogerUrl.searchParams.set("filter.limit", "20");

    const response = await fetch(krogerUrl.toString(), {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
    if (!response.ok) return jsonResponse({ data: [] });
    const body = await response.json();
    return jsonResponse({ data: body.data ?? [] });
  } catch {
    return jsonResponse({ data: [] });
  }
});
