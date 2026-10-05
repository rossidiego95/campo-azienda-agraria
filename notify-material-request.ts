import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
const recipients = ['diego.rossi@vergani.istruzioneer.it', 'rossidiego95@gmail.com'];

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Metodo non consentito.' }, 405);
  const authorization = req.headers.get('Authorization');
  if (!authorization) return json({ error: 'Accesso non autorizzato.' }, 401);
  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } });
  const { data: auth, error: authError } = await userClient.auth.getUser();
  if (authError || !auth.user) return json({ error: 'Accesso non autorizzato.' }, 401);
  const { request_id: requestId } = await req.json();
  if (typeof requestId !== 'string') return json({ error: 'Richiesta non valida.' }, 400);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: member } = await admin.from('company_members').select('role').eq('user_id', auth.user.id).limit(1).maybeSingle();
  if (!member || member.role !== 'richiedente') return json({ error: 'Operazione non autorizzata.' }, 403);
  const { data: item, error } = await userClient.from('material_requests').select('product_type,quantity,unit,reason,requester_name,created_at').eq('id', requestId).eq('requester_id', auth.user.id).single();
  if (error || !item) return json({ error: 'Richiesta non trovata.' }, 404);
  const apiKey = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('RESEND_FROM_EMAIL');
  if (!apiKey || !from) return json({ sent: false, setup_required: true });
  const message = `Nuova richiesta di materiale nell’app Azienda Agraria di Ostellato\n\nRichiedente: ${item.requester_name}\nProdotto: ${item.product_type}\nQuantità: ${item.quantity} ${item.unit}\nMotivazione: ${item.reason}\nData: ${new Date(item.created_at).toLocaleString('it-IT')}`;
  for (const to of recipients) {
    const response = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ from, to, subject: 'Nuova richiesta di materiale — Azienda Agraria di Ostellato', text: message }) });
    if (response.ok) return json({ sent: true });
  }
  return json({ sent: false, error: 'Impossibile recapitare la notifica email.' }, 502);
});
