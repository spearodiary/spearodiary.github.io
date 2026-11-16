// Supabase Edge Function "resolve-link"
// Opens a short Google Maps link (maps.app.goo.gl/…) on the server and returns where it leads,
// so the app can read the coordinates or the place name from the full address.
// Only Google Maps short links are accepted (it is not a general proxy).
//
// Deploy: Supabase Dashboard → Edge Functions → Deploy a new function → Via editor,
// name it resolve-link, paste this file, Deploy. Then in its Details turn OFF "Verify JWT"
// (the site calls it with the publishable key, which is not a JWT).

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};
const allowed = (u: string) => /^https:\/\/(maps\.app\.goo\.gl|goo\.gl\/maps)\/[A-Za-z0-9_-]+/.test(u);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const u = (new URL(req.url).searchParams.get('u') || '').trim();
  if (!allowed(u)) return Response.json({ error: 'only maps.app.goo.gl links' }, { status: 400, headers: cors });
  let cur = u;
  const chain: string[] = [];
  try {
    for (let i = 0; i < 6; i++) {
      const r = await fetch(cur, { redirect: 'manual', headers: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' } });
      const loc = r.headers.get('location');
      if (!loc) break;
      cur = new URL(loc, cur).toString();
      chain.push(cur);
      if (!/goo\.gl/.test(cur)) break; // reached google.com/maps (or the consent page that carries it)
    }
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 502, headers: cors });
  }
  return Response.json({ url: cur, chain }, { headers: cors });
});
