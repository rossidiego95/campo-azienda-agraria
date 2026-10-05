# Archivio dati dell'app Campo

## Come funziona

GitHub conserva il programma. I dati inseriti dall'app sono salvati nel progetto Supabase, per poterli usare anche da un altro dispositivo. Il progetto è stato creato, le tabelle sono state applicate e l'utente per l'accesso è stato aggiunto.

Lo schema [supabase-schema.sql](supabase-schema.sql) include azienda, campagne, appezzamenti, piano colturale, programmazione operazioni e registrazioni per magazzino, fitosanitari, quaderno di campagna e cantina. Le tabelle hanno regole che limitano l'accesso all'utente proprietario autenticato.

## Primo accesso

1. Apri `index.html` con un browser collegato a Internet.
2. Inserisci email e password dell'utente che hai creato in Supabase **Authentication → Users**.
3. Al primo accesso viene creata l'azienda e la campagna 2026/2027.
4. In **Azienda e campagne** puoi modificare il nome dell'azienda e scegliere o aggiungere campagne.
5. Usa **Esporta archivio** per scaricare una copia JSON della campagna. Ogni registro può essere esportato anche in CSV.

La chiave publishable è già configurata nell'app ed è destinata all'uso nel browser. Non usare mai la chiave `secret` o `service_role` nel browser o in GitHub.

## Conservazione e limiti

Supabase Free ha limiti e non offre backup automatici scaricabili: conserva periodicamente le copie esportate fuori dal progetto. Per dettagli aggiornati, consulta la pagina ufficiale [Backup Supabase](https://supabase.com/docs/guides/platform/backups).

Il collegamento al database è predisposto ma deve ancora essere verificato con il primo accesso dall'app. Non inserire ancora dati aziendali importanti finché non hai verificato che accesso, salvataggio e scaricamento funzionino. I registri dell'app non sostituiscono documenti ufficiali e non verificano gli obblighi normativi.
