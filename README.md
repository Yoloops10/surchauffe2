# SURCHAUFFE

Casino-clicker roguelite en pixel art, Godot 4.4, GDScript uniquement.
Le jeu fonctionne sans aucun fichier : tout peut être généré en code (`art/Pixels.gd`, `autoload/Sfx.gd`).
Au démarrage : écran « MADE BY YOLOOPS » (un appui le saute).
Les sprites Gemini (symboles, cartes, machines, titre) et 4 musiques sont intégrés dans `assets/` ; les bruitages restent générés.
Aucun réseau, aucune permission Android.

Tu es la machine à sous : tape le levier, la chaleur monte, le multiplicateur aussi.
Une nuit = 7 tables, 3 jetons de crédit, des cartes de la maison, et des plombs en fin de run.

## Lancer dans l'éditeur

Ouvrir `project.godot` avec Godot 4.4.x, puis F5. Scène principale : `scenes/Boot.tscn` → Menu.
Vérification d'import en ligne de commande : `godot --headless --editor --quit`.

## APK sans rien installer (GitHub Actions)

1. Crée un dépôt GitHub (privé ou public) et pousse ce dossier sur la branche `main`.
2. Onglet **Actions** > **Build APK** > **Run workflow** (il se lance aussi à chaque push).
3. Au bout de ~10 min, télécharge l'artefact **Surchauffe-apk** (un zip contenant `Surchauffe.apk`).
4. Sur le téléphone : copie l'APK, autorise « installer des applications inconnues » pour ton gestionnaire de fichiers, ouvre l'APK.
   Ou, avec le câble et le débogage USB : `adb install -r Surchauffe.apk`.

L'APK est signé avec une clé de debug (installable, mais pas publiable sur le Play Store : il faudrait une clé de release).

## Construire l'APK (en local)

Prérequis :

1. **Godot 4.4.1 stable** et ses **export templates** (Éditeur → Gérer les modèles d'exportation,
   ou archive `Godot_v4.4.1-stable_export_templates.tpz` à décompresser dans
   `~/.local/share/godot/export_templates/4.4.1.stable/`).
2. **JDK 17** (`java` et `keytool` dans le PATH, ou `JAVA_HOME`).
3. **Android SDK** avec `platform-tools`, `build-tools;35.0.1`, `platforms;android-35`,
   `cmdline-tools;latest`, `cmake;3.10.2.4988404`, et NDK `28.1.13356709` si besoin
   (`export ANDROID_HOME=~/Android/Sdk`).

Puis :

```bash
export GODOT=/chemin/vers/godot     # si "godot" n'est pas dans le PATH
export ANDROID_HOME=$HOME/Android/Sdk
./tools/build_apk.sh
```

Le script crée le keystore debug si besoin, renseigne les réglages Android de l'éditeur,
importe le projet puis exporte `build/Surchauffe.apk`.

Preset : `com.surchauffe.game`, version 1.0, arm64-v8a, plein écran immersif, portrait,
aucune permission, signature debug. minSdk 24 / targetSdk 35 sont les valeurs par défaut
de Godot 4.4 pour l'export non-Gradle (24 et 35).

> L'APK n'a pas pu être construit dans l'environnement de développement initial
> (pas d'Android SDK ni de templates d'export). Le script et le preset sont fournis et documentés.

## Interface (inspirée de Balatro / Gambonanza)

Tout est généré en code, dans la palette de 8 couleurs :

- **Police pixel** 5×7 générée en code (`art/PixelFont.gd`) : tailles 8 / 16 / 32 = échelles ×1 / ×2 / ×4,
  accents français. Une police bitmap ne gère pas le contour : il est remplacé par une ombre portée dure
  (écart volontaire avec « outline_size = 4 »).
- **Fond en tourbillon** (`ui/Fond.gd`) : shader façon Balatro, tramé (dithering) sur 3 couleurs de la palette,
  rendu en 1/3 de résolution. En partie, la couleur change à chaque table (gris → vert → orange → rouge → or)
  et le tourbillon s'accélère avec la chauffe.
- **Overlay CRT** (lignes de balayage + vignette) et **fondus** entre écrans : `autoload/Fx.gd`.
- **Boutons 3D** (vert / orange / rouge / or / prune) avec lèvre qui s'enfonce et rebond au toucher,
  panneaux 9-slice à ombre dure, cartes crème penchées qui se balancent.
- Menu façon Balatro : logo qui oscille, main de 3 cartes en éventail (elles tombent à l’ouverture, flottent, sautent au toucher), dock de boutons JOUER géant + MACHINES | MODE. HUD : barre d'objectif,
  minuterie fine, cœurs qui « claquent ». Game over : compteur de plombs qui défile.

## Modes de jeu

Choix dans le menu (sous JOUER), mémorisé dans la sauvegarde (`"mode"`) :

- **ARCADE** (par défaut) : roue 0,6 s, zone chaude ×1,5, pièces d'or, ralenti sur jackpot,
  son du tap qui monte en gamme.
- **CLASSIQUE** : la version d'origine : roue 1,2 s, aucun de ces bonus.

Plombs, machines et record restent communs aux deux modes.

## Fun ajouté (mode Arcade)

Réglages dans `data/Balance.gd` :

