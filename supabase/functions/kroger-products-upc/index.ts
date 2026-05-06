// GET /functions/v1/kroger-products-upc?upc=...&locationId=...

import { corsHeaders, jsonResponse, getAuthedUser, getAppToken, KROGER_API_BASE } from "../_shared/kroger.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });

  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  const url = new URL(req.url);
  const upc = url.searchParams.get("upc");
  const locationId = url.searchParams.get("locationId");
  if (!upc) return jsonResponse({ error: "Missing upc" }, 400);

  try {
    const token = await getAppToken();
    const krogerUrl = new URL(`${KROGER_API_BASE}/products`);
    krogerUrl.searchParams.set("filter.gtin13", upc);
    if (locationId) krogerUrl.searchParams.set("filter.locationId", locationId);

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
