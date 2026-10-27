# Utilizzo dell'AI nella challenge

## Principi di governance adottati
- Ogni output dell'AI è trattato come proposta, non come soluzione: viene letto, compreso e verificato prima di entrare nel repository.
- Nessun secret, token o dato sensibile viene inserito nei prompt; nomi host e domini interni vengono oscurati prima di condividere file di configurazione.
- Nessun comando distruttivo o con sudo viene eseguito senza averne compreso l'effetto.
- Versioni di tool, immagini ed estensioni vengono verificate su fonti ufficiali (release notes, documentazione upstream, marketplace), non accettate dalla memoria del modello.
- Manifest e script vengono validati (lint, dry-run, esecuzione su cluster di test) prima del commit.
- Le istruzioni operative devono usare percorsi assoluti e comandi che creano i file direttamente, per evitare ambiguità sul punto in cui vanno creati.

## Registro

### #1 - Setup ambiente locale (Step 1)
- **Strumento:** Claude (chat)
- **Problema:** definire il set minimo di tool e la configurazione del cluster locale.
- **Approccio/prompt:** descrizione della macchina (Ubuntu 22.04, risorse, versioni già installate) e richiesta di un setup minimale e riproducibile.
- **Output accettato:** scelta di kind multi-nodo, script di bootstrap idempotente con smoke test, esposizione solo su 127.0.0.1.
- **Output corretto/scartato:**
  - kind v0.23 (già installato) avrebbe creato un cluster 1.30, fuori dal version skew supportato con kubectl 1.35 → aggiornato a kind v0.33 con immagine 1.35.8 fissata per digest.
  - ingress-nginx, scelta "di default" per kind, è stato scartato: progetto ritirato a marzo 2026 (verificato sul blog ufficiale kubernetes.io) → sostituito con Traefik.
- **Verifiche effettuate:** release notes di kind su GitHub, annuncio ufficiale di ritiro di ingress-nginx, esecuzione dello script con smoke test end-to-end.
- **Valore prodotto:** evitati un'incompatibilità di versione e l'adozione di un componente senza più patch di sicurezza; setup ricreabile con un solo comando.
- **Limiti riscontrati:** <da compilare con eventuali problemi incontrati in esecuzione>

### #2 - Isolamento ambiente personale/lavoro (Step 1)
- **Strumento:** Claude (chat)
- **Problema:** evitare commit con identità aziendale, push con la chiave sbagliata e comandi kubectl/helm sul cluster sbagliato su una workstation condivisa con il lavoro.
- **Approccio/prompt:** richiesta di separazione degli ambienti; in un secondo momento fornito il .bashrc reale per verificare le configurazioni in uso.
- **Output accettato:** identità Git condizionale per directory (includeIf), alias SSH con IdentitiesOnly, kubeconfig dedicato, guardia sul context nello script di bootstrap, blocco di override condizionale in fondo al .bashrc.
- **Output corretto/scartato:** la prima proposta (KUBECONFIG impostato da VS Code) era plausibile ma non funzionante: il .bashrc ricostruisce KUBECONFIG a ogni shell e lo avrebbe sovrascritto. Anche la pulizia dei context puntava al file sbagliato (con KUBECONFIG multi-file, kind scrive nel primo file della lista). Entrambi corretti dopo l'analisi del .bashrc.
- **Verifiche effettuate:** confronto di variabili e context tra terminale VS Code e Terminator, verifica dell'identità Git dentro e fuori ~/personal, ssh -T sull'alias personale.
- **Valore prodotto:** eliminato il rischio di operare su cluster aziendali dal progetto personale e viceversa.
- **Lezione:** un suggerimento dell'AI va validato nel contesto reale di esecuzione; fornire il contesto (oscurando i dati interni) ha fatto emergere un errore non visibile in astratto.

