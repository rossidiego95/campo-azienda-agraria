# Campo — Gestione azienda agraria

App per gestire appezzamenti, piano colturale, operazioni, magazzino, prodotti fitosanitari, quaderno di campagna e registro di cantina.

## Avvio e accesso

Apri `index.html` con un browser collegato a Internet e accedi con l'email e la password dell'utente creato nel progetto Supabase. Al primo accesso l'app crea l'azienda e la campagna 2026/2027. Puoi modificarle da **Azienda e campagne**.

## Archivio e copie dei dati

I dati sono salvati nel database Supabase; le tabelle sono protette da regole di accesso per l'utente proprietario. Puoi scaricare l'archivio della campagna in JSON e ogni singolo registro in CSV. Conserva le copie esportate fuori dal progetto: il piano gratuito ha limiti e non offre backup automatici scaricabili.

La chiave publishable configurata nell'app è pensata per l'uso nel browser; non usare mai la chiave segreta o `service_role`.

## Nota

Questi registri sono strumenti gestionali: non sostituiscono documenti ufficiali e non verificano gli obblighi normativi.
