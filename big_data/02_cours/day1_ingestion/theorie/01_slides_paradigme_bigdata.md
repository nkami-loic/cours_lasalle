---
marp: true
theme: gaia #default
_class: lead
paginate: false
backgroundColor: #eaeaf2ff
header: "Formation Intro Big Data — Module 1.1 : Le Paradigme Big Data"
footer: "La Salle "
---

# 🚀 Module 1.1 : Le Paradigme Big Data

---

## 📌 Ordre du Jour
1. Le Flux de Données (Cycle de vie & ETL vs ELT)
2. Les 5 V du Big Data 
3. Où atterrissent les données ? (Data Lake, Warehouse, Lakehouse)
4. Bases Transactionnelles (OLTP) vs Analytiques (OLAP) & Stockage Colonnaire
5. Découplage Stockage / Calcul & Architecture Cloud (BigQuery)
6. Et que dit le futur ? (DuckDB, « Big Data is Dead » & Small Data)

---

## 1.  Le Flux de Données 🔄
📥 **1. Collecte & Stockage**
Ingestion brute des sources (APIs, logs, bases) ➔ *GCS / BigQuery Bronze*

⚙️ **2. Préparation & Nettoyage**
Typage, déduplication, enrichissement ➔ *dbt (data build tool) : framework sql pour transformer la donnée via du code SQL versionné.*

🔍 **3. Exploration & Visualisation**
Analyse descriptive et tableaux de bord ➔ *SQL BigQuery & Looker Studio*

📈 **4. Description & Prédiction**
Indicateurs décisionnels (BI) et modèles prédictifs (Machine Learning)

---

## 1.1 ⏳ L'Approche Historique : ETL **Extract ➔ Transform ➔ Load**

- **Fonctionnement :**
  1. **Extract** : Extraction des données depuis les sources (ERP, CRM, SQL).
  2. **Transform** : Nettoyage et agrégation sur un **serveur intermédiaire dédié**
  3. **Load** : Chargement uniquement du résultat final dans le Data Warehouse.
- **Pourquoi ce choix à l'époque ?**
  - Le stockage sur disque et les bases de données coûtaient très cher.
- **Inconvénients majeurs :**
  - ⚠️ **Goulot d'étranglement** : Le serveur de transformation sature vite.
  - ⚠️ **Perte du brut** : Si le besoin métier change, impossible de rejouer l'historique sans réextraire la source.

---

## 1.2  🚀 Le Paradigme Moderne : ELT **Extract ➔ Load ➔ Transform**

- **Fonctionnement :**
  1. **Extract** : Extraction brute rapide des sources (APIs, logs, bases).
  2. **Load** : Ingestion directe de la **donnée brute** dans le Cloud.
  3. **Transform** : Transformation *in-situ* avec la puissance de calcul distribué du Cloud (*dbt, SQL BigQuery*).
- **Pourquoi c'est la norme du Big Data ?**
  - 💾 **Stockage virtuellement illimité et "relativement" abordable** : On conserve 100% des données brutes -> _Notion du Data Lake_
  - ⚡ **Scalabilité massive** : On calcule en quelques secondes sur des téraoctets.
  - 🔄 **Flexibilité totale** : Les règles changent ? On re-transforme sans réinterroger les sources !

---

## 2. Les 5 V du Big Data

On définit le Big Data par les 5 V :

- **📦 Volume** : 
- **⚡ Vélocité** : 
- **🔀 Variété** : 
- **🎯 Véracité** : 
- **💡 Valeur** : 

--- 

## 2. Les 5 V : Ce que l'ingénieur se demande 🛠️

- **📦 Volume** : *« Mes données tiennent-elles encore en RAM sur une seule machine, ou dois-je passer au stockage et calcul distribué ? »*
- **⚡ Vélocité** : *« À quelle fréquence arrivent les données et sous quel délai le métier en a-t-il besoin : Batch quotidien (nuit) ou Streaming temps réel à la seconde (Pub/Sub, Beam) ? »*
- **🔀 Variété** : *« Quels sont les formats sources (tables SQL, JSON imbriqués, fichiers bruts) et comment gérer l'évolution des schémas ? »*
- **🎯 Véracité** : *« Les données sont-elles fiables, complètes et intègres ? Comment détecter les anomalies et automatiser les tests (dbt test, contrats) ? »*
- **💡 Valeur** : *« Quel est le ROI métier face aux coûts d'infrastructure ? Est-ce que cette donnée génère plus de valeur qu'elle ne coûte à stocker et requêter ? »*


---

## 2.1 🛍️ Exemple: Startup E-commerce TheLook - 500k clients

