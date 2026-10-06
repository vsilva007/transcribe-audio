#!/bin/bash
set -e

# ---------------- CONFIG ----------------
ENV_DIR="pyenv"
MODEL="small"
LANG="es"
PYTHON_BIN="/Applications/Xcode.app/Contents/Developer/usr/bin/python3"

# Extensiones que vamos a procesar en modo directorio
EXTS=("mp3" "wav" "m4a" "aac" "flac" "ogg" "mp4" "mov" "mkv" "webm")

# Aumento de volumen: 400% => volume=4.0
VOLUME_FACTOR="4.0"
# ---------------------------------------

# --------- Crear/activar entorno virtual --------
if [ -d "$ENV_DIR" ] && [ -f "$ENV_DIR/pyvenv.cfg" ]; then
  # Si el venv no es Python 3.9 (o no coincide), lo recreamos
  if ! grep -q "version = 3.9" "$ENV_DIR/pyvenv.cfg"; then
    echo "♻️  El venv existente no es Python 3.9. Recreando..."
    rm -rf "$ENV_DIR"
  fi
fi

if [ ! -d "$ENV_DIR" ]; then
  echo "🐍 Creando entorno virtual ($ENV_DIR)..."
  "$PYTHON_BIN" -m venv "$ENV_DIR"
fi

source "$ENV_DIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel >/dev/null

# Dependencias Python
python -m pip show openai-whisper >/dev/null 2>&1 || python -m pip install openai-whisper
python -m pip show torch >/dev/null 2>&1 || python -m pip install torch
python -m pip show "numpy<2" >/dev/null 2>&1 || python -m pip install "numpy<2"

# ffmpeg requerido
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ No encuentro ffmpeg en PATH."
  echo "✅ Instálalo con: brew install ffmpeg"
  exit 1
fi

# --------- Helpers Mac/Linux ---------
get_size_bytes () {
  # macOS: stat -f%z
  # Linux: stat -c%s
  if stat -f%z "$1" >/dev/null 2>&1; then
    stat -f%z "$1"
  else
    stat -c%s "$1"
  fi
}

bytes_to_mb () {
  python -c "import sys; b=int(sys.argv[1]); print(f'{b/1024/1024:.2f}')" "$1"
}

format_hhmm () {
  python -c "import sys; mins=float(sys.argv[1]); total=int(round(mins)); h=total//60; m=total%60; print(f'{h:02d}:{m:02d}')" "$1"
}

bar () {
  python -c "import sys; p=float(sys.argv[1]); width=40; filled=int(width*(p/100.0)); print('[' + '█'*filled + '░'*(width-filled) + f'] {p:.1f}%')" "$1"
}

# --------- Parseo de args ---------
if [ -z "$1" ]; then
  echo "❌ Uso:"
  echo "   Archivo:    $0 archivo.mp3 [directorio_salida]"
  echo "   Directorio: $0 --dir /ruta/audios [directorio_salida]"
  exit 1
fi

MODE="file"
INPUT="$1"
OUT_DIR="$2"

if [ "$1" == "--dir" ]; then
  MODE="dir"
  INPUT="$2"
  OUT_DIR="$3"

  if [ -z "$INPUT" ]; then
    echo "❌ Uso: $0 --dir /ruta/audios [directorio_salida]"
    exit 1
  fi
  if [ ! -d "$INPUT" ]; then
    echo "❌ El directorio '$INPUT' no existe."
    exit 1
  fi
else
  if [ ! -f "$INPUT" ]; then
    echo "❌ El archivo '$INPUT' no existe."
    exit 1
  fi
fi

# Directorio de salida por defecto
if [ -z "$OUT_DIR" ]; then
  if [ "$MODE" == "file" ]; then
    OUT_DIR="$(dirname "$INPUT")"
  else
    OUT_DIR="$INPUT"
  fi
fi
mkdir -p "$OUT_DIR"

