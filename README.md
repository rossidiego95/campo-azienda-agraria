# Campo — Gestione azienda agraria

App web in italiano per organizzare appezzamenti, piano colturale, operazioni in campo, magazzino, prodotti fitosanitari, quaderno di campagna, registro di cantina, vendite, prodotti aziendali, attrezzature, richieste materiali e attività del personale.

## Accesso con username

Gli account invitati accedono con **username e password**, senza usare un indirizzo email. Suggerisci lo username nel formato `nome.cognome`. L’account iniziale del titolare mantiene come username la parte prima della @ dell’indirizzo usato quando è stato creato l’account (in minuscolo).

Un titolare o referente apre **Account e ruoli**, sceglie il tipo di account e inserisce l’email a cui spedire l’invito. Si apre il programma di posta con un link personale; se non inserisci l’email, il link viene copiato e puoi inviarlo tu. Il collega usa il link una sola volta, sceglie username e password, e riceve automaticamente il ruolo dell’invito. Gli inviti scadono dopo 14 giorni. Gli indirizzi destinatari non sono salvati nel database.

Ruoli disponibili:

- **Educatrice / docente di sostegno:** invia richieste materiali, controlla l’esito e scarica la ricevuta PDF quando approvata.
- **Docente ITP:** vede le cose da fare e registra le attività svolte.
- **Referente di sede:** gestisce tutte le sezioni, come il titolare.

I permessi sono applicati anche nel database, oltre che nei menu dell’app.

## Database e configurazione

I dati sono archiviati nel progetto Supabase collegato all’app. La chiave publishable in `supabase-config.js` è pubblica e non è una chiave segreta. Non pubblicare mai la chiave service-role.

Per aggiornare il database già esistente, esegui una sola volta `database/migrations/003_staff_access_requests_tasks.sql` nel SQL Editor Supabase, dopo le migrazioni 001 e 002. Questa migrazione aggiunge i ruoli e le regole di accesso, le richieste, le attività e gli inviti. Non cancellare o ricreare le tabelle esistenti.

Il sorgente della funzione Edge `staff-auth` è `staff-auth.ts` nella cartella principale. Nel pannello Supabase crea una Edge Function con questo nome, incolla il file come `index.ts`, disattiva “Verify JWT” (è una schermata di accesso pubblica) e distribuiscila. Non inserire chiavi segrete nel file o nell’app browser: la funzione usa le variabili server Supabase.

Il sorgente `notify-material-request.ts` invia l’avviso alla mail del titolare e, se il servizio rifiuta l’invio, prova l’indirizzo alternativo. Per abilitarla, crea la funzione omonima nel pannello Supabase e imposta nei Secrets `RESEND_API_KEY` e `RESEND_FROM_EMAIL` con un mittente autorizzato dal servizio email. Senza queste due impostazioni la richiesta rimane salvata e visibile nell’app, ma non parte l’email. Non condividere le chiavi segrete in chat o nel repository.

## Dati ed esportazioni

Il tasto **Esporta archivio** scarica una copia JSON dei dati; i registri e le vendite hanno anche esportazione CSV. Conserva periodicamente copie esportate fuori dal progetto.

## Sezioni già presenti

La sezione Vendite registra cliente, prodotto, quantità, importi e incasso. Prodotti aziendali collega lotti raccolti, appezzamenti e trattamenti del quaderno. Attrezzature registra gli interventi e scala dal magazzino i materiali usati.

## Ambito

Le registrazioni sono strumenti di gestione e non sostituiscono i registri ufficiali né verificano gli obblighi normativi.
