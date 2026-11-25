# 🛡️ Activité Pratique : Audit & Mise en Production Post-Migration
## Résilience, Sécurité, RPO/RTO et Arbitrage FinOps sur Google Cloud SQL

> **Module :** Architecture Data Cloud sur Google Cloud Platform — Jour 1  
> **Niveau :** Master 2 Informatique / Cloud & Data Architecture  
> **Format :** En binôme ou individuel | **Durée estimée :** 1h30  
> **Livrable :** Rapport d'audit de mise en production (captures d'écran avant/après console + justification des arbitrages dans la matrice FinOps)  

---

## 🎯 Objectifs de l'Activité

* **Auditer en conditions réelles** les alertes de sécurité et de résilience d'une instance Cloud SQL PostgreSQL via la Console GCP.
* **Maîtriser les arbitrages RPO (*Recovery Point Objective*) et RTO (*Recovery Time Objective*)** en configurant les sauvegardes automatiques et le *Point-in-Time Recovery* (PITR).
* **Sécuriser les flux d'accès** à la base de données en éliminant les expositions réseau critiques depuis l'interface d'administration.
* **Comprendre la mécanique des 3 types de réplication cloud** : Haute Disponibilité (HA), Read Replica et Réplication Logique (CDC).
* **Adopter une posture d'Architecte Senior (FinOps & Risques)** : savoir quand activer une option en production et quand la refuser en environnement de test.

---

## 🚨 Contexte : Le Bilan Post-Migration chez FastMarket

La base de données monolithique de FastMarket a été importée sur Google Cloud SQL (`pg-fastmarket`). L'application répond, les données sont en place et le CDC Datastream est opérationnel vers BigQuery.

Cependant, avant de donner le feu vert pour basculer le trafic réel des clients, le CTO ouvre la console Google Cloud et constate une série de **badges d'avertissement jaunes et rouges**.

Votre rôle : **mener l'audit dans l'interface Cloud SQL, configurer les paramètres de résilience et de sécurité requis, et justifier chaque décision technique et budgétaire.**

---

## 📋 Mission 1 : L'Audit Visuel dans la Console GCP

Accédez à la console Google Cloud dans le menu **Cloud SQL** et ouvrez la vue détaillée de votre instance `pg-fastmarket`.

Inspectez attentivement l'onglet **Présentation** (*Overview*) et identifiez les alertes remontées par Google :

| Composant | Message d'avertissement console | Niveau de gravité perçu |
|---|---|:---:|
| **Sauvegarde** | ⚠️ *Automated backups are disabled* | Critique |
| **Restauration** | ⚠️ *Point-in-time recovery (PITR) is disabled* | Critique |
| **Disponibilité** | ⚠️ *Single zone instance (No High Availability)* | Majeur |
| **Réseau** | ⚠️ *Public IP enabled with authorized network 0.0.0.0/0* | Bloquant |
| **Chiffrement** | ⚠️ *SSL connections not enforced* | Majeur |
| **Gouvernance** | ⚠️ *Deletion protection is disabled* | Majeur |
| **Réplication** | ⚠️ *No Read Replicas configured* | Informatif |

---

## 💾 Mission 2 : Sauvegardes & PITR (Enjeux RPO / RTO)

### 💥 La Mise en Situation : Le Cauchemar du Vendredi Soir
> *« Vendredi, 16h12. Un développeur exécute par mégarde un script contenant :*  
> ```sql
> DELETE FROM orders; -- Oups, la clause WHERE a sauté !
> ```
> *La dernière sauvegarde quotidienne automatique a eu lieu la nuit précédente à 03h00 du matin. »*

### ❓ Questions d'analyse à résoudre :
1. **RPO Réel :** Combien d'heures précises de chiffre d'affaires et de commandes venez-vous de perdre définitivement si vous restaurez le backup de 03h00 ?
2. **Mécanisme technique :** Pourquoi une sauvegarde snapshot quotidienne est-elle incapable de restaurer la table à l'état de 16h11, alors que le **Point-in-Time Recovery (PITR)** le permet ? Quel composant interne de PostgreSQL rend cette prouesse possible ?

---

## 🔄 Mission 3 : Réplication & CDC — L'Arbitrage Architectural

