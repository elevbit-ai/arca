#!/usr/bin/env python3
"""
make-video.py - Grava o explicador animado (docs/video.html) em um MP4
Projeto: Arca - Cofre de Recuperacao Android
Autor:   Joaquim Pedro de Morais Filho <j360074@hotmail.com>
Licenca: MIT

Usa Playwright (Chromium headless) para abrir o video.html e gravar uma passada
completa das 8 cenas; depois converte para MP4 com ffmpeg (H.264, compativel).

Pre-requisitos:
  pip install playwright
  python -m playwright install chromium
  ffmpeg no PATH   (winget install Gyan.FFmpeg)

Uso:
  python make-video.py                 # gera viewer/arca.mp4
  python make-video.py -o ..\docs\arca.mp4 --seconds 70
"""
import argparse, os, pathlib, shutil, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
VIDEO_HTML = (HERE / ".." / "docs" / "video.html").resolve()
# soma das data-dur das cenas = 70.5s; 70s encerra na cena de fechamento
DEFAULT_SECONDS = 70


def main():
    ap = argparse.ArgumentParser(description="Gera o MP4 do vídeo explicativo do Arca")
    ap.add_argument("-o", "--out", default=str(HERE / "arca.mp4"))
    ap.add_argument("--seconds", type=int, default=DEFAULT_SECONDS)
    ap.add_argument("--width", type=int, default=1280)
    ap.add_argument("--height", type=int, default=720)
    args = ap.parse_args()

    if not VIDEO_HTML.exists():
        sys.exit(f"[arca] video.html nao encontrado em {VIDEO_HTML}")

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        sys.exit("[arca] Playwright ausente. Rode: pip install playwright && python -m playwright install chromium")

    outdir = HERE / "_video_capture"
    if outdir.exists():
        shutil.rmtree(outdir)
    outdir.mkdir(parents=True)

    print(f"[arca] gravando {args.seconds}s de {VIDEO_HTML.name} em {args.width}x{args.height}...")
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--autoplay-policy=no-user-gesture-required"])
        context = browser.new_context(
            viewport={"width": args.width, "height": args.height},
            record_video_dir=str(outdir),
            record_video_size={"width": args.width, "height": args.height},
        )
        page = context.new_page()
        page.goto(VIDEO_HTML.as_uri())
        page.wait_for_timeout(args.seconds * 1000)
        context.close()   # flush do video
        browser.close()

    webms = sorted(outdir.glob("*.webm"), key=os.path.getmtime)
    if not webms:
        sys.exit("[arca] falha: nenhum .webm gerado pelo Playwright.")
    webm = webms[-1]
    print(f"[arca] captura bruta: {webm}")

    out = pathlib.Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    if shutil.which("ffmpeg"):
        print("[arca] convertendo para MP4 (H.264)...")
        subprocess.run([
            "ffmpeg", "-y", "-i", str(webm),
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out),
        ], check=True)
        shutil.rmtree(outdir, ignore_errors=True)
        print(f"[arca] MP4 pronto: {out}")
    else:
        fallback = out.with_suffix(".webm")
        shutil.move(str(webm), str(fallback))
        shutil.rmtree(outdir, ignore_errors=True)
        print(f"[arca] ffmpeg ausente - salvei WEBM: {fallback}")
        print("[arca] instale o ffmpeg (winget install Gyan.FFmpeg) e rode de novo para gerar MP4.")


if __name__ == "__main__":
    main()
