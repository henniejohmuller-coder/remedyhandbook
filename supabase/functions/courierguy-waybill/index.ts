// CourierGuy / Shiplogic waybill creation proxy
// Creates a shipment and returns the waybill number and tracking number.
// Set secret: COURIER_GUY_API_KEY
// Set secret: COLLECTION_ADDRESS_JSON
// Optional secret: COLLECTION_CONTACT_JSON

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const DEFAULT_COLLECTION = {
  street_address: '1 Example Road',
  suburb:         'Sandton',
  city:           'Johannesburg',
  code:           '2196',
  zone:           'GAU',
  country:        'ZA',
};

const DEFAULT_COLLECTION_CONTACT = {
  name:  'Remedy Handbook',
  phone: '+27000000000',
  email: 'orders@remedyhandbook.com',
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

    const collectionContact = (() => {
      const raw = Deno.env.get('COLLECTION_CONTACT_JSON');
      try { return raw ? JSON.parse(raw) : DEFAULT_COLLECTION_CONTACT; }
      catch { return DEFAULT_COLLECTION_CONTACT; }
    })();

    const body = await req.json();
    const {
      orderId,
      serviceCode,
      recipientName,
      recipientPhone,
      recipientEmail,
      deliveryAddress,   // D2D: { street_address, suburb, city, zone, code, country }
      pudoPointId,       // PUDO locker ID
      itemCount = 1,
      orderRef,
    } = body;

    if (!serviceCode || !recipientName || (!deliveryAddress && !pudoPointId)) {
      return new Response(
        JSON.stringify({ error: 'serviceCode, recipientName, and deliveryAddress or pudoPointId are required' }),
        { status: 400, headers: { ...CORS, 'Content-Type': 'application/json' } },
      );
    }

    const parcel = {
      submitted_length_cm: 30,
      submitted_width_cm:  25,
      submitted_height_cm: itemCount > 3 ? 30 : 20,
      submitted_weight_kg: Math.min(itemCount * 0.5, 5),
      packaging: 'parcel',
      description: 'Herbal Products',
    };

    const shipmentBody: Record<string, unknown> = {
      service_level_code:   serviceCode,
      special_instructions: orderRef ? `Order ${orderRef}` : undefined,
      collection_address:   collectionAddress,
      collection_contact:   collectionContact,
      delivery_contact: {
        name:  recipientName,
        phone: recipientPhone ?? '',
        email: recipientEmail ?? '',
      },
      parcels: [parcel],
    };

    if (pudoPointId) {
      shipmentBody['delivery_pickup_point_id']       = pudoPointId;
      shipmentBody['delivery_pickup_point_provider'] = 'tcg-locker';
    } else {
      shipmentBody['delivery_address'] = deliveryAddress;
    }

    const cgRes = await fetch('https://api.shiplogic.com/shipments', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify(shipmentBody),
    });

    const data = await cgRes.json();

    if (!cgRes.ok) {
      console.error('Shiplogic error', cgRes.status, JSON.stringify(data));
      return new Response(JSON.stringify({ error: data?.message ?? 'Shiplogic error', details: data }), {
        status: cgRes.status, headers: { ...CORS, 'Content-Type': 'application/json' },
      });
    }

    // Extract waybill & tracking
    const waybillNumber  = data.shipment_reference ?? data.waybill ?? data.id ?? null;
    const trackingNumber = data.tracking_reference ?? waybillNumber;

    return new Response(
      JSON.stringify({ waybillNumber, trackingNumber, raw: data }),
      { status: 200, headers: { ...CORS, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('courierguy-waybill error', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
});
