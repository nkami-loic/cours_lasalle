# 🔄 Activité Pratique : Déploiement d'un Pipeline CDC avec Datastream

> **Module :** Architecture Data Cloud sur Google Cloud Platform 
> **Niveau :** Master 2 Informatique / Cloud & Data Architecture  
> **Format :** Individuel | **Durée estimée :** 1h30

---

## 🎯 Objectifs

* Découvrir le pattern fondamental du **Change Data Capture (CDC)** sur Google Cloud.
* Connecter une base opérationnelle **PostgreSQL (Cloud SQL)** à un entrepôt de données **BigQuery** sans impacter les performances de production.
* Configurer et superviser un flux temps réel serverless avec **Google Cloud Datastream**.
* Valider la réplication continue en observant la propagation immédiate des transactions dans BigQuery.

---

## 📋 Étape 1 : Prérequis PostgreSQL & Utilisateur de Réplication

Pour que Datastream puisse capturer les modifications depuis le journal de transactions (**WAL**), deux configurations sont indispensables sur l'instance Cloud SQL :

### 1. Activer le Décodage Logique (*Logical Decoding*)
* Dans la console Cloud SQL, vérifiez dans l'onglet **Configuration** que le drapeau de base de données est actif :  
  `cloudsql.logical_decoding = on`  
  *(Si vous devez l'ajouter, appliquez la modification et laissez l'instance redémarrer).*

### 2. Créer un Utilisateur Dédié au CDC avec le Rôle `REPLICATION`
Par principe de sécurité et de moindre privilège, on ne donne jamais le compte applicatif principal à un outil d'ingestion. Vous devez créer un compte dédié à Datastream.

Connectez-vous à la base `fastmarket_shop` (via Cloud Shell ou client SQL) et exécutez les instructions suivantes :

```sql
-- 1. Créer l'utilisateur avec l'attribut REPLICATION
CREATE USER datastream_user WITH REPLICATION PASSWORD 'VotreMotDePasseCDC123!';

-- 2. Accorder les droits de lecture sur les données à répliquer
GRANT USAGE ON SCHEMA public TO datastream_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;
```

> 💡 **Pourquoi le statut `REPLICATION` ?**  
> Ce privilège autorise PostgreSQL à ouvrir un **slot de réplication logique** (*replication slot*) et à streamer le flux binaire du WAL directement vers Datastream.

---

## 🔌 Étape 2 : Création des Profils de Connexion

Depuis la console GCP, rendez-vous dans le service **Datastream > Profils de connexion** (*Connection Profiles*) et créez les deux extrémités du pipeline :

### 1. Profil Source (PostgreSQL)
* **Nom du profil :** `src-postgres-fastmarket`
* **Type :** PostgreSQL
* **Hôte & Port :** IP de votre instance Cloud SQL / Port `5432`
* **Base de données :** `fastmarket_shop`
* **Identifiants :** Utilisateur `datastream_user` / mot de passe défini à l'étape 1
* **Méthode de connectivité :** Liste d'adresses IP autorisées (*IP allowlisting*) ou Connectivité privée

> ⚠️ **Indice Réseau :**  
> Si vous utilisez la méthode par IP autorisée, Datastream affiche une liste d'adresses IP publiques Google. Pensez à ajouter ces IPs dans la section **Réseaux autorisés** (*Authorized Networks*) de votre instance Cloud SQL !

### 2. Profil Destination (BigQuery)
* **Nom du profil :** `dst-bigquery-analytics`
* **Type :** BigQuery
* **Région :** Belgique (`europe-west1`)

---

## 🌊 Étape 3 : Création et Démarrage du Flux (Stream)

Dans **Datastream > Flux** (*Streams*), créez un nouveau flux de réplication en renseignant les informations suivantes :

| Paramètre | Valeur attendue |
|---|---|
| **Nom du flux** | `stream-fastmarket-cdc` |
| **Profil source** | `src-postgres-fastmarket` |
| **Profil de destination** | `dst-bigquery-analytics` |
| **Objets sources à répliquer** | Schéma `public` (sélectionnez toutes les tables : `users`, `products`, `orders`, etc.) |
| **Type de réplication** | Rétroaction historique + Modifications continues (*Backfill + CDC*) |
| **Nom du jeu de données BigQuery cible** | Déduit du nom de la source ou personnalisé (ex: `fastmarket_shop_cdc`) |

> 🔍 **Avant de démarrer le flux :**  
> Cliquez sur **Valider le flux** (*Run validation*). Datastream vérifie automatiquement la connectivité, la présence des slots de réplication et les droits d'accès. Corrigez les éventuelles alertes avant de lancer le flux.

---

## ✅ Étape 4 : Validation du Streaming Temps Réel

Une fois le flux au statut **En cours d'exécution** (*Running*) :

1. **Vérification de l'historique initial dans BigQuery :**
   * Rendez-vous dans **BigQuery Studio**.
   * Localisez le jeu de données créé par Datastream et vérifiez que les tables sont bien répliquées.

2. **Test de capture d'une transaction en direct :**
   * Connectez-vous à votre base PostgreSQL (via Cloud Shell ou client SQL).
   * Insérez un nouvel utilisateur ou une commande de test :
     ```sql
     INSERT INTO users (email, password_hash, first_name, last_name, country)
     VALUES ('test.cdc@datakoko.com', 'hash123', 'Thomas', 'Pesquet', 'France');
     ```
   * Dans BigQuery, interrogez la table `users` correspondante :
     ```sql
     SELECT * FROM `fastmarket_shop_cdc.users` 
     WHERE email = 'test.cdc@datakoko.com';
     ```
   * **Constatez :** La ligne apparaît dans BigQuery en moins de 5 secondes, sans jamais avoir exécuté d'export ou de script batch !
