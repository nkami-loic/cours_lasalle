# Activité 05 : Entrepôt Analytique, Optimisation & Data Lake (FastMarket)

**Objectif :** Transformer la zone CDC brute issue de Datastream en un entrepôt analytique performant (*One Big Table* partitionnée et clusterisée), comprendre `APPEND` face au `MERGE` de Datastream, puis construire un Data Lake sur Cloud Storage (JSON $\rightarrow$ Parquet) interrogeable depuis BigQuery.

* Pensez à noter vos réponses et captures/chiffres observés dans votre compte-rendu.

> **Important :** Dans toutes les requêtes SQL ci-dessous :
> * Votre dataset source CDC (issu du Jour 2) s'appelle **`fastmarket_db_public_NOM`**.
> * Votre nouveau dataset analytique s'appellera **`fastmarket_analytics_NOM`**.
> * Remplacez **`NOM`** par votre nom (ex. `fastmarket_db_public_dupont` et `fastmarket_analytics_dupont`) dans toutes les requêtes.
> * Vérifiez que votre nouveau dataset et votre bucket Cloud Storage sont tous les deux dans la région **`europe-west1`**.

---

## Préparation : Créer le dataset analytique

1. Ouvrez la console **BigQuery** (**BigQuery Studio**).
2. À côté du nom de votre projet dans l'explorateur de gauche, cliquez sur les trois points `⋮` $\rightarrow$ **Créer un ensemble de données** (*Create dataset*).
3. Configurez :
   * **ID de l'ensemble de données :** `fastmarket_analytics_NOM`
   * **Type d'emplacement :** identique à votre dataset source `fastmarket_db_public_NOM` (**`europe-west1`**)
4. Cliquez sur **Créer un ensemble de données**.

---

## Partie 1 : De la 3NF à la One Big Table (OBT) & Optimisation

Au Jour 1, vos requêtes analytiques sur > 90 jours obligeaient PostgreSQL à joindre `order_items`, `orders`, `products` et `users`. Nous allons dénormaliser ces tables dans BigQuery.

### Étape 1.1 : Créer une OBT brute (sans optimisation)
Dans l'éditeur de requêtes BigQuery Studio, exécutez une requête `CREATE OR REPLACE TABLE` pour créer `fastmarket_analytics_VOTRE_NOM.obt_order_items_raw` en joignant vos 4 tables CDC :
* Colonnes à inclure : `order_item_id`, `order_id`, `order_status`, `order_created_at`, `order_updated_at`, `quantity`, `item_unit_price`, `line_total_amount` (`quantity * unit_price`), `product_id`, `product_sku`, `product_title`, `product_category`, `user_id`, `customer_city`, `customer_country`.
* **Contrainte de confidentialité :** N'incluez **aucune** donnée personnelle sensible (`email`, `password_hash`, `phone_number`, `address_line1`, `shipping_address`, `ip_address`).

> *Indice pour les jointures :* Partez de `fastmarket_db_public_NOM.order_items AS oi`, puis joignez `fastmarket_db_public_NOM.orders AS o` (`oi.order_id = o.id`), `fastmarket_db_public_NOM.products AS p` (`oi.product_id = p.id`) et `fastmarket_db_public_NOM.users AS u` (`o.user_id = u.id`).

> Ce processus s'appelle la **Dénormalisation**.

### Étape 1.2 : Créer l'OBT optimisée (Partitionnement & Clustering)
Créez une seconde table `fastmarket_analytics_VOTRE_NOM.obt_order_items_opt` avec exactement les mêmes données, mais en ajoutant :
* Un **partitionnement** par jour sur `DATE(order_created_at)`.
* Un **clustering** sur `(order_status, product_category, customer_country)`.

### Étape 1.3 : Benchmark & Questions de réflexion

Complétez la requête SQL ci-dessous pour calculer le chiffre d'affaires par catégorie de produit sur les **90 derniers jours** pour les commandes payées (`PAID`).

