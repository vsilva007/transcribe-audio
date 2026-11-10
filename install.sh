#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

for dependency in ffmpeg; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "❌ Instala $dependency antes de continuar." >&2
    exit 1
  fi
done

compatible_python() {
  "$1" -c 'import sys, venv; sys.exit(not ((3, 9) <= sys.version_info[:2] <= (3, 12)))' >/dev/null 2>&1
}

if [[ -n "${PYTHON_BIN:-}" ]]; then
  if ! compatible_python "$PYTHON_BIN"; then
    echo "❌ PYTHON_BIN debe apuntar a Python 3.9–3.12." >&2
    exit 1
  fi
else
  for candidate in "$VENV_DIR/bin/python" python3.12 python3.11 python3.10 python3.9 python3 /usr/bin/python3; do
    if compatible_python "$candidate"; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "${PYTHON_BIN:-}" ]]; then
  echo "❌ Instala Python 3.12 y ejecuta: PYTHON_BIN=/ruta/a/python3.12 ./install.sh" >&2
  exit 1
fi

PYTHON_BIN="$("$PYTHON_BIN" -c 'import sys; print(sys._base_executable)')"
PYTHON_VERSION="$("$PYTHON_BIN" -c 'import sys; print(sys.version_info[:2])')"
VENV_VERSION="$("$VENV_DIR/bin/python" -c 'import sys; print(sys.version_info[:2])' 2>/dev/null || true)"

if [[ -e "$VENV_DIR" && "$VENV_VERSION" != "$PYTHON_VERSION" ]]; then
  BACKUP_DIR="$(mktemp -d "${VENV_DIR}.backup.XXXXXX")"
  mv "$VENV_DIR" "$BACKUP_DIR/venv"
  echo "Entorno anterior guardado en: $BACKUP_DIR/venv"
fi

TORCH_PACKAGE=torch
NUMBA_PACKAGE=numba
if [[ "$("$PYTHON_BIN" -c 'import platform; print(platform.system(), platform.machine())')" == "Darwin x86_64" ]]; then
  TORCH_PACKAGE='torch==2.2.2'
  NUMBA_PACKAGE='numba<0.63'
fi

echo "Python seleccionado: $PYTHON_BIN"
"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install openai-whisper "$TORCH_PACKAGE" "$NUMBA_PACKAGE" "numpy<2"
"$VENV_DIR/bin/python" -c 'import whisper, torch, numpy; print("Whisper listo; PyTorch", torch.__version__)'

echo "✅ Entorno listo. Activa con: source .venv/bin/activate"

# En macOS (brew) o Linux/Windows instala ffmpeg:
# macOS:  brew install ffmpeg
# Debian/Ubuntu: sudo apt-get install ffmpeg
# Windows (choco): choco install ffmpeg

