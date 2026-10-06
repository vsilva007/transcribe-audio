# 🎙️ ss-transcribe-audio

**Convierte audio y vídeo en texto y subtítulos con Whisper, desde tu terminal.**

Transcribe archivos individuales o carpetas completas y genera una transcripción `.txt` y subtítulos `.srt` por archivo. El reconocimiento se ejecuta localmente, con español y el modelo `small` como configuración predeterminada.

**Audio y vídeo → Whisper → Texto + Subtítulos**

[Inicio rápido](#-inicio-rápido) · [Uso](#-uso-con-python) · [Script Bash](#-uso-con-bash) · [Consideraciones](#-consideraciones)

## ✨ Funcionalidad

- **Dos salidas por archivo:** texto en UTF-8 y subtítulos SRT con marcas de tiempo.
- **Procesamiento por lotes:** carpetas, búsqueda recursiva y filtros de extensión.
- **Idioma configurable:** español por defecto; detección automática con `--lang ""`.
- **Modelo configurable:** selecciona el modelo de Whisper desde la CLI de Python.
- **Destino flexible:** guarda junto al archivo original o en una carpeta de resultados.
- **Preprocesamiento opcional con Bash:** extrae el audio a un WAV temporal, multiplica el volumen por cuatro y procesa los archivos de menor a mayor tamaño.

Extensiones incluidas en la búsqueda por carpetas:

```text
.mp3  .wav  .m4a  .aac  .flac  .ogg  .mp4  .mov  .mkv  .webm
```

La lectura de los archivos depende de FFmpeg. En modo archivo individual no se aplica este filtro de extensiones.

## 🚀 Inicio rápido

Necesitas **Python 3 con soporte para `venv`**, **pip** y **FFmpeg** disponible en el `PATH`. Ejecuta los ejemplos desde la raíz del proyecto.

### 1. Instala FFmpeg

En macOS, con Homebrew:

```bash
brew install ffmpeg
```

En Debian o Ubuntu:

```bash
sudo apt-get update
sudo apt-get install ffmpeg python3-venv
```

### 2. Prepara el entorno de Python

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install openai-whisper torch "numpy<2"
```

Estos pasos instalan explícitamente `openai-whisper`, el paquete que proporciona el reconocimiento de voz utilizado por el proyecto.

> **Sobre `install.sh`:** el instalador incluido instala primero `openai-whisper`, pero después desinstala e instala `whisper`, un paquete distinto. Utiliza los pasos manuales anteriores para preparar el entorno.

### 3. Transcribe tu primer archivo

```bash
python ss-transcribe-audio.py "grabaciones/entrevista.mp3"
```

Resultado:

```text
grabaciones/
├── entrevista.mp3
├── entrevista.txt
└── entrevista.srt
```

## 📝 Uso con Python

### Archivo individual

```bash
python ss-transcribe-audio.py "audio.mp3"
```

Seleccionar modelo e idioma:

```bash
python ss-transcribe-audio.py "interview.mp4" --model medium --lang en
```

Detectar el idioma automáticamente:

```bash
python ss-transcribe-audio.py "audio.m4a" --lang ""
```

Guardar en una carpeta existente:

```bash
mkdir -p resultados
python ss-transcribe-audio.py "audio.mp3" --out resultados
```

Elegir un prefijo de salida, sin extensión:

```bash
python ss-transcribe-audio.py "audio.mp3" --out "resultados/entrevista"
```

El último comando crea `resultados/entrevista.txt` y `resultados/entrevista.srt`, siempre que `resultados/entrevista` no sea una carpeta existente.

> `--out` se interpreta como carpeta **solo si ya existe**. En cualquier otro caso se utiliza como prefijo literal: `--out resultado.txt` produciría `resultado.txt.txt` y `resultado.txt.srt`.

### Carpetas completas

Transcribir los archivos del primer nivel:

```bash
python ss-transcribe-audio.py --dir "grabaciones"
```

Incluir subcarpetas y elegir un destino:

```bash
python ss-transcribe-audio.py --dir "grabaciones" --recursive --out-dir "resultados"
```

Filtrar extensiones; se aceptan con o sin punto:

```bash
python ss-transcribe-audio.py --dir "grabaciones" --recursive --ext "mp3,wav,m4a"
```

### Opciones

| Argumento | Función | Valor predeterminado |
| --- | --- | --- |
| `audio` | Ruta de un archivo de audio o vídeo; alternativa a `--dir` | — |
| `--dir RUTA` | Carpeta de entrada; alternativa al archivo individual | — |
| `--model NOMBRE` | Modelo de Whisper; la ayuda enumera `tiny`, `base`, `small`, `medium`, `large` | `small` |
| `--lang CÓDIGO` | Idioma; `""` activa la detección automática | `es` |
| `--out RUTA` | Carpeta existente o prefijo de salida, en modo archivo | Junto al archivo original |
| `--out-dir RUTA` | Carpeta de salida, en modo directorio; se crea si hace falta | Carpeta de entrada |
| `--recursive` | Incluye subcarpetas, en modo directorio | Desactivado |
| `--ext LISTA` | Extensiones separadas por comas, en modo directorio | Las diez extensiones indicadas arriba |
| `-h`, `--help` | Muestra la ayuda | — |

## 🔊 Uso con Bash

`ss-transcribe-audio.sh` añade preparación del entorno, amplificación y organización del procesamiento por lotes.

**Antes de ejecutarlo**, revisa las variables al principio del script:

| Variable | Valor incluido | Función |
| --- | --- | --- |
| `ENV_DIR` | `pyenv` | Entorno virtual propio, relativo al directorio de ejecución |
| `PYTHON_BIN` | `/Applications/Xcode.app/Contents/Developer/usr/bin/python3` | Ejecutable usado para crear el entorno |
| `MODEL` | `small` | Modelo de Whisper |
| `LANG` | `es` | Idioma de transcripción |
| `VOLUME_FACTOR` | `4.0` | Multiplicador del volumen |
| `EXTS` | Las diez extensiones indicadas arriba | Filtro de búsqueda por carpetas |

La configuración incluida apunta al Python de Xcode en macOS. Para otra instalación, ajusta `PYTHON_BIN`. El script comprueba que el entorno indique Python `3.9` y **elimina y recrea `pyenv` si no coincide**; adapta también esa comprobación si utilizas otra versión.

Archivo individual, con salida opcional:

```bash
bash ss-transcribe-audio.sh "audio.mp3"
bash ss-transcribe-audio.sh "audio.mp3" "resultados"
```

Carpeta completa, incluyendo subcarpetas automáticamente:

```bash
bash ss-transcribe-audio.sh --dir "grabaciones" "resultados"
```

El script:

1. Prepara y activa `pyenv`, instala las dependencias y comprueba FFmpeg.
2. En modo carpeta, reúne los archivos y los ordena por tamaño ascendente.
3. Convierte cada entrada a un WAV temporal con volumen multiplicado por cuatro.
4. Invoca la CLI de Python para generar los archivos TXT y SRT.
5. Elimina los archivos temporales al terminar.

Sin destino explícito, guarda junto al archivo en modo individual o en la carpeta de entrada en modo directorio. El modelo, el idioma y la amplificación se cambian editando las variables del script; sus argumentos no incluyen las opciones de la CLI de Python.

## ⚖️ Diferencias entre las dos formas de uso

| Comportamiento | Python | Bash |
| --- | --- | --- |
| Entorno | Lo preparas y activas tú | Gestiona `pyenv` al ejecutarse |
| Amplificación | No aplica | Volumen ×4 por defecto |
| Búsqueda recursiva | Con `--recursive` | Siempre en modo carpeta |
| Orden del lote | Sin ordenación explícita | De menor a mayor tamaño |
| Carga del modelo | Una vez por ejecución | Una vez por archivo |
| Estimación de tiempo | No incluida | Regla fija de 13 minutos por cada 30 MB |

## 📌 Consideraciones

- **Resultados existentes:** se sobrescriben. Los lotes concentran las salidas en una sola carpeta, sin replicar subdirectorios; archivos con el mismo nombre base pueden sobrescribirse entre sí, aunque tengan distinta extensión.
- **Errores en lotes:** el procesamiento se detiene si falla un archivo; no hay reanudación ni omisión automática de resultados ya generados.
- **Estimación del script Bash:** es orientativa y depende del tamaño del archivo. La barra representa una carga estimada respecto a dos horas, no el progreso real de la transcripción.
- **Volumen:** multiplicarlo por cuatro puede distorsionar grabaciones que ya tengan un nivel alto. Ajusta `VOLUME_FACTOR` o utiliza directamente Python.
- **Directorio de ejecución:** ejecuta Bash desde la raíz del repositorio, ya que utiliza rutas relativas para el entorno y el script de Python.
- **Instalación de dependencias:** no hay versiones fijadas ni un archivo de dependencias; la compatibilidad depende del Python y los paquetes instalados.

## 🗂️ Estructura del proyecto

```text
ss-transcribe-audio/
├── README.md                 # Documentación
├── ss-transcribe-audio.py     # CLI de transcripción y exportación TXT/SRT
├── ss-transcribe-audio.sh     # Entorno, amplificación y procesamiento por lotes
└── install.sh                # Instalador incluido; consulta la nota de instalación
```

Los entornos `.venv` y `pyenv` se crean localmente según la forma de instalación utilizada.