Tous les mécanismes de réplication ne répondent pas aux mêmes problématiques.

### 🧩 Exercice : Associer le Problème Métier à la Technologie Adéquate

Identifiez pour chaque situation le mécanisme Cloud SQL approprié (**Haute Disponibilité Régionale**, **Read Replica**, ou **Réplication Logique / Datastream**) :

* **Scénario A :** *« Le datacenter de la zone A prend feu ou subit une rupture électrique totale : le site doit basculer automatiquement sur la zone B sans intervention humaine et sans perte de données. »*
* **Scénario B :** *« Lors des soldes, 95% du trafic correspond à des consultations du catalogue. Le CPU de la base primaire approche les 100%. »*
* **Scénario C :** *« L'équipe Data Analyst veut recevoir en direct chaque commande validée dans BigQuery pour piloter les stocks en temps réel. »*

---

### ⚠️ Le Piège Réel de Conception :
> **Question posée par le CTO en réunion d'architecture :**  
> *« Pour décharger totalement notre base principale, pouvons-nous brancher notre flux Datastream (CDC) sur un Read Replica plutôt que sur l'instance Primaire ? »*
>
> ❌ **Que lui répondez-vous ? Pourquoi la documentation officielle de Google Cloud l'interdit-elle formellement ?**  
> *(Indice : que deviennent les slots de réplication logique si le réplica est redémarré ou recréé par la maintenance Google ?)*

---

## ⚖️ Mission 4 : L'Arbitrage FinOps & Sécurité (Rapport pour le CTO)

Chaque case cochée dans la console a un impact direct sur la facture et les performances. 

Complétez le tableau d'arbitrage suivant pour acter la politique officielle de l'entreprise :

| Avertissement Cloud SQL | Risque opérationnel si ignoré | Impact Coût / Performance | Décision en DEV | Décision en PRODUCTION |
|---|---|---|:---:|:---:|
| **IP `0.0.0.0/0`** | Attaque brute-force / scans sur le port 5432 | 0 € (saturation réseau potentielle) | Toléré temporairement | ❌ **INTERDIT** (VPC Privé / Auth Proxy) |
| **Backups & PITR désactivés** | Perte définitive des données métier | Stockage léger des WALs | Désactivé (économie) | ✅ **OBLIGATOIRE** (RPO à la seconde) |
| **Single Zone (No HA)** | Arrêt de service si incident de zone | **Facture Cloud SQL × 2** | ❌ **Désactivé** | ✅ **OBLIGATOIRE** (RTO < 60s) |
| **Deletion Protection = false** | Suppression accidentelle de l'instance | 0 € | Désactivé | ✅ **OBLIGATOIRE (`true`)** |
| **SSL non imposé** | Interception des identifiants et données en clair | Négligeable | Toléré | ✅ **OBLIGATOIRE (`ENCRYPTED_ONLY`)** |
| **Logical Decoding activé** | Flux CDC Datastream impossible | Légère surcharge I/O sur les WALs | ✅ **Activé (pour le TP)** | ✅ **Activé (si besoin CDC)** |

---

## 🛠️ Mission 5 : Plan d'Action Pratique dans la Console GCP

Vous devez maintenant naviguer dans l'interface de Cloud SQL pour appliquer les corrections de niveau production sur votre instance `pg-fastmarket`.

> ⚠️ **Consigne Pédagogique :**  
> L'interface d'administration Cloud regroupe des dizaines d'écrans de configuration. À vous de trouver les bons menus, sections et options dans la console pour atteindre les objectifs ci-dessous **sans aide pas-à-pas**.

---

### 🎯 Défi 1 : Mettre en place un RPO de 0 seconde (Sauvegardes & PITR)
* **Objectif :** Éliminer les deux avertissements critiques liés à la perte de données.
* **Cahier des charges :**
  1. Activer les sauvegardes quotidiennes automatiques en choisissant une fenêtre horaire nocturne adaptée à un site e-commerce français (creux de trafic).
  2. Activer la récupération à un moment précis dans le temps (**Point-in-Time Recovery**).
  3. Conserver un historique de journaux de transactions (WAL) de **7 jours**.
