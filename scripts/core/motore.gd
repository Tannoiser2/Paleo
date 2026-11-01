class_name Motore
extends Node
## Motore di Paleo: stato della partita e regole complete (fase del giorno, fase della notte, moduli A–J).
##
## Il motore non conosce l'interfaccia: quando serve una scelta chiama `chiedi(posto, richiesta)`, che
## gira la domanda al "controllore" del posto (persona, IA o partita online). Tutte le scelte e i tiri di
## dado passano da qui, quindi con lo stesso seme e le stesse risposte la partita è identica ovunque.

signal cambiato
signal messaggio(testo: String)
signal evento(tipo: String, dati: Dictionary)
signal finita(esito: String)

var C: Dictionary
var rng := RandomNumberGenerator.new()
var seme := 0
var controllori: Array = []        # un oggetto con decide(motore, posto, richiesta) per ogni posto

# --- configurazione
var moduli: Array = []
var varianti: Dictionary = {}
var solo := false
var con_dadi := false

# --- stato
var giocatori: Array = []
var risorse := {"cibo": 0, "legno": 0, "pietra": 0}
var scorta_attrezzi := {}
var banco_attrezzi := {}           # attrezzi già pronti davanti alle idee del banco
var mazzo_umani: Array = []
var mazzo_sogni: Array = []
var mazzo_idee: Array = []
var segreti: Array = []            # numeri dei segreti ancora sul tabellone Notte
var missioni: Array = []
var attesa: Array = []
var banco: Array = []              # carte idea nel banco di lavoro
var cimitero: Array = []
var scarti_scoperti: Array = []
var scarti_coperti: Array = []
var depositi := {}                 # id carta -> {risorsa/attrezzo: quantità}
var fiume: Array = []
var guerriere: Array = []
var guerriere_danni := 0
var belva_furiosa := false
var tigre_danni := 0
var teschi := 0
var vittorie := 0
var giorno := 1
var fase := "preparazione"
var esito := ""
var registro: Array = []
var turno := 0
var _gelo := false

const MAX_IDEE := 6


func _init() -> void:
	C = Dati.carte()


# =====================================================================================
# PREPARAZIONE
# =====================================================================================

## config: {giocatori: [{nome, ia}], moduli: [...], varianti: {...}, seme}
func prepara(config: Dictionary) -> void:
	seme = int(config.get("seme", 0))
	if seme == 0:
		seme = randi()
	rng.seed = seme
	moduli = config.get("moduli", ["A", "B"]).duplicate()
	varianti = config.get("varianti", {}).duplicate()
	var gg: Array = config.get("giocatori", [{"nome": "Giocatore 1", "ia": false}])
	solo = gg.size() == 1
	con_dadi = false
	for m in moduli:
		if Dati.MODULI[m]["dadi"]:
			con_dadi = true
	giocatori.clear()
	for g in gg:
		giocatori.append({"nome": g.get("nome", "Gruppo"), "ia": g.get("ia", false), "mazzo": [], "gruppo": [],
			"danni": {}, "attrezzi": {}, "rivelata": -1, "risolta": true, "dorme": false, "aiuto_chiesto": false,
			"cacciatori_usati": false, "lanciatore_usato": false, "chiamata_usata": false})
	for t in Dati.ATTREZZI:
		scorta_attrezzi[t] = int(Dati.ATTREZZI[t]["scorta"])
	# torce, amigdale e lance stanno sul banco di lavoro
	for t in ["torcia", "amigdala", "lancia"]:
		banco_attrezzi[t] = scorta_attrezzi[t]
		scorta_attrezzi[t] = 0
	# mazzi di base
	for id in C:
		var c: Dictionary = C[id]
		match c["modulo"]:
			"2":
				mazzo_umani.append(id)
			"3":
				mazzo_sogni.append(id)
			"4":
				mazzo_idee.append(id)
	var gioco: Array = []
	for id in C:
		if C[id]["modulo"] == "1":
			gioco.append(id)
	segreti.clear()
	for m in moduli:
		var md: Dictionary = Dati.MODULI[m]
		missioni.append(int(md["missione"]))
		for s in md.get("segreti", []):
			if not segreti.has(int(s)):
				segreti.append(int(s))
		var speciali: Array = [int(md["missione"])]
		for x in md.get("idee", []):
			banco.append(int(x))
			speciali.append(int(x))
			_rifornisci_banco(int(x))
		for x in md.get("attesa", []):
			attesa.append(int(x))
			speciali.append(int(x))
		for x in md.get("guerriere", []):
			mazzo_umani.erase(int(x))
			guerriere.append(int(x))
		for x in md.get("artigli", []):
			speciali.append(int(x))
		var del_fiume: Array = []
		for id in C:
			var c: Dictionary = C[id]
			if c["modulo"] == m and not speciali.has(id):
				if md.get("fiume", false) and c["dorso_tipo"] == "fiume":
					del_fiume.append(id)
				else:
					gioco.append(id)
		if not del_fiume.is_empty():
			_mescola(del_fiume)
			fiume = del_fiume
	segreti.sort()
	_mescola(mazzo_umani)
	_mescola(mazzo_sogni)
	_mescola(mazzo_idee)
	_mescola(gioco)
	# risorse iniziali
	risorse = {"cibo": 0 if solo else 5, "legno": 0, "pietra": 0}
	if varianti.get("provviste", false):
		risorse["legno"] += 2
		risorse["pietra"] += 2
		for i in 2:
			_nuova_idea(false)
	# carte ai giocatori
	_distribuisci(gioco)
	for p in giocatori.size():
		for i in 2:
			await _dai_umano(p, true)
	fase = "giorno"
	_log("Inizia il giorno 1. Moduli: %s." % ", ".join(moduli.map(func(m): return Dati.MODULI[m]["nome"])))
	cambiato.emit()


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _distribuisci(carte: Array) -> void:
	for g in giocatori:
		g["mazzo"] = []
	var i := 0
	# chi ha ricevuto meno carte il giorno prima comincia (qui: distribuzione circolare dal primo)
	for id in carte:
		giocatori[i % giocatori.size()]["mazzo"].append(id)
		i += 1


func _rifornisci_banco(idea: int) -> void:
	var o: Dictionary = C[idea]["opzioni"][0]
	for t in o["attrezzi"]:
		banco_attrezzi[t] = banco_attrezzi.get(t, 0) + scorta_attrezzi.get(t, 0)
		scorta_attrezzi[t] = 0


func _log(t: String) -> void:
	registro.append(t)
	if registro.size() > 300:
		registro.pop_front()
	messaggio.emit(t)


# =====================================================================================
# DOMANDE AI CONTROLLORI
# =====================================================================================

## richiesta: {tipo, titolo, testo, opzioni: [{testo, ...}], carta?, posto}
## Risponde con l'indice dell'opzione scelta (o con il valore richiesto dal tipo).
func chiedi(posto: int, richiesta: Dictionary):
	richiesta["posto"] = posto
	if richiesta.has("opzioni") and richiesta["opzioni"].size() == 1 and not richiesta.get("conferma", false):
		return 0
	var ctl = controllori[posto] if posto < controllori.size() else null
	if ctl == null:
		return 0
	var r = await ctl.decide(self, posto, richiesta)
	return r


## Il posto che decide per tutta la tribù (missioni, ordine): il primo giocatore umano.
func capo() -> int:
	for i in giocatori.size():
		if not giocatori[i]["ia"]:
			return i
	return 0


# =====================================================================================
# SVOLGIMENTO
# =====================================================================================

func gioca() -> void:
	while esito == "":
		await _fase_giorno()
		if esito != "":
			break
		await _fase_notte()
	fase = "fine"
	cambiato.emit()
	finita.emit(esito)


func _fase_giorno() -> void:
	fase = "giorno"
	for g in giocatori:
		g["dorme"] = g["mazzo"].is_empty()
		g["risolta"] = true
		g["rivelata"] = -1
		g["cacciatori_usati"] = false
		g["lanciatore_usato"] = false
	cambiato.emit()
	while esito == "":
		var svegli := []
		for i in giocatori.size():
			if not giocatori[i]["dorme"]:
				svegli.append(i)
		if svegli.is_empty():
			break
		turno += 1
		# 1. scelta della carta (in ordine; i compagni vedono solo i dorsi)
		for i in svegli:
			await _scegli_carta(i)
			if esito != "":
				return
		# 2. rivelazione
		var rivelate := []
		for i in svegli:
			var g: Dictionary = giocatori[i]
			if g["rivelata"] >= 0:
				rivelate.append(i)
				g["risolta"] = false
				g["cacciatori_usati"] = false
				g["lanciatore_usato"] = false
				g["chiamata_usata"] = false
				evento.emit("rivela", {"posto": i, "carta": g["rivelata"]})
				_log("%s scopre «%s»." % [g["nome"], C[g["rivelata"]]["nome"]])
		cambiato.emit()
		# carte che vanno messe subito da qualche parte
		for i in rivelate:
			await _sistemazioni_immediate(i)
		# Gelo: va risolto prima di tutte le altre
		for i in rivelate:
			var g: Dictionary = giocatori[i]
			if not g["risolta"] and g["rivelata"] >= 0 and C[g["rivelata"]]["nome"] == "Gelo":
				await _risolvi_carta(i)
		# 3. risoluzione: si sceglie a turno chi agisce
		while esito == "":
			var aperte := []
			for i in rivelate:
				if not giocatori[i]["risolta"]:
					aperte.append(i)
			if aperte.is_empty():
				break
			var chi: int = aperte[0]
			if aperte.size() > 1:
				var opz := []
				for i in aperte:
					opz.append({"testo": "%s — «%s»" % [giocatori[i]["nome"], C[giocatori[i]["rivelata"]]["nome"]], "posto": i})
				var r = await chiedi(capo(), {"tipo": "ordine", "titolo": "Chi agisce adesso?",
					"testo": "Decidete insieme in che ordine risolvere le carte scoperte.", "opzioni": opz})
				chi = opz[int(r)]["posto"]
			await _risolvi_carta(chi)
			_controlla_fine()
		for i in svegli:
			if giocatori[i]["mazzo"].is_empty():
				if not giocatori[i]["dorme"]:
					_log("%s non ha più carte e va a dormire." % giocatori[i]["nome"])
				giocatori[i]["dorme"] = true
		cambiato.emit()


func _scegli_carta(i: int) -> void:
	var g: Dictionary = giocatori[i]
	var quante := 2 if varianti.get("nebbia", false) else 3
	var cima: Array = g["mazzo"].slice(0, quante)
	var opz := []
	for k in cima.size():
		opz.append({"testo": "Carta %d (%s)" % [k + 1, _nome_dorso(cima[k])], "k": "carta", "i": k, "carta": cima[k]})
	if not fiume.is_empty() and _ha_attrezzo_gruppo(i, "zattera"):
		opz.append({"testo": "Scopri la prima carta del Grande fiume", "k": "fiume"})
	opz.append({"testo": "Vai a dormire prima (scarta tutto il mazzo coperto)", "k": "dormi"})
	var r = await chiedi(i, {"tipo": "scegli_carta", "titolo": "%s: quale luogo esplorate?" % g["nome"],
		"testo": "Scegli una delle prime carte del tuo mazzo guardando il dorso.", "opzioni": opz, "conferma": true})
	var o: Dictionary = opz[int(r)]
	match o["k"]:
		"carta":
			g["rivelata"] = g["mazzo"][o["i"]]
			g["mazzo"].remove_at(o["i"])
		"fiume":
			g["rivelata"] = fiume.pop_front()
		"dormi":
			for id in g["mazzo"]:
				scarti_coperti.append(id)
			g["mazzo"].clear()
			g["rivelata"] = -1
			g["dorme"] = true
			_log("%s va a dormire prima." % g["nome"])


