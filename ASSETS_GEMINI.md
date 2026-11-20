# Brief d'assets pour Gemini — SURCHAUFFE

Le jeu fonctionne sans aucun fichier (tout est généré en code). Chaque fichier ci-dessous est
**optionnel** : s'il existe, il remplace le sprite/son généré ; sinon le jeu garde la version code.
On peut donc livrer les assets au fil de l'eau, un par un.

## Règles communes (à coller au début de chaque prompt Gemini)

> Pixel art 2D, vue de face, style casino arcade rétro années 80, néons orange, contours noirs
> de 1 pixel, ombres de 2 pixels, **aucun anti-aliasing, aucun dégradé, aucun flou**, fond
> **transparent** (PNG RGBA). Palette stricte de 8 couleurs uniquement :
> encre #140f1b, prune #2b1b3d, rouge #e8453c, orange #ff8a3d, or #ffd166, crème #f5e6c8,
> vert #3ecf8e, gris #6b6076. Pas de texte sauf si indiqué. Pas de personnage ni logo existant.

Gemini ne sait pas tenir une grille de pixels exacte : demandez-lui **un grand rendu net**
(ex. 8× la taille cible), puis lancez `python3 tools/prepare_assets.py <dossier_gemini>` qui
réduit au pixel près (voisin le plus proche), recolore sur la palette et écrit dans
`assets/sprites/`. Nommez chaque PNG exactement comme la **clé** ci-dessous (ex. `sym_cerise.png`).

## Sprites (clé → taille native en pixels → description)

| Clé | Taille | Description pour le prompt |
|---|---|---|
| `titre` | 384×72 | Logo « SURCHAUFFE » en grosses lettres pixel orange/or, contour noir, flammes et néon rouge derrière. Seul sprite avec texte. |
| `carcasse` | 352×256 | Façade d'une machine à sous vintage, vue de face : corps prune, bords orange néon, **fenêtre vide centrale pour 3 rouleaux**, ampoules sur le pourtour, fronton « 777 » sans texte lisible. |
| `levier_haut` | 64×112 | Levier de machine à sous relevé, boule rouge brillante en haut, tige crème, socle gris. |
| `levier_bas` | 64×112 | Même levier abaissé (boule en bas, tige raccourcie par la perspective). |
| `coeur_plein` / `coeur_vide` | 28×26 | Cœur de vie rouge plein / cœur vide (contour gris, intérieur prune). |
| `ampoule_on` / `ampoule_off` | 8×8 | Ampoule de néon allumée (or/orange) / éteinte (prune). |
| `btn_normal` `btn_press` `btn_off` | 24×24 | Bouton rectangulaire à coins coupés, **9-slice : bordure de 8 px, centre uni**. Normal = orange, pressé = plus sombre, désactivé = gris. |
| `panel` / `panel_or` | 24×24 | Cadre de fenêtre 9-slice (bordure 8 px) : gris/prune ; version bordure or pour l'élément sélectionné. |
| `mach_0` … `mach_5` | 56×56 | Six petites machines à sous miniatures, une couleur dominante chacune (0 rouge, 1 orange, 2 vert, 3 or, 4 crème, 5 gris-bleu). Silhouettes différentes : bandit manchot, vapeur, bécane, distributeur, croupier muet, ruche. |
| `mach_6` … `mach_11` | 56×56 | Six machines supplémentaires (même style) : 6 glaçon (bleu givré), 7 aimant, 8 banquier (billets), 9 jumeaux (deux machines collées), 10 phénix (oiseau de feu), 11 réacteur (nucléaire). |
| `mach_lock` | 56×56 | Machine miniature verrouillée : silhouette grise sombre avec cadenas. |
| `sym_cerise` | 64×64 | Deux cerises rouges avec tige verte. |
| `sym_citron` | 64×64 | Citron jaune/or avec feuille verte. |
| `sym_cloche` | 64×64 | Cloche dorée avec battant. |
| `sym_sept` | 64×64 | Chiffre 7 rouge à contour crème, très lisible. |
| `sym_jackpot` | 64×64 | Étoile ou diamant doré rayonnant, éclats orange. |
| `sym_zero` | 64×64 | Double zéro « 00 » vert sur fond prune. |
| `ic_double_zero` | 84×84 | Carte : deux zéros verts, un roulette. |
| `ic_maison` | 84×84 | Carte : petite maison/casino avec pièce d'or. |
| `ic_plombier` | 84×84 | Carte : clé à molette et tuyau. |
| `ic_rythme` | 84×84 | Carte : baguette de chef + notes / métronome. |
| `ic_coup_barre` | 84×84 | Carte : flocon de glace bleu-vert sur flamme gelée (gèle la chauffe). |
| `ic_stagiaire` | 84×84 | Carte : petit employé en cravate tapant sur une machine. |
| `ic_fer_cheval`, `ic_ventilo`, `ic_tirelire`, `ic_pari`, `ic_bouclier`, `ic_usurier`, `ic_chrono`, `ic_combo`, `ic_turbo`, `ic_gilet`, `ic_givre`, `ic_trefle`, `ic_equipe` | 84×84 | 13 nouvelles cartes : fer à cheval, ventilateur, cochon tirelire, dé, bouclier, pièce à dollar, chronomètre, étoile « x10 », éclair, cœur, flocon, trèfle à 4 feuilles, deux employés. (Générées en code tant qu'aucun PNG n'est fourni.) |