* 🔍 **Observation attendue :**  
  * *Que se passe-t-il au niveau de l'instance lors de l'enregistrement ? Pourquoi Google affiche-t-il un message d'avertissement spécifique concernant la disponibilité de la base ?*
  * *Dans quel onglet de la console pouvez-vous suivre l'opération en cours et constater le redémarrage effectif ?*

---

### 🎯 Défi 2 : Durcir la Sécurité Réseau & Chiffrer les Flux
* **Objectif :** Éliminer l'accès universel non sécurisé tout en conservant vos accès pour les TPs.
* **Cahier des charges :**
  1. Repérer où est configurée l'autorisation `0.0.0.0/0`.
  2. Restreindre l'accès réseau : remplacez `0.0.0.0/0` par votre propre adresse IP publique de connexion (ou l'adresse IP fixe de votre passerelle).
  3. Localiser l'option qui impose le chiffrement des communications et configurer l'instance pour refuser toute connexion non chiffrée par **SSL/TLS**.
* 🔍 **Vérification :**  
  * *Quel est le libellé exact de l'option choisie pour le SSL ?*
  * *Le badge rouge d'exposition réseau a-t-il disparu de l'onglet de présentation ?*

---

### 🎯 Défi 3 : Sécurité de Gouvernance anti-erreur humaine
* **Objectif :** Empêcher qu'un administrateur ou un script ne détruise l'instance par erreur.
* **Cahier des charges :**
  1. Trouver et activer la protection contre la suppression de l'instance (*Deletion Protection*).
  2. Tenter de supprimer l'instance via le bouton d'action de la console pour tester l'efficacité de la protection.
* 🔍 **Résultat attendu :**  
  * *Quel message d'erreur précis la console renvoie-t-elle ?*

---

### 🎯 Défi 4 : Simulation FinOps Haute Disponibilité (Ne PAS appliquer !)
* **Objectif :** Estimer l'impact financier de la Haute Disponibilité sans impacter vos crédits cloud.
* **Cahier des charges :**
  1. Localiser l'option permettant de transformer votre instance actuelle en instance **Haute Disponibilité (plusieurs zones)**.
  2. Observer l'estimation du coût mensuel calculée par la console en bas ou à droite de l'écran de modification.
  3. **Annuler la modification** sans valider.
* 🔍 **Question FinOps :**  
  * *Quel est le surcoût mensuel exact en pourcentage et en euros pour passer en multi-zone ?*

---

## ✍️ Questions de Synthèse & Restitution

Pour valider votre activité, préparez les réponses aux questions suivantes pour votre soutenance ou rapport :

1. **RPO vs RTO :**  
   * Quelle est la définition exacte de chaque terme ?
   * Quel paramètre configuré dans le Défi 1 minimise le RPO ?
   * Quel paramètre simulé dans le Défi 4 minimise le RTO ?
2. **Fenêtre de maintenance :** Pourquoi la modification de certains paramètres (PITR, flags PostgreSQL, instance type) ne doit-elle **jamais** être réalisée en journée sur une base e-commerce ?
3. **Architecture Cible :** Pourquoi préconise-t-on d'utiliser **Cloud SQL Auth Proxy** ou **Private Service Connect (PSC)** plutôt que de renseigner des IP autorisées (*Authorized Networks*) dans un environnement d'entreprise ?

Reponse


Mission 1 : audit visuel
 
Mission 2 : sauvegardes et PITR
1.	RPO réel : entre 03h00 et 16h12, on perd 13 h 12 min de commandes, définitivement.
2.	Mécanisme : un snapshot est une photo figée à un instant T, il ne contient rien de ce qui s'est passé après. Le PITR restaure le dernier backup puis rejoue les journaux de transactions jusqu'à la seconde voulue

Mission 3 : réplication
Scénario	Mécanisme
A : feu dans la zone, bascule automatique sans perte	Haute Disponibilité régionale (réplication synchrone vers une autre zone)
B : 95 % de lectures, CPU saturé	Read Replica (on redirige les SELECT du catalogue)
C : chaque commande en direct dans BigQuery	Réplication logique / Datastream (CDC)

Mission 5 : la console
Défi 1 : sauvegardes et PITR