func _nome_dorso(id: int) -> String:
	return {"umano": "umano", "sogno": "sogno", "idea": "idea", "fiume": "fiume", "montagna": "montagna",
		"bosco": "bosco", "casa": "casa", "rosso": "pericolo", "orme": "orme", "neve": "neve",
		"missione": "missione", "segreto": "segreto"}.get(C[id]["dorso_tipo"], "?")


func e_rosso(id: int) -> bool:
	return C[id]["dorso_tipo"] == "rosso"


## Carte che, scoperte, vanno subito nel gruppo o nell'attesa (Pescatore, segreti…).
func _sistemazioni_immediate(i: int) -> void:
	var g: Dictionary = giocatori[i]
	var id: int = g["rivelata"]
	if id < 0:
		return
	var c: Dictionary = C[id]
	if c["tipo"] == "U" and c["zona"] == "gruppo":
		g["gruppo"].append(id)
		g["rivelata"] = -1
		g["risolta"] = true
		_log("«%s» si unisce al gruppo di %s." % [c["nome"], g["nome"]])
		cambiato.emit()


# =====================================================================================
# RISOLUZIONE DI UNA CARTA SCOPERTA
# =====================================================================================

func _risolvi_carta(i: int) -> void:
	var g: Dictionary = giocatori[i]
	var id: int = g["rivelata"]
	if id < 0:
		g["risolta"] = true
		return
	var c: Dictionary = C[id]
	var vietate := {}
	while true:
		if esito != "":
			return
		var voci := _voci_carta(i, id, vietate)
		var opz := []
		for v in voci:
			opz.append({"testo": v["testo"], "voce": v})
		var r = await chiedi(i, {"tipo": "opzione", "titolo": "%s: «%s»" % [g["nome"], c["nome"]],
			"testo": "Scegli che cosa fare con la carta scoperta.", "opzioni": opz, "carta": id, "conferma": true})
		var v: Dictionary = opz[int(r)]["voce"]
		var esito_voce := await _esegui_voce(i, id, v)
		if esito_voce == "fatto":
			break
		if esito_voce == "riprova":
			vietate[v["chiave"]] = true
			continue
		if esito_voce == "attendi":
			return
	g["risolta"] = true
	cambiato.emit()


## Elenco delle scelte possibili per la carta scoperta del giocatore i.
func _voci_carta(i: int, id: int, vietate: Dictionary) -> Array:
	var c: Dictionary = C[id]
	var g: Dictionary = giocatori[i]
	var voci := []
	var pericolo: bool = c["tipo"] == "P"
	var opzioni: Array = _opzioni_effettive(id)
	var neg_possibili := []
	var qualcosa_positivo := false
	for k in opzioni.size():
		var o: Dictionary = opzioni[k]
		if o["aiuto_carta"]:
			continue
		if not _stato_ok(o):
			continue
		var chiave := "o%d" % k
		if vietate.has(chiave):
			continue
		if o["neg"]:
			neg_possibili.append(k)
			continue
		var serve := _serve_aiuto(i, o, id)
		if serve == "no":
			continue
		qualcosa_positivo = true
		voci.append({"k": "azione", "o": k, "chiave": chiave, "testo": descrivi_opzione(o, id) + ("  (serve aiuto)" if serve == "aiuto" else "")})
	# azioni negative: vanno scelte fra quelle eseguibili; se nessuna lo è, si esegue il possibile
	var neg_eseguibili := []
	for k in neg_possibili:
		if _neg_eseguibile(i, opzioni[k], id):
			neg_eseguibili.append(k)
	var neg_da_offrire: Array = neg_eseguibili if not neg_eseguibili.is_empty() else neg_possibili
	for k in neg_da_offrire:
		voci.append({"k": "azione", "o": k, "chiave": "o%d" % k, "testo": "[negativa] " + descrivi_opzione(opzioni[k], id)})
	# aiutare una carta (carte con l'azione «aiuta» nel gruppo o nell'attesa)
	if c["aiuto"]:
		for ac in _carte_da_aiutare(i):
			var oc: Dictionary = C[ac["carta"]]["opzioni"][ac["o"]]
			var s := _serve_aiuto(i, oc, ac["carta"])
			if s != "no":
				voci.append({"k": "aiuta_carta", "carta": ac["carta"], "o": ac["o"], "chiave": "a%d_%d" % [ac["carta"], ac["o"]],
					"testo": "Aiuta «%s»: %s" % [C[ac["carta"]]["nome"], descrivi_opzione(oc, ac["carta"])]})
	# azioni aggiuntive delle carte scoperte nel gruppo o nell'attesa (non contano come opzione)
	for ec in _azioni_aggiuntive(i):
		var oe: Dictionary = C[ec["carta"]]["opzioni"][ec["o"]]
		if not vietate.has("e%d_%d" % [ec["carta"], ec["o"]]) and _fattibile(i, [i], oe, ec["carta"], false):
			voci.append({"k": "extra", "carta": ec["carta"], "o": ec["o"], "chiave": "e%d_%d" % [ec["carta"], ec["o"]],
				"testo": "Azione aggiuntiva di «%s»: %s" % [C[ec["carta"]]["nome"], descrivi_opzione(oe, ec["carta"])]})
	# talismano contro i pericoli
	if pericolo and _ha_attrezzo_gruppo(i, "talismano"):
		voci.append({"k": "talismano", "chiave": "tal", "testo": "Usa il talismano: ignora il pericolo"})
	if not pericolo:
		voci.append({"k": "ignora", "chiave": "ign", "testo": "Ignora la carta"})
	# attendere che gli altri agiscano (per poter usare risorse o aiuti ottenuti dopo)
	var altri := 0
	for j in giocatori.size():
		if j != i and not giocatori[j]["risolta"] and giocatori[j]["rivelata"] >= 0:
			altri += 1
	if altri > 0:
		voci.append({"k": "attendi", "chiave": "att", "testo": "Aspetta: lascia agire prima gli altri"})
	# radice curativa: azione gratuita prima o dopo
	if _ha_attrezzo_gruppo(i, "radice") and _danni_gruppo(i) > 0:
		voci.append({"k": "radice", "chiave": "rad", "testo": "Usa la radice curativa (cura fino a 3), poi scegli ancora"})
	if voci.is_empty():
		voci.append({"k": "ignora", "chiave": "ign", "testo": "Scarta la carta (nessuna azione possibile)"})
	return voci


## Opzioni della carta, con quelle aggiunte da altre carte (Battuta di caccia sul Branco di lupi).
func _opzioni_effettive(id: int) -> Array:
	var o: Array = C[id]["opzioni"].duplicate()
	if C[id]["nome"] == "Branco di lupi" and attesa.has(Dati.segreto_id(4)):
		o.append({"neg": false, "req": {"F": 7, "W": 1}, "carte": 3, "distruggi": true, "paga": {}, "paga_attrezzi": {},
			"cond": [], "guadagna": {"cibo": 4, "V": 1}, "attrezzi": {}, "danno": 0, "teschi": 0, "speciali": [],
			"stato": "", "aiuto_carta": false, "deposito": false})
	return o


func _stato_ok(o: Dictionary) -> bool:
	match o.get("stato", ""):
		"calma":
			return not belva_furiosa
		"furiosa":
			return belva_furiosa
	return true


func _carte_da_aiutare(i: int) -> Array:
	var out := []
	var dove: Array = attesa.duplicate()
	for j in giocatori.size():
		dove.append_array(giocatori[j]["gruppo"])
	for id in dove:
		var c: Dictionary = C[id]
		for k in c["opzioni"].size():
			if c["opzioni"][k]["aiuto_carta"]:
				# carta nel gruppo di un altro: anche lui deve partecipare (si gestisce come aiuto richiesto)
				out.append({"carta": id, "o": k})
	return out


func _azioni_aggiuntive(i: int) -> Array:
	var out := []
	var dove: Array = attesa.duplicate()
	dove.append_array(giocatori[i]["gruppo"])
	for id in dove:
		var c: Dictionary = C[id]
		if c["tipo"] != "G":
			continue
		for k in c["opzioni"].size():
			var o: Dictionary = c["opzioni"][k]
			if not o["aiuto_carta"] and not o["neg"]:
				out.append({"carta": id, "o": k})
	return out


func _danni_gruppo(i: int) -> int:
	var t := 0
	for id in giocatori[i]["danni"]:
		t += int(giocatori[i]["danni"][id])
	return t


# =====================================================================================
# ABILITÀ, REQUISITI E COSTI
# =====================================================================================

## Abilità permanenti dei gruppi indicati.
func abilita_permanenti(posti: Array) -> Dictionary:
	var a := {"F": 0, "P": 0, "D": 0}
	for p in posti:
		var g: Dictionary = giocatori[p]
		for id in g["gruppo"]:
			for s in C[id]["abilita"]:
				a[s] += 1
		for t in g["attrezzi"]:
			var perm: Dictionary = Dati.ATTREZZI.get(t, {}).get("perm", {})
			for s in perm:
				a[s] += int(perm[s]) * int(g["attrezzi"][t])
	return a


func _ha_attrezzo_gruppo(p: int, t: String) -> bool:
	return int(giocatori[p]["attrezzi"].get(t, 0)) > 0


func _attrezzi_totali(posti: Array) -> Dictionary:
	var a := {}
	for p in posti:
		for t in giocatori[p]["attrezzi"]:
			a[t] = a.get(t, 0) + int(giocatori[p]["attrezzi"][t])
	return a


func _ha_carta_titolo(posti: Array, titolo: String) -> bool:
	for p in posti:
		for id in giocatori[p]["gruppo"]:
			if C[id]["nome"] == titolo:
				return true
	return false


func _nel_cimitero(titolo: String) -> bool:
	for id in cimitero:
		if C[id]["nome"] == titolo:
			return true
	return false


func numero_umani(p: int) -> int:
	var n := 0
	for id in giocatori[p]["gruppo"]:
		if C[id]["tipo"] == "U":
			n += 1
	return n


func _cond_ok(conds: Array, posti: Array) -> bool:
	for cnd in conds:
		var s: String = cnd
		if s.begins_with("carta:"):
			var ok := false
			for t in s.substr(6).split("|"):
				if _ha_carta_titolo(posti, t):
					ok = true
			if not ok:
				return false
		elif s.begins_with("distrutta:"):
			if not _nel_cimitero(s.substr(10)):
				return false
		elif s == "umani1-2":
			if numero_umani(posti[0]) > 2:
				return false
		elif s == "umani3+":
			if numero_umani(posti[0]) < 3:
				return false
		elif s == "lupi5":
			var n := 0
			for id in cimitero:
				if Dati.LUPI.has(id):
					n += 1
			if n < 5:
				return false
		elif s == "desideri0":
			for d in [125, 126, 127, 128]:
				if not cimitero.has(d):
					return false
		elif s == "fiumevuoto":
			if not fiume.is_empty():
				return false
		elif s == "vittorie5":
			if vittorie < 5:
				return false
		elif s == "aiutozattera":
			var ok := false
			for p in posti.slice(1):
				if _ha_attrezzo_gruppo(p, "zattera"):
					ok = true
			if not ok:
				return false
	return true


