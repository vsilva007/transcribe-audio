#!/usr/bin/env bash
set -e

## Requisitos del sistema
#if ! command -v brew >/dev/null 2>&1; then
#  echo "❌ Homebrew no encontrado. Instala Homebrew primero."
#  exit 1
#fi
#brew install ffmpeg

# Crear venv local y preparar whisper
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install openai-whisper
pip uninstall -y numpy torch whisper
pip install "numpy<2" torch whisper

echo "✅ Entorno listo. Activa con: source .venv/bin/activate"

# En macOS (brew) o Linux/Windows instala ffmpeg:
# macOS:  brew install ffmpeg
# Debian/Ubuntu: sudo apt-get install ffmpeg
# Windows (choco): choco install ffmpeg

