---
marp: true
theme: gaia
_class: lead
paginate: true
backgroundColor: #f8fafc
color: #0f172a
header: "Architecture Data Cloud — M2 Informatique"
footer: "Entrepôt Analytique, Optimisation & Data Lake | FastMarket Case"
style: |
  section {
    font-size: 23px;
    font-family: 'Inter', system-ui, sans-serif;
  }
  h1 { color: #0f172a; border-bottom: 3px solid #db2777; padding-bottom: 8px; }
  h2 { color: #1e3a8a; }
  h3 { color: #be185d; }
  code { background: #e2e8f0; color: #0f172a; border-radius: 4px; padding: 2px 6px; }
  pre { background: #0f172a; color: #f8fafc; border-radius: 8px; padding: 12px; }
  pre code { background: transparent; color: #f8fafc; padding: 0; }
  strong { color: #1e3a8a; }
  em { color: #be185d; font-style: normal; font-weight: 600; }
  blockquote { background: #fce7f3; border-left: 8px solid #db2777; color: #0f172a; padding: 10px 16px; }
  table { font-size: 19px; width: 100%; border-collapse: collapse; }
  th { background-color: #1e3a8a; color: white; padding: 8px; }
  td { border: 1px solid #cbd5e1; padding: 8px; }
---

<!-- _class: lead -->

# Jour 3 : Structurer l'Analytique & le Data Lake
## De la réplication CDC brute à l'architecture Lakehouse

*FastMarket Case — Cloud SQL → Datastream → BigQuery & Cloud Storage*

---

## Où en sommes-nous sur FastMarket ?

```text
[Jour 1 : Cloud SQL] ──▶  (Jour 2 : Datastream CDC) ──▶ [BigQuery : Zone CDC brute]

   (OLTP Normalisé)                                       (Miroir des 5 tables)

```

### Les 3 défis du Jour 3 :
1. **Modélisation :** Faut-il garder les 5 tables normalisées pour l'analytique ?
2. **Alimentation & Coûts :** Comment ingérer (`APPEND` vs `MERGE`) et optimiser nos requêtes à > 90 jours ?
3. **Data Lake :** Où stocker les données massives non transactionnelles (ex. *événements panier* en JSON) ?

---

# 1. Modélisation Analytique : 3NF vs One Big Table (OBT)

## Pourquoi notre base Cloud SQL est normalisée (3NF) ?

Dans PostgreSQL, **5 tables** sont reliées par des clés étrangères :

`users` ◀── `orders` ◀── `order_items` ──▶ `products` (+ `payments`)

| Objectif OLTP (Cloud SQL) | Conséquence OLAP (Analytique) |
| :--- | :--- |
| Éviter la redondance en écriture | Multiplication des `JOIN` à la lecture |
| Garantir l'intégrité (`UPDATE` sur 1 ligne) | Coût CPU / réseau élevé sur > 90 jours |
| Requêtes ciblées par `id` (index B-Tree) | Scan lent dès qu'on agrège par catégorie/pays |

> En analytique distribuée (BigQuery), le **stockage est peu coûteux**, mais le **calcul et les jointures distribuées (shuffle)** coûtent cher.

---

## La Dénormalisation & le pattern One Big Table (OBT)

Principe : **pré-joindre** les tables métiers dans une grande table analytique large dédiée au reporting (couche *Gold*).

* **Avant (CDC brut) :** `order_items` + `orders` + `products` + `users` à joindre à chaque requête BI.
* **Après (OBT) :** Une table unique `obt_order_items` contenant directement :
  * La ligne de commande (`quantity`, `unit_price`, `line_total`)
  * Le contexte commande (`order_status`, `order_created_at`)
  * Le contexte produit (`product_sku`, `product_category`, `product_title`)
  * Le contexte géo (`customer_city`, `customer_country`) — *sans PII sensibles !*

> *Bon réflexe Sécurité (Jour 4) :* On exclut `password_hash`, `email`, `ip_address` dès la construction de l'OBT.

---

# 2. Stratégies d'ingestion : APPEND vs MERGE

## Ce que Datastream nous a appris:

Dans vos tables BigQuery répliquées, `datastream_metadata` contient uniquement `uuid` et `source_timestamp` :
* Datastream fonctionne en mode **MERGE** (car chaque table a une `PRIMARY KEY`).
* Quand une commande passe de `PENDING` → `PAID` → `SHIPPED`, BigQuery **écrase la ligne existante**.

### Conséquence architecturale :
* Vous avez la **photo instantanée** (*Current State*) de FastMarket.
* Vous avez **perdu l'historique** : combien de temps une commande reste-t-elle en `PENDING` ?

---

## APPEND (`INSERT INTO`) : Le journal immuable

On **ajoute** systématiquement de nouvelles lignes à la fin de la table sans jamais modifier l'existant.

* **Avantages :**
  * Ultra-rapide et peu coûteux (pas de lecture/recherche de clé avant écriture).
  * Conserve **100 % de l'historique** (audit, traçabilité, *Event Sourcing*).
* **Inconvénient :**
  * Non idempotent par défaut (relancer le job crée des doublons).
* **Quand choisir `APPEND` sur FastMarket ?**
  * Événements panier (`ADD_TO_CART`), logs techniques, historique des paiements, snapshots quotidiens.

---

## MERGE (`Upsert`) : L'état de référence à jour

On compare une source (delta) à la table cible via une **clé métier** :
* **Si la clé existe (`WHEN MATCHED`) :** on met à jour (`UPDATE`).
* **Si la clé n'existe pas (`WHEN NOT MATCHED`) :** on insère (`INSERT`).

* **Avantages :**
  * **Idempotent** : rejouer la requête 2 fois donne exactement le même résultat.
  * Table prête à l'emploi pour les analystes (1 ligne = 1 commande).
* **Inconvénient :**
  * Plus coûteux en calcul (BigQuery doit scanner/réécrire les micro-partitions impactées).
* **Quand choisir `MERGE` sur FastMarket ?**
  * Mettre à jour `orders.status`, le stock dans `products`, ou rafraîchir notre table **OBT**.

---

## Quiz FastMarket : `APPEND` ou `MERGE` ?

| Cas d'usage sur notre base e-commerce | Quel mode choisir ? |
| :--- | :---: |
| **1.** Un client tente un paiement (`payments`) ou clique sur *Ajouter au panier* : la donnée décrit un fait passé qui vient de se produire. | `__________` |
| **2.** Le stock d'un produit (`products.stock_quantity`) baisse ou un client modifie son adresse (`users.city`) : on ne veut garder que l'état à jour. | `__________` |
| **3.** On veut mesurer le temps passé par une commande (`orders.status`) entre `PENDING`, `PAID` et `SHIPPED` sans rien écraser. | `__________` |
| **4.** Pendant le *Black Friday*, on ingère des milliers d'événements/sec : il faut écrire vite et à moindre coût, sans relire la table cible. | `__________` |
| **5.** Le batch qui met à jour le CA des commandes (`orders.total_amount`) plante à 90 % et est relancé : aucun doublon toléré. | `__________` |

---
# Réponses :
1. APPEND (événement immuable : paiements / clics panier)
2. MERGE (état courant modifiable : stock produit / fiche client)
3. APPEND (besoin d'historiser chaque transition de statut)
4. APPEND (pas de scan/lookup préalable sur la table cible -> latence et coût min)
5. MERGE (idempotence garantie si le job est rejoué, pas de double comptage du CA)

---

# 3. Optimiser BigQuery : Partitionnement & Clustering

## Pourquoi nos requêtes > 90 jours coûtaient cher ?

Par défaut, BigQuery stocke les données en colonnes, mais sans organisation temporelle ni tri :
* Filtrer sur `WHERE created_at >= ...` oblige BigQuery à **scanner toutes les colonnes demander**
_(c'est pour cela qu'on évite le `SELECT *` !)_
* Sur une table de 500 Go, chaque requête pourrait être facturé 500 Go scannés !

### Deux mécanismes complémentaires dans BigQuery :
1. **Le Partitionnement** : découper physiquement la table en « tiroirs » indépendants.
2. **Le Clustering** : trier les données *à l'intérieur* de chaque tiroir.

---

## Le Partitionnement

Dans BigQuery, on  segmente la table en sous-blocs (souvent par valeur temporelle comme une colonne `DATE` ou `TIMESTAMP`).

```sql
CREATE TABLE `fastmarket_analytics.obt_order_items`
PARTITION BY DATE(order_created_at) ...
```

* **Limites :** 1 seule colonne de partitionnement par table (max 10 000 partitions).

> *Règle d'or :* Toujours partitionner les tables analytiques volumineuses sur la date la plus filtrée.

---

## Visualiser le Partitionnement sur FastMarket


<style scoped>
  .pm-wrap { display: grid; grid-template-columns: 1fr 110px 1.35fr; gap: 14px; align-items: center; margin-top: 6px; }
  .pm-title { background: #e2e8f0; color: #0f172a; font-weight: 700; font-size: 14px; text-align: center; padding: 5px 10px; border-radius: 6px 6px 0 0; border: 1px solid #cbd5e1; border-bottom: none; font-family: monospace; }
  table.pm-tbl { width: 100%; border-collapse: collapse; font-size: 13.5px !important; margin: 0; }
  table.pm-tbl th { background: #334155 !important; color: #ffffff !important; padding: 4px 8px !important; text-align: center; border: 1px solid #475569; }
  table.pm-tbl td { padding: 3.5px 8px !important; text-align: center; border: 1px solid #cbd5e1; color: #0f172a; }
  .pm-y { background: #fef3c7 !important; }
  .pm-g { background: #dcfce7 !important; }
  .pm-p { background: #ede9fe !important; }
  .pm-arrow { background: #2563eb; color: #ffffff; font-weight: 700; font-size: 14px; height: 46px; display: flex; align-items: center; justify-content: center; padding-right: 18px; clip-path: polygon(0% 25%, 72% 25%, 72% 0%, 100% 50%, 72% 100%, 72% 75%, 0% 75%); }
  .pm-stack { display: flex; flex-direction: column; gap: 8px; }
  .pm-part { display: grid; grid-template-columns: 82px 1fr; align-items: stretch; }
  .pm-lbl { display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 13px; color: #334155; border: 1px solid #cbd5e1; border-right: none; font-family: monospace; }
</style>

<div class="pm-wrap">

  <div>
    <div class="pm-title">fastmarket.orders</div>
    <table class="pm-tbl">
      <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
      <tbody>
        <tr class="pm-y"><td>2026-11-23</td><td>#101</td><td>PAID</td></tr>
        <tr class="pm-y"><td>2026-11-23</td><td>#102</td><td>SHIPPED</td></tr>
        <tr class="pm-g"><td>2026-11-24</td><td>#103</td><td>PAID</td></tr>
        <tr class="pm-p"><td>2026-11-25</td><td>#104</td><td>PENDING</td></tr>
        <tr class="pm-g"><td>2026-11-24</td><td>#105</td><td>CANCELLED</td></tr>
        <tr class="pm-y"><td>2026-11-23</td><td>#106</td><td>SHIPPED</td></tr>
        <tr class="pm-g"><td>2026-11-24</td><td>#107</td><td>PAID</td></tr>
        <tr class="pm-p"><td>2026-11-25</td><td>#108</td><td>PAID</td></tr>
        <tr class="pm-y"><td>2026-11-23</td><td>#109</td><td>PAID</td></tr>
      </tbody>
    </table>
  </div>

  <div class="pm-arrow">Partition</div>

  <div>
    <div class="pm-title">fastmarket.orders_partitioned</div>
    <div class="pm-stack">
      <div class="pm-part">
        <div class="pm-lbl pm-y">20261123</div>
        <table class="pm-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="pm-y"><td>2026-11-23</td><td>#101</td><td>PAID</td></tr>
            <tr class="pm-y"><td>2026-11-23</td><td>#102</td><td>SHIPPED</td></tr>
            <tr class="pm-y"><td>2026-11-23</td><td>#106</td><td>SHIPPED</td></tr>
            <tr class="pm-y"><td>2026-11-23</td><td>#109</td><td>PAID</td></tr>
          </tbody>
        </table>
      </div>
      <div class="pm-part">
        <div class="pm-lbl pm-g">20261124</div>
        <table class="pm-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="pm-g"><td>2026-11-24</td><td>#103</td><td>PAID</td></tr>
            <tr class="pm-g"><td>2026-11-24</td><td>#105</td><td>CANCELLED</td></tr>
            <tr class="pm-g"><td>2026-11-24</td><td>#107</td><td>PAID</td></tr>
          </tbody>
        </table>
      </div>
      <div class="pm-part">
        <div class="pm-lbl pm-p">20261125</div>
        <table class="pm-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="pm-p"><td>2026-11-25</td><td>#104</td><td>PENDING</td></tr>
            <tr class="pm-p"><td>2026-11-25</td><td>#108</td><td>PAID</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

</div>

---

## Le Clustering (Tri intra-partition)

Le clustering trie et colocalise les lignes selon **1 à 4 colonnes** dans l'ordre de priorité.

```sql
CREATE TABLE `fastmarket_analytics.obt_order_items`
PARTITION BY DATE(order_created_at)
CLUSTER BY order_status, product_category, customer_country ...
```

* **Ordre des colonnes :** Mettre d'abord la colonne la plus fréquemment filtrée (ou la moins cardinale si filtrée en égalité `=`).
* **Bonus :** Le clustering est **automatiquement réorganisé** en tâche de fond par BigQuery, sans coût supplémentaire !

---

## Visualiser le Clustering sur FastMarket (`CLUSTER BY status`)

<style scoped>
  .cl-wrap { display: grid; grid-template-columns: 1fr 118px 1fr; gap: 12px; align-items: center; margin-top: 4px; }
  .cl-title { background: #e2e8f0; color: #0f172a; font-weight: 700; font-size: 13.5px; text-align: center; padding: 5px 8px; border-radius: 6px 6px 0 0; border: 1px solid #cbd5e1; border-bottom: none; font-family: monospace; }
  .cl-stack { display: flex; flex-direction: column; gap: 10px; }
  .cl-part { display: grid; grid-template-columns: 76px 1fr; align-items: stretch; }
  .cl-lbl { display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 12.5px; color: #334155; background: #f1f5f9; border: 1px solid #cbd5e1; border-right: none; font-family: monospace; }
  table.cl-tbl { width: 100%; border-collapse: collapse; font-size: 13px !important; margin: 0; }
  table.cl-tbl th { background: #334155 !important; color: #ffffff !important; padding: 3.5px 6px !important; text-align: center; border: 1px solid #475569; }
  table.cl-tbl td { padding: 3px 6px !important; text-align: center; border: 1px solid #cbd5e1; color: #0f172a; }
  .cl-c { background: #fce7f3 !important; }
  .cl-p { background: #d1fae5 !important; }
  .cl-s { background: #dbeafe !important; }
  .cl-blk td { border-top: 2px dashed #475569 !important; }
  .cl-arrow { background: #db2777; color: #ffffff; font-weight: 700; font-size: 13px; text-align: center; line-height: 1.15; height: 50px; display: flex; align-items: center; justify-content: center; padding-right: 18px; clip-path: polygon(0% 22%, 72% 22%, 72% 0%, 100% 50%, 72% 100%, 72% 78%, 0% 78%); }
</style>

<div class="cl-wrap">

  <div>
    <div class="cl-title">Partitionnée (non triée)</div>
    <div class="cl-stack">
      <div class="cl-part">
        <div class="cl-lbl">20261123</div>
        <table class="cl-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="cl-p"><td>2026-11-23</td><td>#101</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-s"><td>2026-11-23</td><td>#102</td><td><strong>SHIPPED</strong></td></tr>
            <tr class="cl-c"><td>2026-11-23</td><td>#106</td><td><strong>CANCELLED</strong></td></tr>
            <tr class="cl-p"><td>2026-11-23</td><td>#109</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-s"><td>2026-11-23</td><td>#110</td><td><strong>SHIPPED</strong></td></tr>
          </tbody>
        </table>
      </div>
      <div class="cl-part">
        <div class="cl-lbl">20261124</div>
        <table class="cl-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="cl-s"><td>2026-11-24</td><td>#103</td><td><strong>SHIPPED</strong></td></tr>
            <tr class="cl-p"><td>2026-11-24</td><td>#105</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-s"><td>2026-11-24</td><td>#107</td><td><strong>SHIPPED</strong></td></tr>
            <tr class="cl-p"><td>2026-11-24</td><td>#111</td><td><strong>PAID</strong></td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <div class="cl-arrow">Cluster<br>by status</div>

  <div>
    <div class="cl-title">Partitionnée + Clusterisée</div>
    <div class="cl-stack">
      <div class="cl-part">
        <div class="cl-lbl">20261123</div>
        <table class="cl-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="cl-c"><td>2026-11-23</td><td>#106</td><td><strong>CANCELLED</strong></td></tr>
            <tr class="cl-p cl-blk"><td>2026-11-23</td><td>#101</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-p"><td>2026-11-23</td><td>#109</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-s cl-blk"><td>2026-11-23</td><td>#102</td><td><strong>SHIPPED</strong></td></tr>
            <tr class="cl-s"><td>2026-11-23</td><td>#110</td><td><strong>SHIPPED</strong></td></tr>
          </tbody>
        </table>
      </div>
      <div class="cl-part">
        <div class="cl-lbl">20261124</div>
        <table class="cl-tbl">
          <thead><tr><th>created_at</th><th>order_id</th><th>status</th></tr></thead>
          <tbody>
            <tr class="cl-p"><td>2026-11-24</td><td>#105</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-p"><td>2026-11-24</td><td>#111</td><td><strong>PAID</strong></td></tr>
            <tr class="cl-s cl-blk"><td>2026-11-24</td><td>#103</td><td><strong>SHIPPED</strong></td></tr>
            <tr class="cl-s"><td>2026-11-24</td><td>#107</td><td><strong>SHIPPED</strong></td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

</div>

> **Requête :** `WHERE DATE(created_at) = '2026-11-23' AND status = 'PAID'` → BigQuery ouvre la partition `20261123`, puis **ne lit que le bloc vert** (*Block Pruning* grâce aux bornes Min/Max).
---

## Partitionnement vs Clustering : Le duo gagnant

| Critère | Partitionnement | Clustering |
| :--- | :--- | :--- |
| **Nombre de colonnes** | 1 seule | **Jusqu'à 4** |
| **Types supportés** | `DATE`, `TIMESTAMP`, `INT64` (range) | `STRING`, `INT64`, `DATE`, `BOOL`, etc. |
| **Estimation coût avant exécution** | Exacte (visible dans l'UI) | Estimée (gain réel visible après exécution) |
| **Usage FastMarket (OBT)** | `DATE(order_created_at)` | `order_status, product_category, customer_country` |

---

# 4. Data Lake sur Cloud Storage & Modélisation Lakehouse

## Pourquoi un Data Lake en plus de BigQuery ?

Doit-on envoyer *toutes* les données de FastMarket dans Cloud SQL ou BigQuery ? **Non.**

* **Exemples de données hors BDD transactionnelle :**
  * Événements de navigation et paniers abandonnés (`ADD_TO_CART`, `REMOVE_FROM_CART`).
  * Payloads bruts de prestataires (comme `payments.raw_payload_json` !).
  * Fichiers médias, exports partenaires, logs applicatifs.

### Rôle de Cloud Storage (GCS) :
* Stockage objet **quasi illimité et très peu cher**.
* Découplage total entre le **stockage** (GCS) et le **moteur de calcul** (BigQuery, Spark, etc.).

---

## Modéliser son Data Lake : L'architecture Medallion

Organiser un bucket GCS en zones logiques claires évite de créer un *Data Swamp* (marécage de données) :

```text
gs://fastmarket-datalake-<id>/
 ├── bronze/                   ◀── Zone RAW (Immuable, format d'origine : JSON)
 │    └── cart_events/
 ├── silver/                   ◀── Zone CLEANED (Typée, dédupliquée, format PARQUET)
 │    └── cart_events/
 └── gold/ (ou BigQuery)       ◀── Zone BUSINESS (OBT, agrégats BI)
```

* **Bronze (JSON) :** Fidèle à ce qu'émettent les microservices des développeurs.
* **Silver (Parquet) :** Optimisé pour la lecture analytique et les jointures.

---

## JSON vs Parquet : Pourquoi transformer ?

| Critère | JSON (Newline Delimited) | Apache Parquet |
| :--- | :--- | :--- |
| **Orientation** | **Ligne** (texte brut lisible) | **Colonne** (binaire optimisé) |
| **Schéma & Types** | Implicite / fragile (ex: `TIMESTAMP` en texte) | **Fortement typé** dans l'en-tête du fichier |
| **Compression** | Faible / verbeuse (noms de clés répétés) | **Excellente** (Snappy / Zstd, jusqu'à -80 % de taille) |
| **Column Pruning** | ❌ Lit tout le fichier même pour 1 colonne | ✅ Ne lit que les colonnes demandées dans `SELECT` |

> *Sans code Python :* BigQuery peut lire du JSON via une **Table Externe**, puis le convertir en Parquet dans GCS via une simple requête SQL `EXPORT DATA` !

---

## Architecture cible FastMarket à l'issue du Jour 3

```text
  [Cloud SQL] ──(Datastream MERGE)──▶ [BigQuery CDC] ──(CTAS / MERGE)──▶ [OBT Gold]
                                                                      (Partition + Cluster)
                                                                              ▲
  [App Web/Mobile] ──(JSON)──▶ [GCS Bronze] ──(EXPORT DATA)──▶ [GCS Silver] ──┘
                                 (JSON)         (BigQuery SQL)   (Parquet + Table Externe)
```

* **Prochaine étape (Jours 4 & 5) :** Sécuriser ces données (PII, IAM, masquage), observer les pipelines et maîtriser les coûts (FinOps).