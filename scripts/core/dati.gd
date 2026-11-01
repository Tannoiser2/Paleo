class_name Dati
## Dati fissi del gioco: carte (da data/carte.json), attrezzi, moduli e livelli.

## Attrezzi: abilità permanenti (perm), abilità monouso (uso), effetti speciali, quantità nella scatola.
const ATTREZZI := {
	"torcia": {"nome": "Torcia", "uso": {"P": 1}, "scorta": 5},
	"amigdala": {"nome": "Amigdala", "perm": {"D": 1}, "scorta": 5},
	"lancia": {"nome": "Lancia", "perm": {"F": 1}, "scorta": 5},
	"vestiti": {"nome": "Vestiti", "para": 3, "scorta": 2},
	"pelle": {"nome": "Pelle", "para": 1, "scorta": 9},
	"talismano": {"nome": "Talismano", "scorta": 2},
	"lupo": {"nome": "Lupo addomesticato", "perm": {"P": 1}, "scorta": 2},
	"radice": {"nome": "Radice curativa", "cura": 3, "scorta": 2},
	"ascia": {"nome": "Ascia", "perm": {"F": 1, "D": 1}, "scorta": 2},
	"corda": {"nome": "Corda", "uso": {"X": 1}, "scorta": 3},
	"trappola": {"nome": "Trappola", "uso": {"F": 2}, "scorta": 3},
	"tenda": {"nome": "Tenda", "scorta": 3},
	"totem": {"nome": "Totem", "perm": {"P": 2}, "scorta": 1},
	"zattera": {"nome": "Zattera", "scorta": 4},
}

const ABILITA := {"F": "Forza", "P": "Percezione", "D": "Destrezza"}
const RISORSE := {"cibo": "Cibo", "legno": "Legno", "pietra": "Pietra"}
const SCORTA_RISORSE := {"cibo": 20, "legno": 12, "pietra": 8}

## Idee sempre presenti sul banco di lavoro (costo -> attrezzo).
const IDEE_BASE := [
	{"id": "torcia", "nome": "Torcia", "paga": {"legno": 1}, "attrezzo": "torcia"},
	{"id": "amigdala", "nome": "Amigdala", "paga": {"pietra": 1}, "attrezzo": "amigdala"},
	{"id": "lancia", "nome": "Lancia", "paga": {"legno": 1, "pietra": 1}, "attrezzo": "lancia"},
]

## Facce dei dadi.
const DADO := [{"F": 1}, {"F": 2}, {"P": 2}, {"F": 1}, {"P": 1}, {"D": 1}]