## Prova a coprire i requisiti di abilità con permanenti + monouso. Restituisce {ok, usa: [[posto, attrezzo]], cacciatori, lanciatore}.
func risolvi_requisiti(posti: Array, req: Dictionary, riserva: Dictionary = {}) -> Dictionary:
	var base := abilita_permanenti(posti)
	var manca := {"F": max(0, int(req.get("F", 0)) - base["F"]), "P": max(0, int(req.get("P", 0)) - base["P"]),
		"D": max(0, int(req.get("D", 0)) - base["D"])}
	var usa := []
	var disp := {}
	for p in posti:
		for t in giocatori[p]["attrezzi"]:
			var n: int = int(giocatori[p]["attrezzi"][t])
			if riserva.has(t):
				var tolti: int = min(n, int(riserva[t]))
				riserva = riserva.duplicate()
				riserva[t] = int(riserva[t]) - tolti
				n -= tolti
			for k in n:
				disp[[p, t, k]] = true
	var prendi := func(t: String) -> bool:
		for key in disp:
			if key[1] == t:
				disp.erase(key)
				usa.append([key[0], t])
				return true
		return false
	var cacciatori := false
	var lanciatore := false
	if manca["F"] > 0:
		for p in posti:
			if manca["F"] > 0 and _ha_carta_titolo([p], "Cacciatori affamati") and not giocatori[p]["cacciatori_usati"]:
				cacciatori = true
				manca["F"] -= 2
				break
	while manca["F"] > 0 and prendi.call("trappola"):
		manca["F"] -= 2
	if manca["F"] > 0:
		for p in posti:
			if _ha_carta_titolo([p], "Lanciatore") and not giocatori[p]["lanciatore_usato"] and int(giocatori[p]["attrezzi"].get("lancia", 0)) > 0:
				# si scarta una lancia (che smette di dare +1) per +3
				usa.append([p, "lancia"])
				lanciatore = true
				manca["F"] -= 2
				break
	while manca["P"] > 0 and prendi.call("torcia"):
		manca["P"] -= 1
	for s in ["F", "P", "D"]:
		while manca[s] > 0 and prendi.call("corda"):
			manca[s] -= 1
	var ok: bool = manca["F"] <= 0 and manca["P"] <= 0 and manca["D"] <= 0
	return {"ok": ok, "usa": usa, "cacciatori": cacciatori, "lanciatore": lanciatore}


## Può il giocatore i (eventualmente con aiuto) eseguire l'opzione? "solo" / "aiuto" / "no"
func _serve_aiuto(i: int, o: Dictionary, id: int) -> String:
	if _fattibile(i, [i], o, id, false):
		return "solo"
	if solo and not giocatori[i]["chiamata_usata"]:
		# in solitario si può chiedere aiuto ai dadi: basta che il resto sia pagabile
		var senza := o.duplicate()
		senza["req"] = {"W": o["req"].get("W", 0)}
		if _fattibile(i, [i], senza, id, false):
			return "aiuto"
	var tutti := [i]
	for j in giocatori.size():
		if j != i and _puo_aiutare(j):
			tutti.append(j)
	if tutti.size() > 1 and _fattibile(i, tutti, o, id, false):
		return "aiuto"
	return "no"


func _puo_aiutare(j: int) -> bool:
	var g: Dictionary = giocatori[j]
	return not g["risolta"] and g["rivelata"] >= 0 and C[g["rivelata"]]["aiuto"]


## Controllo completo (con i dadi già tirati in req se dadi=true).
func _fattibile(i: int, posti: Array, o: Dictionary, id: int, dadi_tirati: bool, extra: Dictionary = {}) -> bool:
	if not _cond_ok(o["cond"], posti):
		return false
	var carte_da_scartare: int = int(o["carte"])
	if giocatori[i]["mazzo"].size() < carte_da_scartare:
		return false
	if varianti.get("lunghe_strade", false):
		for p in posti.slice(1):
			if giocatori[p]["mazzo"].size() < 2:
				return false
	# risorse
	var any_n := 0
	for r in o["paga"]:
		if r == "any":
			any_n += int(o["paga"][r])
		elif risorse[r] < int(o["paga"][r]):
			return false
	if any_n > 0:
		var tot := 0
		for r in risorse:
			tot += risorse[r]
		for r in o["paga"]:
			if r != "any":
				tot -= int(o["paga"][r])
		if tot < any_n:
			return false
	if o.get("speciali", []).has("ciboperdesiderio"):
		if risorse["cibo"] < _desideri_rimasti():
			return false
	# attrezzi da consegnare
	var att := _attrezzi_totali(posti)
	for t in o["paga_attrezzi"]:
		if int(att.get(t, 0)) < int(o["paga_attrezzi"][t]):
			return false
	# deposito
	if o.get("deposito", false) and not _deposito_completo(id):
		return false
	# abilità
	var req := {}
	for s in ["F", "P", "D"]:
		req[s] = int(o["req"].get(s, 0)) + int(extra.get(s, 0))
	if not dadi_tirati and int(o["req"].get("W", 0)) > 0:
		pass   # i dadi si tirano dopo: qui si guardano solo i requisiti scritti
	var rs := risolvi_requisiti(posti, req, o["paga_attrezzi"])
	if not rs["ok"]:
		return false
	# costruire: almeno un'idea costruibile
	if int(o["guadagna"].get("costruisci", 0)) > 0 and _idee_costruibili(posti).is_empty():
		return false
	if o.get("speciali", []).has("distruggiahab") and not _ha_carta_titolo(posti, "Ahab"):
		return false
	return true


func _neg_eseguibile(i: int, o: Dictionary, id: int) -> bool:
	for r in o["paga"]:
		if r == "any":
			var tot := 0
			for x in risorse:
				tot += risorse[x]
			if tot < int(o["paga"][r]):
				return false
		elif risorse[r] < int(o["paga"][r]):
			return false
	var att := _attrezzi_totali([i])
	for t in o["paga_attrezzi"]:
		if int(att.get(t, 0)) < int(o["paga_attrezzi"][t]):
			return false
	if giocatori[i]["mazzo"].size() < int(o["carte"]):
		return false
	if o.get("speciali", []).has("ciboperdesiderio") and risorse["cibo"] < _desideri_rimasti():
		return false
	if not _cond_ok(o["cond"], [i]):
		return false
	return true


func _desideri_rimasti() -> int:
	var n := 0
	for d in [125, 126, 127, 128]:
		if attesa.has(d):
			n += 1
	return n


# =====================================================================================
# ESECUZIONE
# =====================================================================================

## Restituisce "fatto", "riprova" (azione fallita: scegli altro) o "attendi".
func _esegui_voce(i: int, id: int, v: Dictionary) -> String:
	var g: Dictionary = giocatori[i]
	match v["k"]:
		"attendi":
			_log("%s aspetta." % g["nome"])
			return "attendi"
		"ignora":
			_scarta_rivelata(i, false)
			_log("%s ignora «%s»." % [g["nome"], C[id]["nome"]])
			return "fatto"
		"talismano":
			_togli_attrezzo(i, "talismano")
			_scarta_rivelata(i, false)
			_log("%s usa il talismano e ignora «%s»." % [g["nome"], C[id]["nome"]])
			return "fatto"
		"radice":
			_togli_attrezzo(i, "radice")
			await _cura([i], 3)
			return "riprova_senza"
		"extra":
			var ok_e := await _esegui_opzione(i, v["carta"], C[v["carta"]]["opzioni"][v["o"]], true)
			return "riprova_senza" if ok_e else "riprova"
		"aiuta_carta":
			var ok := await _esegui_opzione(i, v["carta"], C[v["carta"]]["opzioni"][v["o"]], true)
			if not ok:
				return "riprova"
			_scarta_rivelata(i, false)
			return "fatto"
		"azione":
			var o: Dictionary = _opzioni_effettive(id)[v["o"]]
			var ok := await _esegui_opzione(i, id, o, false)
			if not ok:
				return "riprova"
			if giocatori[i]["rivelata"] == id:
				if o["distruggi"]:
					_distruggi_rivelata(i)
				else:
					_scarta_rivelata(i, false)
			return "fatto"
	return "fatto"


func _scarta_rivelata(i: int, coperta: bool) -> void:
	var g: Dictionary = giocatori[i]
	var id: int = g["rivelata"]
	if id < 0:
		return
	if coperta:
		scarti_coperti.append(id)
	else:
		scarti_scoperti.append(id)
	g["rivelata"] = -1
	cambiato.emit()


func _distruggi_rivelata(i: int) -> void:
	var g: Dictionary = giocatori[i]
	var id: int = g["rivelata"]
	if id < 0:
		return
	cimitero.append(id)
	g["rivelata"] = -1
	evento.emit("distrutta", {"carta": id})
	cambiato.emit()


