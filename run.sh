#!/usr/bin/env bash
set -euo pipefail

echo "=== Job FFmpeg iniciado ==="

# ===============================
# 0. VARIABLES DEL JOB
# ===============================
: "${IMAGES:?Debes definir IMAGES}"
: "${AUDIOS:?Debes definir AUDIOS}"
: "${OUTPUT_BUCKET:?Debes definir OUTPUT_BUCKET}"

OUTPUT_FILENAME="${OUTPUT_FILENAME:-video_$(date +%s).mp4}"

WORKDIR="/tmp/work"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "=== Parámetros recibidos ==="
echo "IMAGES=$IMAGES"
echo "AUDIOS=$AUDIOS"
echo "OUTPUT_BUCKET=$OUTPUT_BUCKET"
echo "OUTPUT_FILENAME=$OUTPUT_FILENAME"
echo "Directorio: $WORKDIR"
echo "============================="

# ===============================
# 1. PARSEAR LISTAS COMA → ARRAY
# ===============================
IFS=',' read -ra IMG_ARRAY <<< "$IMAGES"
IFS=',' read -ra AUD_ARRAY <<< "$AUDIOS"

IMG_COUNT=${#IMG_ARRAY[@]}
AUD_COUNT=${#AUD_ARRAY[@]}

if [[ "$IMG_COUNT" -ne "$AUD_COUNT" ]]; then
  echo "Error: cantidad imágenes ($IMG_COUNT) ≠ audios ($AUD_COUNT)"
  exit 1
fi

TOTAL=$IMG_COUNT
echo "Total de pares: $TOTAL"

# ===============================
# 2. DESCARGAR ARCHIVOS
# ===============================
echo "Descargando imágenes y audios..."

for (( i=0; i<TOTAL; i++ )); do
  IMG_URL="${IMG_ARRAY[$i]}"
  AUD_URL="${AUD_ARRAY[$i]}"

  echo "Descargando img$i.jpg..."
  curl -L "$IMG_URL" -o "img$i.jpg"

  echo "Descargando audio$i.mp3..."
  curl -L "$AUD_URL" -o "audio$i.mp3"
done

ls -lh

# ===============================
# 3. GENERAR CLIPS (CON EFECTOS)
# ===============================
echo "Generando clips…"

for (( i=0; i<TOTAL; i++ )); do
  echo "Generando clip$i.mp4..."

  # Duración exacta del audio para sincronizar efectos
  DURACION=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "audio$i.mp3")
  echo "Duración audio$i.mp3: $DURACION s"

  ffmpeg -y \
    -loop 1 -i "img$i.jpg" \
    -i "audio$i.mp3" \
    -filter_complex "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,format=yuv420p,zoompan=z='min(1.0+0.0007*n,1.10)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30,fade=t=in:st=0:d=0.4,fade=t=out:st=${DURACION}-0.4:d=0.4[v];[1:a]afade=t=in:st=0:d=0.3,afade=t=out:st=${DURACION}-0.3:d=0.3[a]" \
    -t "$DURACION" \
    -map "[v]" -map "[a]" \
    -c:v libx264 -preset medium -tune stillimage \
    -c:a aac \
    "clip$i.mp4"
done

# ===============================
# 4. CONCATENAR TODOS LOS CLIPS
# ===============================
echo "Concatenando…"

LIST="list.txt"
> "$LIST"

for (( i=0; i<TOTAL; i++ )); do
  echo "file 'clip$i.mp4'" >> "$LIST"
done

ffmpeg -y -f concat -safe 0 -i "$LIST" -c copy "final.mp4"

echo "Final generado:"
ls -lh final.mp4

# ===============================
# 5. SUBIR A GOOGLE CLOUD STORAGE
# ===============================
echo "Subiendo a GCS…"

OUTPUT_BUCKET_NORM="${OUTPUT_BUCKET%/}/"

gsutil cp "final.mp4" "${OUTPUT_BUCKET_NORM}${OUTPUT_FILENAME}"

BUCKET_PATH="${OUTPUT_BUCKET_NORM#gs://}"
BUCKET_NAME="${BUCKET_PATH%%/*}"
OBJECT_PREFIX="${BUCKET_PATH#*/}"

[[ "$OBJECT_PREFIX" == "$BUCKET_NAME" ]] && OBJECT_PREFIX=""
[[ -n "$OBJECT_PREFIX" && "${OBJECT_PREFIX: -1}" != "/" ]] && OBJECT_PREFIX="${OBJECT_PREFIX}/"

PUBLIC_URL="https://storage.googleapis.com/${BUCKET_NAME}/${OBJECT_PREFIX}${OUTPUT_FILENAME}"

echo "VIDEO_URL=$PUBLIC_URL"
echo "$PUBLIC_URL"

echo "=== Job FFmpeg finalizado correctamente ==="