- **📦 Volume** : 10 000 commandes/jour, mais **5 millions d'événements de clics et vues par jour** (*clickstream*) ➔ des dizaines de Go/jour.
- **⚡ Vélocité** : Pendant les soldes (Black Friday), pics à 2 000 requêtes/sec. Détection de fraude et gestion des stocks en temps réel.
- **🔀 Variété** : Base SQL (utilisateurs, paiements) + flux JSON (logs web & panier) + avis clients non-structurés.
- **🎯 Véracité** : Filtrer le trafic des bots, éliminer les paniers fantômes et gérer les erreurs de paiement...
- **💡 Valeur** : Moteur de recommandation personnalisé (+15% de conversion) et réapprovisionnement prédictif des stocks.

---

## 3.1 🔄 Où atterrissent ces données ? (Le réceptacle de l'ELT)

Face aux 5 V de TheLook, l'architecture sépare nettement le brut de l'analytique :

- **📥 Ingestion brute dans le Data Lake (ex: Google Cloud Storage / S3)** :
  - **Extract & Load** : logs JSON, clics de navigation, exports SQL sont déversés tels quels (fichiers bruts).
  - Coût de stockage minime, format ouvert (Parquet, JSON, Avro), historique 100% conservé.
- **⚡ Préparation & Analyse dans le Data Warehouse (ex: BigQuery)** :
  - **Transform** : données nettoyées, structurées et prêtes pour le SQL métier.
  - Performance ultra-rapide par calcul distribué. C'est l'essence même de l'**ELT** !

---

## 3.2 🏛️ Data Lake vs Data Warehouse vs Data Lakehouse

| Concept | Rôle principal | Formats & Données | Outils types |
| :--- | :--- | :--- | :--- |
| **Data Lake** | Stockage brut & volumineux | JSON, CSV, Parquet, Images | GCS, AWS S3, Azure ADLS |
| **Data Warehouse** | Requêtage SQL & Décisionnel (BI) | Tables structurées, gouvernées | BigQuery, Snowflake |
| **Data Lakehouse** | Le meilleur des deux mondes | Fichiers ouverts (Iceberg/Parquet) avec gouvernance SQL | BigLake, Databricks Delta |

> 💡 **En résumé** : En ELT, on charge d'abord tout dans le **Data Lake**, puis on transforme et modélise dans le **Data Warehouse** (ou directement via un **Lakehouse**).

---

## 4.1  Les types de bases de données: OLTP - OLAP
> Citez **au moins une base de données OLTP** que vous avez déjà utilisée ou rencontrée, et décrivez brièvement ses **cas d'usage typiques**.


- **Indices d'exemples** : il y a souvent SQL dans le nom...

---

## 4.2 Caractéristiques des bases de données: OLTP - OLAP

| Caractéristique | OLTP (ex: PostgreSQL, MySQL) | OLAP (ex: BigQuery, Snowflake) |
| :--- | :--- | :--- |
| **Objectif** | Transactions métier unitaires rapides | Analyse décisionnelle globale |
| **Organisation** | Stockage orienté **Lignes** | Stockage orienté **Colonnes** |
| **Volumétrie** | Mo/Go par requête | Go/To/Po par requête |
| **Écritures** | INSERT/UPDATE/DELETE fréquents | Ingestion massive (Append/Batch) |


---

## 4.3 Stockage en Lignes vs Stockage en Colonnes

- **Lignes (RDBMS)** :
  - `[ID_1, Nom, Prénom, Age, Adresse, ...]`
  - Lecture complète de la ligne nécessaire même pour calculer l'âge moyen.
- **Colonnes (BigQuery / Capacitor)** :
  - `Colonne Age : [25, 34, 19, 42, ...]`
  - Lecture **uniquement** du vecteur d'âges $\rightarrow$ réduction massive des I/O !

---

## 5.1 🌐 L'analogie du Web : Monolithe vs Microservices & Stateless

Pensez à la manière dont une application web évolue :

- **Le serveur classique (stateful & couplé)** :
  - Votre code tourne sur une machine virtuelle unique qui stocke aussi ses fichiers utilisateurs sur son disque local.
  - 💥 **Problème** : Pour gérer plus de trafic, on est obligé de grossir la machine (**scale-up**). Si elle crash, on perd tout.
- **L'application moderne (stateless & découplée)** :
  - L'application ne garde aucun état en local (Node.js/Python sur Cloud Run ou conteneurs).
  - Les fichiers vont sur un stockage dédié (**S3 / GCS**), la base sur un service géré.  
  🚀 **Résultat** : On peut instancier 100 conteneurs en 2 secondes en cas de pic, puis redescendre à zéro !

---

## 5.2 ⚙️ En Big Data : Le passage du couplé au découplé

La data a suivi exactement la même révolution que le web :