### #3 - Profilo VS Code dedicato e lanciatore (Step 1)
- **Strumento:** Claude (chat)
- **Problema:** aprire il progetto in un editor separato da quello di lavoro (estensioni, kubeconfig dell'estensione Kubernetes, indicatori visivi) con un avvio a un clic che non erediti l'ambiente di lavoro.
- **Approccio/prompt:** richiesta delle estensioni minime e di un'icona per avviare VS Code con il profilo dedicato.
- **Output accettato:** unico script idempotente (fuori dal repository) che crea il profilo "Personal", installa le estensioni solo in quel profilo, ne scrive le impostazioni (kubeconfig dell'estensione Kubernetes, titolo finestra [PERSONAL], barra di stato viola) e crea il lanciatore nel menu, sulla Scrivania e nella dock.
- **Output corretto/scartato:**
  - Le prime istruzioni usavano percorsi relativi e rimandavano a file "da creare" in passaggi precedenti: diversi file non sono stati creati. Segnalato dall'utente → adottati percorsi assoluti e comandi che creano i file direttamente.
  - L'estensione "Docker" di Microsoft è stata sostituita da "Container Tools" (verificato su documentazione e marketplace ufficiali).
  - Non affidabile l'ipotesi che `code --install-extension --profile` crei il profilo se assente → il profilo viene creato aprendo VS Code una volta, poi lo script prosegue.
  - Scartato l'avvio di VS Code da Terminator: la prima istanza eredita le variabili d'ambiente del processo padre (KUBECONFIG e VAULT_ADDR di lavoro).
- **Verifiche effettuate:** avvio dall'icona, titolo [PERSONAL] e barra di stato viola, estensioni presenti solo nel profilo Personal, KUBECONFIG corretto nel terminale integrato, profilo di lavoro invariato.
- **Valore prodotto:** separazione visiva e funzionale tra i due contesti con un avvio a un clic; configurazione ricreabile rilanciando lo script.
- **Limiti riscontrati:** lo script legge la posizione del profilo da storage.json, file interno di VS Code non garantito stabile tra versioni (presente un fallback con modifica manuale); se Settings Sync è attivo con un account di lavoro, anche il profilo Personal verrebbe sincronizzato.

### #4 - Troubleshooting installazione Traefik: helm --wait in timeout (Step 1)
- **Strumento:** Claude (chat)
- **Sintomo:** `helm upgrade --install --wait --atomic` falliva con "context deadline exceeded"; la release veniva disinstallata automaticamente. Negli eventi compariva "Readiness probe failed: connection refused".
- **Analisi:**
  1. Il primo indizio (readiness probe) suggeriva un malfunzionamento di Traefik. Leggendo la sequenza temporale degli eventi è emerso che l'immagine era presente, il container era partito senza riavvii e la probe falliva solo un secondo dopo "Killing", cioè durante lo spegnimento provocato da --atomic: il pod era sano.
  2. Ipotesi: `helm --wait` attende anche l'IP esterno dei Service LoadBalancer, che su kind non viene mai assegnato.
  3. Verifica: installazione senza --wait/--atomic per conservare le risorse; Service risultato LoadBalancer con EXTERNAL-IP <pending>; `helm show values` sulla versione 42.1.3 ha mostrato che il tipo si imposta con `service.spec.type`.
- **Causa:** values scritti per una versione precedente del chart. La chiave `service.type` è ignorata senza errori nel chart 42.x. Nella stessa revisione erano cambiate anche le chiavi dei log (v41: logs.general → log, logs.access → accessLog).
- **Correzione:** `service.spec.type: NodePort`, chiavi dei log aggiornate, verifica del render con `helm template` prima di applicare.
- **Cosa ho scartato:** l'ipotesi di problemi di pull dell'immagine (smentita dall'evento "already present on machine") e interventi sulla readiness probe (il pod era sano).
- **Valore prodotto:** la diagnosi è partita dalle evidenze (eventi, stato delle risorse, values effettivi del chart) invece di modificare configurazioni a tentativi.
- **Lezioni operative:** usare `--atomic` solo quando l'installazione è già validata, perché in diagnosi cancella le prove; verificare sempre i manifest generati (`helm template`, `helm get manifest`) e non solo i values; ricontrollare i values a ogni cambio di versione maggiore di un chart.

### #5 - Analisi iniziale dell'applicazione (Step 2)
- **Strumento:** Claude (chat)
- **Problema:** comprendere rapidamente servizi, linguaggi, dipendenze, protocolli, packaging e osservabilità di Online Boutique.
- **Approccio:** l'AI ha fornito una mappa preliminare dei servizi basata sulla conoscenza generale del progetto, dichiarata come ipotesi; la mappa è stata poi verificata con comandi sul repository (Dockerfile, demo.proto, variabili *_ADDR, porte e probe nei manifest, router HTTP del frontend, struttura del chart Helm e dei componenti Kustomize).
- **Confermato dalla verifica:** ruoli e linguaggi dei servizi, gRPC interno e HTTP verso il frontend, Redis come unico componente stateful.
- **Emerso solo dalla verifica sul codice:**
  - base upstream v0.10.7, runtime aggiornati (Go 1.27, .NET 10, Java 25, Node 24, Python 3.14), immagini base fissate per digest, tranne Redis (`redis:alpine`, tag mobile);
  - shoppingassistantservice presente, in HTTP e non in gRPC; il frontend richiede comunque la variabile SHOPPING_ASSISTANT_SERVICE_ADDR (mustMapEnv) e va in crash se manca, anche con l'assistente disattivato;
  - health check gRPC nativi del kubelet su tutti i servizi gRPC; il frontend usa /_healthz per liveness e readiness senza verificare i servizi a valle;
  - porte Service diverse da quelle del container (emailservice 5000→8080, frontend 80→8080);
  - Redis definito nel manifest di cartservice, con dati in emptyDir (persi alla ricreazione del pod);
  - frontend esposto anche con un Service LoadBalancer, inutilizzabile su kind;
  - log JSON nei servizi Go; nessuna metrica Prometheus esposta dai servizi; tracing non attivo nei manifest base;
  - Helm chart di upstream senza Ingress e senza separazione degli ambienti; workflow CI di upstream orientati a GKE.
- **Decisioni derivate:** chart copiato ed esteso in platform/charts; Ingress al posto del LoadBalancer; esclusione di shoppingassistant, Istio, Terraform e Cloud Build; loadgenerator solo in dev; metrica applicativa da costruire.
- **Valore prodotto:** analisi completata in tempi ridotti partendo da un'ipotesi strutturata, con ogni affermazione del documento di architettura riconducibile a un file del repository; individuato un failure scenario realistico (variabile d'ambiente obbligatoria) dalla lettura del codice.
- **Limiti:** la mappa preliminare non prevedeva i dettagli di versione, le particolarità del deploy (probe native, porte, posizione e persistenza di Redis) né la dipendenza obbligatoria del frontend dalla variabile dell'assistente: senza verifica, il documento avrebbe contenuto imprecisioni plausibili.

### #6 - Documento di architettura (Step 3)
- **Strumento:** Claude (chat)
- **Problema:** produrre il documento di architettura con diagrammi coerenti con l'applicazione reale e con le decisioni prese.
- **Approccio:** bozza generata dall'AI a partire dall'analisi dello step 2, con i punti incerti marcati "da verificare"; verifiche mirate sul codice prima della versione finale.
- **Output corretto dopo la verifica:**
  - l'ipotesi "metriche RED su tutti i servizi" era sovrastimata: il tracing è supportato da 7 servizi su 11 (cart, shipping e ad non sono strumentati);
  - il Collector di upstream esporta solo verso Google Cloud e dipende dal metadata server di GCP: non riutilizzabile su kind, sostituito da una configurazione propria;
  - l'invio dell'email di conferma non è bloccante per l'ordine (warning nel log): introdotta la distinzione tra dipendenze bloccanti e non bloccanti.
- **Verifiche effettuate:** grep di ENABLE_TRACING nei sorgenti, lettura del template del Collector e dei values del chart, lettura della gestione degli errori in checkoutservice; anteprima dei diagrammi Mermaid in VS Code.
- **Valore prodotto:** documento allineato al codice reale; individuato un secondo failure scenario (degrado controllato con emailservice non disponibile).