Astuce : demandez toujours une **planche** (ex. 6 symboles dans une grille) pour garder un style
homogène, puis découpez.

## Musique (boucles, sans paroles)

Dossier `assets/audio/`, noms exacts. Formats acceptés : `.ogg` (conseillé), `.mp3`, `.wav`.
Les boucles doivent être **bouclables sans coupure** (début = fin). Mute géré par le jeu.

| Fichier | Durée | Prompt musique |
|---|---|---|
| `musique_menu.ogg` | 60–90 s | Chiptune 8-bit casino lounge, 100 BPM, basse funky, arpèges d'ondes carrées, ambiance machine à sous en néon, légèrement mystérieuse. |
| `musique_run.ogg` | 90–120 s | Chiptune 8-bit tendu et rapide, 140 BPM, ostinato de basse, batterie électronique, montée de tension continue comme une chauffe qui monte, boucle sans fin. |
| `musique_gameover.ogg` | 20–30 s | Chiptune mélancolique et ironique, 70 BPM, petite cadence descendante façon casino qui ferme, boucle douce. |

## Effets sonores (courts)

Mêmes dossier et formats. Préfixe `sfx_`. Sans réverbération longue, normalisés à −3 dB.

| Fichier | Durée | Prompt |
|---|---|---|
| `sfx_tap.ogg` | 0,05–0,1 s | « Tic » sec de levier mécanique + bip carré aigu. |
| `sfx_spin.ogg` | 1,2 s | Rouleaux de machine à sous qui tournent puis ralentissent, cliquetis crescendo. |
| `sfx_jackpot.ogg` | 2–3 s | Fanfare chiptune triomphale, pièces qui tombent, sirène de casino. |
| `sfx_surchauffe.ogg` | 1–1,5 s | Grondement grave, vapeur qui siffle, alarme saturée descendante. |
| `sfx_table.ogg` | 0,8–1 s | Petit jingle de victoire ascendant (do-mi-sol-do), brillant. |

## Installation

```
assets/
  sprites/  <cle>.png
  audio/    musique_menu.ogg  musique_run.ogg  musique_gameover.ogg
            sfx_tap.ogg  sfx_spin.ogg  sfx_jackpot.ogg  sfx_surchauffe.ogg  sfx_table.ogg
```

Rouvrir le projet dans Godot (réimport automatique). Supprimer un fichier restaure la version générée en code.
