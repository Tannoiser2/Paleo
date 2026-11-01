class_name IA
extends RefCounted
## Compagno di tribù guidato dal computer. Paleo è cooperativo: l'IA cerca il bene di tutta la tribù
## (cibo per la notte, attrezzi, pezzi di pittura) evitando danni e teschi.

var ritardo := 0.0   # pausa (secondi) prima di rispondere, per seguire le mosse a schermo


func decide(m: Motore, posto: int, req: Dictionary):
	if ritardo > 0.0 and m.get_tree() != null:
		await m.get_tree().create_timer(ritardo).timeout
	return scegli(m, posto, req)


func scegli(m: Motore, posto: int, req: Dictionary) -> int:
	var opz: Array = req.get("opzioni", [])
	if opz.is_empty():
		return 0
	match req.get("tipo", ""):
		"scegli_carta":
			return _scegli_carta(m, posto, opz)
		"opzione":
			return _scegli_opzione(m, posto, opz)
		"aiutanti":
			return 0
		"danno":
			req_n = int(req.get("n", 1))
			return _scegli_danno(m, posto, opz)
		"missione":
			return _scegli_missione(m, opz, req)
		"costruisci":
			return _scegli_costruzione(m, opz)
		"cura":
			return _scegli_cura(m, opz)
		"destinatario":
			return _destinatario(m, opz)
		"chiama_aiuto":
			return 1 if m.giocatori[posto]["mazzo"].size() > 6 else 0
		"deposito":
			return 0
		"belva_vittoria":
			return 1 if m.teschi >= 3 else 0
		"talismano":
			return 0
		"visione":
			return _visione(m, opz)
		"scarta_scelta":
			for k in opz.size():
				var c: int = opz[k].get("c", -1)
				if c >= 0 and m.e_rosso(c):
					return k
			return opz.size() - 1
		"mercante":
			return _mercante(m, opz)
		"risorsa":
			var best := 0
			var maxv := -1
			for k in opz.size():
				var r: String = opz[k]["r"]
				var v: int = m.risorse[r] - (3 if r == "cibo" else 0)
				if v > maxv:
					maxv = v
					best = k
			return best
		"para_singolo":
			return 0
		"terre":
			return 0
		"idea_piena":
			return 0
		"ordine":
			return _ordine(m, opz)
		"umano":
			return 0
	return 0


func _fame(m: Motore) -> int:
	var bisogno := 0
	for p in m.giocatori.size():
		bisogno += m.numero_umani(p)
	bisogno += _bisogni_missioni(m).get("cibo", 0)
	return max(0, bisogno - m.risorse["cibo"])


## Che cosa chiedono stanotte le missioni (l'opzione senza teschio più economica).
func _bisogni_missioni(m: Motore) -> Dictionary:
	var b := {}
	for id in m.missioni:
		for o in m.C[id]["opzioni"]:
			if int(o["teschi"]) > 0 or not o["neg"]:
				continue
			for r in o["paga"]:
				b[r] = b.get(r, 0) + int(o["paga"][r])
			for t in o["paga_attrezzi"]:
				b["t:" + t] = b.get("t:" + t, 0) + int(o["paga_attrezzi"][t])
			break
	return b


## Quanti danni (da 1) il gruppo può prendere senza che muoia nessuno.
func _assorbimento(m: Motore, posto: int) -> int:
	var g: Dictionary = m.giocatori[posto]
	var n := _protezioni(m, posto)
	for id in g["gruppo"]:
		var c: Dictionary = m.C[id]
		if c["tipo"] == "U" or int(c["vita"]) > 0:
			n += max(0, int(c["vita"]) - int(g["danni"].get(id, 0)))
	return n


## Il danno più grande che un solo umano regge senza morire (o che si para).
func _assorbe_singolo(m: Motore, posto: int) -> int:
	var g: Dictionary = m.giocatori[posto]
	var best := _protezioni(m, posto)
	for id in g["gruppo"]:
		var c: Dictionary = m.C[id]
		if int(c["vita"]) > 0:
			best = max(best, int(c["vita"]) - int(g["danni"].get(id, 0)))
	return best


func _protezioni(m: Motore, posto: int) -> int:
	return int(m.giocatori[posto]["attrezzi"].get("pelle", 0)) + int(m.giocatori[posto]["attrezzi"].get("vestiti", 0)) * 3


