# Pipeline ELT TheLook eCommerce (architecture Médaillon)

```
GCS (JSON brut) --dlt--> bronze_products --SQL--> silver_products --SQL--> gold_category_metrics
```

| Couche | Fichier | Rôle |
|:---|:---|:---|
| Bronze | `ingestion/load_products.py` | Charge le JSON brut avec dlt, sans le modifier |
| Silver | `transformations/silver.sql` | Typage, valeurs `'NULL'` -> `NULL`, fusion des colonnes de prix |
| Gold | `transformations/gold.sql` | Nombre de produits, prix moyen, marge moyenne par catégorie |
| Orchestration | `.github/workflows/elt_pipeline.yml` | Enchaîne les 3 étapes chaque jour à minuit (UTC) |

## Choix principaux

- **ELT** : les données sont chargées brutes puis transformées en SQL dans BigQuery.
- **Bronze non modifiée** : on garde la trace de la source. Les erreurs sont corrigées en Silver.
- **Variant columns dlt** : `retail_price` (entier) et `retail_price__v_double` (décimal) sont fusionnées avec `COALESCE`.
- **`SAFE_CAST`** : une valeur illisible devient `NULL` au lieu de faire échouer le pipeline.
- **Idempotence** : `write_disposition="replace"` et `CREATE OR REPLACE TABLE` permettent de relancer sans doublons.
- **Authentification sans clé** : Workload Identity Federation, aucun secret dans le dépôt.
- **Un seul job séquentiel** : une étape en échec arrête les suivantes.
