// CourierGuy / Shiplogic pickup-points proxy (lockers & kiosks)
// Set secret: COURIER_GUY_API_KEY in Supabase dashboard → Edge Functions → Secrets

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  try {
    // TODO: Move back to secret once Supabase restores secret storage
    const apiKey = Deno.env.get('COURIER_GUY_API_KEY') ?? '56913188326c43d2a471499d63589c55';

    const body = await req.json();
    const { search, lat, lng, type = 'locker' } = body;

    const params = new URLSearchParams({ type });
    if (search)  params.set('search', search);
    if (lat)     params.set('lat', String(lat));
    if (lng)     params.set('lng', String(lng));
    if (lat && lng) params.set('order_closest', 'true');

    const cgRes = await fetch(`https://api.shiplogic.com/pickup-points?${params}`, {
      headers: { 'Authorization': `Bearer ${apiKey}` },
    });

    const data = await cgRes.json();
    return new Response(JSON.stringify(data), {
      status: cgRes.status,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
});
