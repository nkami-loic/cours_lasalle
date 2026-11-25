---
marp: true
theme: gaia
_class: lead
paginate: true
backgroundColor: #f8fafc
color: #0f172a
header: "Architecture Data Cloud — M2 Informatique"
footer: "Résilience, Continuité d'Activité & Sécurité Réseau | FastMarket Case"
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

# Résilience, Haute Disponibilité & Réseau Cloud SQL
## De la Continuité d'Activité à la Sécurité Réseau Zéro Trust


1. **Backups Automatisés** 
2. **Read Replicas** 
3. **Point-In-Time Recovery - PITR** 
4. **Le Spectre Réseau** : Du pire (*IP Publique*) au meilleur (*PSC*)

---

## 🧭 Vue d'ensemble : Les Défis Post-Migration

Une base de données migrée dans le Cloud n'est **pas automatiquement prête pour la production**.

Deux exigences non négociables incombent à l'Architecte Cloud :

1. **La Résilience & Continuité d'activité** :
   * *Que se passe-t-il si un développeur supprime une table ?* (RPO)
   * *Que se passe-t-il si le CPU explose à cause des lectures ?* (Scale-out)
   * *Que se passe-t-il en cas de corruption de données à 15h42 ?* (PITR)

2. **L'Herméticité Réseau & Sécurité** :
   * *Comment exposer la base aux microservices sans ouvrir la porte à tout Internet ?*
   * *Comment naviguer entre simplicité temporaire et standards bancaires/RGPD ?*

---

<!-- _class: lead -->

# 📦 Thème 1 : Les Backups Automatisés
### *L'assurance tous risques des données*

---

## 1.1 Backups : Concept & Objectif Métier

> **Objectif :** Créer une copie d'état complète et régulière de la base pour se prémunir d'une destruction majeure (sinistre, crash disque, suppression de base).

