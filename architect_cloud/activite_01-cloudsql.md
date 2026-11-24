# 🛠️ Activité Pratique : Déploiement Cloud SQL & Import de Données

> **Module :** Architecture Data Cloud sur Google Cloud Platform — Jour 1  
> **Niveau :** Master 2 Informatique / Cloud & Data Architecture  
> **Format :** Individuel | **Durée estimée :** 45 minutes  

---

## 🎯 Objectifs

* Découvrir et manipuler un service de base de données managé en mode **PaaS / DBaaS** (*Google Cloud SQL*).
* Déployer une instance PostgreSQL selon un **cahier des charges de production**.
* Réaliser une **restauration de données** à partir d'un dump stocké sur **Google Cloud Storage (GCS)**.

---

## 📋 Étape 1 : Création de l'Instance Cloud SQL

Depuis la **Console Google Cloud Platform (GCP)**, créez une nouvelle instance Cloud SQL en respectant scrupuleusement le cahier des charges ci-dessous :

| Paramètre | Valeur attendue |
|---|---|
| **Moteur de base de données** | PostgreSQL |
| **Version du moteur** | PostgreSQL 16 |
| **Édition** | Enterprise edition |
| **ID de l'instance** | `fastmarket-VOTRE_NOM` *(ex: `fastmarket-jolafrite`)* |
| **Région & Zone** | Belgique (`europe-west1`) |
| **Configuration machine** | Shared-core / Usage général (1 vCPU, 0.614 Go RAM — `db-f1-micro`) |
| **Stockage** | SSD — 10 Go |
| **Connectivité réseau** | Adresse IP publique activée |
| **Observabilité** | Query Insights activé |

> 💡 **Pendant la création de l'instance (3 à 5 minutes) :**  
> Explorez les différents onglets de configuration (*Sauvegardes*, *Maintenance*, *Drapeaux de base de données*, *Protection contre la suppression*). Notez les différences fondamentales avec l'administration d'un serveur VM classique.

---

## 📥 Étape 2 : Importation de la Base de Données

Un export SQL de l'application monolithique FastMarket a été mis à disposition dans le bucket Cloud Storage :  
`gs://migration-fastmarket-db`

### Votre Mission :
1. Créez la base de données cible sur votre instance : **`fastmarket_shop`**.
2. Réalisez l'importation du fichier SQL depuis le bucket vers votre base de données.

> ⚠️ **Indice d'Architecture & Sécurité :**  
> Si l'importation échoue ou indique un refus d'accès, posez-vous la question suivante :  
> *Quel compte ou composant tente réellement de lire le fichier dans le bucket Cloud Storage, et dispose-t-il des autorisations nécessaires ?*

---

## ✅ Étape 3 : Validation

Une fois l'importation terminée :
1. Connectez-vous à votre base de données (via la console ou votre client habituel).
2. Vérifiez que les tables applicatives (`users`, `products`, `orders`, `order_items`, `payments`) sont bien créées et contiennent des données.