const MODULI := {
	"A": {"nome": "Caccia grossa", "difficolta": "Facile", "missione": 85, "segreti": [1, 2], "dadi": false,
		"storia": "Per superare l'inverno dobbiamo fare scorte. Per fortuna le nostre vedette hanno avvistato un branco di mammut vicino al fiume."},
	"B": {"nome": "Un nuovo mondo", "difficolta": "Facile", "missione": 96, "segreti": [], "idee": [95], "dadi": false,
		"storia": "Dobbiamo spostarci e seguire le prede, se non vogliamo morire di fame."},
	"C": {"nome": "Ululati nella notte", "difficolta": "Media", "missione": 106, "segreti": [3, 4], "dadi": true,
		"storia": "In questa regione non siamo noi in cima alla catena alimentare... almeno per ora."},
	"D": {"nome": "Il passo successivo", "difficolta": "Facile", "missione": 117, "segreti": [5, 6, 7], "attesa": [116], "dadi": true,
		"storia": "Senza le materie prime non possiamo inventare nuovi attrezzi."},
	"E": {"nome": "L'eroe dell'era glaciale", "difficolta": "Media", "missione": 129, "segreti": [3, 8, 9, 10, 11], "attesa": [125, 126, 127, 128], "dadi": true,
		"storia": "Quattro potenti viandanti sono comparsi nel nostro accampamento. Finora di potente hanno soltanto l'appetito."},
	"F": {"nome": "Tempesta di neve", "difficolta": "Media", "missione": 146, "segreti": [7, 12, 13, 14, 15], "idee": [145], "dadi": true,
		"storia": "È arrivato il momento: l'inverno stende il suo freddo mantello sulla tundra."},
	"G": {"nome": "Febbre delirante", "difficolta": "Difficile", "missione": 161, "segreti": [8, 16, 17], "dadi": true,
		"storia": "Una malattia sta decimando la tribù. Forse la sciamana sa quali bacche possono aiutare."},
	"H": {"nome": "Corrente impetuosa", "difficolta": "Difficile", "missione": 175, "segreti": [10, 18, 19, 20], "idee": [174], "dadi": true, "fiume": true,
		"storia": "Chissà cosa troveremo sull'altra riva di questo fiume?"},
	"I": {"nome": "Attacco delle Mani Bianche", "difficolta": "Difficile", "missione": 186, "segreti": [6, 9], "dadi": true, "guerriere": [13, 14, 15, 20],
		"storia": "Solo le nostre guerriere più forti riescono a proteggere il villaggio."},
	"J": {"nome": "La belva", "difficolta": "Mortale", "missione": 200, "segreti": [21, 22], "dadi": true, "artigli": [187, 188, 189, 190, 191, 192],
		"storia": "La creatura crudele si aggira intorno al nostro accampamento: non siamo al sicuro da nessuna parte!"},
}

const LIVELLI := [
	{"nome": "Livello I", "moduli": ["A", "B"]},
	{"nome": "Livello II", "moduli": ["C", "D"]},
	{"nome": "Livello III", "moduli": ["E", "F"]},
	{"nome": "Livello IV", "moduli": ["C", "G"]},
	{"nome": "Livello V", "moduli": ["A", "H"]},
	{"nome": "Livello VI", "moduli": ["B", "I"]},
	{"nome": "Livello VII", "moduli": ["D", "E", "J"]},
]

const VARIANTI := {
	"grande_tribu": {"nome": "Grande tribù", "facile": true, "testo": "Quando ricevi un umano ne peschi 2 e ne scegli 1."},
	"provviste": {"nome": "Provviste", "facile": true, "testo": "All'inizio 2 idee nel banco di lavoro, 2 legno e 2 pietra nel campo."},
	"squadra": {"nome": "Lavoro di squadra", "facile": true, "testo": "Quando ti aiutano, scegliete insieme chi scarta le carte."},
	"nebbia": {"nome": "Nebbia", "facile": false, "testo": "Scegli solo fra le prime 2 carte del mazzo (invece di 3)."},
	"debolezza": {"nome": "Debolezza", "facile": false, "testo": "Ogni umano che ricevi subisce 1 danno."},
	"lunghe_strade": {"nome": "Lunghe strade", "facile": false, "testo": "Per aiutare un compagno devi scartare 2 carte in più."},
}

## Carte con "Wolf" nel titolo originale (missione Ululati nella notte).
const LUPI := [54, 68, 88, 97, 101, 103, 104, 105, 133, 198]
## Carte animale (zoccolo in alto a sinistra): Fame senza fine, Terre lontane.
const ANIMALI := [45, 47, 49, 52, 57, 59, 62, 67, 23, 24, 32, 78, 82, 84, 121, 162, 165, 167, 169, 171, 94, 136, 119]

static var _carte := {}


static func carte() -> Dictionary:
	if _carte.is_empty():
		var f := FileAccess.open("res://data/carte.json", FileAccess.READ)
		var arr: Array = JSON.parse_string(f.get_as_text())
		for c in arr:
			_carte[int(c["id"])] = c
	return _carte


static func carta(id: int) -> Dictionary:
	return carte().get(id, {})


static func segreto_id(n: int) -> int:
	return 220 + n


static func nome_attrezzo(t: String) -> String:
	return ATTREZZI.get(t, {}).get("nome", t.capitalize())