* **Périodicité typique :** Quotidienne, déclenchée dans une **fenêtre de maintenance creuse** (ex: 03h00 du matin).
* **Impact sur le RPO (*Recovery Point Objective*) :**
  * Le RPO correspond au **volume maximal de données que l'entreprise accepte de perdre**.
  * Avec un backup unique à 03h00, si un crash survient à 23h00 :
    $$\text{RPO Réel} = 20\text{ heures de chiffre d'affaires perdu !}$$
* **Nécessaire mais insuffisant :** Un backup quotidien protège contre la mort de la machine, mais est catastrophique pour un incident en journée.

---

## 1.2 Backups : Fonctionnement sous le capot

Cloud SQL n'exécute pas un `pg_dump` texte qui saturerait le CPU et bloquerait les tables !

* **Snapshot persistant au niveau bloc (Storage Layer) :**
  * Le moteur Cloud SQL fige brièvement les métadonnées de stockage et prend un **snapshot** du disque persistant Google Cloud.
  * Impact I/O négligeable sur les transactions applicatives en cours.
* **Stockage géorégional automatique :**
  * Les sauvegardes Cloud SQL sont répliquées par Google dans plusieurs zones ou régions pour survivre à la destruction du datacenter principal.
* **Rétention configurable :**
  * Par défaut de 1 à 365 sauvegardes conservées (politique standard : 7 à 30 jours pour l'audit et la conformité).

---

## 1.3 Backups : Bonnes Pratiques & Limites

* ⚠️ **Ce qu'un backup classique NE PEUT PAS faire :**
  * Impossible de revenir à 14h25 si le backup a été pris à 03h00.
  * La restauration recrée une **nouvelle instance** avec une nouvelle IP :
    $$\text{RTO (\textit{Recovery Time Objective})} = \text{Temps de reprovisioning de la VM} + \text{Restauration du snapshot}$$
> 🎯 **Règles d'or en Production :**
> 1. Fixer l'heure de sauvegarde durant le creux d'activité de l'e-commerce (ex: 02h00 - 05h00 locale).
> 2. Activer `deletion_protection = true` pour interdire la suppression accidentelle de l'instance et de ses sauvegardes associées.
> 3. **Tester régulièrement la procédure de restauration** : une sauvegarde non testée n'existe pas!

---

<!-- _class: lead -->

# ⚡ Thème 2 : Les Read Replicas
### *Délestage horizontal et scalabilité des lectures*

---

## 2.1 Read Replica : Définition & Cas d'Usage

> **Principe :** Créer une ou plusieurs copies en lecture seule (*Read-Only*) de l'instance primaire pour absorber la charge de consultation.

* **Cas d'usage emblématique (90/10) :**
  * 90% du trafic = Catalogue produits, recherche, consultation panier (Lectures).
  * 10% du trafic = Validation commande, paiement, mise à jour stock (Écritures).
* **Bénéfice immédiat :**
  * L'instance primaire réserve 100% de ses IOPS et CPU aux transactions critiques (`INSERT`, `UPDATE`, `DELETE`).
  * Les microservices de consultation interrogent l'IP du **Read Replica**.
* **Coût FinOps :** Chaque réplica est une VM Cloud SQL facturée à 100%.

---

## 2.2 Read Replica : Mécanisme de Réplication

Cloud SQL s'appuie sur le mécanisme natif de **Streaming Replication PostgreSQL** :

```
[ Instance Primaire (RW) ]
         │
         │  1. Écritures dans le WAL (Write-Ahead Log)
         ▼
[ Envoi continu des WALs via réseau privé ]
         │
         ▼  2. Replay en continu des transactions
[ Read Replica (RO) ]
```

* **Réplication Asynchrone :** L'instance primaire n'attend pas l'accusé de réception du réplica pour acquitter la transaction au client.
* **Replication Lag :** Délai (en ms ou secondes) entre l'écriture primaire et sa visibilité sur le réplica.
  * *Attention à la consistance éventuelle !* Un utilisateur qui modifie son profil puis rafraîchit immédiatement peut lire une donnée périmée si la lecture va sur le réplica.

---

## 2.3 Read Replica : Pièges & Erreurs Classiques

* ❌ **Piège n°1 : Le confondre avec la Haute Disponibilité (HA)**
  * Un Read Replica n'a **pas de failover automatique** transparent pour l'application. Si la primaire meurt, le réplica doit être promu manuellement.
  * Pour la tolérance aux pannes matérielles transparentes, utiliser l'option `availability_type = "REGIONAL"`.

* ❌ **Piège n°2 : Y brancher un outil de CDC (Datastream)**
  * *« Branchons Datastream sur le réplica pour ne pas toucher à la prod ! »*
  * **Interdiction formelle GCP :** Lors d'une maintenance ou panne du réplica, les slots de réplication logique sont **détruits**. Le pipeline CDC vers BigQuery casse définitivement.

* ✅ **Règle d'architecture :**
  * Read Replica = **Scaling des requêtes OLTP en lecture**.
  * CDC / BigQuery = **Déportation analytique OLAP**.

---

<!-- _class: lead -->

# ⏱️ Thème 3 : Le Point-in-Time Recovery (PITR)
### *La machine à remonter le temps pour sauver la production*

---

## 3.1 PITR : Le Concept & la Valeur Métier

> **Mise en situation :**  
> Vendredi 16h12, un script de migration supprime la table `orders` (`DELETE FROM orders;` sans `WHERE`).  
> Le dernier backup date de 03h00 du matin.

* **Sans PITR :** 13h12 de ventes perdues à jamais (ou ressaisies à la main).
* **Avec le PITR :**
  * On ordonne à Cloud SQL de restaurer l'instance à :  
    **Vendredi 16h11m59s** (1 seconde avant la gaffe du développeur).
  * **RPO Métier obtenu = $\approx 0$ seconde !**
* Le PITR transforme une catastrophe industrielle fatale pour l'entreprise en un simple incident d'exploitation maîtrisé.

---

## 3.2 PITR : Fonctionnement Technique (WAL Replay)

Le PITR repose sur l'association de **deux composants indissociables** :

1. **Le dernier Snapshot de stockage complet** (pris à $T_0$, ex: la nuit dernière).
2. **L'archivage continu des Write-Ahead Logs (WAL)** : chaque transaction validée (`COMMIT`) est immédiatement archivée dans Cloud Storage.

```
[ Snapshot Nuit 03:00 ] 
         │
         ▼
[ Replay séquentiel des WALs transaction par transaction... ]
   ├── 03:01 OK
   ├── 08:30 Vente #1402
   ├── 16:11 Vente #8990
   └── [ STOP à 16:11:59 ] ──X (Ignore le DELETE de 16:12:00)
```

---

## 3.3 PITR : Contraintes Opérationnelles & Pièges

* ⚠️ **Prérequis technique obligatoire :**
  * Le PITR ne peut pas fonctionner sans les **Automated Backups activés**.
* ⚠️ **Le piège de l'activation en plein jour :**
  * Activer le PITR sur Cloud SQL PostgreSQL modifie le paramétrage du moteur WAL $\rightarrow$ **provoque un redémarrage immédiat de l'instance** !
  * *Ne jamais l'activer un vendredi après-midi sans fenêtre de coupure annoncée.*
* 💰 **Impact FinOps :**
  * Conserve entre 1 et 7 jours de journaux WAL sur Cloud Storage.
  * Léger coût de stockage d'objets, largement rentabilisé par la sécurité apportée.
* 🛠️ **Restauration vers une nouvelle instance :**
  * Cloud SQL crée une instance clonée (ex: `pg-fastmarket-recovered`).
  * Il faut ensuite faire pointer les applications vers la nouvelle IP.

---

<!-- _class: lead -->

# 🌐 Partie 4 : Le Spectre Réseau Cloud SQL
### *De l'IP publique au standard Zero Trust (PSC)*

---

## 🗺️ Pourquoi la Sécurité Réseau est Capitale ?

Une base de données contient le **patrimoine le plus précieux** de l'entreprise :
* Données personnelles des clients (RGPD / PII).
* Coordonnées bancaires, cartes de paiement (PCI-DSS).
* Données financières, commandes, stocks stratégiques.

La défense en profondeur exige de **rendre la base invisible depuis Internet**.

Nous allons étudier les **5 niveaux de maturité réseau**, du pire au meilleur :

$$\text{Niveau 1} \longrightarrow \text{Niveau 2} \longrightarrow \text{Niveau 3} \longrightarrow \text{Niveau 4} \longrightarrow \text{Niveau 5 (Graal)}$$

---

## ❌ Niveau 1 (Le Pire) : IP Publique sans restriction (`0.0.0.0/0`)

* **Configuration :**
  ```hcl
  ip_configuration {
    ipv4_enabled = true
    authorized_networks {
      name = "all"
      value = "0.0.0.0/0" # Porte ouverte au monde entier !
    }
  }
  ```
* 💣 **Pourquoi c'est catastrophique :**
  * Le port PostgreSQL `5432` est exposé publiquement sur Internet.
  * Des robots scannent et tentent des attaques *brute-force* H24.
  * Risque maximal d'exfiltration en cas de mot de passe faible.
* 📍 **Cas d'usage réel :** **AUCUN en entreprise !** Uniquement toléré dans un TP étudiant éphémère.

---

## ⚠️ Niveau 2 : IP Publique avec Réseaux Autorisés & SSL

* **Configuration :** IP Publique activée, mais filtrée sur des IP fixes strictes + `ssl_mode = "ENCRYPTED_ONLY"`.
  ```hcl
  authorized_networks {
    name  = "siege-paris"
    value = "195.154.120.45/32" # IP publique de sortie de l'entreprise
  }
  ```
* ⚖️ **Avantages & Limites :**
  * ✅ Bloque les scanners d'Internet non autorisés.
  * ❌ Inadapté au télétravail : les box des développeurs ont des IP dynamiques.
  * ❌ Le trafic transite par l'Internet public (bien que chiffré par TLS).
* 📍 **Cas d'usage concret :**
  * Startup connectant un serveur hébergé chez OVHcloud à Cloud SQL sans mettre en place de VPN dédié.

---

## 🛡️ Niveau 3 : Cloud SQL Auth Proxy & IAM Connectors

* **Principe :** Un binaire open-source léger (*sidecar* ou poste local) crée un **tunnel chiffré mTLS** vers Cloud SQL.
* 🔑 **Authentification 100% IAM Google Cloud :**
  * Pas besoin de whitelister d'adresse IP !
  * Le proxy négocie des certificats éphémères renouvelés automatiquement toutes les heures via le compte de service IAM (`roles/cloudsql.client`).

```
[ App / Dev Mac ] ──► (localhost:5432) ──► [ Auth Proxy ]
                                                 │ Tunnel mTLS (Port 3307)
                                                 ▼
                                        [ Cloud SQL Instance ]
```

* 📍 **Cas d'usage concret :**
  * Développeurs accédant à la base de dev depuis leur machine personnelle.
  * Pods Kubernetes (GKE) ou Cloud Run exécutant le proxy en conteneur compagnon.

---

## 🔒 Niveau 4 : Private Services Access (VPC Peering)

* **Principe :** Assigner à Cloud SQL une **IP purement privée RFC 1918** (ex: `10.128.0.5`) via un Peering VPC entre votre VPC et le VPC managé de Google.

```
[ Votre VPC Entreprise : 10.0.0.0/16 ]
       │
       └── (VPC Network Peering direct)
                   │
                   ▼
[ Google Managed Tenant VPC : 10.128.0.0/20 ] ──► [ Cloud SQL (10.128.0.5) ]
```

* ⚖️ **Avantages & Limites :**
  * ✅ **Zéro trafic sur Internet**, IP invisible de l'extérieur.
  * ❌ **Problème de l'IP Overlap :** Consomme un bloc d'IP entier (`/24` ou `/20`).
  * ❌ **Non-transitif :** Difficile à router depuis un datacenter on-premise connecté en VPN sans Cloud Routers complexes.
* 📍 **Cas d'usage concret :** Architecture GCP classique monolithique mono-VPC.

---

## 🏆 Niveau 5 (Le Graal) : Private Service Connect (PSC)

> **Private Service Connect (PSC)** est le standard d'architecture moderne Zero-Trust de Google Cloud pour consommer des services managés.

* **Comment ça marche ?**
  * Cloud SQL expose un **Service Attachment**.
  * Vous créez un **Endpoint PSC** (une simple IP interne) directement **dans le sous-réseau de votre choix** au sein de votre VPC.

```
[ Votre VPC (Projet A) : 10.10.1.0/24 ]
    └── IP Endpoint PSC : 10.10.1.50 ── (Liaison L4 unidirectionnelle)
                                                    │
                                                    ▼
[ Projet Managé Google ] ─────────────► [ Cloud SQL Instance ]
```

---

* 🎯 **Pourquoi PSC surpasse le VPC Peering :**
  1. **Zéro conflit d'IP (*No Overlap*) :** Ne monopolise qu'une seule adresse IP.
  2. **Transitivité totale :** Immédiatement accessible depuis On-Premise via VPN/Interconnect ou depuis d'autres VPCs.
  3. **Sécurité d'isolation maximale :** Connexion unidirectionnelle producteur/consommateur.

---

## 🏢 Cas d'Usage Concrets : Quand utiliser quoi ?

| Niveau Réseau | Mécanisme | Sécurité | Complexité | Cas d'usage recommandé |
|---|---|:---:|:---:|---|
| **1. Wildcard** | `0.0.0.0/0` | 🔴 Nulle | Très faible | ❌ **Strictement interdit en entreprise** (TP jetable uniquement). |
| **2. Auth Networks** | Whitelist IP + SSL | 🟠 Faible | Faible | Partenaire tiers ou passerelle fixe externe temporaire. |
| **3. Auth Proxy** | Tunnel IAM mTLS | 🟢 Élevée | Moyenne | Développeurs nomades, Cloud Run, Cloud Functions, GKE. |
| **4. PSA Peering** | VPC Peering IP Privée | 🟢 Bonne | Élevée | Infrastructure simple hébergée 100% sur un seul VPC GCP. |
| **5. PSC (Graal)** | Private Service Connect | 🟣 Maximale | Standard | **Grandes entreprises, multi-VPC, hybride on-premise, fintech.** |

---

<!-- _class: lead -->

# 🏁 Synthèse : La Checklist de l'Architecte

1. **Backups Automatisés :** Obligatoires pour parer à la perte de l'infrastructure.
2. **Point-in-Time Recovery (PITR) :** Obligatoire pour garantir un **RPO à la seconde** contre les erreurs humaines et logicielles.
3. **Read Replicas :** Réservés au **délestage des lectures applicatives (OLTP)**, jamais pour de l'analytique CDC lourd.
4. **Sécurité Réseau :** Bannir l'IP publique. Privilégier **Cloud SQL Auth Proxy** pour les devs et **PSC (Private Service Connect)** pour l'interconnexion d'entreprise.
