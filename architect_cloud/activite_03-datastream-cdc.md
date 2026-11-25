# 🔄 Activité Pratique : Déploiement d'un Pipeline CDC avec Datastream

> **Module :** Architecture Data Cloud sur Google Cloud Platform 
> **Niveau :** Master 2 Informatique / Cloud & Data Architecture  
> **Format :** Individuel 

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

### 2. Créer l'Utilisateur et les Objets de Réplication (Publication & Slot)
Par principe de sécurité et de moindre privilège, on ne donne jamais le compte applicatif principal à un outil d'ingestion. 

Datastream a besoin de 3 éléments sous PostgreSQL pour fonctionner :
1. Un utilisateur avec l'attribut `REPLICATION`.
2. Une **Publication** qui liste les tables dont les changements doivent être capturés.
3. Un **Slot de Réplication Logique** (*Replication Slot*) utilisant le plugin `pgoutput`.


> Suivez les indications de Datastream dans la section 'Avant de continuer, voir les prérequis'

> 💡 **Pourquoi ces objets sont-ils nécessaires ?**  
> * **La Publication (`fastmarket-pub`)** : C'est le "filtre" PostgreSQL qui spécifie quelles tables envoient leurs événements de modification (`INSERT`, `UPDATE`, `DELETE`).
> * **Le Slot de Réplication (`fastmarket-rep`)** : C'est le curseur PostgreSQL qui garde en mémoire la position de Datastream dans le journal WAL. Tant que Datastream n'a pas acquitté la lecture des événements, PostgreSQL conserve le WAL pour éviter toute perte de données.

---

## 🔌 Étape 2 : Création des Profils de Connexion

Depuis la console GCP, rendez-vous dans le service **Datastream > Profils de connexion** (*Connection Profiles*) et créez les deux extrémités du pipeline :

### 1. Profil Source (PostgreSQL)
* **Nom du profil :** `src-postgres-fastmarket-VOTRE_NOM`
* **Type :** PostgreSQL
* **Hôte & Port :** IP de votre instance Cloud SQL / Port `5432`
* **Base de données :** `NOM_DE_VOTRE_DB`
* **Identifiants :** Utilisateur `datastream_user` / mot de passe défini à l'étape 1
* **Méthode de connectivité :** Liste d'adresses IP autorisées (*IP allowlisting*) 

> ⚠️ **Indice Réseau :**  
> Si vous utilisez la méthode par IP autorisée, Datastream affiche une liste d'adresses IP publiques Google. Pensez à ajouter ces IPs dans la section **Réseaux autorisés** (*Authorized Networks*) de votre instance Cloud SQL !

### 2. Profil Destination (BigQuery)
* **Nom du profil :** `dst-bigquery-analytics-VOTRE_NOM`
* **Type :** BigQuery
* **Région :** Belgique (`europe-west1`)

---

## 🌊 Étape 3 : Création et Démarrage du Flux (Stream)

Dans **Datastream > Flux** (*Streams*), créez un nouveau flux de réplication en renseignant les informations suivantes :

| Paramètre | Valeur attendue |
|---|---|
| **Nom du flux** | `fastmarket-cdc-VOTRE_NOM` |
| **Profil source** | `src-postgres-fastmarket-VOTRE_NOM` |
| **Profil de destination** | `dst-bigquery-analytics-VOTRE_NOM` |
| **Objets sources à répliquer** | Schéma et tables qui vous ssemblent logiques |
| **Nom du jeu de données BigQuery cible** | Déduit du nom de la source ou personnalisé |
| **Fraicheur des données*** | 5 minutes | (sera modifier après tests)
| Methode d'ajout | Append | 

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
     VALUES ('test.cdc@mail.com', 'hash123', 'Thomas', 'Pesquet', 'France');
     ```
   * Dans BigQuery, interrogez la table `users` correspondante :
     ```sql
     SELECT * FROM `fastmarket_shop_cdc.users` 
     WHERE email = 'test.cdc@mail.com';
     ```
   * **Constatez :** La ligne apparaît dans BigQuery, sans jamais avoir exécuté d'export ou de script batch !

> ⚠️ les analystes ont besoin d'une fraîcheur de la donnée quotidienne. 
**Modifier** la fraîcheur des données de manière appropriée. /!\ garder en tête que plus la donner fraîche, plus les coups seront élevés!