## Risorse e attrezzi da tenere da parte per costruire ciò che manca alle missioni.
func _riserva(m: Motore) -> Dictionary:
	var r := {}
	var bis := _bisogni_missioni(m)
	for k in bis:
		if String(k).begins_with("t:"):
			var t: String = String(k).substr(2)
			if _manca_attrezzo(m, t) <= 0:
				continue
			for id in m.banco:
				var o: Dictionary = m.C[id]["opzioni"][0]
				if o["attrezzi"].has(t):
					for x in o["paga"]:
						r[x] = r.get(x, 0) + int(o["paga"][x])
					for x in o["paga_attrezzi"]:
						r["t:" + x] = r.get("t:" + x, 0) + int(o["paga_attrezzi"][x])
		else:
			r[k] = r.get(k, 0) + int(bis[k])
	return r


func _manca_attrezzo(m: Motore, t: String) -> int:
	var serve: int = _bisogni_missioni(m).get("t:" + t, 0)
	var ha: int = m._attrezzi_totali(range(m.giocatori.size())).get(t, 0)
	return max(0, serve - ha)


func _scegli_carta(m: Motore, posto: int, opz: Array) -> int:
	var g: Dictionary = m.giocatori[posto]
	var fame := _fame(m)
	var best := 0
	var best_v := -999.0
	var rosse := 0
	for c in g["mazzo"]:
		if m.e_rosso(c):
			rosse += 1
	for k in opz.size():
		var o: Dictionary = opz[k]
		var v := 0.0
		match o.get("k", ""):
			"carta":
				var dt: String = m.C[o["carta"]]["dorso_tipo"]
				match dt:
					"rosso":
						v = -3.0
					"casa":
						v = 2.0 if m.numero_umani(posto) < 3 or m.risorse["legno"] + m.risorse["pietra"] >= 2 else 1.0
					"bosco", "fiume":
						v = 1.5 + 0.4 * fame
					"montagna":
						v = 1.0 + (0.5 if m.risorse["pietra"] < 2 else 0.0)
					"sogno":
						v = 1.2
					"idea":
						v = 1.5
					"umano":
						v = 1.5
					"orme":
						v = 0.6
					"neve":
						v = -1.0
					_:
						v = 0.5
				v -= 0.05 * o["i"]
			"fiume":
				v = 0.8
			"dormi":
				# andare a dormire prima scarta tutto senza danni: conviene quando restano solo pericoli
				v = -99.0
				var tutte_rosse := true
				for o2 in opz:
					if o2.get("k", "") == "carta" and not m.e_rosso(o2["carta"]):
						tutte_rosse = false
				if tutte_rosse:
					v = 1.0 if _assorbimento(m, posto) <= 2 else -2.5
				if g["mazzo"].size() <= 6 and rosse * 10 >= g["mazzo"].size() * 6:
					v = max(v, 0.5)
		if v > best_v:
			best_v = v
			best = k
	return best