# Directorio temporal para audios amplificados
TMP_DIR="$(mktemp -d)"
cleanup () { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# --------- Modo archivo ---------
if [ "$MODE" == "file" ]; then
  echo "🎧 Transcribiendo archivo:"
  echo "   📄 $INPUT"
  echo "   📁 Salida: $OUT_DIR"

  base="$(basename "$INPUT")"
  stem="${base%.*}"
  amplified="$TMP_DIR/${stem}.wav"

  echo "🔊 Amplificando +400% (ffmpeg volume=${VOLUME_FACTOR})..."
  ffmpeg -hide_banner -loglevel error -y -i "$INPUT" -vn -af "volume=${VOLUME_FACTOR}" "$amplified"

  echo "📝 Transcribiendo (Whisper)..."
  python ss-transcribe-audio.py "$amplified" \
    --model "$MODEL" \
    --lang "$LANG" \
    --out "$OUT_DIR/$stem"

  echo "✅ Listo. Archivos en: $OUT_DIR"
  exit 0
fi

# --------- Modo directorio ---------
echo "📂 Transcribiendo directorio:"
echo "   📁 Entrada: $INPUT"
echo "   📁 Salida:  $OUT_DIR"

# Construir lista de archivos (solo EXTS) y obtener tamaños
# Guardamos líneas: "<bytes>\t<path>"
LIST_FILE="$TMP_DIR/files.tsv"
: > "$LIST_FILE"

# Build find args safely (macOS-friendly) + soporta espacios con -print0
find_args=("$INPUT" -type f "(")
for e in "${EXTS[@]}"; do
  find_args+=(-iname "*.${e}" -o)
done
# quitar el último "-o"
unset 'find_args[${#find_args[@]}-1]'
find_args+=(")" -print0)

# Recolectar archivos
while IFS= read -r -d '' f; do
  sz="$(get_size_bytes "$f")"
  printf "%s\t%s\n" "$sz" "$f" >> "$LIST_FILE"
done < <(find "${find_args[@]}")

if [ ! -s "$LIST_FILE" ]; then
  echo "⚠️ No encontré archivos válidos en $INPUT"
  echo "   Extensiones buscadas: ${EXTS[*]}"
  exit 1
fi

# Total bytes
TOTAL_BYTES="$(awk -F'\t' '{sum+=$1} END{printf "%.0f", sum}' "$LIST_FILE")"
TOTAL_MB="$(python - <<PY
b=int("$TOTAL_BYTES")
print(f"{b/1024/1024:.2f}")
PY
)"

# Estimación: 13 min cada 30MB => minutos = (MB/30)*13
EST_MIN="$(python - <<PY
mb=float("$TOTAL_MB")
print((mb/30.0)*13.0)
PY
)"
EST_HHMM="$(format_hhmm "$EST_MIN")"

echo ""
echo "📦 Tamaño total: ${TOTAL_MB} MB"
echo "⏱️ Estimación:  13 min / 30MB  →  ~ ${EST_HHMM} (hh:mm)"
# Barra “visual” basada en un máximo arbitrario: 2 horas = 120 min = 100%
# (solo para dar sensación visual; ajusta si quieres)
PCT="$(python - <<PY
mins=float("$EST_MIN")
pct=min(100.0, (mins/120.0)*100.0)
print(pct)
PY
)"
echo "📊 Carga estimada:"
bar "$PCT"
echo ""

# Ordenar por tamaño ascendente
SORTED_FILE="$TMP_DIR/files_sorted.tsv"
sort -n "$LIST_FILE" > "$SORTED_FILE"

COUNT="$(wc -l < "$SORTED_FILE" | tr -d ' ')"
echo "🔢 Archivos encontrados: $COUNT"
echo "➡️  Se procesarán de menor a mayor."
echo ""

i=0
while IFS=$'\t' read -r sz path; do
  i=$((i+1))
  mb="$(python - <<PY
b=int("$sz")
print(f"{b/1024/1024:.2f}")
PY
)"

  base="$(basename "$path")"
  stem="${base%.*}"
  amplified="$TMP_DIR/${i}_${stem}.wav"

  echo "[$i/$COUNT] 🎧 $base  (${mb} MB)"
  echo "      🔊 Amplificando +400% → WAV temporal"
  ffmpeg -hide_banner -loglevel error -y -i "$path" -vn -af "volume=${VOLUME_FACTOR}" "$amplified"

  echo "      📝 Transcribiendo..."
  python ss-transcribe-audio.py "$amplified" \
    --model "$MODEL" \
    --lang "$LANG" \
    --out "$OUT_DIR/$stem"

  echo "      ✅ OK → $OUT_DIR/${stem}.txt / ${stem}.srt"
  echo ""
done < "$SORTED_FILE"

echo "✅ Finalizado. Resultados en: $OUT_DIR"

