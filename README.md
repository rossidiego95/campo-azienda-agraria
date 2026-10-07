# Campo — Gestione azienda agraria

App web in italiano per organizzare appezzamenti, piano colturale, operazioni in campo, magazzino, prodotti fitosanitari, quaderno di campagna, registro di cantina, vendite, prodotti aziendali, attrezzature, richieste materiali e attività del personale.

## Accesso con email

Gli account invitati accedono con **email e password**. Il titolare o un referente apre **Account e ruoli**, crea un invito e condivide il link personale con il collega. Chi riceve il link sceglie l’email e la password del proprio account. Gli inviti scadono dopo 14 giorni.

I ruoli disponibili sono:

- **Educatrice / docente di sostegno:** invia richieste materiali, controlla l’esito, e può aggiungere attività da svolgere e registrare quelle svolte nella pagina **Cose da fare**.
- **Docente ITP:** consulta le attività, ne può aggiungere di nuove e registra quelle svolte nella stessa pagina.
- **Referente di sede:** gestisce tutte le sezioni, come il titolare.

Il titolare e i referenti vedono le attività inserite da tutto il personale. I permessi sono applicati anche nel database, oltre che nei menu dell’app.

## Database e configurazione

I dati sono archiviati nel progetto Supabase collegato all’app. La chiave publishable in `supabase-config.js` è pubblica e non è una chiave segreta. Non pubblicare mai la chiave service-role.

Per aggiornare un database esistente, esegui nel SQL Editor Supabase le migrazioni numerate non ancora applicate, in ordine. La migrazione `005_staff_tasks.sql` estende l’accesso alle attività per ITP ed educatori/docenti di sostegno; `004_fix_invite_code_generation.sql` corregge la generazione dei link d’invito. Non cancellare o ricreare le tabelle esistenti.

Il sorgente della funzione Edge `staff-auth` è `staff-auth.ts` nella cartella principale. Nel pannello Supabase crea una Edge Function con questo nome, incolla il file come `index.ts`, disattiva “Verify JWT” (è una schermata di accesso pubblica) e distribuiscila. Non inserire chiavi segrete nel file o nell’app browser: la funzione usa le variabili server Supabase.

Il sorgente `notify-material-request.ts` invia l’avviso alla mail del titolare e, se il servizio rifiuta l’invio, prova l’indirizzo alternativo. Per abilitarla, crea la funzione omonima nel pannello Supabase e imposta nei Secrets `RESEND_API_KEY` e `RESEND_FROM_EMAIL` con un mittente autorizzato dal servizio email. Senza queste due impostazioni la richiesta rimane salvata e visibile nell’app, ma non parte l’email. Non condividere le chiavi segrete in chat o nel repository.

## Dati ed esportazioni

Il tasto **Esporta archivio** scarica una copia JSON dei dati; i registri e le vendite hanno anche esportazione CSV. Conserva periodicamente copie esportate fuori dal progetto.

## Sezioni già presenti

La sezione Vendite registra cliente, prodotto, quantità, importi e incasso. Prodotti aziendali collega lotti raccolti, appezzamenti e trattamenti del quaderno. Attrezzature registra gli interventi e scala dal magazzino i materiali usati.

## Ambito

Le registrazioni sono strumenti di gestione e non sostituiscono i registri ufficiali né verificano gli obblighi normativi.