## Valore approssimato del bottino di un'opzione per la tribù.
func valore_opzione(m: Motore, posto: int, o: Dictionary) -> float:
	var fame := _fame(m)
	var v := 0.0
	var gu: Dictionary = o["guadagna"]
	v += float(min(int(gu.get("cibo", 0)), fame + 2)) * (1.0 + 0.6 * min(fame, 6)) + float(max(0, int(gu.get("cibo", 0)) - fame - 2)) * 0.6
	var ris := _riserva(m)
	var tutti_att: Dictionary = m._attrezzi_totali(range(m.giocatori.size()))
	v += float(gu.get("legno", 0)) * (0.9 + (1.3 if m.risorse["legno"] < int(ris.get("legno", 0)) else 0.0))
	v += float(gu.get("pietra", 0)) * (1.0 + (1.3 if m.risorse["pietra"] < int(ris.get("pietra", 0)) else 0.0))
	for t in o["attrezzi"]:
		if int(tutti_att.get(t, 0)) < int(ris.get("t:" + t, 0)):
			v += 2.0 * float(o["attrezzi"][t])
	for t in o["attrezzi"]:
		v += 3.0 * min(float(o["attrezzi"][t]), float(_manca_attrezzo(m, t)))
		v += float(o["attrezzi"][t]) * {"pelle": 1.2, "lancia": 1.6, "talismano": 2.0, "tenda": 2.5, "radice": 1.5,
			"trappola": 1.2, "corda": 1.2, "vestiti": 1.8, "ascia": 2.2, "lupo": 2.0, "totem": 2.5, "zattera": 2.0}.get(t, 1.0)
	var umani := m.numero_umani(posto)
	v += float(gu.get("U", 0)) * (0.3 if fame > 2 else (3.0 if umani < 3 else 1.0))
	v += float(gu.get("S", 0)) * 0.6
	v += float(gu.get("I", 0)) * 2.0
	v += float(gu.get("V", 0)) * 9.0
	v += float(gu.get("K", 0)) * 6.0
	v += float(gu.get("cura", 0)) * (1.2 if m._danni_gruppo(posto) > 0 else 0.0)
	if int(gu.get("costruisci", 0)) > 0:
		var possibili: Array = m._idee_costruibili([posto])
		var opz := []
		for x in possibili:
			opz.append({"x": x})
		opz.append({"x": {}})
		var k := _scegli_costruzione(m, opz)
		v += 2.5 if not opz[k]["x"].is_empty() else -0.5
	v += float(gu.get("G", []).size()) * 3.0
	# costi: le carte scartate dalla cima del mazzo (i dorsi si vedono: le rosse fanno danno)
	var nc: int = int(o["carte"])
	v -= float(nc) * 0.35
	var mazzo: Array = m.giocatori[posto]["mazzo"]
	var rosse := 0
	for k in min(nc, mazzo.size()):
		if m.e_rosso(mazzo[k]):
			rosse += 1
	if rosse > 0:
		var assorbe := _assorbimento(m, posto)
		v -= 1.6 * min(rosse, assorbe) + 9.0 * max(0, rosse - assorbe)
	if int(o["danno"]) > 0:
		var ass2 := _assorbimento(m, posto)
		if int(o["danno"]) > ass2 and _assorbe_singolo(m, posto) < int(o["danno"]):
			v -= 7.0
	for r in o["paga"]:
		v -= float(o["paga"][r]) * (1.4 if r == "cibo" else 0.9)
	for t in o["paga_attrezzi"]:
		v -= float(o["paga_attrezzi"][t]) * 1.2
	v -= float(o["danno"]) * 2.5
	v -= float(o["teschi"]) * 8.0
	var sp: Array = o.get("speciali", [])
	if sp.has("distruggiumano"):
		v -= 9.0
	if sp.has("umanosenzateschio"):
		v -= 4.0
	if sp.has("tigre1"):
		v += 7.0
	if sp.has("tigre2"):
		v += 12.0
	if sp.has("visione") or sp.has("avvertimento") or sp.has("scartarossa"):
		v += 1.0
	if sp.has("mercante"):
		v += 0.8
	if sp.has("coraggio") or sp.has("coraggio2"):
		v -= 0.3
	if sp.has("febbre") or sp.has("contagio"):
		v -= 3.0
	if sp.has("guerriera2"):
		v -= 3.0
	return v


func _scegli_opzione(m: Motore, posto: int, opz: Array) -> int:
	var best := 0
	var best_v := -999.0
	for k in opz.size():
		var voce: Dictionary = opz[k]["voce"]
		var v := 0.0
		match voce["k"]:
			"azione":
				var id: int = m.giocatori[posto]["rivelata"]
				var o: Dictionary = m._opzioni_effettive(id)[voce["o"]]
				v = valore_opzione(m, posto, o)
				if String(voce["testo"]).ends_with("(serve aiuto)"):
					v -= 1.5
				if not o["neg"] and int(o["req"].get("W", 0)) > 0:
					v -= 1.0 * int(o["req"]["W"])
			"aiuta_carta", "extra":
				var o2: Dictionary = m.C[voce["carta"]]["opzioni"][voce["o"]]
				v = valore_opzione(m, posto, o2) + 0.5
			"ignora":
				v = 0.0
			"talismano":
				v = 1.0
			"attendi":
				v = -50.0
			"radice":
				v = 2.0 if m._danni_gruppo(posto) >= 2 else -1.0
		if v > best_v:
			best_v = v
			best = k
	return best


var req_n := 1


func _manca_attrezzo_dopo(m: Motore, t: String) -> bool:
	var serve: int = _bisogni_missioni(m).get("t:" + t, 0)
	var ha: int = m._attrezzi_totali(range(m.giocatori.size())).get(t, 0)
	return serve > 0 and ha <= serve


func _scegli_danno(m: Motore, posto: int, opz: Array) -> int:
	var best := 0
	var best_v := -999.0
	for k in opz.size():
		var o: Dictionary = opz[k]
		var v := 0.0
		if o["k"] == "para":
			v = 5.0 if o["t"] == "pelle" else 4.0
			if _manca_attrezzo_dopo(m, o["t"]):
				v = 0.5
		else:
			var g: Dictionary = m.giocatori[o["posto"]]
			var c: Dictionary = m.C[o["carta"]]
			var resta: int = int(c["vita"]) - int(g["danni"].get(o["carta"], 0))
			v = float(resta)
			if resta < int(req_n):
				v -= 20.0
			if c["tipo"] != "U":
				v += 2.0
		if v > best_v:
			best_v = v
			best = k
	return best


