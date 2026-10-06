import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Metodo non consentito.' }, 405);
  const url = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  if (!url || !serviceKey || !anonKey) return json({ error: 'Funzione non configurata dal gestore.' }, 500);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const { action, email: rawEmail, password, invite_code: inviteCode } = await req.json();
    const email = String(rawEmail || '').trim().toLowerCase();
    if (action === 'register' && !emailPattern.test(email)) return json({ error: 'Inserisci un indirizzo email valido.' }, 400);
    if (action === 'login' && !email && !String(rawEmail || '').trim()) return json({ error: 'Inserisci la tua email.' }, 400);
    if (typeof password !== 'string' || password.length < 8) return json({ error: 'La password deve contenere almeno 8 caratteri.' }, 400);
    let authEmail: string;
    if (action === 'register') {
      if (typeof inviteCode !== 'string' || inviteCode.length < 32) return json({ error: 'Il codice invito non è valido.' }, 400);
      const { data: invite, error: inviteError } = await admin.from('company_invites').select('id,expires_at').eq('invite_code', inviteCode).maybeSingle();
      if (inviteError || !invite || new Date(invite.expires_at).getTime() <= Date.now()) return json({ error: 'Invito non valido o scaduto. Chiedi un nuovo invito al referente.' }, 400);
      const { data: duplicate, error: duplicateError } = await admin.from('company_members').select('id').eq('username', email).maybeSingle();
      if (duplicateError) throw duplicateError;
      if (duplicate) return json({ error: 'Questa email è già associata a un account aziendale.' }, 409);
      authEmail = email;
      const { data: created, error: createError } = await admin.auth.admin.createUser({ email: authEmail, password, email_confirm: true, user_metadata: { username: email, invite_code: inviteCode } });
      if (createError || !created.user) return json({ error: createError?.message || 'Non è stato possibile creare l’account.' }, 400);
      const { data: member, error: memberError } = await admin.from('company_members').select('id').eq('user_id', created.user.id).maybeSingle();
      if (memberError || !member) {
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: 'Invito già usato o scaduto. Chiedi un nuovo invito al referente.' }, 400);
      }
    } else if (action === 'login') {
      if (email.includes('@')) authEmail = email;
      else {
        const { data: member, error: memberError } = await admin.from('company_members').select('user_id').eq('username', email).limit(1).maybeSingle();
        if (memberError || !member) return json({ error: 'Email, username o password non corretti.' }, 401);
        const { data: userData, error: userError } = await admin.auth.admin.getUserById(member.user_id);
        if (userError || !userData.user?.email) return json({ error: 'Email, username o password non corretti.' }, 401);
        authEmail = userData.user.email;
      }
    } else return json({ error: 'Richiesta non valida.' }, 400);
    const publicClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: signed, error: signError } = await publicClient.auth.signInWithPassword({ email: authEmail, password });
    if (signError || !signed.session) return json({ error: 'Email o password non corretti.' }, 401);
    return json({ session: signed.session });
  } catch (error) {
    console.error('staff-auth failure', error);
    return json({ error: 'Non è stato possibile completare la richiesta.' }, 500);
  }
});
