// PUT /functions/v1/kroger-cart-add
// Body: { items: [{ upc: string, quantity: number }] }
// Adds items to the signed-in user's Kroger online cart. Requires the user
// to have connected their Kroger account first.

import { corsHeaders, jsonResponse, getAuthedUser, getUserKrogerToken, KROGER_API_BASE } from "../_shared/kroger.ts";

interface CartItem {
  upc: string;
  quantity: number;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });
  if (req.method !== "PUT" && req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const user = await getAuthedUser(req);
  if (!user) return jsonResponse({ error: "Not authenticated" }, 401);

  let body: { items?: CartItem[] };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const items = body.items ?? [];
  if (items.length === 0) return jsonResponse({ error: "No items provided" }, 400);

  const token = await getUserKrogerToken(user.id);
  if (!token) {
    return jsonResponse({ error: "kroger_not_connected" }, 401);
  }

  const cartItems = items.map(({ upc, quantity }) => ({ upc, quantity }));

  const response = await fetch(`${KROGER_API_BASE}/cart/add`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ items: cartItems }),
  });

  if (response.status === 401) {
    return jsonResponse({ error: "kroger_session_expired" }, 401);
  }

  if (!response.ok) {
    const text = await response.text();
    return jsonResponse({ error: text || "Failed to add to cart" }, response.status);
  }

  return jsonResponse({ success: true, itemsAdded: items.length });
});
