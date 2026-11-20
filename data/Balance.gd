extends RefCounted
## Toutes les constantes d'equilibrage du jeu. Ajustables ICI et nulle part ailleurs.

# --- Taps ------------------------------------------------------------------
const TAP_COURT_MAX_MS: int = 250        # < 250 ms = tap court, >= 250 ms = tap maintenu
const GAIN_TENU: float = 3.0             # tap maintenu : gain x3
const CHAUFFE_COURT: float = 1.0         # chauffe ajoutee par un tap court
const CHAUFFE_TENU: float = 3.0          # chauffe ajoutee par un tap maintenu
const BASE_GAIN_DEPART: float = 6.0      # base_gain au niveau 0 (non fixe par le cahier des charges)

# --- Chauffe ---------------------------------------------------------------
const CHAUFFE_MAX_BASE: float = 20.0
const MULT_PAR_CHAUFFE: float = 0.15     # multiplicateur = 1 + 0,15 x chauffe
const REFROID_DELAI: float = 0.4         # s sans tap avant refroidissement
const REFROID_VITESSE: float = 3.0       # chauffe perdue par seconde
const VERROU_SURCHAUFFE: float = 2.0     # s de verrouillage apres surchauffe
const TAPS_FAIBLES: int = 3              # nombre de taps affaiblis apres surchauffe
const FACTEUR_FAIBLE: float = 0.5

# --- Fun (MODE ARCADE uniquement) : zone chaude, pieces d'or, ralenti ---------------------------------
# Zone chaude : a partir de 80 % de la jauge (et avant la surchauffe) chaque tap vaut x1,5.
const ZONE_CHAUDE_SEUIL: float = 0.8
const ZONE_CHAUDE_BONUS: float = 1.5
# Piece d'or : apparait toute seule, 3,5 s pour la toucher, rapporte 40 x valeur_tap.
const PIECE_DELAI_MIN: float = 10.0
const PIECE_DELAI_MAX: float = 20.0
const PIECE_DUREE: float = 3.5
const PIECE_COEF: float = 40.0
# Ralenti dramatique au jackpot (facteur de vitesse, duree reelle en secondes).
const RALENTI_FACTEUR: float = 0.3
const RALENTI_DUREE: float = 0.3

# --- La roue ---------------------------------------------------------------
const TAPS_PAR_ROUE: int = 25
# Duree d'animation selon le mode ; les rouleaux s'arretent a 50 / 75 / 100 %.
const ROUE_DUREE_ARCADE: float = 0.6
const ROUE_DUREE_CLASSIQUE: float = 1.2
const PAIEMENT_BASE_TAPS: float = 25.0   # paiement = coef x valeur_tap x 25
const COEF_RATE: float = 0.3             # aucun triple
const SYMBOLES: Array[String] = ["cerise", "citron", "cloche", "sept", "jackpot", "zero"]
const SYMBOLES_MIN: int = 3              # le plombier ne descend pas sous 3 symboles

const POIDS_CERISE: float = 40.0
const POIDS_CITRON: float = 28.0
const POIDS_CLOCHE: float = 16.0
const POIDS_SEPT: float = 9.0
const POIDS_SEPT_CHAUFFE: float = 0.3    # + 0,3 x chauffe
const POIDS_JACKPOT: float = 2.0
const POIDS_JACKPOT_CHAUFFE: float = 0.5 # + 0,5 x chauffe
const POIDS_JACKPOT_AIMANT: float = 2.0  # + 2 x aimants (crochet pour les machines a venir)
const POIDS_ZERO: float = 6.0            # symbole « double zero » (carte), absent sinon

const COEFS: Dictionary = {
	"cerise": 3.0,
	"citron": 6.0,
	"cloche": 14.0,
	"sept": 40.0,
	"jackpot": 120.0,
	"zero": 60.0,                        # triple 00 (carte Double zero)
}

# --- Upgrades (prix = base x ratio ^ niveau) ---------------------------------
const UPG_NOMS: Array[String] = ["EMPLOYÉ", "LEVIER POLI", "RADIATEUR"]
const UPG_BASE: Array[float] = [150.0, 400.0, 800.0]
const UPG_RATIO: Array[float] = [2.2, 3.0, 2.8]
const EMPLOYE_JETONS_S: float = 2.0      # +2 jetons/s par niveau
const LEVIER_FACTEUR: float = 1.5        # base_gain x1,5 par niveau
const RADIATEUR_CHAUFFE: float = 4.0     # chauffe_max +4 par niveau
const RADIATEUR_REFROID: float = 1.0     # refroidissement +1/s par niveau

# --- Run -------------------------------------------------------------------
const VIES_DEPART: int = 3
const DUREE_TABLE: float = 90.0
const DUREE_TABLE_FINALE: float = 75.0
const PAUSE_TRANSITION: float = 1.8      # s d'affichage apres une table ratee
const PLOMBS_COEF: float = 0.05          # plombs = max(1, floor(0,05 x pic / 10 000))
const PLOMBS_DIV: float = 10000.0

# --- Contraintes de tables -------------------------------------------------
const MULT_MIN_TABLE_6: float = 3.0

# --- Cartes de la maison ---------------------------------------------------
const DOUBLE_ZERO_CHAUFFE: float = 2.0
const DOUBLE_ZERO_JACKPOT: float = -1.0
const MAISON_PAIEMENT: float = 2.0
const MAISON_SURCHAUFFE_PERTE: float = 0.10
const RYTHME_BON: float = 1.5
const RYTHME_MAUVAIS: float = 0.8
const COUP_DE_BARRE_DUREE: float = 10.0
const STAGIAIRE_TAPS_S: float = 1.0
const OFFRE_CARTES: int = 3