- **Roue 2× plus rapide** : `ROUE_DUREE` 1,2 s → 0,6 s (rouleaux arrêtés à 50 / 75 / 100 %), son raccourci.
- **Zone chaude** : à partir de 80 % de la jauge, chaque tap vaut ×1,5 (« CHAUD ! ») : on joue avec le feu.
- **Pièce d'or** : toutes les 10 à 20 s une pièce apparaît, 3,5 s pour la toucher : +40 × valeur_tap.
- **Ralenti** dramatique (hit-stop) sur jackpot, **son du tap qui monte en gamme** avec la chauffe,
  salves et son à chaque achat d'upgrade.

## Mécaniques de rétention (dark patterns assumés)

Aucune monnaie réelle, aucun réseau : tout est local, réglable dans `data/Balance.gd`.

- **Série quotidienne** : bonus de plombs chaque jour (1, 2, 3, 4, 6, 8, puis 20 au 7e jour). Un jour
  manqué remet la série à zéro (aversion à la perte), compte à rebours « PERTE DANS hh:mm:ss » au menu.
  Le bouton de refus est volontairement culpabilisant (« NON, JE RENONCE »).
- **Offre flash** : une machine à −40 % pendant 4 h (urgence artificielle, elle tourne ensuite).
- **« Presque ! »** : les tirages sans paire deviennent parfois une paire visuelle (souvent sept/jackpot).
  Jamais de triple ajouté, les paiements sont strictement inchangés.
- **Fin de run** : « IL TE MANQUAIT X JETONS ! (92 % de l'objectif) », bouton « ABANDONNER »
  et bonus « REJOUE EN 15 s : plombs ×1,5 ».
- Horloge locale (UTC) : changer l'heure du téléphone permet de tricher, volontairement non protégé.

## Contenu long terme

- **Tutoriel** (1re partie, table 1) : 3 bulles — tape, chauffe, zone chaude — qui avancent selon ce que fait le joueur ;
  toucher une bulle la passe. Marqué fait dans la sauvegarde (`tuto_fait`).
- **12 machines** toutes actives (les 6 « ??? » sont devenues : Glaçon, Aimant, Banquier, Jumeaux, Phénix, Réacteur).
- **19 cartes de la maison** (13 nouvelles : fer à cheval, ventilo, tirelire, pari, bouclier, usurier, chrono, combo,
  roue turbo, gilet, givre, trèfle, équipe de nuit). Le Gilet n'est proposé que si on a perdu un cœur.
- **10 tables dont 3 boss** : Le Vigile (aucune surchauffe), Le Givre (chauffe max ÷ 2), Le Croupier muet (pas de roue).
  +2 plombs par boss vaincu. Bandeau « BOSS ! » à l'arrivée.
- **Succès** (18, plombs à la clé) et **statistiques** : écran SUCCÈS du menu, bandeaux dorés en fin de partie.
- **Défi du jour** : bouton DÉFI du menu. Graine = numéro du jour (mêmes tirages de roue pour tous), machine de base,
  un modificateur par jour (5 possibles), +5 plombs la 1re fois, record du jour conservé. Local, sans classement.
- **Mises** (comme les stakes de Balatro) : gagner une nuit à la mise la plus haute débloquée débloque la suivante.
  Malus cumulés : objectifs +20 %, 2 cœurs, verrou +1 s, refroidissement −25 %, tables −15 %.
  Chaque mise multiplie les plombs gagnés (×1,25 à ×3) : les machines s'achètent plus vite.
  Réglages : `data/Balance.gd` (`MISES`, `BOSS_*`, `DEFI_*`), `data/Succes.gd`, `data/Tables.gd`.

## Assets externes (intégrés)

- `assets/sprites/` : symboles (6), icônes de cartes (6), machines (6 + cadenas), titre. Convertis depuis les JPG Gemini
  par `tools/import_gemini.py` (détourage du faux damier, mise à la taille native, recoloration sur la palette).
  Boutons, panneaux, cœurs, ampoules et carcasse restent générés en code (les versions Gemini étaient incomplètes
  ou de proportions différentes). Supprimer un PNG suffit à revenir au sprite codé.
- `assets/audio/` : `musique_menu`, `musique_run`, `run2`, `run3`, `run4`, `run5` (une piste tirée au sort à chaque partie, sans répéter la précédente), `musique_gameover` (mp3, en boucle).
  Bruitages : générés. Pour en fournir : `assets/audio/sfx_<nom>.ogg|mp3|wav` (voir `ASSETS_GEMINI.md`).
- Images `vfx_*` du lot : non utilisées pour l'instant.

## Structure

```
project.godot  export_presets.cfg
art/       Palette.gd, Pixels.gd, PixelFont.gd   palette, sprites ASCII → texture, police pixel
autoload/  Save.gd, Game.gd, Sfx.gd, Fx.gd   sauvegarde, logique de run, sons, CRT/fondus
data/      Balance.gd, Cards.gd, Tables.gd, Machines.gd
scenes/    Boot, Menu, Run, CardPick, GameOver
ui/        Hud, FloatText, Fond
tools/     build_apk.sh, import_gemini.py, prepare_assets.py, preview_sprites.gd
assets/    sprites/ (PNG), audio/ (mp3)
```

Toutes les constantes d'équilibrage sont dans `data/Balance.gd`.
Sauvegarde : `user://save.json` (tolérante aux fichiers corrompus).
