# Fichier: ingestion/load_products.py
# --- Starter Kit à copier dans votre projet ---

import dlt
import json
from dlt.sources.filesystem import filesystem
import os

# --- AUTHENTIFICATION GOOGLE CLOUD ---
# je dois vous fournir un fichier 'cle-examen.json'. 
# Placez-le EXACTEMENT dans le même dossier que ce notebook.
#os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "cle-examen.json"


# 1. Création d'une ressource filesystem pointant vers le bucket
# L'authentification GCP est gérée automatiquement par WIF (GitHub Actions) ou `gcloud auth` (Local)
gcs_source = filesystem(
    bucket_url="gs://exam_bucket_eu/",
    file_glob="**/*.json"
)

# 2. Définition d'un lecteur (transformer) JSON personnalisé
@dlt.transformer
def read_json(file_items):
    for item in file_items:
        with item.open("r", encoding="utf-8") as f:
            yield from json.load(f)

# 3. Initialisation du pipeline dlt
pipeline = dlt.pipeline(
    pipeline_name="exam_pipeline",
    destination="bigquery",
    dataset_name="examen_loic",
)

# 4. Exécution du chargement en combinant la ressource et le lecteur JSON
load_info = pipeline.run(
    gcs_source | read_json, 
    table_name="bronze_products",
    write_disposition="replace",
)

print("✅ Chargement terminé !")
print(load_info)
