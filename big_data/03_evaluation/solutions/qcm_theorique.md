# 📝 QCM Théorique — Big Data & Data Engineering sur GCP


---

### Question 1 (1 point)
**Dans les architectures Big Data et les moteurs analytiques distribués, quel est l'objectif principal du partitionnement des données (ex: par date) ?**
- [ ] A) Répartir les calculs de manière aléatoire sur les nœuds du cluster pour équilibrer la charge matérielle.
- [ ] B) Permettre au moteur d'ignorer les fichiers ou blocs hors du filtre de la requête (Partition Pruning), réduisant drastiquement le volume de données scannées et le temps d'exécution.
- [ ] C) Empêcher automatiquement l'insertion de doublons ou de valeurs manquantes dans le dataset.
- [ ] D) Crypter automatiquement les données sensibles à l'aide d'une clé asymétrique propre à chaque partition.

---

### Question 2 (1 point)
**Dans le traitement de données massives (Big Data / OLAP), pourquoi privilégie-t-on les formats de stockage orientés colonne (comme Parquet ou les tables analytiques) par rapport aux formats orientés ligne (comme le CSV ou les bases relationnelles transactionnelles) ?**
- [ ] A) Parce que les formats orientés ligne sont techniquement limités à un volume maximal de 10 000 enregistrements.
- [ ] B) Parce que les requêtes analytiques lisent uniquement les colonnes sélectionnées sans scanner toute la ligne, et que les données d'un même type se compressent beaucoup plus efficacement.
- [ ] C) Parce que les formats colonnaires sont les seuls compatibles avec le langage SQL standard.
- [ ] D) Parce qu'ils permettent de modifier (UPDATE) une cellule individuelle instantanément sans réécrire le fichier.

---

### Question 3 (1 point)
**Dans l'architecture Medallion, quel est le rôle principal de la couche Silver ?**
- [ ] A) Archiver les fichiers au format ZIP.
- [ ] B) Stocker les données brutes telles qu'elles arrivent de l'API.
- [ ] C) Nettoyer, typer, dédupliquer et structurer la donnée.
- [ ] D) Servir directement de tableau de bord pour la direction générale.

---

### Question 4 (1 point)
**Quelle est la différence principale entre l'approche ETL (traditionnelle) et ELT (moderne, sur BigQuery) ?**
- [ ] A) L'ETL est réservé aux gros volumes de données, tandis que l'ELT s'utilise pour les petits fichiers.
- [ ] B) En ETL, la transformation se fait sur un serveur dédié, alors qu'en ELT, les données sont d'abord chargées brutes puis transformées in-situ grâce à la puissance de l'entrepôt cloud.
- [ ] C) ELT signifie "Extract Load Transfer" et sert uniquement à déplacer des fichiers sur le réseau.
- [ ] D) L'ELT nécessite d'effacer les données brutes après transformation pour économiser du stockage.

---

### Question 5 (1 point)
**Quel est le principal avantage du découplage entre le stockage et le calcul dans une architecture cloud moderne ?**
- [ ] A) Il permet d'utiliser l'écosystème Hadoop (HDFS) plus efficacement.
- [ ] B) Il impose un coût mensuel fixe garantissant la stabilité des performances.
- [ ] C) Il permet de stocker massivement des données à bas coût et d'allouer (et payer) des ressources de calcul uniquement lors de l'exécution des requêtes.
- [ ] D) Il réduit la latence réseau en stockant les données directement sur l'ordinateur de l'utilisateur.

---

### Question 6 (1 point)
**Dans BigQuery, pourquoi privilégie-t-on souvent la dénormalisation avec des champs de type STRUCT et ARRAY au lieu d'un modèle en étoile classique (Kimball) ?**
- [ ] A) Parce que BigQuery ne supporte pas la clause SQL JOIN.
- [ ] B) Pour réduire le nombre de jointures nécessaires, diminuant ainsi le volume de données scannées et le temps CPU, ce qui réduit le coût final.
- [ ] C) Pour garantir que les données puissent être mises à jour (UPDATE) plus facilement.
- [ ] D) Parce que Looker Studio ne peut lire que des données imbriquées.

---

### Question 7 (1 point)
**Quelle est la différence fondamentale entre une Vue Logique (Logical View) et une Vue Matérialisée (Materialized View) dans BigQuery ?**
- [ ] A) Une vue logique stocke physiquement les données sur disque à chaque écriture, tandis qu'une vue matérialisée ne stocke que la définition de la requête SQL.
- [ ] B) Une vue logique réexécute la requête SQL sous-jacente à chaque consultation (aucun résultat n'est stocké), tandis qu'une vue matérialisée précalcule et stocke physiquement les résultats pour des lectures beaucoup plus rapides et économiques.
- [ ] C) Une vue logique ne peut interroger qu'une seule table à la fois, alors qu'une vue matérialisée est obligatoire dès qu'il y a une jointure (JOIN).
- [ ] D) Une vue matérialisée devient statique et obsolète dès que la table sous-jacente change, alors qu'une vue logique est toujours mise à jour manuellement par un administrateur.

---

### Question 8 (1 point)
**Qu'est-ce qu'un DAG (Directed Acyclic Graph) dans le domaine de l'orchestration des données ?**
- [ ] A) Un format de fichier optimisé pour le stockage Big Data, similaire à Parquet.
- [ ] B) Une modélisation des tâches et de leurs dépendances sans boucle, garantissant le bon ordre d'exécution d'un pipeline.
- [ ] C) Une fonction SQL BigQuery permettant de dédupliquer automatiquement les lignes d'une table.
- [ ] D) Un composant réseau de Google Cloud pour accélérer les transferts.

---

### Question 9 (1 point)
**Que signifie l'abstraction "Serverless" pour un développeur ou un ingénieur ?**
- [ ] A) Il n'y a plus de serveurs physiques hébergeant les données dans les data centers de Google.
- [ ] B) Le Data Engineer doit configurer manuellement le système d'exploitation de la machine virtuelle.
- [ ] C) Le code s'exécute en pair-à-pair entre les différentes bases de données de l'entreprise.
- [ ] D) Le développeur écrit uniquement la logique métier sans se soucier de l'infrastructure, et le cloud s'occupe de provisionner les ressources à la demande, en facturant à l'usage.

---

### Question 10 (1 point)
**Quelle est la bonne pratique pour gérer des enregistrements en double lors de l'ingestion de données ?**
- [ ] A) Filtrer et supprimer les doublons directement lors du chargement initial dans la couche Bronze.
- [ ] B) Ignorer les doublons car BigQuery déduplique automatiquement toutes les tables analytiques.
- [ ] C) Conserver la couche Bronze intacte (toutes les données brutes) et appliquer la déduplication lors de la transformation vers la couche Silver.
- [ ] D) Utiliser une vue matérialisée, car elle supporte nativement la fonction de fenêtrage `ROW_NUMBER()` pour la déduplication.

---
