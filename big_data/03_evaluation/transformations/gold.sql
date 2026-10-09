/*
COUCHE GOLD : indicateurs métier par catégorie

Pour chaque catégorie : nombre de produits, prix de vente moyen
et marge unitaire moyenne (prix de vente - coût).

Choix techniques :
  * La source est silver_products (données déjà typées et propres),
    jamais la bronze.
  * AVG ignore les NULL : un produit sans coût ou sans prix n'est pas
    compté dans la moyenne, mais reste compté dans total_products.
  * WHERE category IS NOT NULL : on exclut les produits sans catégorie,
    qui fausseraient le classement.
  * ORDER BY marge DESC : catégories les plus rentables en premier.
    (BigQuery ne garantit pas l'ordre stocké : retrier à la lecture.)
  * CREATE OR REPLACE : requête idempotente, relançable chaque jour.

*/

CREATE OR REPLACE TABLE `lasalle-big-data.examen_loic.gold_category_metrics` AS
SELECT
  category,
  COUNT(*)                         AS total_products,
  AVG(retail_price)                AS avg_retail_price,
  AVG(retail_price - cost)         AS avg_unit_margin
FROM `lasalle-big-data.examen_loic.silver_products`
WHERE category IS NOT NULL
GROUP BY category
ORDER BY avg_unit_margin DESC;