## Esegue un'opzione (azione positiva o negativa) della carta id per il giocatore i.
## per_aiuto: l'azione si fa su una carta che si «aiuta» (resta dov'è).
func _esegui_opzione(i: int, id: int, o: Dictionary, per_aiuto: bool) -> bool:
	var g: Dictionary = giocatori[i]
	var posti := [i]
	# carta da aiutare nel gruppo di un altro: il proprietario partecipa
	if per_aiuto:
		for j in giocatori.size():
			if j != i and giocatori[j]["gruppo"].has(id):
				posti.append(j)
	if o["neg"]:
		await _esegui_negativa(i, id, o)
		return true
	# aiutanti
	if not _fattibile(i, posti, o, id, false) or _qualcuno_vuole_aiutare(i, posti):
		var candidati := []
		for j in giocatori.size():
			if not posti.has(j) and _puo_aiutare(j):
				candidati.append(j)
		if not candidati.is_empty():
			var scelti: Array = await _scegli_aiutanti(i, posti, candidati, o, id)
			posti.append_array(scelti)
	if not _fattibile(i, posti, o, id, false) and not (solo and not g["chiamata_usata"]):
		_log("«%s»: non ci sono abbastanza abilità o risorse." % C[id]["nome"])
		return false
	# dadi
	var extra := {}
	var nd: int = int(o["req"].get("W", 0))
	if nd > 0:
		var facce := []
		for k in nd:
			var f: Dictionary = Dati.DADO[rng.randi_range(0, 5)]
			facce.append(f)
			for s in f:
				extra[s] = extra.get(s, 0) + int(f[s])
		evento.emit("dadi", {"facce": facce})
		_log("Dadi: %s." % _descrivi_dadi(facce))
	# variante solitario: chiedere aiuto (dadi a favore)
	var bonus := {}
	if solo and not g["chiamata_usata"] and not _fattibile(i, posti, o, id, true, extra):
		var r = await chiedi(i, {"tipo": "chiama_aiuto", "titolo": "Chiedere aiuto?",
			"testo": "Da solo non basta. Puoi scartare carte per tirare dadi che si sommano alle tue abilità.",
			"opzioni": [{"testo": "No"}, {"testo": "Scarta 2 carte e tira 1 dado"}, {"testo": "Scarta 4 carte e tira 2 dadi"}]})
		var nn: int = int(r)
		if nn > 0 and g["mazzo"].size() >= nn * 2 + int(o["carte"]):
			g["chiamata_usata"] = true
			await _scarta_dal_mazzo(i, nn * 2, posti)
			var facce2 := []
			for k in nn:
				var f: Dictionary = Dati.DADO[rng.randi_range(0, 5)]
				facce2.append(f)
				for s in f:
					bonus[s] = bonus.get(s, 0) - int(f[s])
			evento.emit("dadi", {"facce": facce2})
			_log("Aiuto: %s." % _descrivi_dadi(facce2))
	var extra_tot := extra.duplicate()
	for s in bonus:
		extra_tot[s] = extra_tot.get(s, 0) + bonus[s]
	if not _fattibile(i, posti, o, id, true, extra_tot):
		# il talismano può salvare anche dopo i dadi
		if C[id]["tipo"] == "P" and _ha_attrezzo_gruppo(i, "talismano") and giocatori[i]["rivelata"] == id:
			var r2 = await chiedi(i, {"tipo": "talismano", "titolo": "I dadi non bastano", "testo": "Vuoi usare il talismano per ignorare il pericolo?",
				"opzioni": [{"testo": "Usa il talismano"}, {"testo": "No, scelgo un'altra azione"}]})
			if int(r2) == 0:
				_togli_attrezzo(i, "talismano")
				_scarta_rivelata(i, false)
				return true
		_log("I dadi alzano troppo i requisiti: l'azione non riesce.")
		for p in posti.slice(1):
			_aiutante_usato(p)
		return false
	# pagamento: abilità monouso
	var req := {}
	for s in ["F", "P", "D"]:
		req[s] = int(o["req"].get(s, 0)) + int(extra_tot.get(s, 0))
	var rs := risolvi_requisiti(posti, req, o["paga_attrezzi"])
	for u in rs["usa"]:
		_togli_attrezzo(u[0], u[1])
	if rs["cacciatori"]:
		for p in posti:
			if _ha_carta_titolo([p], "Cacciatori affamati"):
				giocatori[p]["cacciatori_usati"] = true
				break
	if rs["lanciatore"]:
		for p in posti:
			if _ha_carta_titolo([p], "Lanciatore"):
				giocatori[p]["lanciatore_usato"] = true
				break
	# risorse
	await _paga_risorse(i, o["paga"])
	if o.get("speciali", []).has("ciboperdesiderio"):
		risorse["cibo"] -= _desideri_rimasti()
	# attrezzi
	for t in o["paga_attrezzi"]:
		for k in int(o["paga_attrezzi"][t]):
			var da := _chi_ha_attrezzo(posti, t)
			if da >= 0:
				_togli_attrezzo(da, t)
	# deposito
	if o.get("deposito", false):
		depositi.erase(id)
	# carte da scartare (le rosse fanno danno)
	if int(o["carte"]) > 0:
		await _scarta_dal_mazzo(i, int(o["carte"]), posti)
	if varianti.get("lunghe_strade", false):
		for p in posti.slice(1):
			await _scarta_dal_mazzo(p, 2, [p])
	for p in posti.slice(1):
		_aiutante_usato(p)
	# carta aiutata nel gruppo di un altro / distruzione per carta aiutata
	if per_aiuto and o["distruggi"]:
		_rimuovi_carta_ovunque(id)
		cimitero.append(id)
	if o.get("speciali", []).has("distruggiahab"):
		for p in posti:
			for c2 in giocatori[p]["gruppo"]:
				if C[c2]["nome"] == "Ahab":
					giocatori[p]["gruppo"].erase(c2)
					cimitero.append(c2)
					break
	_log("%s: %s." % [giocatori[i]["nome"], descrivi_opzione(o, id)])
	# bottino
	await _bottino(i, posti, o, id, rs["cacciatori"])
	await _speciali(i, posti, o, id)
	if int(o["danno"]) > 0:
		await _subisci_danno(posti, int(o["danno"]), C[id]["nome"])
	if int(o["teschi"]) > 0:
		_aggiungi_teschi(int(o["teschi"]))
	cambiato.emit()
	return true


func _qualcuno_vuole_aiutare(i: int, posti: Array) -> bool:
	# L'aiuto è sempre facoltativo: lo si propone solo se serve davvero (o per il bottino, scelto dai compagni IA mai).
	return false


func _scegli_aiutanti(i: int, posti: Array, candidati: Array, o: Dictionary, id: int) -> Array:
	var scelti := []
	while true:
		if _fattibile(i, posti + scelti, o, id, false):
			break
		var opz := []
		for j in candidati:
			if not scelti.has(j):
				var ab := abilita_permanenti([j])
				opz.append({"testo": "%s aiuta (Forza %d, Percezione %d, Destrezza %d)" % [giocatori[j]["nome"], ab["F"], ab["P"], ab["D"]], "posto": j})
		if opz.is_empty():
			break
		opz.append({"testo": "Nessun altro aiuto", "posto": -1})
		var r = await chiedi(i, {"tipo": "aiutanti", "titolo": "Serve aiuto per «%s»" % C[id]["nome"],
			"testo": "Chi aiuta? Chi aiuta usa l'opzione «aiutare» della propria carta.", "opzioni": opz, "conferma": true})
		var p: int = opz[int(r)]["posto"]
		if p < 0:
			break
		scelti.append(p)
	return scelti


func _aiutante_usato(p: int) -> void:
	var g: Dictionary = giocatori[p]
	if g["rivelata"] >= 0 and not g["risolta"]:
		_log("%s aiuta con «%s»." % [g["nome"], C[g["rivelata"]]["nome"]])
		_scarta_rivelata(p, false)
		g["risolta"] = true


func _chi_ha_attrezzo(posti: Array, t: String) -> int:
	for p in posti:
		if int(giocatori[p]["attrezzi"].get(t, 0)) > 0:
			return p
	return -1


func _togli_attrezzo(p: int, t: String) -> void:
	var a: Dictionary = giocatori[p]["attrezzi"]
	if int(a.get(t, 0)) <= 0:
		return
	a[t] = int(a[t]) - 1
	if a[t] <= 0:
		a.erase(t)
	scorta_attrezzi[t] = scorta_attrezzi.get(t, 0) + 1
	evento.emit("attrezzo_usato", {"posto": p, "attrezzo": t})


func _paga_risorse(i: int, paga: Dictionary) -> void:
	for r in paga:
		if r == "any":
			continue
		risorse[r] -= int(paga[r])
	var n_any: int = int(paga.get("any", 0))
	for k in n_any:
		var opz := []
		for r in risorse:
			if risorse[r] > 0:
				opz.append({"testo": "Dai 1 %s (ne avete %d)" % [Dati.RISORSE[r].to_lower(), risorse[r]], "r": r})
		if opz.is_empty():
			break
		var x = await chiedi(i, {"tipo": "risorsa", "titolo": "Quale risorsa date?", "testo": "Ancora %d da dare." % (n_any - k), "opzioni": opz})
		risorse[opz[int(x)]["r"]] -= 1


func _descrivi_dadi(facce: Array) -> String:
	var t := []
	for f in facce:
		for s in f:
			t.append("%d %s" % [f[s], Dati.ABILITA[s]])
	return ", ".join(t)


## Scarta n carte dalla cima del mazzo di i (coperte). Le rosse fanno 1 danno ciascuna.
func _scarta_dal_mazzo(i: int, n: int, posti: Array) -> void:
	var g: Dictionary = giocatori[i]
	var rosse := 0
	for k in n:
		if g["mazzo"].is_empty():
			break
		var id: int = g["mazzo"].pop_front()
		scarti_coperti.append(id)
		if e_rosso(id):
			rosse += 1
	if rosse > 0:
		_log("Fra le carte scartate ce n'erano %d con il dorso rosso." % rosse)
		for k in rosse:
			await _subisci_danno(posti, 1, "carta rossa scartata")
	cambiato.emit()


func _bottino(i: int, posti: Array, o: Dictionary, id: int, cacciatori: bool) -> void:
	var gu: Dictionary = o["guadagna"]
	for r in ["cibo", "legno", "pietra"]:
		var n: int = int(gu.get(r, 0))
		if r == "cibo" and cacciatori:
			n = max(0, n - 2)
		if n > 0:
			await _guadagna_risorsa(i, r, n, C[id]["nome"])
	for t in o["attrezzi"]:
		for k in int(o["attrezzi"][t]):
			await _guadagna_attrezzo(i, posti, t, C[id]["nome"])
	for k in int(gu.get("U", 0)):
		var chi_u := i
		if posti.size() > 1:
			chi_u = await _chi_riceve(i, posti, "un nuovo umano")
		await _dai_umano(chi_u, false)
	for k in int(gu.get("S", 0)):
		_dai_sogno(i)
	for k in int(gu.get("I", 0)):
		await _nuova_idea_scelta(i)
	for k in int(gu.get("K", 0)):
		_togli_teschio()
	if int(gu.get("cura", 0)) > 0:
		await _cura(posti, int(gu["cura"]))
	for k in int(gu.get("V", 0)):
		await _guadagna_vittoria(i)
	if int(gu.get("costruisci", 0)) > 0:
		await _costruisci(i, posti, int(gu["costruisci"]))
	for n in gu.get("G", []):
		await _segreto(i, posti, int(n))


func _chi_riceve(i: int, posti: Array, cosa: String) -> int:
	var opz := []
	for p in posti:
		opz.append({"testo": giocatori[p]["nome"], "posto": p})
	var r = await chiedi(i, {"tipo": "destinatario", "titolo": "Chi riceve %s?" % cosa, "testo": "Potete dividere il bottino fra chi ha partecipato.", "opzioni": opz})
	return opz[int(r)]["posto"]


func _guadagna_risorsa(i: int, r: String, n: int, fonte: String) -> void:
	for k in n:
		# deposito su una carta desiderio/guarigione
		var dep := _deposito_possibile(r, fonte)
		if dep >= 0:
			var x = await chiedi(i, {"tipo": "deposito", "titolo": "Mettere %s su «%s»?" % [Dati.RISORSE[r].to_lower(), C[dep]["nome"]],
				"testo": "La carta permette di conservarlo lì per la sua azione.", "opzioni": [{"testo": "Sì, sulla carta"}, {"testo": "No, nel campo"}]})
			if int(x) == 0:
				depositi[dep] = depositi.get(dep, {})
				depositi[dep][r] = int(depositi[dep].get(r, 0)) + 1
				var fk := r + "@" + fonte
				depositi[dep][fk] = int(depositi[dep].get(fk, 0)) + 1
				continue
		var tot_in_gioco: int = risorse[r]
		if tot_in_gioco >= int(Dati.SCORTA_RISORSE[r]):
			_log("La scorta di %s è finita." % Dati.RISORSE[r].to_lower())
			break
		risorse[r] += 1
	evento.emit("risorse", {"r": r, "n": n})


