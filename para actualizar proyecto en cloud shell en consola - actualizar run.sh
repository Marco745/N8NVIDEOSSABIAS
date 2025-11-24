1️⃣ Primero indica el proyecto correcto

En Cloud Shell ejecuta:

gcloud config set project airy-environs-475503-e1


Te preguntará algo tipo “Updated property…”, listo.

Si te sale error de que no existe, revisamos el ID, pero por lo que pusiste antes ese es el que estás usando en Cloud Run.

2️⃣ Ahora sí, vuelve a construir la imagen

Desde la carpeta ffmpeg-job:

gcloud builds submit --tag gcr.io/airy-environs-475503-e1/ffmpeg-job

3️⃣ Actualiza el Job para usar la nueva imagen

Cuando termine el build:

gcloud run jobs update ffmpeg-subs-job \
  --image gcr.io/airy-environs-475503-e1/ffmpeg-job \
  --region us-central1


(agrego --region por si acaso).