Exécutez-la (ou observez simplement l'estimation du validateur) d'abord sur `obt_order_items_raw`, puis sur `obt_order_items_opt` :

```sql
SELECT
  product_category,
  _____(line_total_amount) AS revenue
FROM `fastmarket_analytics_VOTRE_NOM._____` -- Remplacez par obt_order_items_raw puis obt_order_items_opt
WHERE _____(order_created_at) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND CURRENT_DATE()
  AND order_status = '_____'
_____ _____ product_category
ORDER BY revenue DESC;
```

**Questions à répondre :**
1. En regardant le message vert en haut à droite de l'éditeur BigQuery (*« Cette requête traitera X ... lors de son exécution »*) **avant** d'exécuter la requête, quelle différence observez-vous entre `_raw` et `_opt` ? Pourquoi ? *(Astuce : si vos données de test datent toutes d'aujourd'hui, testez également avec une plage passée sans données comme `BETWEEN DATE('2025-01-01') AND DATE('2025-04-01')` pour voir le Partition Pruning à `0 o`).*
2. Pourquoi avons-nous choisi `order_created_at` pour la partition et non `order_status` ?
3. Pourquoi avoir exclu `email` et `password_hash` dès la création de l'OBT ?

---
_INFORMEZ LE FORMATEUR QUE VOUS AVEZ TERMINÉ_

---

## Partie 2 : Stratégie d'ingestion — `APPEND` face au `MERGE` de Datastream

**Objectif :** Votre pipeline Datastream a répliqué `public.orders` en mode **`MERGE`** (fusion en français : idempotent, toujours à jour, mais qui écrase l'ancien état). Dans cette partie, vous allez tester la stratégie inverse — **`APPEND` (`INSERT INTO`)** — pour conserver un historique, et observer ses limites en cas de relance d'un job.

### Étape 2.1 : Tester le pattern `APPEND` sur une nouvelle table de dimension

1. **Constat sur votre pipeline CDC existant (mode `MERGE`) :**
   Exécutez la requête suivante pour observer vos commandes répliquées par Datastream :
   ```sql
   SELECT id, status, created_at, updated_at
   FROM `fastmarket_db_public_NOM.orders`
   LIMIT 5;
   ```
   *(Comme Datastream fonctionne en `MERGE`, seul le **dernier statut** de chaque commande est visible : impossible de savoir à quelle heure une commande est passée de `PENDING` à `PAID` puis `SHIPPED`).*

2. **Création et alimentation d'une nouvelle table de dimension historique (`APPEND`) :**
   Pour conserver cet historique sans toucher à la source, vous allez **créer une nouvelle table de dimension** (`fastmarket_analytics_VOTRE_NOM.dim_order_status_history`) dédiée au suivi des changements de statut, puis y insérer en mode **`APPEND`** 3 événements retraçant la vie de la commande `1`. Exécutez les deux requêtes suivantes :
   ```sql
   -- 1) Création de la nouvelle table de dimension historique
   CREATE TABLE IF NOT EXISTS `fastmarket_analytics_VOTRE_NOM.dim_order_status_history` (
     event_id STRING,
     order_id INT64,
     new_status STRING,
     changed_at TIMESTAMP
   )
   PARTITION BY DATE(changed_at);

   -- 2) Alimentation en mode APPEND (ajout de 3 événements)
   INSERT INTO `fastmarket_analytics_VOTRE_NOM.dim_order_status_history` (event_id, order_id, new_status, changed_at)
   VALUES
     ('evt_1001', 1, 'PENDING', TIMESTAMP('2026-11-24 10:00:00+00')),
     ('evt_1002', 1, 'PAID',    TIMESTAMP('2026-11-24 10:05:00+00')),
     ('evt_1003', 1, 'SHIPPED', TIMESTAMP('2026-11-25 08:30:00+00'));
   ```

3. **Simulation d'une panne et relance du job :**
   Imaginez que votre pipeline batch plante juste après l'écriture et soit **relancé automatiquement**. Exécutez **une deuxième fois uniquement la requête `INSERT INTO`**, puis vérifiez le contenu de la table :
   ```sql
   SELECT * FROM `fastmarket_analytics_VOTRE_NOM.dim_order_status_history` ORDER BY changed_at;
   ```

**Questions à répondre :**
4. Qu'avez-vous observé après la 2ᵉ exécution de l'`INSERT INTO` sur `dim_order_status_history` ? En comparant avec le mode `MERGE` de Datastream sur `public.orders`, lequel est **idempotent** (ne crée pas de doublon si rejoué) et lequel conserve l'historique ?
5. Pour les événements de clics/paniers (`cart_events`) ou les tentatives de paiements (`payments`) de FastMarket, quel mode choisiriez-vous (`APPEND` ou `MERGE`) ? Justifiez.

---
_INFORMEZ LE FORMATEUR QUE VOUS AVEZ TERMINÉ_

---

## Partie 3 : Data Lake sur Cloud Storage (JSON Bronze $\rightarrow$ Parquet Silver)

Les tables PostgreSQL ne capturent pas la navigation ni les **paniers abandonnés**. L'application FastMarket dépose donc les événements bruts de navigation au format **NDJSON** dans un bucket Cloud Storage partagé (zone **Bronze**) : **`gs://fastmarket-website-data`**.

### Étape 3.1 : Observer la zone Bronze dans Cloud Storage (UI Web)
1. Dans la console GCP, ouvrez **Cloud Storage** $\rightarrow$ accédez au bucket partagé `fastmarket-website-data` (ou explorez son arborescence si l'accès liste vous est ouvert).
2. Observez l'organisation des dossiers par date (`cart_events/dt=2026-11-22/`, `dt=2026-11-23/`, etc.), le découpage en plusieurs micro-fichiers `.ndjson` et leur taille totale.

> *Note (facultatif) : Avec cette commande dans Google Cloud Shell, vous pouvez avoir un aperçu des 5 premières lignes d'un fichier JSON :*
> ```bash
> gcloud storage cat gs://fastmarket-website-data/cart_events/dt=2026-11-25/events_part_001.ndjson | head -n 5
> ```

### Étape 3.2 : Créer votre bucket personnel (Zone Silver) dans Cloud Storage (UI Web)
Vous allez maintenant créer **votre propre bucket** pour y stocker la version nettoyée et optimisée (zone **Silver**).
1. Dans **Cloud Storage** $\rightarrow$ **Buckets**, cliquez sur **Créer** (*Create*) :
   * **Nom :** `fastmarket-datalake-<vos-initiales>-<nombre>` (doit être unique mondialement).
   * **Type d'emplacement :** choisissez impérativement la **même région** que votre dataset `fastmarket_analytics_VOTRE_NOM` et que `gs://fastmarket-website-data` (**`europe-west1`**).
   * Conservez les autres options par défaut et cliquez sur **Créer**.

### Étape 3.3 : Requêter la zone Bronze (JSON) depuis BigQuery
1. Dans **BigQuery Studio**, créez une **Table Externe** nommée `fastmarket_analytics_VOTRE_NOM.ext_cart_events_bronze_json` pointant vers les fichiers JSON du bucket source :
   * Chemin URI : `gs://fastmarket-website-data/cart_events/*/*.ndjson` *(le `*/*` permet de lire tous les dossiers `dt=...` et tous les fichiers `.ndjson`)*.
   * Format : `NEWLINE_DELIMITED_JSON` (avec détection automatique du schéma).
2. Exécutez `SELECT * FROM fastmarket_analytics_VOTRE_NOM.ext_cart_events_bronze_json LIMIT 20;` puis inspectez l'onglet **Schéma** de la table : observez la structure des colonnes `client` et `marketing` (type `RECORD`) et `event_timestamp`.

### Étape 3.4 : Transformer en Parquet aplati (Zone Silver) sans Python
1. Exécutez la requête suivante dans BigQuery Studio (pensez à remplacer `<VOTRE-BUCKET>` par le nom de votre bucket Silver et `VOTRE_NOM` par votre nom) :

   ```sql
   EXPORT DATA OPTIONS (
     uri = 'gs://<VOTRE-BUCKET>/silver/cart_events/*.parquet',
     format = 'PARQUET',
     compression = 'SNAPPY',
     overwrite = true
   ) AS
   SELECT
     event_id,
     session_id,
     CAST(user_id AS INT64) AS user_id,
     CAST(product_id AS INT64) AS product_id,
     event_type,
     CAST(quantity AS INT64) AS quantity,
     CAST(unit_price_seen AS NUMERIC) AS unit_price_seen,
     -- Aplatissement des sous-objets JSON (RECORD -> colonnes simples)
     client.device AS device,
     client.os AS os,
     client.browser AS browser,
     client.country AS country,
     marketing.utm_source AS utm_source,
     marketing.utm_campaign AS utm_campaign,
     CAST(event_timestamp AS TIMESTAMP) AS event_timestamp
   FROM `fastmarket_analytics_VOTRE_NOM.ext_cart_events_bronze_json`;
   ```
   *(Note : l'option `overwrite = true` évite une erreur si la requête est relancée une deuxième fois sur le même dossier GCS).*

2. Rendez-vous dans **Cloud Storage** dans `gs://<VOTRE-BUCKET>/silver/cart_events/` pour vérifier que le fichier `.parquet` a bien été créé et notez sa taille.
3. Dans **BigQuery Studio**, créez une seconde **Table Externe** nommée `fastmarket_analytics_VOTRE_NOM.ext_cart_events_silver_parquet` pointant vers `gs://<VOTRE-BUCKET>/silver/cart_events/*.parquet` (format `PARQUET`).

### Étape 3.5 : Requête Lakehouse (Croiser Data Lake Silver $\leftrightarrow$ Data Warehouse)

Exécutez la requête suivante en l'adaptant à votre dataset (`VOTRE_NOM`) :

```sql
SELECT
  p.id AS product_id,
  p.title,
  p.category,
  COUNT(e.event_id) AS nb_add_to_cart,
  SUM(e.quantity) AS total_qty_added,
  COUNTIF(e.device = 'mobile') AS nb_mobile_add_to_cart
FROM `fastmarket_analytics_VOTRE_NOM.ext_cart_events_silver_parquet` AS e
INNER JOIN `fastmarket_db_public_NOM.products` AS p
  ON e.product_id = p.id
WHERE e.event_type = 'ADD_TO_CART'
GROUP BY p.id, p.title, p.category
ORDER BY total_qty_added DESC;
```

**Questions à répondre :**
6. Comparez l'onglet **Schéma** de `ext_cart_events_bronze_json` et celui de `ext_cart_events_silver_parquet` dans BigQuery : quels avantages concrets apporte le passage en zone Silver (types comme `FLOAT` $\rightarrow$ `NUMERIC`, et aplatissement des objets `RECORD` `client`/`marketing`) ?
7. Exécutez `SELECT event_type, COUNT(*) FROM ... GROUP BY 1` successivement sur la table Bronze (JSON) puis sur la table Silver (Parquet), et comparez les **Octets traités** (*Bytes processed* dans l'onglet *Informations sur la tâche*). Si le Data Lake contenait **100 Go** de JSON, pourquoi la version Parquet coûterait-elle beaucoup moins cher et irait-elle plus vite ?
8. À l'étape 3.3, vous avez pu observer que `user_id` vaut parfois `NULL`. 
Si vous enrichissiez la requête de l'étape 3.5 en joignant également la table `fastmarket_db_public_NOM.users` (sur `user_id`), quel type de jointure (`INNER JOIN` ou `LEFT JOIN`) faudrait-il choisir pour ne pas perdre les ajouts au panier des visiteurs anonymes ?