func _guadagna_attrezzo(i: int, posti: Array, t: String, fonte: String) -> void:
	if scorta_attrezzi.get(t, 0) <= 0 and banco_attrezzi.get(t, 0) > 0:
		# i segnalini pronti davanti alle idee del banco fanno parte della scorta
		banco_attrezzi[t] -= 1
		scorta_attrezzi[t] = scorta_attrezzi.get(t, 0) + 1
	if scorta_attrezzi.get(t, 0) <= 0:
		_log("Non ci sono più segnalini «%s»." % Dati.nome_attrezzo(t))
		return
	var dep := _deposito_possibile(t, fonte)
	if dep >= 0:
		var x = await chiedi(i, {"tipo": "deposito", "titolo": "Mettere «%s» su «%s»?" % [Dati.nome_attrezzo(t), C[dep]["nome"]],
			"testo": "La carta permette di conservarlo lì per la sua azione.", "opzioni": [{"testo": "Sì, sulla carta"}, {"testo": "No, al gruppo"}]})
		if int(x) == 0:
			scorta_attrezzi[t] -= 1
			depositi[dep] = depositi.get(dep, {})
			depositi[dep][t] = int(depositi[dep].get(t, 0)) + 1
			return
	var p := i
	if posti.size() > 1:
		p = await _chi_riceve(i, posti, "«%s»" % Dati.nome_attrezzo(t))
	scorta_attrezzi[t] -= 1
	giocatori[p]["attrezzi"][t] = int(giocatori[p]["attrezzi"].get(t, 0)) + 1
	evento.emit("attrezzo", {"posto": p, "attrezzo": t})


## Carta in attesa che accetta questa risorsa/attrezzo proveniente da questa fonte (non ancora piena).
func _deposito_possibile(cosa: String, fonte: String) -> int:
	for id in attesa:
		var dep: Dictionary = C[id]["deposito"]
		if not dep.has(cosa):
			continue
		for regola in dep[cosa]:
			var fonti: Array = regola["fonti"]
			if not fonti.is_empty() and not fonti.has(fonte):
				continue
			var gia := 0
			if fonti.is_empty():
				gia = int(depositi.get(id, {}).get(cosa, 0))
			else:
				gia = int(depositi.get(id, {}).get(cosa + "@" + fonte, 0))
				# per carte con più fonti in un'unica regola conta il totale
				if fonti.size() > 1:
					gia = int(depositi.get(id, {}).get(cosa, 0))
			if gia < int(regola["n"]):
				return id
	return -1


func _deposito_completo(id: int) -> bool:
	var dep: Dictionary = C[id]["deposito"]
	for cosa in dep:
		var tot := 0
		for regola in dep[cosa]:
			tot += int(regola["n"])
		if int(depositi.get(id, {}).get(cosa, 0)) < tot:
			return false
	return true


func _dai_umano(p: int, iniziale: bool) -> void:
	if mazzo_umani.is_empty():
		_log("Non ci sono più umani da reclutare.")
		return
	var id: int = mazzo_umani.pop_front()
	if varianti.get("grande_tribu", false) and not mazzo_umani.is_empty():
		var id2: int = mazzo_umani.pop_front()
		var opz := [{"testo": _descrivi_umano(id), "id": id}, {"testo": _descrivi_umano(id2), "id": id2}]
		var r = await chiedi(p, {"tipo": "umano", "titolo": "Grande tribù: chi si unisce?", "testo": "L'altro torna sotto il mazzo.", "opzioni": opz, "conferma": true})
		var scelto: int = opz[int(r)]["id"]
		var altro: int = id2 if scelto == id else id
		mazzo_umani.append(altro)
		id = scelto
	var g: Dictionary = giocatori[p]
	g["gruppo"].append(id)
	var t: String = C[id]["attrezzo"]
	if t != "" and scorta_attrezzi.get(t, 0) > 0:
		scorta_attrezzi[t] -= 1
		g["attrezzi"][t] = int(g["attrezzi"].get(t, 0)) + 1
	if varianti.get("debolezza", false):
		g["danni"][id] = 1
	if not iniziale:
		_log("%s accoglie un nuovo umano: %s." % [g["nome"], C[id]["nome"]])
		evento.emit("umano", {"posto": p, "carta": id})
	cambiato.emit()


func _descrivi_umano(id: int) -> String:
	var c: Dictionary = C[id]
	var ab: Array = c["abilita"].map(func(s): return Dati.ABILITA[s])
	var t := "%s — %s, %d %s" % [c["nome"], ", ".join(ab) if not ab.is_empty() else "nessuna abilità", c["vita"], "cuore" if c["vita"] == 1 else "cuori"]
	if c["attrezzo"] != "":
		t += ", porta: " + Dati.nome_attrezzo(c["attrezzo"])
	return t


func _dai_sogno(p: int) -> void:
	if mazzo_sogni.is_empty():
		_log("Non ci sono più sogni.")
		return
	var id: int = mazzo_sogni.pop_front()
	giocatori[p]["mazzo"].push_front(id)
	_log("%s riceve un sogno (in cima al proprio mazzo)." % giocatori[p]["nome"])
	evento.emit("sogno", {"posto": p})


func _nuova_idea_scelta(p: int) -> void:
	if mazzo_idee.is_empty():
		_log("Non ci sono più idee.")
		return
	var id: int = mazzo_idee.pop_front()
	if banco.size() >= MAX_IDEE:
		var opz := []
		for b in banco:
			opz.append({"testo": "Elimina «%s»" % C[b]["nome"], "id": b})
		var r = await chiedi(p, {"tipo": "idea_piena", "titolo": "Il banco di lavoro è pieno", "testo": "Nuova idea: «%s». Quale idea finisce nel cimitero?" % C[id]["nome"], "opzioni": opz, "conferma": true})
		var via: int = opz[int(r)]["id"]
		banco.erase(via)
		cimitero.append(via)
	banco.append(id)
	_rifornisci_banco(id)
	_log("Nuova idea nel banco di lavoro: «%s»." % C[id]["nome"])
	evento.emit("idea", {"carta": id})


func _nuova_idea(_annuncia: bool) -> void:
	if mazzo_idee.is_empty() or banco.size() >= MAX_IDEE:
		return
	var id: int = mazzo_idee.pop_front()
	banco.append(id)
	_rifornisci_banco(id)


## Idee costruibili adesso dai gruppi indicati (base + carte del banco).
func _idee_costruibili(posti: Array) -> Array:
	var out := []
	for b in Dati.IDEE_BASE:
		if banco_attrezzi.get(b["attrezzo"], 0) > 0 and _puo_pagare(b["paga"]):
			out.append({"base": b, "testo": "%s (%s)" % [b["nome"], _testo_paga(b["paga"])]})
	for id in banco:
		var o: Dictionary = C[id]["opzioni"][0]
		var ok := true
		for t in o["attrezzi"]:
			if banco_attrezzi.get(t, 0) <= 0:
				ok = false
		if not ok or not _puo_pagare(o["paga"]):
			continue
		var att := _attrezzi_totali(posti)
		for t in o["paga_attrezzi"]:
			if int(att.get(t, 0)) < int(o["paga_attrezzi"][t]):
				ok = false
		if not ok:
			continue
		var req := {"F": int(o["req"].get("F", 0)), "P": int(o["req"].get("P", 0)), "D": int(o["req"].get("D", 0))}
		if not risolvi_requisiti(posti, req, o["paga_attrezzi"])["ok"]:
			continue
		out.append({"carta": id, "testo": "%s (%s)" % [C[id]["nome"], descrivi_opzione(o, id)]})
	return out


func _puo_pagare(paga: Dictionary) -> bool:
	for r in paga:
		if r != "any" and risorse[r] < int(paga[r]):
			return false
	return true


func _testo_paga(paga: Dictionary) -> String:
	var t := []
	for r in paga:
		t.append("%d %s" % [paga[r], Dati.RISORSE.get(r, r).to_lower()])
	return ", ".join(t)


func _costruisci(i: int, posti: Array, n: int) -> void:
	for k in n:
		var possibili := _idee_costruibili(posti)
		if possibili.is_empty():
			break
		var opz := []
		for x in possibili:
			opz.append({"testo": "Costruisci: " + x["testo"], "x": x})
		opz.append({"testo": "Basta così", "x": {}})
		var r = await chiedi(i, {"tipo": "costruisci", "titolo": "Costruire (%d di %d)" % [k + 1, n], "testo": "Scegli un'idea del banco di lavoro.", "opzioni": opz, "conferma": true})
		var x: Dictionary = opz[int(r)]["x"]
		if x.is_empty():
			break
		if x.has("base"):
			var b: Dictionary = x["base"]
			for rr in b["paga"]:
				risorse[rr] -= int(b["paga"][rr])
			banco_attrezzi[b["attrezzo"]] -= 1
			var p := i if posti.size() == 1 else await _chi_riceve(i, posti, "«%s»" % b["nome"])
			giocatori[p]["attrezzi"][b["attrezzo"]] = int(giocatori[p]["attrezzi"].get(b["attrezzo"], 0)) + 1
			_log("%s costruisce: %s." % [giocatori[i]["nome"], b["nome"]])
			evento.emit("attrezzo", {"posto": p, "attrezzo": b["attrezzo"]})
		else:
			var id: int = x["carta"]
			var o: Dictionary = C[id]["opzioni"][0]
			var req := {"F": int(o["req"].get("F", 0)), "P": int(o["req"].get("P", 0)), "D": int(o["req"].get("D", 0))}
			var rs := risolvi_requisiti(posti, req, o["paga_attrezzi"])
			for u in rs["usa"]:
				_togli_attrezzo(u[0], u[1])
			for rr in o["paga"]:
				risorse[rr] -= int(o["paga"][rr])
			for t in o["paga_attrezzi"]:
				for kk in int(o["paga_attrezzi"][t]):
					var da := _chi_ha_attrezzo(posti, t)
					if da >= 0:
						_togli_attrezzo(da, t)
			_log("%s costruisce: %s." % [giocatori[i]["nome"], C[id]["nome"]])
			for t in o["attrezzi"]:
				banco_attrezzi[t] -= 1
				var p := i if posti.size() == 1 else await _chi_riceve(i, posti, "«%s»" % Dati.nome_attrezzo(t))
				giocatori[p]["attrezzi"][t] = int(giocatori[p]["attrezzi"].get(t, 0)) + 1
				evento.emit("attrezzo", {"posto": p, "attrezzo": t})
			if o["distruggi"]:
				banco.erase(id)
				cimitero.append(id)
			var gu: Dictionary = o["guadagna"]
			for kk in int(gu.get("V", 0)):
				await _guadagna_vittoria(i)
			for kk in int(gu.get("K", 0)):
				_togli_teschio()
			for sn in gu.get("G", []):
				await _segreto(i, posti, int(sn))
		cambiato.emit()


# =====================================================================================
# DANNI, CURE, TESCHI E VITTORIE
# =====================================================================================

