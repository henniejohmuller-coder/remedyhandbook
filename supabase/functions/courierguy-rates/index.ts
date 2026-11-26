// CourierGuy / Shiplogic rates proxy
// Avoids CORS issues by calling the API server-side.
// Set secret: COURIER_GUY_API_KEY in Supabase dashboard → Edge Functions → Secrets
// Set secret: COLLECTION_ADDRESS_JSON  (JSON string of your dispatch address)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Default collection address — override with COLLECTION_ADDRESS_JSON secret
const DEFAULT_COLLECTION: Record<string, string> = {
  street_address: '1 Example Road',
  suburb:         'Sandton',
  city:           'Johannesburg',
  code:           '2196',
  zone:           'GAU',
  country:        'ZA',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  try {
    // TODO: Move back to secret once Supabase restores secret storage
    const apiKey = Deno.env.get('COURIER_GUY_API_KEY') ?? '56913188326c43d2a471499d63589c55';

    const collectionAddress = (() => {
      const raw = Deno.env.get('COLLECTION_ADDRESS_JSON');
      try { return raw ? JSON.parse(raw) : DEFAULT_COLLECTION; }
      catch { return DEFAULT_COLLECTION; }
    })();

    const body = await req.json();
    // body must contain: deliveryAddress (D2D) OR pudoPointId (PUDO), plus itemCount
    const { deliveryAddress, pudoPointId, itemCount = 1 } = body;

    const parcel = {
      submitted_length_cm: 30,
      submitted_width_cm:  25,
      submitted_height_cm: itemCount > 3 ? 30 : 20,
      submitted_weight_kg: Math.min(itemCount * 0.5, 5),
      packaging: 'parcel',
    };

    const rateBody: Record<string, unknown> = {
      collection_address: collectionAddress,
      parcels: [parcel],
    };

    if (pudoPointId) {
      rateBody['delivery_pickup_point_id']       = pudoPointId;
      rateBody['delivery_pickup_point_provider'] = 'tcg-locker';
    } else if (deliveryAddress) {
      rateBody['delivery_address'] = deliveryAddress;
    } else {
      return new Response(JSON.stringify({ error: 'deliveryAddress or pudoPointId required' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
      });
    }

    const cgRes = await fetch('https://api.shiplogic.com/rates', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(rateBody),
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
