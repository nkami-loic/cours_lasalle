---
marp: true
theme: gaia
_class: lead
paginate: true
backgroundColor: #f8fafc
color: #0f172a
header: "Architecture Data Cloud — M2 Informatique"
footer: "Du Monolithe à l'Analytique : CDC & WAL PostgreSQL | FastMarket Case"
style: |
  section {
    font-size: 24px;
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
---

<!-- _class: lead -->

# 🔄 Du Monolithe à l'Analytique : Le CDC
## Réplication temps réel vers BigQuery sans impacter la production via le WAL PostgreSQL

### Objectifs de la session
- Comprendre pourquoi et comment déporter la charge analytique vers **BigQuery**
- Analyser les pièges des approches d'ingestion naïves (*Batch SQL* & *Dual-Write*)
- Découvrir le pattern fondamental : **Change Data Capture (CDC)**
- Maîtriser le fonctionnement interne du **WAL (Write-Ahead Log)** de PostgreSQL
- Mettre en œuvre **Google Cloud Datastream** pour synchroniser OLTP et OLAP

---

## 🎯 Le Défi : Alimenter l'Analytique sans Tuer la Prod

Après l'audit du monolithe FastMarket, le constat est clair : **la base transactionnelle (PostgreSQL) doit être soulagée**.

```
  [ Clients Web ] ──► [ FastMarket API ] ──► [ Cloud SQL (PostgreSQL) ]
                                                          │
                                                ❌ CONFLITS DE VERROUS
                                                ❌ RESSOURCES SATURÉES
                                                          ▼
                                              [ Rapports BI Marketing ]
```

### La Cible : BigQuery (Data Warehouse Cloud)
* **Stockage colonnaire & distribué** : Scanne des milliards de lignes en quelques secondes.
* **Architecture Serverless** : Les calculs analytiques lourds sont exécutés sur les slots Google, avec **zéro impact CPU/RAM sur la base opérationnelle**.

 *Comment transférer en continu les données de PostgreSQL vers BigQuery ?*

---

## Idée n°1 : Execution SQL Périodique

L'approche développeur classique : un script Cron / ETL qui s'exécute toutes les heures.

```sql
-- Exécuté toutes les heures sur la base de production PostgreSQL
SELECT * FROM orders WHERE updated_at >= NOW() - INTERVAL '1 hour';
```

  _Que pensez vous de cette approche ?_

---


### Pourquoi cette approche échoue en production :
1. **Pertes des suppressions (`DELETE`)** : Une ligne effacée de PostgreSQL ne correspond plus à aucun `updated_at` et reste indéfiniment orpheline dans BigQuery.
2. **Impact immédiat sur les perfs** : Chaque heure, une requête lourde charge le CPU et balaye les disques au détriment des utilisateurs finaux.
3. **Latence élevée (batch)** : Les décideurs travaillent sur des données vieilles de 60 minutes au mieux.
4. **Porblème de consistance et fiabilité** : Décalages temporels, transactions longues validées après le batch.

---

## Idée n°2 : Le "Dual-Write" Applicatif

Le développeur tente de notifier l'analytique directement dans le code métier de l'API.

```python
# Dans le contrôleur de validation de panier
@app.post("/orders")
def create_order(order: Order):
    db.session.add(order)
    db.session.commit()       # Étape 1 : Sauvegarde PostgreSQL
    
    bigquery_client.insert(order)  # Étape 2 : Notification analytique (ou Pub/Sub)
    return {"status": "ok"}
```

---

### Le Piège du "Dual-Write" : Manque de consistance.
* **Que se passe-t-il si le réseau coupe entre l'étape 1 et l'étape 2 ?**
  * La base a validé la commande, mais BigQuery ne l'apprendra jamais !
* **Que se passe-t-il si la base plante pendant le commit alors que l'API a déjà envoyé l'événement ?**
  * Des données fantômes polluent le reporting financier.


**Principe fondamental** : 
          Sans protocole de validation à 2 phases, deux écritures réseau indépendantes ne peuvent jamais être **atomiques**.

---

## ⚡ La Solution Définitive : Le Change Data Capture (CDC)

Le **CDC (Change Data Capture)** consiste à écouter les flux de modifications directement **au niveau du moteur de stockage**, sans modifier le code de l'application.

```
 [ FastMarket API ] ──► [ PostgreSQL ] ──(Écriture)──► [ Journal WAL ]
                              │                              │
                        (Transactions)                       ▼ (Lecture passive)
                                                     [ Connecteur CDC ]
                                                             │
                                                             ▼
                                                    [ Google BigQuery ]
```

### Les 3 Principes Fondamentaux du CDC
1. **Zéro impact applicatif** : L'API n'a pas conscience qu'une réplication a lieu.
2. **Capture exhaustive** : Tous les `INSERT`, `UPDATE` et `DELETE` sont fidèlement capturés.
3. **Latence sub-seconde** : Les changements sont streamés instantanément.

---

## 🪵 Sous le Capot de PostgreSQL : Le WAL (Write-Ahead Log)

### Qu'est-ce que le WAL ?
* Avant de modifier une table ou un index sur disque (fichiers de données volumineux), PostgreSQL enregistre l'opération dans un **journal séquentiel append-only** : le **WAL**.
* Si la machine s'éteint brutalement, PostgreSQL rejoue le WAL au redémarrage pour réparer les tables.

```
      Transaction SQL
             │
             ▼
   ┌───────────────────┐      Flush disque séquentiel ultra-rapide
   │   Écriture WAL    │ ──────────────────────────────────────────► Disque WAL
   └───────────────────┘
             │
             ▼ (Asynchrone via Checkpointer)
   ┌───────────────────┐
   │ Pages de Données  │ ──────────────────────────────────────────► Fichiers Tables
   └───────────────────┘
```

---

## ☁️ Le CDC Serverless sur GCP : Google Cloud Datastream

Plutôt que d'administrer soi-même des clusters Kafka Connect et Debezium, GCP propose **Datastream**.

```
 ┌─────────────────┐       Replication Slot       ┌──────────────────────┐
 │    Cloud SQL    │ ───────────────────────────► │   Cloud Datastream   │
 │  PostgreSQL 16  │       (pgoutput / WAL)       │     (Serverless)     │
 └─────────────────┘                              └──────────────────────┘
                                                             │
                                              Streaming direct via Storage API
                                                             │
                                                             ▼
                                                  ┌──────────────────────┐
                                                  │    Google BigQuery   │
                                                  │ (Dataset Répliqué)   │
                                                  └──────────────────────┘
```

* **100% Managé & Serverless** : S'adapte automatiquement au volume d'événements.
* **Auto-discovery des schémas** : Répercute automatiquement les ajouts de colonnes.
* **Intégration directe BigQuery** : Déverse les données dans des tables BigQuery.
---

## 📊 Modèle de Données dans BigQuery : Changelog vs Vue Réconciliée

Comment BigQuery représente-t-il les flux provenant du CDC Datastream ?

### 1. La Table Append-Only (Changelog / Log d'événements)
Chaque opération reçue est insérée comme une nouvelle ligne avec des métadonnées de traçabilité :

| `order_id` | `customer_id` | `amount` | `_metadata_change_type` | `_metadata_timestamp` |
|---|---|---|---|---|
| 101 | 42 | 89.00 | `INSERT` | 2026-11-19 10:00:01 |
| 101 | 42 | 99.00 | `UPDATE` | 2026-11-19 10:05:12 |
| 102 | 87 | 15.50 | `INSERT` | 2026-11-19 10:06:00 |


---

## 🏗️ Architecture Cible FastMarket & Synthèse

```
 [ Clients / Web ]
         │
         ▼
 ┌───────────────┐       WAL Logique       ┌────────────┐
 │  PostgreSQL   │ ──────────────────────► │ Datastream │
 │ (Transaction) │                         │   (CDC)    │
 └───────────────┘                         └────────────┘
                                                 │
                                                 ▼
                                        ┌────────────────┐
                                        │    BigQuery    │
                                        │ (Analytique)   │
                                        └────────────────┘
                                                 │
                                                 ▼
                                        [ Looker Studio ]
```

---

### Les Bénéfices pour l'Équipe :
* ✅ **Zéro impact sur les achats** : Plus aucun rapport lourd ne tourne sur Cloud SQL.
* ✅ **Données fraîches en < 2 secondes** pour les tableaux de bord décisionnels.
* ✅ **Aucune modification de code** requise dans l'application web monolithique.