## Un danno da una sola fonte va tutto su un solo umano (si può parare con pelle/vestiti).
func _subisci_danno(posti: Array, n: int, fonte: String) -> void:
	if n <= 0:
		return
	var chi: int = posti[0]
	# chi subisce: si può scegliere fra i partecipanti
	var opz := []
	for p in posti:
		var g: Dictionary = giocatori[p]
		for t in ["vestiti", "pelle"]:
			if int(g["attrezzi"].get(t, 0)) > 0:
				var para: int = int(Dati.ATTREZZI[t]["para"])
				opz.append({"testo": "Para con %s di %s (fino a %d danni)" % [Dati.nome_attrezzo(t).to_lower(), g["nome"], para], "k": "para", "posto": p, "t": t})
	var bersagli := _bersagli_danno(posti)
	for b in bersagli:
		opz.append(b)
	if opz.is_empty():
		return
	var resto := n
	while resto > 0:
		var r = await chiedi(chi, {"tipo": "danno", "n": resto, "titolo": "%d danno da «%s»" % [resto, fonte],
			"testo": "Il danno di una sola fonte va su un solo umano. Puoi pararlo con pelle o vestiti.", "opzioni": opz, "conferma": true})
		var o: Dictionary = opz[int(r)]
		if o["k"] == "para":
			_togli_attrezzo(o["posto"], o["t"])
			resto -= int(Dati.ATTREZZI[o["t"]]["para"])
			_log("%s para il danno con %s." % [giocatori[o["posto"]]["nome"], Dati.nome_attrezzo(o["t"]).to_lower()])
			opz = opz.filter(func(x): return not (x["k"] == "para" and x["posto"] == o["posto"] and x["t"] == o["t"] and int(giocatori[o["posto"]]["attrezzi"].get(o["t"], 0)) <= 0))
			continue
		_ferisci(o["posto"], o["carta"], resto)
		resto = 0
	cambiato.emit()


func _bersagli_danno(posti: Array) -> Array:
	var out := []
	for p in posti:
		var g: Dictionary = giocatori[p]
		for id in g["gruppo"]:
			var c: Dictionary = C[id]
			if c["tipo"] == "U" or (c["tipo"] == "G" and c["vita"] > 0):
				var d: int = int(g["danni"].get(id, 0))
				out.append({"testo": "%s di %s (%d/%d cuori feriti)" % [c["nome"], g["nome"], d, c["vita"]], "k": "umano", "posto": p, "carta": id})
	return out


func _ferisci(p: int, id: int, n: int) -> void:
	var g: Dictionary = giocatori[p]
	var c: Dictionary = C[id]
	var d: int = int(g["danni"].get(id, 0)) + n
	evento.emit("danno", {"posto": p, "carta": id, "n": n})
	if d > int(c["vita"]):
		g["danni"].erase(id)
		g["gruppo"].erase(id)
		cimitero.append(id)
		if c["tipo"] == "U":
			_log("%s di %s muore." % [c["nome"], g["nome"]])
			_aggiungi_teschi(1)
			_controlla_gruppo_vuoto(p)
		else:
			_log("«%s» è distrutto." % c["nome"])
	else:
		g["danni"][id] = d
		_log("%s di %s subisce %d danno." % [c["nome"], g["nome"], n])


func _controlla_gruppo_vuoto(p: int) -> void:
	if numero_umani(p) == 0 and esito == "":
		_log("L'ultimo umano di %s è morto: arriva subito un nuovo umano." % giocatori[p]["nome"])
		await _dai_umano(p, false)


func _cura(posti: Array, n: int) -> void:
	var resto := n
	while resto > 0:
		var opz := []
		for p in posti:
			var g: Dictionary = giocatori[p]
			for id in g["danni"]:
				if int(g["danni"][id]) > 0:
					opz.append({"testo": "Cura %s di %s (%d danni)" % [C[id]["nome"], g["nome"], g["danni"][id]], "posto": p, "carta": id})
		if opz.is_empty():
			return
		opz.append({"testo": "Basta così", "posto": -1})
		var r = await chiedi(posti[0], {"tipo": "cura", "titolo": "Cura (ancora %d)" % resto, "testo": "Togli un danno a un umano.", "opzioni": opz})
		var o: Dictionary = opz[int(r)]
		if o["posto"] < 0:
			return
		var g2: Dictionary = giocatori[o["posto"]]
		g2["danni"][o["carta"]] = int(g2["danni"][o["carta"]]) - 1
		if g2["danni"][o["carta"]] <= 0:
			g2["danni"].erase(o["carta"])
		resto -= 1
		evento.emit("cura", {"posto": o["posto"], "carta": o["carta"]})
	cambiato.emit()


func _aggiungi_teschi(n: int) -> void:
	teschi = min(5, teschi + n)
	_log("Teschi: %d di 5." % teschi)
	evento.emit("teschio", {"n": teschi})
	_controlla_fine()


func _togli_teschio() -> void:
	if teschi > 0:
		teschi -= 1
		_log("Un teschio viene tolto: %d di 5." % teschi)
		evento.emit("teschio", {"n": teschi})


func _guadagna_vittoria(i: int) -> void:
	if attesa.has(Dati.segreto_id(21)) and teschi > 0:
		var r = await chiedi(i, {"tipo": "belva_vittoria", "titolo": "La belva si è risvegliata", "testo": "Invece del pezzo di pittura puoi togliere un teschio.",
			"opzioni": [{"testo": "Prendi il pezzo di pittura"}, {"testo": "Togli un teschio"}]})
		if int(r) == 1:
			_togli_teschio()
			return
	vittorie = min(5, vittorie + 1)
	_log("Pittura rupestre: %d di 5 pezzi." % vittorie)
	evento.emit("vittoria", {"n": vittorie})
	_controlla_fine()


func _controlla_fine() -> void:
	if esito != "":
		return
	var belva := moduli.has("J")
	if not belva and vittorie >= 5:
		esito = "vittoria"
	elif belva and tigre_danni >= 5:
		esito = "vittoria"
	elif teschi >= 5:
		esito = "sconfitta"
	if esito != "":
		_log("La pittura rupestre è completa: avete vinto!" if esito == "vittoria" else "Cinque teschi: la tribù non ce l'ha fatta.")
		cambiato.emit()


func _rimuovi_carta_ovunque(id: int) -> void:
	attesa.erase(id)
	for g in giocatori:
		g["gruppo"].erase(id)
		g["danni"].erase(id)
	missioni.erase(id)
	banco.erase(id)


# =====================================================================================
# SEGRETI
# =====================================================================================

func _segreto(i: int, posti: Array, n: int) -> void:
	if not segreti.has(n):
		_log("Il segreto %d non è più disponibile." % n)
		return
	segreti.erase(n)
	var id := Dati.segreto_id(n)
	var c: Dictionary = C[id]
	_log("%s scopre il segreto %d: «%s»." % [giocatori[i]["nome"], n, c["nome"]])
	evento.emit("segreto", {"carta": id, "posto": i})
	if c["distruggi_alla_scoperta"] != "":
		for m in missioni.duplicate():
			if C[m]["nome"] == c["distruggi_alla_scoperta"]:
				missioni.erase(m)
				cimitero.append(m)
				_log("La missione «%s» è superata." % C[m]["nome"])
	match c["zona"]:
		"gruppo":
			giocatori[i]["gruppo"].append(id)
			cambiato.emit()
			return
		"attesa":
			attesa.append(id)
			if n == 21:
				belva_furiosa = true
				_log("La belva è furiosa! I sei artigli vengono mescolati nei mazzi.")
				for a in Dati.MODULI["J"]["artigli"]:
					var g: Dictionary = giocatori[rng.randi_range(0, giocatori.size() - 1)]
					g["mazzo"].insert(rng.randi_range(0, g["mazzo"].size()), int(a))
			cambiato.emit()
			return
	# segreti da risolvere subito (azioni o pericoli): come una carta in più
	await _risolvi_extra(i, posti, id)


## Risolve una carta in più (segreto, nevicata…) per il giocatore i.
func _risolvi_extra(i: int, posti: Array, id: int) -> void:
	var g: Dictionary = giocatori[i]
	var prima: int = g["rivelata"]
	var prima_risolta: bool = g["risolta"]
	g["rivelata"] = id
	g["risolta"] = false
	cambiato.emit()
	var vietate := {}
	while esito == "":
		var voci := _voci_carta(i, id, vietate).filter(func(v): return v["k"] != "attendi")
		var opz := []
		for v in voci:
			opz.append({"testo": v["testo"], "voce": v})
		var r = await chiedi(i, {"tipo": "opzione", "titolo": "%s: «%s»" % [g["nome"], C[id]["nome"]], "testo": "Carta in più da risolvere.", "opzioni": opz, "carta": id, "conferma": true})
		var v: Dictionary = opz[int(r)]["voce"]
		var e := await _esegui_voce(i, id, v)
		if e == "riprova":
			vietate[v["chiave"]] = true
			continue
		if e == "riprova_senza":
			continue
		break
	if g["rivelata"] == id:
		_scarta_rivelata(i, false)
	g["rivelata"] = prima
	g["risolta"] = prima_risolta
	cambiato.emit()


# =====================================================================================
# EFFETTI SPECIALI
# =====================================================================================

func _speciali(i: int, posti: Array, o: Dictionary, id: int) -> void:
	for s in o.get("speciali", []):
		await _speciale(i, posti, String(s), id)


func _esegui_negativa(i: int, id: int, o: Dictionary) -> void:
	var g: Dictionary = giocatori[i]
	# si esegue il più possibile
	for r in o["paga"]:
		if r == "any":
			var n: int = int(o["paga"][r])
			var tot := 0
			for x in risorse:
				tot += risorse[x]
			await _paga_risorse(i, {"any": min(n, tot)})
		else:
			risorse[r] = max(0, risorse[r] - int(o["paga"][r]))
	for t in o["paga_attrezzi"]:
		for k in int(o["paga_attrezzi"][t]):
			if _ha_attrezzo_gruppo(i, t):
				_togli_attrezzo(i, t)
	if int(o["carte"]) > 0:
		await _scarta_dal_mazzo(i, int(o["carte"]), [i])
	_log("%s subisce: %s." % [g["nome"], descrivi_opzione(o, id)])
	for t in o["attrezzi"]:
		for k in int(o["attrezzi"][t]):
			await _guadagna_attrezzo(i, [i], t, C[id]["nome"])
	var gu: Dictionary = o["guadagna"]
	for r in ["cibo", "legno", "pietra"]:
		if int(gu.get(r, 0)) > 0:
			await _guadagna_risorsa(i, r, int(gu[r]), C[id]["nome"])
	for k in int(gu.get("S", 0)):
		_dai_sogno(i)
	for sn in gu.get("G", []):
		await _segreto(i, [i], int(sn))
	await _speciali(i, [i], o, id)
	if int(o["danno"]) > 0:
		await _subisci_danno([i], int(o["danno"]), C[id]["nome"])
	if int(o["teschi"]) > 0:
		_aggiungi_teschi(int(o["teschi"]))
	if g["rivelata"] == id:
		if o["distruggi"]:
			_distruggi_rivelata(i)
		else:
			_scarta_rivelata(i, false)


