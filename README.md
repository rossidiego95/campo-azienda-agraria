# Campo — Gestione azienda agraria

App web in italiano per organizzare appezzamenti, piano colturale, operazioni in campo, magazzino, prodotti fitosanitari, quaderno di campagna, registro di cantina, vendite, prodotti aziendali e attrezzature.

## Avvio e accesso

Apri `index.html` con un browser collegato a Internet. La prima volta accedi con l'indirizzo email e la password dell'utente creato nel progetto Supabase. Le schermate usano il database online; non condividere la password.

Al primo accesso l'app crea una scheda azienda e la campagna 2026/2027. Puoi cambiare il nome dell'azienda e la campagna attiva da **Azienda e campagne**.

## Dati e backup

I dati sono archiviati nel progetto Supabase configurato per questa app. Il file `supabase-schema.sql` contiene lo schema applicato al database e le regole di accesso. Il tasto **Esporta archivio** scarica una copia JSON dei dati della campagna selezionata; i registri hanno anche esportazione CSV.

Supabase Free ha limiti e non offre backup automatici scaricabili: conserva periodicamente copie esportate fuori dal progetto. La chiave publishable usata nel browser non è la chiave segreta; tutte le tabelle sono protette da Row Level Security.

## Vendite

La sezione Vendite registra data, cliente, prodotto, quantità, unità, prezzo unitario, totale calcolato, stato dell'incasso e note. I dati sono filtrati per campagna, esportabili in CSV e inclusi nell'archivio JSON. Per aggiornare un progetto Supabase già esistente, esegui una sola volta `001_add_sales.sql` nel SQL Editor del progetto.

## Prodotti e attrezzature

La sezione **Prodotti aziendali** registra i lotti raccolti, l’appezzamento di origine e le attività/trattamenti del quaderno collegati a quell’appezzamento. Per associare trattamenti futuri, seleziona l’appezzamento quando inserisci una voce nel quaderno di campagna o nel registro fitosanitari. In fase di registrazione puoi anche caricare il prodotto nel magazzino.

La sezione **Attrezzature** conserva il parco macchine e lo storico degli interventi. Nella manutenzione puoi indicare più prodotti/ricambi dal magazzino; l’app registra gli scarichi e rifiuta l’operazione se la giacenza risulta insufficiente.

Per aggiornare un progetto Supabase esistente, esegui una sola volta `002_products_equipment.sql` nel SQL Editor del progetto dopo la migrazione `001_add_sales.sql`.

## Ambito

Le registrazioni dell'app sono strumenti di gestione e non sostituiscono i registri ufficiali né verificano gli obblighi normativi. Prima di usarle in azienda, controlla che i campi e i processi soddisfino le regole applicabili.
