---
marp: true
theme: gaia
_class: lead
paginate: true
backgroundColor: #eaeaea
color: #1a1a2e
header: "Formation Big Data — Module 2 : Transformation & Modélisation"
footer: "La Salle — Intro Big Data"
style: |
  section {
    font-size: 24px;
    font-family: 'Segoe UI', sans-serif;
  }
  h1 { color: #6a0572; }
  h2 { color: #7b2d8b; border-bottom: 2px solid #9d4edd; padding-bottom: 8px; }
  h3 { color: #9d4edd; }
  code { background: #2d2d44; color: #e0aaff; border-radius: 4px; padding: 2px 6px; }
  pre { background: #2d2d44; border-radius: 8px; }
  strong { color: #6a0572; }
  em { color: #7b2d8b; }
---

# 🔄 Module 2 — Transformation & Modélisation Analytique

### De la donnée brute à l'insight métier

> *"Data is the new oil — but only if you refine it."*

---

## 📌 Ordre du Jour

| # | Thème | Durée |
|---|-------|-------|
| 1 | Pourquoi transformer la donnée ? | 15 min |
| 2 | L'Architecture Medallion (Bronze → Silver → Gold) | 20 min |
| 3 | Transformations SQL & Requêtes Planifiées BigQuery | 25 min |
| 3+ | Qualité des données : déduplication, late data, benchmark | 20 min |
| 4 | Modélisation : Kimball vs Dénormalisation BigQuery | 15 min |
| 5 | Aperçu dbt — l'outil pro *(démo)* | 10 min |
| 6 | *(Bonus)* Deep dive : `STRUCT` & `ARRAY` | 20 min |

---

<!-- _class: lead -->

# Partie 1
## Pourquoi transformer la donnée ?

---

## 🤔 Le problème des données brutes

Les données arrivent rarement prêtes à l'emploi :

- 🔴 **Formats hétérogènes** : JSON imbriqué, CSV mal encodé, timestamps incohérents
- 🔴 **Qualité médiocre** : valeurs nulles, doublons, incohérences entre systèmes
- 🔴 **Sémantique absente** : colonnes nommées `col_1`, `val`, `tmp_flag`...
- 🔴 **Granularité inappropriée** : la BI veut des agrégats, pas des events unitaires

### L'objectif des transformations

Convertir la donnée **brute** → donnée **fiable** → donnée **utile**

---

## 🏗️ Le pipeline de transformation typique

```
Sources             Ingestion           Transformation       Consommation
───────             ─────────           ──────────────       ────────────
APIs REST  ──►  ┐                                       ┌──► Looker Studio
Bases OLTP ──►  ├──► GCS/BigQuery ──► dbt / Dataform ──├──► BI Tools
Événements ──►  ┘   (Bronze/Raw)      (Silver/Gold)    └──► Data Science
```

- **ELT** (Extract-Load-Transform) : charger d'abord, transformer dans l'entrepôt
- Approche préférée sur BigQuery : exploite le moteur SQL massivement parallèle

---

## 🆚 ETL vs ELT — Le changement de paradigme

| Critère | **ETL** (traditionnel) | **ELT** (BigQuery / Cloud) |
|---------|------------------------|---------------------------|
| Où transformer ? | Serveur intermédiaire | Dans l'entrepôt lui-même |
| Coût infra | Serveurs dédiés (cher) | Serverless (payer à l'usage) |
| Scalabilité | Limitée | Quasi-illimitée |
| Outils | Informatica, SSIS, Talend | **dbt**, Dataform, SQL |
| Conservation du brut ? | Souvent non | **Oui** (couche Bronze) |
| Vitesse de développement | Lente | **Rapide** (SQL + Git) |

> 💡 BigQuery = moteur de transformation **natif** — pas besoin d'un serveur ETL séparé

---

<!-- _class: lead -->

# Partie 2
## L'Architecture Medallion

---

## 🏅 Les 3 couches de l'Architecture Medallion

```
  GCS / Sources brutes
         │
         ▼
  ┌─────────────┐     Ingestion brute, JAMAIS modifié
  │  🥉 BRONZE  │     → données RAW as-is
  │   (Raw)     │     → historique complet
  └──────┬──────┘
         │  Nettoyage, typage, déduplication
         ▼
  ┌─────────────┐     Source de vérité propre
  │  🥈 SILVER  │     → jointures applicatives
  │  (Cleansed) │     → règles métier appliquées
  └──────┬──────┘
         │  Agrégation, calculs métiers
         ▼
  ┌─────────────┐     Prêt pour la BI / ML
  │  🥇  GOLD   │     → data marts par domaine
  │  (Curated)  │     → tables dénormalisées
  └─────────────┘
```

---

## 🥉 Couche Bronze — La Landing Zone

**Principe : ingérer sans altérer**

```sql
-- Exemple : table Bronze events bruts
CREATE TABLE bronze.raw_events (
  _ingested_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  _source_file  STRING,         -- traçabilité de la source
  raw_payload   JSON,           -- JSON entier non parsé
  event_date    DATE            -- pour le partitionnement
)
PARTITION BY event_date;
```

✅ Avantages :
- **Rejeu possible** : si une transformation est fausse, on peut tout recalculer
- **Auditabilité** : on sait exactement ce qui est arrivé et quand
- **Coût maîtrisé** : tables partitionnées → scans limités au strict nécessaire

---

## 🥈 Couche Silver — La Source de Vérité

**Principe : nettoyer, typer, dédupliquer**

```sql
-- Exemple : transformation Bronze → Silver
CREATE OR REPLACE TABLE silver.events AS
SELECT
  JSON_VALUE(raw_payload, '$.event_id')                        AS event_id,
  JSON_VALUE(raw_payload, '$.user_id')                         AS user_id,
  CAST(JSON_VALUE(raw_payload, '$.amount') AS FLOAT64)         AS amount,
  PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ',
    JSON_VALUE(raw_payload, '$.created_at'))                   AS created_at,
  _ingested_at
FROM bronze.raw_events
WHERE JSON_VALUE(raw_payload, '$.event_id') IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY JSON_VALUE(raw_payload, '$.event_id')
  ORDER BY _ingested_at DESC) = 1;   -- déduplication
```

---

## 🥇 Couche Gold — Les Data Marts

**Principe : agréger pour répondre aux questions métier**

```sql
-- Exemple : KPI quotidien prêt pour Looker Studio
CREATE OR REPLACE TABLE gold.daily_revenue AS
SELECT
  DATE(created_at)              AS report_date,
  COUNT(DISTINCT user_id)       AS active_users,
  COUNT(event_id)               AS total_transactions,
  ROUND(SUM(amount), 2)         AS total_revenue,
  ROUND(AVG(amount), 2)         AS avg_basket
FROM silver.events
WHERE event_type = 'purchase'
GROUP BY 1
ORDER BY 1 DESC;
```

> 🎯 La couche Gold est **optimisée pour la lecture**, pas pour l'écriture.

---

<!-- _class: lead -->

# Partie 3

## Modélisation des données
### Kimball vs Dénormalisation BigQuery

---

## 🌟 Le Modèle en Étoile (Kimball)

Approche classique d'architecture de base de données :

```
                    dim_date
                      │
dim_users ──── fct_orders ──── dim_products
                      │
                  dim_stores
```

**Avantages :**
- Structure logique et compréhensible
- Facilité de maintenance des dimensions

**Inconvénients sur BigQuery :**
- Chaque JOIN coûte du temps CPU sur des milliards de lignes
- Les tables de dimensions peuvent devenir des goulots d'étranglement

---

## 🔀 La Dénormalisation — L'approche BigQuery

```sql
-- Au lieu de 4 tables + 3 JOINs...
-- Une seule table dénormalisée avec des colonnes plates
CREATE TABLE gold.fct_orders_denormalized AS
SELECT
    o.order_id,
    o.created_at,
    -- Données utilisateur (dénormalisées, pas de JOIN)
    u.user_id,
    u.country       AS user_country,
    u.segment       AS user_segment,
    -- Données produit (dénormalisées)
    p.product_id,
    p.category      AS product_category,
    p.brand         AS product_brand,
    -- Métriques
    o.quantity,
    o.unit_price,
    o.quantity * o.unit_price AS total_amount
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN products p ON o.product_id = p.product_id;
```

---

## ⚡ Dénormalisation vs Étoile — Comparatif BigQuery

| Critère | Modèle Étoile | Dénormalisé |
|---------|--------------|-------------|
| Nombre de tables | Plusieurs | Une seule |
| Requête Looker Studio | Plusieurs JOINs | Simple `SELECT` |
| Bytes scannés | Élevé | **Faible** (colonnes ciblées) |
| Redondance données | Nulle | Élevée |
| Coût BigQuery | **Plus élevé** | **Plus faible** |
| Maintenabilité | ✅ Meilleure | ❌ Modifications difficiles |

> 💡 **Règle pratique** : Dénormaliser les tables Gold stables à fort volume de requêtes BI.

---
<!-- _class: lead -->

# Partie 4
## Transformations SQL & Requêtes Planifiées

---

## 🔄 Vues Matérialisées — Le rafraîchissement automatique

Alternative aux Scheduled Queries pour les agrégations simples :

```sql
CREATE MATERIALIZED VIEW `gold.mv_daily_kpis`
PARTITION BY report_date
OPTIONS (
  enable_refresh = true,
  refresh_interval_minutes = 60
)
AS
SELECT
  DATE(event_ts)          AS report_date,
  country,
  COUNT(DISTINCT user_id) AS active_users,
  SUM(amount)             AS revenue
FROM `silver.events`
GROUP BY 1, 2;
```

BigQuery **met à jour automatiquement** la vue à chaque modification de la source.

---

## ⏰ Scheduled Queries — L'automatisation sans serveur

BigQuery peut exécuter une requête SQL **automatiquement** sur un calendrier.

```
 Console BigQuery → Éditeur → "Planifier" → "Créer une requête planifiée"
```

| Paramètre | Exemple |
|-----------|--------|
| Récurrence | `Toutes les heures`, `Chaque jour à 02:00` |
| Dataset cible | `silver` |
| Table cible | `events` |
| Mode écriture | `Overwrite` (reconstruction) ou `Append` (incrémental) |

> ✅ Pas de VM, pas de Spark, pas de code Python — **juste du SQL planifié**

---


## 🆚 Quel outil pour quel besoin ?

| Besoin | Solution recommandée |
|--------|--------------------|
| Transformation simple, peu de logique | **Vue SQL** |
| Agrégation Gold auto-actualisée | **Materialized View** |
| Transformation complexe (dédup, typage) | **Scheduled Query** (nightly) |
| Pipeline multi-tables, tests, lineage | **dbt** (outil avancé) |

---

## 🧹 Qualité des données — Les problèmes fréquents

Les problèmes typiques de la couche Bronze :

| Problème | Exemple réel | Traitement Silver |
|----------|-------------|------------------|
| **Doublons** | valeur x  présente 2 fois | `ROW_NUMBER() OVER (PARTITION BY event_id ...)` |
| **Types incorrects** | `amount_str = '49.99'` (STRING) | `SAFE_CAST(amount_str AS FLOAT64)` |
| **Valeurs invalides** | `device_os = 'UnknownOS'` | `WHERE device_os NOT IN ('UnknownOS')` |
| **Pays inconnus** | `country = 'XX'` | `AND country != 'XX'` |
| **Timestamps STRING** | `'2024-01-15T10:23:45Z'` | `PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', event_ts)` |
| **Valeurs NULL** | `amount_str IS NULL` | Conservé comme `NULL FLOAT64` valide |

> ⚠️ **Bronze ne filtre jamais** — c'est la responsabilité exclusive de **Silver**.

---

## 🔁 Déduplication — Les patterns BigQuery

### Pattern 1 : `ROW_NUMBER()` (plus flexible)
```sql
-- Étape 1 : Création d'une CTE (table temporaire) pour classer les doublons
WITH deduped AS (
  SELECT 
    *,
    -- ROW_NUMBER() attribue un numéro séquentiel unique (1, 2, 3...) à chaque ligne
    ROW_NUMBER() OVER (
      -- PARTITION BY : Regroupe les lignes par identifiant unique (délimite le périmètre des doublons)
      PARTITION BY event_id       
      ORDER BY event_ts DESC      
    ) AS rn -- Colonne temporaire contenant le rang attribué
  FROM `bronze.raw_events`
)

SELECT 
  -- EXCEPT(rn) : Syntaxe BigQuery/DuckDB pour conserver toutes les colonnes 
  -- d'origine tout en retirant la colonne technique 'rn' du résultat final
  * EXCEPT(rn)
FROM deduped
-- On ne conserve que la première ligne de chaque groupe (le plus récent)
WHERE rn = 1;
```
---

## 📊 Benchmark Partitionnement

Impact mesuré sur `silver.events` avec ~18 000 lignes :

| Requête | Filtre appliqué | Bytes scannés | Coût estimé |
|---------|----------------|--------------|-------------|
| Full scan | Aucun | 100% | Référence |
| Filtre sur partition | `WHERE event_date BETWEEN ...` | ~10-20% | ↓ 80-90% |

```sql
-- ❌ Scan complet — éviter en production
SELECT COUNT(*), SUM(amount) FROM `silver.events`;

-- ✅ Optimisé avec partition pruning
SELECT COUNT(*), SUM(amount)
FROM `silver.events`
WHERE event_date = '2024-01-15';  -- partition pruning → scan 1 seule partition
```


---

## 💰 Coûts BigQuery — Comprendre la facturation

BigQuery facture principalement sur les **bytes scannés** (mode on-demand) :

```
Coût = (Bytes scannés) × (5$ / TB)
```

### Optimisations à retenir

| Technique | Réduction coût | Comment |
|-----------|---------------|--------|
| `PARTITION BY` | ↓ 80-90% | Limiter le scan à quelques partitions |
| Sélection de colonnes | ↓ proportionnel | `SELECT col1, col2` au lieu de `SELECT *` |
| `SAFE_CAST` | 0 coût | Évite les erreurs qui relancent la requête |

```sql
-- Estimer le coût AVANT d'exécuter :
-- Cocher "Traitement requis" dans BigQuery avant de cliquer sur Exécuter
-- Ou utiliser : SELECT * FROM `silver.events` WHERE ...
-- → BigQuery affiche les bytes estimés en haut à droite
```

---


<!-- _class: lead -->

# Partie 5
## Aperçu dbt — L'Outil Standard Pro
### (Démonstration rapide)

---

## 🔧 Qu'est-ce que dbt ?

**dbt** (Data Build Tool) est le framework standard de transformation de données en entreprise.

> *"dbt permet de transformer la donnée en écrivant uniquement des requêtes SELECT."*

- ✅ **SQL uniquement** : Pas besoin de Python ou Spark.
- ✅ **Gestion de versions** : Chaque transformation est un fichier `.sql` tracé avec Git.
- ✅ **Tests intégrés** : Tests de qualité des données (valeurs nulles, unicité).
- ✅ **Lineage automatique** : Déduction automatique des dépendances entre tables.

---

## 🚀 Le paradigme dbt en action

Un modèle dbt = **un fichier SQL avec une requête `SELECT`**.

```sql
-- models/gold/fct_daily_sales.sql
SELECT
    DATE(created_at) AS report_date,
    SUM(amount)      AS daily_revenue
FROM {{ ref('int_user_sessions') }} -- 🔗 dbt gère la dépendance automatiquement !
GROUP BY 1
```


---

<!-- _class: lead -->

# Partie 6 - Bonus
## Deep Dive : `STRUCT` & `ARRAY`
### La dénormalisation hiérarchique dans BigQuery

---

## 🗂️ STRUCT — Des objets imbriqués dans une colonne

Un `STRUCT` est un **enregistrement structuré** dans une cellule :

```sql
CREATE TABLE silver.orders (
    order_id    STRING,
    created_at  TIMESTAMP,
    customer    STRUCT<
        id      STRING,
        name    STRING,
        country STRING,
        segment STRING
    >
);

-- Requêter un champ du STRUCT avec la notation pointée
SELECT
    order_id,
    customer.name     AS customer_name,
    customer.country  AS customer_country
FROM silver.orders;
```

---

## 📋 ARRAY — Des listes imbriquées dans une ligne

Un `ARRAY` stocke plusieurs valeurs dans **une seule cellule** :

```sql
CREATE TABLE silver.orders_with_items (
    order_id    STRING,
    customer_id STRING,
    created_at  TIMESTAMP,
    items       ARRAY<STRUCT<
        product_id   STRING,
        product_name STRING,
        quantity     INT64,
        unit_price   FLOAT64
    >>
);
```

**Résultat :**
| order_id | customer_id | items |
|----------|-------------|-------|
| ORD-001 | USR-42 | `[{prod_A, 2, 9.99}, {prod_B, 1, 24.99}]` |
| ORD-002 | USR-17 | `[{prod_C, 5, 4.49}]` |

---

## 🔓 UNNEST — Déplier les ARRAYs pour l'analyse

```sql
-- Calculer le chiffre d'affaires par produit
SELECT
    o.order_id,
    o.customer_id,
    item.product_name,
    item.quantity,
    item.unit_price,
    item.quantity * item.unit_price   AS line_total
FROM silver.orders_with_items AS o
CROSS JOIN UNNEST(o.items) AS item   -- déplier le tableau
ORDER BY line_total DESC;
```

**Résultat :**
| order_id | product_name | quantity | unit_price | line_total |
|----------|--------------|----------|------------|------------|
| ORD-001 | Produit B | 1 | 24.99 | 24.99 |
| ORD-001 | Produit A | 2 | 9.99 | 19.98 |

---

## 💰 Pourquoi STRUCT + ARRAY ?

### Sans imbrication — modèle normalisé

```
orders (10M lignes)  ──JOIN──  order_items (50M lignes)
→ Scan : 60M lignes × colonnes des 2 tables
```

### Avec imbrication — ARRAY dans BigQuery

```
orders_with_items (10M lignes, items imbriqués)
→ Scan : 10M lignes seulement, pas de JOIN !
```

**Impact coût :**
- BigQuery facture au **bytes scannés**
- Moins de JOINs = moins de bytes = **moins cher** ✅
- Stockage colonnaire : 3 colonnes sur 20 sélectionnées = **15% du coût** ✅

---

## 🎯 Quand utiliser STRUCT & ARRAY ?

| Cas d'usage | Recommandation |
|-------------|---------------|
| Commande → articles | `ARRAY<STRUCT<...>>` ✅ |
| Utilisateur → adresses multiples | `ARRAY<STRUCT<...>>` ✅ |
| Session → séquence d'events | `ARRAY<STRUCT<...>>` ✅ |
| Dimensions changeant souvent | Table séparée (SCD Type 2) |
| Données relationnelles OLTP | Tables normalisées |
| Données BI / Gold stables | Dénormaliser + STRUCT ✅ |

> ⚠️ **Limite** : les `ARRAY` compliquent les `UPDATE` et `DELETE`.
> Réservez-les aux couches **Silver** et **Gold** en lecture.

---

## 🏁 Synthèse du Module 2

```
Bronze (Raw)           Silver (Propre)           Gold (Métier)
────────────           ───────────────           ─────────────
JSON brut              Typé + nettoyé            Agrégé
Partitionné            PARTITION BY              Prêt pour Looker
Jamais modifié         Scheduled Query (nightly) Scheduled Query (daily)
```

| Outil | Rôle |
|-------|------|
| **SQL natif BigQuery** | `CREATE TABLE AS SELECT` pour les transformations |
| **Scheduled Queries** | Automatiser sans serveur ni orchestrateur |
| **Materialized Views** | Agrégations Gold auto-actualisées |
| **PARTITION BY** | Réduire les coûts de scan (↓ 80-90%) |
| **SAFE_CAST** | Gérer les valeurs malformées sans erreur |
| **ROW_NUMBER() OVER (PARTITION BY _)** | Déduplication propre et fiable |
| **dbt** *(avancé)* | Orchestration, lineage, tests — outil pro |

---

### 🧠 Questions de réflexion :

1. Quand une **Scheduled Query** est-elle insuffisante ? Que choisir alors ?
2. Pourquoi ne pas tout mettre directement en **Gold** sans passer par Silver ?
3. Comment gérer des données qui arrivent en retard *(late data)* ?
4. Pourquoi partitionner par `event_date` plutôt que par `user_id` ?
5. Si de nouvelles données arrivent en **continu** (streaming), quelle approche choisir ?
