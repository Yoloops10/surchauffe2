#!/usr/bin/env python3
"""Convertit les images Gemini brutes (JPG, faux damier de transparence cuit dans l'image)
en PNG transparents aux tailles natives de SURCHAUFFE, recolores sur la palette à 8 couleurs.

Usage : python3 -I tools/import_gemini.py <dossier_jpg> [dossier_sortie]
Le dossier source doit contenir les fichiers du lot « b94e5a39-assets » (noms d'origine, parenthèses incluses).
Nécessite Pillow + numpy + scipy.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

PALETTE = ["140f1b", "2b1b3d", "e8453c", "ff8a3d", "ffd166", "f5e6c8", "3ecf8e", "6b6076"]
PAL = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in PALETTE], dtype=np.float32)

# fichier source (nom sans parenthèse/extension) -> (cle, taille native, découpe optionnelle (x0,y0,x1,y1) en fraction)
CARTE = {
    "sym_cerise": ("sym_cerise", (64, 64), None), "sym_citron": ("sym_citron", (64, 64), None),
    "sym_cloche": ("sym_cloche", (64, 64), None), "sym_sept": ("sym_sept", (64, 64), None),
    "sym_jackpot": ("sym_jackpot", (64, 64), None), "sym_zero": ("sym_zero", (64, 64), None),
    "ic_double_zero": ("ic_double_zero", (84, 84), None), "ic_maison": ("ic_maison", (84, 84), None),
    "ic_plombier": ("ic_plombier", (84, 84), None), "ic_rythme": ("ic_rythme", (84, 84), None),
    "ic_coup_barre": ("ic_coup_barre", (84, 84), None), "ic_stagiaire": ("ic_stagiaire", (84, 84), None),
    "titre": ("titre", (384, 72), None),
    # machines : bandit, vapeur, bécane, distributeur, muet, ruche, cadenas
    "Gemini_Generated_Image_6t7wny6t7wny6t7w(3)": ("mach_0", (56, 56), None),
    "Gemini_Generated_Image_6t7wny6t7wny6t7w(5)": ("mach_1", (56, 56), None),
    "Gemini_Generated_Image_68sejo68sejo68se": ("mach_2", (56, 56), (0.34, 0.02, 0.66, 0.48)),
    "Gemini_Generated_Image_6t7wny6t7wny6t7w(2)": ("mach_3", (56, 56), (0.0, 0.0, 1.0, 0.82)),
    "Gemini_Generated_Image_6t7wny6t7wny6t7w(1)": ("mach_4", (56, 56), None),
    "Gemini_Generated_Image_6t7wny6t7wny6t7w(4)": ("mach_5", (56, 56), None),
    "Gemini_Generated_Image_6t7wny6t7wny6t7w": ("mach_lock", (56, 56), None),
}


def lum(a):
    return a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)


def masque_fond(rgb):
    """True = fond. Fond = pixels neutres dont la luminance est dans la plage de la bordure."""
    f = rgb.astype(np.float32)
    h, w, _ = f.shape
    bord = np.concatenate([f[0], f[-1], f[:, 0], f[:, -1]])
    lb = lum(bord)
    lo, hi = np.percentile(lb, 2) - 14, np.percentile(lb, 98) + 14
    dark = hi < 110
    ecart = f.max(axis=2) - f.min(axis=2)
    cand = (ecart <= (9 if dark else 12)) & (lum(f) >= lo) & (lum(f) <= hi)
    lab, n = ndi.label(cand)
    touche = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    touche = touche[touche > 0]
    # trous de fond enfermés dans le sprite (anse de cerise...) : retirés aussi si assez gros
    aires = ndi.sum(cand, lab, range(1, n + 1))
    gros = [i + 1 for i, a in enumerate(aires) if a >= 300]
    return np.isin(lab, np.union1d(touche, gros))


def traiter(src: Path, dst: Path, taille, decoupe):
    im = Image.open(src).convert("RGB")
    if decoupe:
        w, h = im.size
        im = im.crop((int(decoupe[0] * w), int(decoupe[1] * h), int(decoupe[2] * w), int(decoupe[3] * h)))
    rgb = np.array(im)
    fond = masque_fond(rgb)
    fg = ~fond
    fg = ndi.binary_opening(fg, iterations=2)
    lab, n = ndi.label(fg)
    if n == 0:
        raise RuntimeError("rien trouvé : " + src.name)
    tailles = ndi.sum(fg, lab, range(1, n + 1))
    garde = [i + 1 for i, t in enumerate(tailles) if t >= 0.04 * tailles.max()]
    fg = np.isin(lab, garde)
    fg = ndi.binary_fill_holes(fg) if src.stem.startswith(("sym_", "ic_")) is False else fg
    fg = ndi.binary_erosion(fg, iterations=2)
    ys, xs = np.where(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb, fg = rgb[y0:y1, x0:x1].astype(np.float32), fg[y0:y1, x0:x1].astype(np.float32)
    h, w = fg.shape
    k = min(taille[0] / w, taille[1] / h)
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    # moyenne pondérée par le masque (BOX) pour ne pas mélanger la couleur du fond
    def red(a):
        return np.array(Image.fromarray(a).resize((nw, nh), Image.BOX))
    m = red(fg)
    c = np.stack([red((rgb[..., i] * fg).astype(np.float32)) for i in range(3)], axis=-1) / np.maximum(m[..., None], 1e-3)
    idx = np.argmin(((c[:, :, None, :] - PAL[None, None]) ** 2).sum(-1), axis=-1)
    out = np.zeros((taille[1], taille[0], 4), dtype=np.uint8)
    ox, oy = (taille[0] - nw) // 2, (taille[1] - nh) // 2
    zone = out[oy:oy + nh, ox:ox + nw]
    zone[..., :3] = PAL[idx].astype(np.uint8)
    zone[..., 3] = np.where(m >= 0.5, 255, 0)
    dst.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(dst)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    source = Path(sys.argv[1])
    sortie = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "assets" / "sprites"
    for f in sorted(source.glob("*.jpg")):
        nom = f.stem.replace(")", "").lstrip("(")
        # les noms d'origine ont perdu une parenthèse ouvrante : "Gemini_..._w(3" -> garde "(3)"
        if nom.startswith("Gemini") and nom[-1].isdigit() and "(" in nom:
            nom += ")"
        if nom not in CARTE:
            print("ignoré :", f.name)
            continue
        cle, taille, dec = CARTE[nom]
        traiter(f, sortie / (cle + ".png"), taille, dec)
        print("ok :", f.name, "->", cle)
    return 0


if __name__ == "__main__":
    sys.exit(main())
