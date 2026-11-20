#!/usr/bin/env python3
"""Prépare des PNG générés (Gemini...) pour SURCHAUFFE.

Usage : python3 tools/prepare_assets.py <dossier_source> [dossier_sortie]
Chaque PNG doit porter le nom d'une clé de ASSETS_GEMINI.md (ex. sym_cerise.png).
Le script : recadre sur le contenu, réduit à la taille native EXACTE (voisin le plus proche),
recolore chaque pixel sur la palette à 8 couleurs, binarise la transparence.
Nécessite Pillow (pip install pillow).
"""
import sys
from pathlib import Path
from PIL import Image

PALETTE = ["140f1b", "2b1b3d", "e8453c", "ff8a3d", "ffd166", "f5e6c8", "3ecf8e", "6b6076"]
PAL_RGB = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in PALETTE]

TAILLES = {
    "titre": (384, 72), "carcasse": (352, 256), "levier_haut": (64, 112), "levier_bas": (64, 112),
    "coeur_plein": (28, 26), "coeur_vide": (28, 26), "ampoule_on": (8, 8), "ampoule_off": (8, 8),
    "btn_normal": (24, 24), "btn_press": (24, 24), "btn_off": (24, 24), "panel": (24, 24),
    "panel_or": (24, 24), "mach_lock": (56, 56),
    **{f"mach_{i}": (56, 56) for i in range(6)},
    **{f"sym_{s}": (64, 64) for s in ["cerise", "citron", "cloche", "sept", "jackpot", "zero"]},
    **{f"ic_{c}": (84, 84) for c in ["double_zero", "maison", "plombier", "rythme", "coup_barre", "stagiaire"]},
}


def plus_proche(rgb):
    return min(PAL_RGB, key=lambda p: sum((a - b) ** 2 for a, b in zip(p, rgb)))


def traiter(src: Path, dst: Path, taille):
    im = Image.open(src).convert("RGBA")
    boite = im.getbbox()
    if boite and src.stem not in ("btn_normal", "btn_press", "btn_off", "panel", "panel_or"):
        im = im.crop(boite)
    im = im.resize(taille, Image.NEAREST)
    px = im.load()
    for y in range(taille[1]):
        for x in range(taille[0]):
            r, g, b, a = px[x, y]
            px[x, y] = (*plus_proche((r, g, b)), 255) if a >= 128 else (0, 0, 0, 0)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    source = Path(sys.argv[1])
    sortie = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "assets" / "sprites"
    for f in sorted(source.glob("*.png")):
        if f.stem not in TAILLES:
            print(f"ignoré (clé inconnue) : {f.name}")
            continue
        traiter(f, sortie / f.name, TAILLES[f.stem])
        print(f"ok : {f.stem} -> {TAILLES[f.stem][0]}x{TAILLES[f.stem][1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