func _speciale(i: int, posti: Array, s: String, id: int) -> void:
	var g: Dictionary = giocatori[i]
	match s:
		"visione":
			await _visione(i)
		"avvertimento":
			await _scarta_a_scelta(i, false)
		"scartarossa":
			await _scarta_a_scelta(i, true)
		"coraggio", "coraggio2":
			var n := 3 if s == "coraggio" else 2
			var prese := []
			for k in n:
				if scarti_coperti.is_empty():
					break
				prese.append(scarti_coperti.pop_back())
			prese.reverse()
			for k in range(prese.size() - 1, -1, -1):
				g["mazzo"].push_front(prese[k])
			_log("%s rimette %d carte coperte in cima al proprio mazzo." % [g["nome"], prese.size()])
		"mercante":
			var opz := []
			for r in risorse:
				if risorse[r] > 0:
					opz.append({"testo": "Dai 1 %s, ricevi le altre due" % Dati.RISORSE[r].to_lower(), "r": r})
			if opz.is_empty():
				return
			opz.append({"testo": "Non scambiare", "r": ""})
			var x = await chiedi(i, {"tipo": "mercante", "titolo": "Mercante", "testo": "Dai una risorsa e prendi una di ciascuna delle altre due.", "opzioni": opz})
			var r0: String = opz[int(x)]["r"]
			if r0 != "":
				risorse[r0] -= 1
				for r in risorse:
					if r != r0:
						await _guadagna_risorsa(i, r, 1, C[id]["nome"])
		"valanga":
			var monti := []
			for c in g["mazzo"]:
				if C[c]["dorso_tipo"] == "montagna":
					monti.append(c)
			for c in monti:
				g["mazzo"].erase(c)
				scarti_scoperti.append(c)
			_log("%s scarta %d carte montagna dal mazzo." % [g["nome"], monti.size()])
			for k in monti.size():
				await _subisci_danno([i], 1, "valanga")
			if g["rivelata"] == id:
				_distruggi_rivelata(i)
		"gelo":
			for j in giocatori.size():
				var gj: Dictionary = giocatori[j]
				if gj["rivelata"] >= 0 and not gj["risolta"] and C[gj["rivelata"]]["dorso_tipo"] == "bosco":
					_log("Il gelo rovina «%s» di %s." % [C[gj["rivelata"]]["nome"], gj["nome"]])
					_scarta_rivelata(j, false)
					gj["risolta"] = true
		"umanosenzateschio", "distruggiumano":
			var opz := []
			for c in g["gruppo"]:
				if C[c]["tipo"] == "U":
					opz.append({"testo": "Perdi %s" % C[c]["nome"], "c": c})
			if opz.is_empty():
				return
			var x = await chiedi(i, {"tipo": "perdi_umano", "titolo": "Un umano va perso", "testo": "Scegli chi lascia il gruppo." + (" Non prendete teschi." if s == "umanosenzateschio" else ""), "opzioni": opz, "conferma": true})
			var c0: int = opz[int(x)]["c"]
			g["gruppo"].erase(c0)
			g["danni"].erase(c0)
			cimitero.append(c0)
			_log("%s perde %s." % [g["nome"], C[c0]["nome"]])
			if s == "distruggiumano":
				_aggiungi_teschi(1)
			await _controlla_gruppo_vuoto(i)
		"nevicata":
			var k := -1
			for n in g["mazzo"].size():
				if C[g["mazzo"][n]]["dorso_tipo"] == "neve":
					k = n
					break
			if k < 0:
				await _subisci_danno([i], 2, "nevicata")
				return
			var neve: int = g["mazzo"][k]
			g["mazzo"].remove_at(k)
			if g["rivelata"] == id:
				_scarta_rivelata(i, false)
			_log("%s scopre la carta neve «%s»." % [g["nome"], C[neve]["nome"]])
			await _risolvi_extra(i, posti, neve)
		"contagio":
			for c in g["gruppo"].duplicate():
				if int(g["danni"].get(c, 0)) > 0:
					await _danno_singolo(i, c, "contagio")
		"febbre":
			for p in giocatori.size():
				for c in giocatori[p]["gruppo"].duplicate():
					if C[c]["tipo"] == "U":
						await _danno_singolo(p, c, "febbre")
		"guerriera2":
			_danno_guerriera(2)
		"curaguerriera2":
			guerriere_danni = max(0, guerriere_danni - 2)
			_log("Jhula cura la guerriera.")
		"missionemani":
			if guerriere.is_empty():
				_aggiungi_teschi(1)
			else:
				_danno_guerriera(2)
		"tigre1", "tigre2":
			var n := 1 if s == "tigre1" else 2
			if attesa.has(Dati.segreto_id(22)):
				tigre_danni += n
				_log("La tigre dai denti a sciabola subisce %d danno (%d di 5)." % [n, tigre_danni])
				evento.emit("tigre", {"n": tigre_danni})
				if tigre_danni >= 5:
					attesa.erase(Dati.segreto_id(22))
					cimitero.append(Dati.segreto_id(22))
				_controlla_fine()
		"fameinfinita":
			var opz := []
			for j in giocatori.size():
				var gj: Dictionary = giocatori[j]
				if j != i and gj["rivelata"] >= 0 and not gj["risolta"] and Dati.ANIMALI.has(gj["rivelata"]):
					opz.append({"testo": "Distruggi «%s» di %s" % [C[gj["rivelata"]]["nome"], gj["nome"]], "posto": j})
			if opz.is_empty():
				await _subisci_danno([i], 3 if belva_furiosa else 1, "fame senza fine")
				return
			var x = await chiedi(i, {"tipo": "fame", "titolo": "Fame senza fine", "testo": "La belva divora un animale scoperto da un compagno.", "opzioni": opz})
			var j0: int = opz[int(x)]["posto"]
			_distruggi_rivelata(j0)
			giocatori[j0]["risolta"] = true
		"ignorapericolo":
			var opz := []
			for j in giocatori.size():
				var gj: Dictionary = giocatori[j]
				if j != i and gj["rivelata"] >= 0 and not gj["risolta"] and C[gj["rivelata"]]["tipo"] == "P":
					opz.append({"testo": "Scarta «%s» di %s" % [C[gj["rivelata"]]["nome"], gj["nome"]], "posto": j})
			if opz.is_empty():
				return
			var x = await chiedi(i, {"tipo": "ahab", "titolo": "Ahab", "testo": "Il pericolo di un compagno viene scartato senza effetti.", "opzioni": opz})
			var j0: int = opz[int(x)]["posto"]
			_scarta_rivelata(j0, false)
			giocatori[j0]["risolta"] = true
		"fiume2", "fiume3":
			var n := 2 if s == "fiume2" else 3
			for k in n:
				if fiume.is_empty():
					break
				scarti_scoperti.append(fiume.pop_front())
			_log("%d carte del Grande fiume vanno negli scarti." % n)
			if s == "fiume2" and _ha_attrezzo_gruppo(i, "zattera"):
				_togli_attrezzo(i, "zattera")
		"terrelontane":
			var animali := cimitero.filter(func(c): return Dati.ANIMALI.has(c))
			var prese := 0
			while prese < 3 and not animali.is_empty():
				var opz := []
				for c in animali:
					opz.append({"testo": "Riprendi «%s»" % C[c]["nome"], "c": c})
				opz.append({"testo": "Basta così", "c": -1})
				var x = await chiedi(i, {"tipo": "terre", "titolo": "Terre lontane", "testo": "Fino a 3 animali dal cimitero, coperti sul tuo mazzo.", "opzioni": opz})
				var c0: int = opz[int(x)]["c"]
				if c0 < 0:
					break
				animali.erase(c0)
				cimitero.erase(c0)
				g["mazzo"].push_front(c0)
				prese += 1
		"distruggiahab", "ciboperdesiderio":
			pass


func _danno_singolo(p: int, c: int, fonte: String) -> void:
	var g: Dictionary = giocatori[p]
	for t in ["pelle", "vestiti"]:
		if int(g["attrezzi"].get(t, 0)) > 0:
			var r = await chiedi(p, {"tipo": "para_singolo", "titolo": "%s: 1 danno a %s" % [fonte.capitalize(), C[c]["nome"]],
				"testo": "Vuoi parare con %s?" % Dati.nome_attrezzo(t).to_lower(), "opzioni": [{"testo": "Para con " + Dati.nome_attrezzo(t).to_lower()}, {"testo": "Subisci il danno"}]})
			if int(r) == 0:
				_togli_attrezzo(p, t)
				return
			break
	_ferisci(p, c, 1)


func _danno_guerriera(n: int) -> void:
	if guerriere.is_empty():
		return
	guerriere_danni += n
	var c: int = guerriere[0]
	_log("La guerriera in guardia subisce %d danni." % n)
	if guerriere_danni > int(C[c]["vita"]):
		guerriere.pop_front()
		cimitero.append(c)
		guerriere_danni = 0
		_log("La guerriera cade.")
		_aggiungi_teschi(1)
	cambiato.emit()


func _visione(i: int) -> void:
	var g: Dictionary = giocatori[i]
	var n: int = min(3, g["mazzo"].size())
	if n == 0:
		return
	var viste: Array = g["mazzo"].slice(0, n)
	var r = await chiedi(i, {"tipo": "visione", "titolo": "Visione", "testo": "Guardi le prime %d carte del tuo mazzo. Scegli quali spostare in fondo." % n,
		"carte": viste, "opzioni": [{"testo": "Lascia tutto com'è", "fondo": []}] + _combinazioni_fondo(viste), "conferma": true})
	var opz: Array = [{"testo": "", "fondo": []}] + _combinazioni_fondo(viste)
	var fondo: Array = opz[int(r)]["fondo"]
	for c in fondo:
		g["mazzo"].erase(c)
		g["mazzo"].append(c)
	if not fondo.is_empty():
		_log("%s sposta %d carte in fondo al mazzo." % [g["nome"], fondo.size()])


func _combinazioni_fondo(viste: Array) -> Array:
	var out := []
	var n := viste.size()
	for mask in range(1, 1 << n):
		var sel := []
		var nomi := []
		for k in n:
			if mask & (1 << k):
				sel.append(viste[k])
				nomi.append(C[viste[k]]["nome"])
		out.append({"testo": "In fondo: " + ", ".join(nomi), "fondo": sel})
	return out


func _scarta_a_scelta(i: int, solo_rosse: bool) -> void:
	var g: Dictionary = giocatori[i]
	var opz := []
	for k in g["mazzo"].size():
		var c: int = g["mazzo"][k]
		if solo_rosse and not e_rosso(c):
			continue
		opz.append({"testo": "Carta %d del mazzo (dorso %s)" % [k + 1, _nome_dorso(c)], "c": c})
	if opz.is_empty():
		return
	opz.append({"testo": "Nessuna", "c": -1})
	var r = await chiedi(i, {"tipo": "scarta_scelta", "titolo": "Scarta una carta dal tuo mazzo", "testo": "Va negli scarti coperti senza effetti (anche se rossa).", "opzioni": opz, "conferma": true})
	var c0: int = opz[int(r)]["c"]
	if c0 >= 0:
		g["mazzo"].erase(c0)
		scarti_coperti.append(c0)
		_log("%s scarta una carta dal mazzo senza effetti." % g["nome"])


# =====================================================================================
# NOTTE
# =====================================================================================

