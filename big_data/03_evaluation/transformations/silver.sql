/*
- COUCHE SILVER : nettoyage et typage de bronze_products

problèmes constatés dans la table bronze (JSON volontairement sale) :
   * product_id, cost, added_date sont chargés en STRING   
   * le texte 'NULL' est utilisé à la place d'un vrai NULL
  * retail_price est éclaté par dlt en 2 colonnes (variant column) :
      - retail_price           (INTEGER) : valeurs entières de la source
       - retail_price__v_double (FLOAT)   : valeurs décimales de la source

 Choix techniques :
   * NULLIF(col, 'NULL')  : convertit le texte 'NULL' en vrai NULL
   * SAFE_CAST            : renvoie NULL si la conversion échoue, au lieu
                           de faire planter tout le job (pipeline robuste)
   * COALESCE             : fusionne les 2 colonnes de prix en une seule
  * TRIM                 : retire les espaces parasites dans les textes
  * CREATE OR REPLACE    : requête idempotente, relançable chaque jour
-  * _dlt_load_id / _dlt_id sont volontairement exclues (colonnes techniques)
*/ 
CREATE OR REPLACE TABLE `lasalle-big-data.examen_loic.silver_products` AS
SELECT
  SAFE_CAST(NULLIF(product_id, 'NULL') AS INT64)       AS product_id,
  NULLIF(TRIM(name), 'NULL')                           AS name,
  NULLIF(TRIM(category), 'NULL')                       AS category,
  SAFE_CAST(NULLIF(cost, 'NULL') AS FLOAT64)           AS cost,
  -- prix unique : la version décimale d'abord, sinon l'entier converti en FLOAT64
  COALESCE(retail_price__v_double, CAST(retail_price AS FLOAT64)) AS retail_price,
  is_active,
  SAFE_CAST(NULLIF(added_date, 'NULL') AS DATE)        AS added_date
FROM `lasalle-big-data.examen_loic.bronze_products`;
