# Architecture Data Cloud

_Lors du cours d'introduction au Big Data, vous avez conçu un pipeline ELT. Durant ces cinq jours, nous allons prendre du recul et concevoir l'architecture data sur le cloud en proposant une alternative moderne à une application monolithique existante. Pour cela, nous allons travailler sur un projet fil rouge : une compagnie de e-commerce._

---

 ***FastMarket est une entreprise de e-commerce en pleine croissance. Son système repose sur un monolithe classique hébergé sur un serveur unique, connecté à une base de données relationnelle PostgreSQL mutualisée pour l'ensemble des fonctionnalités.***

 ### Schéma de l'Architecture Monolithique Actuelle

```mermaid
graph TD
    Client["💻 Client: site web"]

    subgraph Monolith [" "]
        Payment["💳 Paiement"]
        Cart["🛒 Panier"]
        Inventory["📦 Inventaire"]
    end

    Instance["🗄️ Instance unique <br/><i>(Serveur & BDD PostgreSQL)</i>"]

    Client --> Payment
    Client --> Cart
    Client --> Inventory

    Payment --> Instance
    Cart --> Instance
    Inventory --> Instance

    %% Couleur des flèches en bleu marine
    linkStyle default stroke:#1E3A8A,stroke-width:1.5px

    %% Couleurs : Bleu / Marine / Rose foncé (Fuchsia)
    style Monolith fill:none,stroke:none
    style Client fill:#EBF4FF,stroke:#1E3A8A,stroke-width:2px,color:#0F172A
    style Payment fill:#FDF2F8,stroke:#C026D3,stroke-width:2px,color:#701A75
    style Cart fill:#FDF2F8,stroke:#DB2777,stroke-width:2px,color:#831843
    style Inventory fill:#FDF2F8,stroke:#BE185D,stroke-width:2px,color:#831843
    style Instance fill:#0F172A,stroke:#DB2777,stroke-width:2px,color:#F8FAFC
```


### Le constat opérationnel (Retours des équipes métiers & décisionnelles)

L'entreprise fait face à des signaux d'alerte remontés quotidiennement par les différents services :

* **Tensions entre équipes métiers et direction technique :**  
  > *« À chaque fois que l'équipe marketing rafraîchit le tableau de bord des ventes le matin, l'équipe web nous appelle en panique car le site rame et des clients n'arrivent plus à valider leur panier d'achat. On nous a formellement interdit de générer des rapports entre 9h et 19h. »*  
  *(— Un Data Analyst)*

* **Rapports trop lents et historiques inexploitables :**  
  > *« Impossible d'obtenir une vision consolidée de l'année passée pour préparer les soldes : au-delà de trois mois d'historique, les requêtes plantent avec un message d'erreur d'expiration (timeout). Le pilotage se fait à vue avec des données partielles. »*  
  *(— La Direction Commerciale)*

* **Inquiétudes du service juridique (DPO) :**  
  > *« Des clients demandent la suppression définitive de leur compte et de leurs données personnelles. Pourtant, nous continuons de retrouver leurs informations dans d'anciens fichiers et certains rapports d'activité. Nous sommes dans l'incapacité de garantir notre conformité en cas de contrôle de la CNIL. »*  
  *(— Le DPO - Délégué à la Protection des Données)*

* **Incompréhension de la direction financière :**  
  > *« La facture d'infrastructure augmente tous les trimestres car la technique demande constamment d'augmenter la taille du serveur principal, sans que la rapidité de nos outils d'analyse ne s'améliore pour autant. Nous ne savons pas quel service consomme quoi. »*  
  *(— La Direction Financière)*

---

## Objectifs du Cours

L'objectif de ces 5 jours n'est pas d'écrire un simple script d'ingestion, mais d'endosser le rôle d'Architecte Data & Cloud.

En équipe, vous allez concevoir la migration technique complète de FastMarket vers une architecture moderne sur Google Cloud Platform (GCP) :

- Comprendre les enjeux du cloud et comment optimiser une architecture data.

- Découpler le monolithe en isolant les contextes métiers vers des microservices autonomes 

- Concevoir un Data Lake robuste : Designer la topologie, les formats adaptés, le partitionnement et le cycle de vie.

- Modéliser pour l'analytique moderne : Sortir des schémas relationnels classiques (3NF) pour exploiter la puissance distribuée d'un entrepot de données comme BigQuery.

- Intégrer le RGPD dès la conception (Sécurité par le Design) : Mettre en œuvre le droit à l'effacement sur du stockage analytique immuable et sécuriser les accès aux données sensibles.

- Maîtriser les coûts (FinOps) : Anticiper et modéliser la facture cloud, en optimisant la consommation de ressources.


## Evaluation

Évaluation sera en deux parties:

1. **Evaluation continue**. Lors des activités et des exercices pratiques, vous serez sur la capacité à retransmettre ce que vous venez de faire (retour déxercice à l'oral) ainsi que l'investissement dans le travail d'équipe (prise de parole lors des questions du professeur, force de proposition lors du travail de groupe)

2. **Soutenance**. Lors du dernier jour, vous aurez a préparé une soutenance qui expliquer l'ensemble de la nouvelle architecture que vous proposeriez au management de l'entreprise fictive qui vous emploie. 
Il y aura deux aspects:
- _Explication non technique,_ dédiée aux décideurs. Celle ci sera orienté sur les coûts et les bénéfices que l'entreprise bénéficiera de cette nouvelle architecture.
- _Explications technique,_ dédié au leader technique de votre équipe informatique.