func _fase_notte() -> void:
	fase = "notte"
	_log("Cala la notte (giorno %d)." % giorno)
	evento.emit("notte", {})
	cambiato.emit()
	# 1. nutrire gli umani
	var bocche := 0
	for p in giocatori.size():
		bocche += numero_umani(p)
	var mangiano: int = min(bocche, risorse["cibo"])
	risorse["cibo"] -= mangiano
	_log("La tribù mangia: %d cibo per %d umani." % [mangiano, bocche])
	if bocche > mangiano:
		_log("%d umani restano affamati." % (bocche - mangiano))
		_aggiungi_teschi(bocche - mangiano)
	cambiato.emit()
	if esito != "":
		return
	# 2. missioni
	for m in missioni.duplicate():
		if esito != "":
			return
		await _risolvi_notturna(m, C[m]["opzioni"])
	# 3. carte notturne nei gruppi e nell'attesa
	var notturne := []
	for p in giocatori.size():
		for id in giocatori[p]["gruppo"]:
			if not C[id]["notte"].is_empty():
				notturne.append(id)
	for id in attesa:
		if not C[id]["notte"].is_empty():
			notturne.append(id)
	for id in notturne:
		if esito != "":
			return
		await _risolvi_notturna(id, C[id]["notte"])
	if esito != "":
		return
	# 4. nuovo giorno
	var tutte: Array = scarti_scoperti + scarti_coperti
	for g in giocatori:
		tutte.append_array(g["mazzo"])
		g["mazzo"] = []
	scarti_scoperti = []
	scarti_coperti = []
	_mescola(tutte)
	_distribuisci(tutte)
	giorno += 1
	_log("Inizia il giorno %d." % giorno)
	evento.emit("giorno", {"n": giorno})
	cambiato.emit()


## Missione o carta notturna: la tribù sceglie insieme una delle azioni (chi paga lo decide il capo).
func _risolvi_notturna(id: int, opzioni: Array) -> void:
	var tutti := range(giocatori.size())
	var opz := []
	var neg_eseg := []
	var neg_tutte := []
	for k in opzioni.size():
		var o: Dictionary = opzioni[k]
		if not o["neg"]:
			if _fattibile_tribu(o):
				opz.append({"testo": descrivi_opzione(o, id), "k": k})
			continue
		neg_tutte.append(k)
		if _paga_tribu_possibile(o):
			neg_eseg.append(k)
	for k in (neg_eseg if not neg_eseg.is_empty() else neg_tutte):
		opz.append({"testo": descrivi_opzione(opzioni[k], id), "k": k})
	if opz.is_empty():
		return
	var r = await chiedi(capo(), {"tipo": "missione", "titolo": "Notte: «%s»" % C[id]["nome"], "testo": "Scegliete insieme una delle azioni.", "opzioni": opz, "carta": id, "conferma": true})
	var o: Dictionary = opzioni[opz[int(r)]["k"]]
	_log("«%s»: %s." % [C[id]["nome"], descrivi_opzione(o, id)])
	# pagamento collettivo
	for rr in o["paga"]:
		if rr == "any":
			await _paga_risorse(capo(), {"any": int(o["paga"][rr])})
		else:
			risorse[rr] = max(0, risorse[rr] - int(o["paga"][rr]))
	for t in o["paga_attrezzi"]:
		for k in int(o["paga_attrezzi"][t]):
			var da := _chi_ha_attrezzo(tutti, t)
			if da >= 0:
				_togli_attrezzo(da, t)
	if o.get("speciali", []).has("ciboperdesiderio"):
		risorse["cibo"] = max(0, risorse["cibo"] - _desideri_rimasti())
	if o["distruggi"]:
		_rimuovi_carta_ovunque(id)
		cimitero.append(id)
	var gu: Dictionary = o["guadagna"]
	for k in int(gu.get("V", 0)):
		await _guadagna_vittoria(capo())
	for k in int(gu.get("S", 0)):
		_dai_sogno(capo())
	for sn in gu.get("G", []):
		await _segreto(capo(), [capo()], int(sn))
	await _speciali(capo(), [capo()], o, id)
	if int(o["teschi"]) > 0:
		_aggiungi_teschi(int(o["teschi"]))
	cambiato.emit()


func _fattibile_tribu(o: Dictionary) -> bool:
	if not _cond_ok(o["cond"], range(giocatori.size())):
		return false
	return _paga_tribu_possibile(o)


func _paga_tribu_possibile(o: Dictionary) -> bool:
	var tot := 0
	for r in risorse:
		tot += risorse[r]
	var any_n := 0
	for r in o["paga"]:
		if r == "any":
			any_n += int(o["paga"][r])
		elif risorse[r] < int(o["paga"][r]):
			return false
		else:
			tot -= int(o["paga"][r])
	if tot < any_n:
		return false
	var att := _attrezzi_totali(range(giocatori.size()))
	for t in o["paga_attrezzi"]:
		if int(att.get(t, 0)) < int(o["paga_attrezzi"][t]):
			return false
	if o.get("speciali", []).has("ciboperdesiderio") and risorse["cibo"] < _desideri_rimasti():
		return false
	return true


# =====================================================================================
# TESTI
# =====================================================================================

const TESTI_SPECIALI := {
	"visione": "guarda 3 carte del mazzo e riordinale",
	"avvertimento": "scarta una carta qualsiasi del mazzo senza effetti",
	"scartarossa": "scarta una carta rossa del mazzo senza effetti",
	"coraggio": "rimetti in cima al mazzo le 3 carte coperte in cima agli scarti",
	"coraggio2": "rimetti in cima al mazzo 2 carte coperte dagli scarti",
	"mercante": "dai 1 risorsa e prendi le altre due",
	"valanga": "scarta tutte le carte montagna del mazzo: 1 danno per carta",
	"gelo": "chi ha scoperto un bosco lo scarta senza effetti",
	"umanosenzateschio": "perdi un umano (senza teschio)",
	"distruggiumano": "perdi un umano e prendi un teschio",
	"nevicata": "scopri la prossima carta neve del mazzo e risolvila",
	"contagio": "ogni umano ferito del gruppo subisce 1 danno",
	"febbre": "ogni umano subisce 1 danno",
	"guerriera2": "la guerriera in guardia subisce 2 danni",
	"curaguerriera2": "cura 2 danni alla guerriera in guardia",
	"missionemani": "la guerriera in guardia subisce 2 danni (senza guerriere: un teschio)",
	"tigre1": "1 danno alla tigre dai denti a sciabola",
	"tigre2": "2 danni alla tigre dai denti a sciabola",
	"fameinfinita": "distruggi un animale scoperto da un compagno",
	"ignorapericolo": "scarta il pericolo scoperto da un compagno",
	"fiume2": "2 carte del Grande fiume negli scarti",
	"fiume3": "3 carte del Grande fiume negli scarti",
	"terrelontane": "fino a 3 animali dal cimitero sul tuo mazzo",
	"distruggiahab": "Ahab lascia il gruppo",
	"ciboperdesiderio": "1 cibo per ogni carta desiderio rimasta",
}


func descrivi_opzione(o: Dictionary, id: int = -1) -> String:
	var parti := []
	var req: Dictionary = o["req"]
	for s in ["F", "P", "D"]:
		if int(req.get(s, 0)) > 0:
			parti.append("%d %s" % [req[s], Dati.ABILITA[s]])
	if int(req.get("W", 0)) > 0:
		parti.append("%d %s" % [req["W"], "dado" if int(req["W"]) == 1 else "dadi"])
	for cnd in o["cond"]:
		var s: String = cnd
		if s.begins_with("carta:"):
			parti.append("avete «%s»" % s.substr(6).replace("|", "» o «"))
		elif s.begins_with("distrutta:"):
			parti.append("«%s» è distrutta" % s.substr(10))
		elif s == "umani1-2":
			parti.append("hai 1–2 umani")
		elif s == "umani3+":
			parti.append("hai 3 o più umani")
		elif s == "lupi5":
			parti.append("5 lupi distrutti")
		elif s == "desideri0":
			parti.append("tutti e 4 i desideri esauditi")
		elif s == "fiumevuoto":
			parti.append("il Grande fiume è vuoto")
		elif s == "vittorie5":
			parti.append("avete 5 pezzi di pittura")
		elif s == "aiutozattera":
			parti.append("ti aiuta un compagno con la zattera")
	for r in o["paga"]:
		parti.append("dai %d %s" % [o["paga"][r], "risorse a scelta" if r == "any" else Dati.RISORSE[r].to_lower()])
	for t in o["paga_attrezzi"]:
		parti.append("dai %s%s" % ["" if int(o["paga_attrezzi"][t]) == 1 else str(o["paga_attrezzi"][t]) + " ", Dati.nome_attrezzo(t).to_lower()])
	if o.get("deposito", false):
		parti.append("con quanto messo sulla carta")
	if int(o["carte"]) > 0:
		parti.append("scarta %d %s" % [o["carte"], "carta" if int(o["carte"]) == 1 else "carte"])
	if o["distruggi"]:
		parti.append("distruggi la carta")
	var costo := ", ".join(parti)
	var bott := []
	var gu: Dictionary = o["guadagna"]
	for r in ["cibo", "legno", "pietra"]:
		if int(gu.get(r, 0)) > 0:
			bott.append("%d %s" % [gu[r], Dati.RISORSE[r].to_lower()])
	for t in o["attrezzi"]:
		bott.append(("%d " % o["attrezzi"][t] if int(o["attrezzi"][t]) > 1 else "") + Dati.nome_attrezzo(t).to_lower())
	if int(gu.get("U", 0)) > 0:
		bott.append("un nuovo umano")
	if int(gu.get("S", 0)) > 0:
		bott.append("%d sogn%s" % [gu["S"], "o" if int(gu["S"]) == 1 else "i"])
	if int(gu.get("I", 0)) > 0:
		bott.append("%d ide%s" % [gu["I"], "a" if int(gu["I"]) == 1 else "e"])
	if int(gu.get("costruisci", 0)) > 0:
		bott.append("costruisci %d ide%s" % [gu["costruisci"], "a" if int(gu["costruisci"]) == 1 else "e"])
	if int(gu.get("cura", 0)) > 0:
		bott.append("cura %d" % gu["cura"])
	if int(gu.get("K", 0)) > 0:
		bott.append("togli un teschio")
	if int(gu.get("V", 0)) > 0:
		bott.append("%d pezz%s di pittura" % [gu["V"], "o" if int(gu["V"]) == 1 else "i"])
	for n in gu.get("G", []):
		bott.append("segreto %d" % n)
	for s in o.get("speciali", []):
		if s != "distruggiahab":
			bott.append(TESTI_SPECIALI.get(s, s))
	if int(o["danno"]) > 0:
		bott.append("%d dann%s" % [o["danno"], "o" if int(o["danno"]) == 1 else "i"])
	if int(o["teschi"]) > 0:
		bott.append("%d teschi%s" % [o["teschi"], "o" if int(o["teschi"]) == 1 else ""])
	var b := ", ".join(bott)
	if o["neg"]:
		var t := costo
		if b != "":
			t = (t + ", " if t != "" else "") + b
		return t if t != "" else "nessun effetto"
	if costo == "":
		return b if b != "" else "nessun effetto"
	if b == "":
		return costo
	return costo + " — ottieni " + b


func descrivi_carta(id: int) -> String:
	var c: Dictionary = C[id]
	if c["tipo"] == "U":
		return _descrivi_umano(id)
	var righe := []
	for o in c["opzioni"]:
		righe.append(("Aiutando la carta: " if o["aiuto_carta"] else "") + descrivi_opzione(o, id))
	if c["aiuto"]:
		righe.append("Oppure: aiuta un compagno o una carta")
	for o in c["notte"]:
		righe.append("Di notte: " + descrivi_opzione(o, id))
	return "\n".join(righe)


# =====================================================================================
# INFORMAZIONI PER L'INTERFACCIA
# =====================================================================================

func istantanea() -> Dictionary:
	return {"giocatori": giocatori.duplicate(true), "risorse": risorse.duplicate(), "teschi": teschi, "vittorie": vittorie, "giorno": giorno}
