import argparse
import os
import whisper
from pathlib import Path
from typing import Optional

DEFAULT_EXTS = {".mp3", ".wav", ".m4a", ".mp4", ".mov", ".aac", ".flac", ".ogg", ".webm", ".mkv"}

def to_srt(segments):
    def ft(s):  # segundos -> hh:mm:ss,ms
        h = int(s // 3600)
        m = int((s % 3600) // 60)
        sec = s % 60
        return f"{h:02d}:{m:02d}:{int(sec):02d},{int((sec - int(sec)) * 1000):03d}"

    lines = []
    for i, seg in enumerate(segments, 1):
        start = ft(seg["start"]); end = ft(seg["end"])
        text = seg["text"].strip()
        lines += [str(i), f"{start} --> {end}", text, ""]
    return "\n".join(lines)

def resolve_base_path(input_path: Path, out_dir: Optional[Path] = None, out_prefix: Optional[Path] = None) -> Path:
    """
    Devuelve el base_path sin extensión.
    - Si out_prefix se pasa, se usa tal cual (sin extensión).
    - Si out_dir se pasa, guarda en out_dir con el mismo nombre base.
    - Si no, guarda junto al archivo.
    """
    if out_prefix is not None:
        return out_prefix

    if out_dir is not None:
        out_dir.mkdir(parents=True, exist_ok=True)
        return out_dir / input_path.stem

    return input_path.with_suffix("")

def transcribe_one(model, audio_path: Path, lang: str, out_dir: Optional[Path] = None, out_prefix: Optional[Path] = None):
    print(f"[+] Transcribiendo: {audio_path}")
    options = {}
    if lang:
        options["language"] = lang

    result = model.transcribe(str(audio_path), **options)

    base_path = resolve_base_path(audio_path, out_dir=out_dir, out_prefix=out_prefix)
    txt_path = Path(str(base_path) + ".txt")
    srt_path = Path(str(base_path) + ".srt")

    txt_path.parent.mkdir(parents=True, exist_ok=True)

    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(result["text"].strip() + "\n")

    with open(srt_path, "w", encoding="utf-8") as f:
        f.write(to_srt(result["segments"]))

    print(f"[✔] TXT: {txt_path}")
    print(f"[✔] SRT: {srt_path}")

def iter_media_files(root: Path, exts, recursive: bool):
    if recursive:
        for p in root.rglob("*"):
            if p.is_file() and p.suffix.lower() in exts:
                yield p
    else:
        for p in root.iterdir():
            if p.is_file() and p.suffix.lower() in exts:
                yield p

def main():
    p = argparse.ArgumentParser(description="Transcribe audio local con Whisper (archivo o directorio)")
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument("audio", nargs="?", help="Ruta del archivo de audio/vídeo (mp3, wav, m4a, mp4...)")
    group.add_argument("--dir", dest="input_dir", help="Directorio con archivos a transcribir")

    p.add_argument("--model", default="small", help="tiny/base/small/medium/large")
    p.add_argument("--lang", default="es", help="Idioma (ej. es, en, pt). Vacío = auto")

    # Mantengo tu --out original para modo archivo (compatibilidad)
    p.add_argument("--out", default="", help="(Modo archivo) Si es carpeta, guarda ahí; si es prefijo, usa ese base path")

    # Nuevo: salida para modo directorio
    p.add_argument("--out-dir", default="", help="(Modo directorio) Directorio donde guardar TXT/SRT (mismo nombre base)")
    p.add_argument("--recursive", action="store_true", help="(Modo directorio) Buscar también en subdirectorios")
    p.add_argument("--ext", default="", help="(Modo directorio) Extensiones permitidas separadas por coma. Ej: .mp3,.wav,.m4a")

    args = p.parse_args()

    print(f"[+] Cargando modelo: {args.model}")
    model = whisper.load_model(args.model)

    # ---- Modo archivo (como antes) ----
    if args.audio:
        audio_path = Path(args.audio).expanduser().resolve()
        if not audio_path.exists():
            raise SystemExit(f"❌ No existe: {audio_path}")

        out_prefix = None
        out_dir = None
        if args.out:
            out_abs = Path(args.out).expanduser().resolve()
            if out_abs.is_dir():
                out_dir = out_abs
            else:
                out_prefix = out_abs

        transcribe_one(model, audio_path, args.lang, out_dir=out_dir, out_prefix=out_prefix)
        return

    # ---- Modo directorio ----
    root = Path(args.input_dir).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"❌ Directorio inválido: {root}")

    out_dir = Path(args.out_dir).expanduser().resolve() if args.out_dir else root
    out_dir.mkdir(parents=True, exist_ok=True)

    exts = DEFAULT_EXTS
    if args.ext.strip():
        exts = {e.strip().lower() for e in args.ext.split(",") if e.strip()}
        exts = {e if e.startswith(".") else f".{e}" for e in exts}

    files = list(iter_media_files(root, exts, args.recursive))
    if not files:
        raise SystemExit(f"⚠️ No encontré archivos con extensiones: {sorted(exts)} en {root}")

    print(f"[+] Archivos encontrados: {len(files)}")
    print(f"[+] Salida: {out_dir}")

    for fpath in files:
        # mantiene mismo nombre base; si hay conflictos (mismo stem), se pisa.
        # Si quieres evitar colisiones, puedo añadir subcarpetas espejo.
        transcribe_one(model, fpath, args.lang, out_dir=out_dir)

if __name__ == "__main__":
    main()