func _scegli_missione(m: Motore, opz: Array, req: Dictionary) -> int:
	# la prima opzione non negativa è sempre buona; poi la meno dannosa
	var id: int = req.get("carta", -1)
	var best := 0
	var best_v := -999.0
	for k in opz.size():
		var t: String = opz[k]["testo"]
		var v := 0.0
		if t.contains("teschi"):
			v = -8.0
		elif t.contains("pezz"):
			v = 10.0
		else:
			v = -2.0
		if v > best_v:
			best_v = v
			best = k
	return best


func _scegli_costruzione(m: Motore, opz: Array) -> int:
	# prima gli attrezzi che servono alle missioni
	for k in opz.size():
		var x: Dictionary = opz[k]["x"]
		var t := ""
		if x.has("base"):
			t = x["base"]["attrezzo"]
		elif x.has("carta"):
			for tt in m.C[x["carta"]]["opzioni"][0]["attrezzi"]:
				t = tt
		if t != "" and _manca_attrezzo(m, t) > 0:
			return k
	for k in opz.size():
		var x: Dictionary = opz[k]["x"]
		if x.has("carta"):
			var o: Dictionary = m.C[x["carta"]]["opzioni"][0]
			if int(o["guadagna"].get("V", 0)) > 0 or int(o["guadagna"].get("K", 0)) > 0:
				return k
	var tutti: Dictionary = m._attrezzi_totali(range(m.giocatori.size()))
	var ab: Dictionary = m.abilita_permanenti(range(m.giocatori.size()))
	var ris := _riserva(m)
	for k in opz.size():
		var x: Dictionary = opz[k]["x"]
		var paga: Dictionary = x["base"]["paga"] if x.has("base") else (m.C[x["carta"]]["opzioni"][0]["paga"] if x.has("carta") else {})
		var intacca := false
		for r in paga:
			if r != "any" and m.risorse[r] - int(paga[r]) < int(ris.get(r, 0)):
				intacca = true
		if intacca:
			continue
		if x.has("carta"):
			var o: Dictionary = m.C[x["carta"]]["opzioni"][0]
			var dup := false
			for tt in o["attrezzi"]:
				if int(tutti.get(tt, 0)) >= m.giocatori.size():
					dup = true
			if not dup:
				return k
		if x.has("base"):
			var t: String = x["base"]["attrezzo"]
			if int(tutti.get(t, 0)) >= m.giocatori.size():
				continue
			if t == "torcia" and int(tutti.get("torcia", 0)) >= 1:
				continue
			if t == "amigdala" and ab["D"] >= 3:
				continue
			return k
	return opz.size() - 1


func _scegli_cura(m: Motore, opz: Array) -> int:
	var best := opz.size() - 1
	var maxd := 0
	for k in opz.size():
		var o: Dictionary = opz[k]
		if o["posto"] < 0:
			continue
		var d: int = int(m.giocatori[o["posto"]]["danni"].get(o["carta"], 0))
		if d > maxd:
			maxd = d
			best = k
	return best


func _destinatario(m: Motore, opz: Array) -> int:
	var best := 0
	var minn := 999
	for k in opz.size():
		var p: int = opz[k]["posto"]
		var n := 0
		for t in m.giocatori[p]["attrezzi"]:
			n += int(m.giocatori[p]["attrezzi"][t])
		if n < minn:
			minn = n
			best = k
	return best


func _visione(m: Motore, opz: Array) -> int:
	# manda in fondo tutte le rosse
	var best := 0
	var best_n := -1
	for k in opz.size():
		var fondo: Array = opz[k].get("fondo", [])
		var buone := true
		var n := 0
		for c in fondo:
			if not m.e_rosso(c):
				buone = false
			n += 1
		if buone and n > best_n:
			best_n = n
			best = k
	return best


func _mercante(m: Motore, opz: Array) -> int:
	var best := opz.size() - 1
	var maxv := 2
	for k in opz.size():
		var r: String = opz[k].get("r", "")
		if r != "" and m.risorse[r] > maxv:
			maxv = m.risorse[r]
			best = k
	return best


func _ordine(m: Motore, opz: Array) -> int:
	# prima chi non può aiutare (i pericoli), così chi ha l'aiuto resta disponibile
	for k in opz.size():
		var p: int = opz[k]["posto"]
		var id: int = m.giocatori[p]["rivelata"]
		if id >= 0 and not m.C[id]["aiuto"]:
			return k
	return 0