# --- Machines (meta) -------------------------------------------------------
const VERROU_VAPEUR: float = 3.0
const VERROU_BECANE: float = 4.0
const BECANE_MULT: float = 1.25
const MUET_FACTEUR: float = 2.5
const RUCHE_JAUGES: int = 3

# --- Retention (dark patterns assumes : aucune monnaie reelle, tout est local) ---------
# Serie quotidienne : plombs offerts par jour de serie (le 7e jour est le gros lot,
# puis le cycle recommence). Rater un jour remet la serie a zero (aversion a la perte).
const SERIE_RECOMPENSES: Array[int] = [1, 2, 3, 4, 6, 8, 20]
# Offre flash : une machine a -40 % pendant une fenetre de 4 h, qui tourne ensuite.
const OFFRE_FENETRE_S: float = 14400.0
const OFFRE_REMISE: float = 0.4
# « Presque ! » : part des tirages sans paire qui sont transformes en paire visuelle.
# N'ajoute JAMAIS de triple : les paiements restent identiques.
const PRESQUE_PROBA: float = 0.5
# Bonus de relance : rejouer dans les N secondes apres une defaite = plombs x1,5 a la prochaine fin.
const RELANCE_DELAI_S: float = 15.0
const RELANCE_MULT: float = 1.5

# --- Machines 7 a 12 ---------------------------------------------------------
const GLACON_REFROID: float = 2.0        # refroidissement x2
const GLACON_CHAUFFE_MAX: float = 4.0
const AIMANT_MACHINE: int = 3            # aimants de depart (poids jackpot +2 chacun)
const BANQUIER_PERIODE: float = 5.0
const BANQUIER_TAUX: float = 0.01        # +1 % des jetons toutes les 5 s
const JUMEAUX_PROBA: float = 0.15
const REACTEUR_TAPS: float = 10.0        # une surchauffe paie 10 taps d'un coup

# --- Cartes 7 a 19 -----------------------------------------------------------
const FER_CHEVAL_POIDS: float = 3.0      # + au poids du sept et du jackpot
const VENTILO_REFROID: float = 2.0
const TIRELIRE_PLOMBS: int = 3
const PARI_GAIN_TENU: float = 5.0        # taps maintenus x5 (au lieu de x3)
const PARI_CHAUFFE: float = 2.0          # ...mais +2 de chauffe de plus
const USURIER_GAINS: float = 1.25
const USURIER_OBJECTIF: float = 1.15
const CHRONO_BONUS_S: float = 15.0
const COMBO_PERIODE: int = 10            # un tap sur 10 vaut x3
const COMBO_FACTEUR: float = 3.0
const TURBO_TAPS_PAR_ROUE: int = 18
const GIVRE_DUREE: float = 5.0           # chauffe gelee au debut de chaque table
const TREFLE_COEF_RATE: float = 1.0      # une roue ratee paie x1 au lieu de x0,3
const EQUIPE_FACTEUR: float = 2.0        # employes x2

# --- Mises (niveaux de difficulte, comme les « stakes » de Balatro) --------------
# Gagner une nuit a la mise la plus haute debloquee debloque la suivante. Les malus se CUMULENT.
# « plombs » : multiplicateur de plombs gagnes (plus de plombs = machines plus vite achetees).
const MISES: Array = [
	{"nom": "MISE 1", "malus": "Aucun malus.", "plombs": 1.0},
	{"nom": "MISE 2", "malus": "Objectifs +20 %.", "plombs": 1.25},
	{"nom": "MISE 3", "malus": "Tu n'as que 2 cœurs.", "plombs": 1.5},
	{"nom": "MISE 4", "malus": "Verrou de surchauffe +1 s.", "plombs": 2.0},
	{"nom": "MISE 5", "malus": "Refroidissement -25 %.", "plombs": 2.5},
	{"nom": "MISE 6", "malus": "Tables 15 % plus courtes.", "plombs": 3.0},
]
const MISE_OBJECTIF: float = 1.2         # des la mise 2
const MISE_VERROU: float = 1.0           # des la mise 4
const MISE_REFROID: float = 0.75         # des la mise 5
const MISE_DUREE: float = 0.85           # des la mise 6

# --- Bosses et plombs ----------------------------------------------------------
const BOSS_PLOMBS: int = 2               # plombs bonus par boss vaincu
const BOSS_CHAUD_MAX: float = 0.5        # boss « Le Givre » : chauffe max divisee par 2

# --- Defi du jour (graine = numero du jour, aucun reseau) ------------------------
const DEFI_PLOMBS_PREMIER: int = 5       # plombs offerts la 1re fois chaque jour
const DEFI_MODIFS: Array = [
	{"id": "froid", "nom": "GRAND FROID", "desc": "Refroidissement x2."},
	{"id": "fournaise", "nom": "FOURNAISE", "desc": "Multiplicateur x1,5 mais chauffe max -5."},
	{"id": "chance", "nom": "JOUR DE CHANCE", "desc": "Jackpot deux fois plus fréquent."},
	{"id": "blitz", "nom": "BLITZ", "desc": "Tables de 60 secondes."},
	{"id": "soldes", "nom": "SOLDES", "desc": "Améliorations -30 %."},
]

## Prix d'une upgrade au niveau donne.
static func prix_upgrade(i: int, niveau: int) -> float:
	return roundf(UPG_BASE[i] * pow(UPG_RATIO[i], float(niveau)))