- **L'ère Hadoop / HDFS (Couplage Stockage + Calcul)** :
  - Chaque serveur du cluster possédait ses propres disques durs et ses CPUs.
  - 🛑 **Le piège financier et technique** :
    - Besoin de stocker 50 To d'archives sans calcul ? Obligé d'acheter des serveurs complets avec RAM + CPU inutilisés !
    - Un gros calcul ponctuel ? Limité par les CPUs des machines existantes.

- **Le Nouveau Standard : Le Découplage Total** : _on separe le `calcul` du `stockage`_
  - Le stockage est géré par une couche hautement disponible et quasi infinie.
  - Le calcul est un pool de CPU éphémères loués uniquement pendant l'exécution de la requête. _"C'est la définition même du Serverless/PaaS Data"_

---

## 5.3 ☁️ Exemple GCP : Sous le capot de BigQuery

BigQuery applique ce découplage à l'extrême grâce au réseau ultra-rapide de Google (Jupiter) :

```
       [ Calcul : Dremel ]      <-- Des milliers de Workers CPU alloués à la seconde
               ▲
               │ Réseau Pébifit/s (Jupiter)
               ▼
       [ Stockage : Colossus ]  <-- Fichiers colonnes Capacitor répliqués sur disque
```

- **Stockage (**Colossus / GCS**)** : Très peu cher (~0.02$/Go/mois), sécurisé, persistant.
- **Calcul (**Dremel Slots**)** : Alloué dynamiquement en millisecondes pour exécuter votre SQL sur des centaines de nœuds.
- 💡 **Le bénéfice concret** : Si aucune requête ne tourne, **le calcul coûte 0 €**. On ne paie que les secondes CPU consommées ou les Go scannés !

---

## Et que dit le futur du Big Data

_Quelques pistes de réflexion..._

---
## Le retour au local avec DuckDB 🦆

- **Le constat matériel** :
  - Un MacBook ou un PC moderne dispose aujourd'hui de 16 à 64 Go de RAM et de SSDs NVMe ultra-rapides (> 3 Go/s).
  - Est-il toujours nécessaire de déployer un cluster Spark ou d'utiliser le Cloud pour analyser quelques dizaines de Go ?
- **La révolution DuckDB ("le SQLite de l'OLAP")** :
  - Moteur SQL vectorisé, colonnaire et *in-process*.
  - Capable de requêter directement des fichiers Parquet/CSV locaux ou distants (S3/GCS) plus vite que Postgres ou Pandas, sans aucune infrastructure !
- 📖 **Ressource à lire** :
  - [*Why DuckDB* (Documentation DuckDB)](https://duckdb.org/why_duckdb)
  - [*Big data guide*](https://motherduck.com/learn/big-data/)

---

## BONUS - « Big Data » est relatif !

- **L'analyse choc par un créateur de BigQuery** :
  - Jordan Tigani (fondateur de MotherDuck, ex-ingénieur BigQuery) a analysé les requêtes réelles des entreprises sur les data warehouses :
    - **99% des requêtes** dans le monde analysent **moins de 10 Go** de données.
    - Seul un infime pourcentage atteint réellement l'échelle du Pétaoctet.
- **Le piège de la sur-ingénierie ("Complexity Tax")** :
  - Ne déployez pas d'usines à gaz distribuées si un moteur simple suffit.
  - Choisissez le bon outil adapté à votre échelle réelle pour ne pas 'over-engineer'
- 📖 **Article & Vidéo de référence** :
  - Article culte : [*"Big Data is Dead"* — Jordan Tigani (MotherDuck)](https://motherduck.com/blog/big-data-is-dead/)
  - Conférence vidéo : [*Big Data is Dead - What's Next? (YouTube)*](https://youtu.be/lisIQ9ohU8g?si=wlEnR-ilvGjM2Gph&t=103)

---

## 📉 Les 3 vérités de l'article « Big Data is Dead »

1. **La majorité des données est petite** :
   - La taille médiane des tables interrogées sur BigQuery est inférieure à **100 Mo**.
   - Très peu d'entreprises ont réellement des pétaoctets de données actives.

2. **On ne requête que les données récentes (*Hot vs Cold Data*)** :
   - Plus de **80% du volume scanné** concerne des données générées il y a **moins de 7 jours**.
   - L'historique lointain dort sur du stockage froid (*GCS Coldline / Archive*).

3. **Le matériel a rattrapé la donnée** :
   - Les machines actuelles (RAM généreuse, SSD NVMe ultra-rapides) scalent verticalement (**scale-up**) bien mieux qu'à l'époque de la création de Hadoop en 2006.
   - 🎯 **Moralité** : Distribué si nécessaire, simple par défaut !
