extends Control
## Vista della partita: tabelloni Campo, Natura e Notte, gruppi dei giocatori, banco di lavoro e scelte.

signal scelta_fatta(indice: int)

var main
var config: Dictionary = {}
var motore: Motore
var ia := IA.new()
var locale := ControlloLocale.new()
var online: SessioneOnline = null

# nodi principali
var barra_giorno: Label
var box_teschi: HBoxContainer
var box_pittura: HBoxContainer
var box_risorse: HBoxContainer
var col_sx: VBoxContainer
var col_dx: VBoxContainer
var centro: Control
var griglia: GridContainer
var pannello_scelta: PanelContainer
var scelta_titolo: Label
var scelta_testo: Label
var scelta_opzioni: HFlowContainer
var scelta_scroll: ScrollContainer
var registro: RichTextLabel
var zoom: PanelContainer
var zoom_img: TextureRect
var zoom_testo: RichTextLabel
var zoom_titolo: Label
var tavolo3d = null
var vista3d := false
var stato_online: Label
var overlay_dadi: Control

var _richiesta := {}
var _in_attesa := false
var _da_aggiornare := false
var _ultime_rivelate := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	locale.vista = self
	_costruisci()
	motore = Motore.new()
	add_child(motore)
	motore.cambiato.connect(_segna_aggiornamento)
	motore.messaggio.connect(_al_messaggio)
	motore.evento.connect(_al_evento)
	motore.finita.connect(_alla_fine)
	ia.ritardo = float(config.get("ritardo_ia", 0.7))
	online = config.get("online", null)
	var gg: Array = config.get("giocatori", [])
	if online != null:
		add_child(online)
		online.view = self
		online.locale = locale
		for i in gg.size():
			motore.controllori.append(online)
	else:
		for g in gg:
			motore.controllori.append(ia if g.get("ia", false) else locale)
	vista3d = config.get("vista3d", false)
	await motore.prepara({"giocatori": gg, "moduli": config.get("moduli", ["A", "B"]),
		"varianti": config.get("varianti", {}), "seme": int(config.get("seme", 0))})
	for t in motore.registro:
		_al_messaggio(t)
	_aggiorna()
	if vista3d:
		_imposta_3d(true)
	if online != null and online.role != "host":
		online.battito()
	motore.gioca()


# =====================================================================================
# COSTRUZIONE DELLA SCHERMATA
# =====================================================================================

func _costruisci() -> void:
	var radice := VBoxContainer.new()
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 6)
	add_child(radice)
	# ---- barra in alto
	var barra := UI.pannello(Color(0.12, 0.08, 0.06, 0.94))
	radice.add_child(barra)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	barra.add_child(hb)
	var logo := UI.titolo("PALEO", 40, UI.OCRA)
	logo.add_theme_font_override("font", UI.font_logo)
	logo.add_theme_font_size_override("font_size", 34)
	hb.add_child(logo)
	barra_giorno = UI.titolo("Giorno 1", 36, UI.PERGAMENA)
	barra_giorno.custom_minimum_size.x = 260
	hb.add_child(barra_giorno)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(UI.etichetta("Teschi", 18, UI.CENERE))
	box_teschi = HBoxContainer.new()
	box_teschi.tooltip_text = "Al quinto teschio la tribù perde."
	hb.add_child(box_teschi)
	hb.add_child(UI.etichetta("Pittura rupestre", 18, UI.CENERE))
	box_pittura = HBoxContainer.new()
	box_pittura.add_theme_constant_override("separation", 0)
	box_pittura.tooltip_text = "Con 5 pezzi la pittura è completa e la tribù vince."
	hb.add_child(box_pittura)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp2)
	box_risorse = HBoxContainer.new()
	box_risorse.add_theme_constant_override("separation", 12)
	hb.add_child(box_risorse)
	var b3d := UI.bottone("Vista 3D", 18)
	b3d.toggle_mode = true
	b3d.toggled.connect(_imposta_3d)
	b3d.name = "B3D"
	hb.add_child(b3d)
	var breg := UI.bottone("Regole", 18)
	breg.pressed.connect(_mostra_regole)
	hb.add_child(breg)
	var bmenu := UI.bottone("Menu", 18)
	bmenu.pressed.connect(_torna_menu)
	hb.add_child(bmenu)
	# ---- corpo
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 8)
	radice.add_child(corpo)
	var ssx := ScrollContainer.new()
	ssx.custom_minimum_size.x = 320
	ssx.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(ssx)
	col_sx = VBoxContainer.new()
	col_sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_sx.add_theme_constant_override("separation", 8)
	ssx.add_child(col_sx)
	var mezzo := VBoxContainer.new()
	mezzo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mezzo.add_theme_constant_override("separation", 6)
	corpo.add_child(mezzo)
	centro = Control.new()
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.clip_contents = true
	mezzo.add_child(centro)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.name = "ScrollGruppi"
	centro.add_child(sc)
	griglia = GridContainer.new()
	griglia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	griglia.add_theme_constant_override("h_separation", 8)
	griglia.add_theme_constant_override("v_separation", 8)
	sc.add_child(griglia)
	# pannello delle scelte
	pannello_scelta = UI.pannello(Color(0.24, 0.15, 0.09, 0.97), UI.OCRA)
	pannello_scelta.custom_minimum_size.y = 230
	mezzo.add_child(pannello_scelta)
	var vs := VBoxContainer.new()
	vs.add_theme_constant_override("separation", 4)
	pannello_scelta.add_child(vs)
	var hs := HBoxContainer.new()
	vs.add_child(hs)
	scelta_titolo = UI.titolo("", 34, UI.OCRA)
	hs.add_child(scelta_titolo)
	stato_online = UI.etichetta("", 17, UI.CENERE)
	stato_online.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stato_online.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hs.add_child(stato_online)
	scelta_testo = UI.etichetta("", 18, UI.CENERE)
	scelta_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vs.add_child(scelta_testo)
	scelta_scroll = ScrollContainer.new()
	scelta_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scelta_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vs.add_child(scelta_scroll)
	scelta_opzioni = HFlowContainer.new()
	scelta_opzioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scelta_opzioni.add_theme_constant_override("h_separation", 8)
	scelta_opzioni.add_theme_constant_override("v_separation", 8)
	scelta_scroll.add_child(scelta_opzioni)
	var sdx := ScrollContainer.new()
	sdx.custom_minimum_size.x = 330
	sdx.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(sdx)
	col_dx = VBoxContainer.new()
	col_dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_dx.add_theme_constant_override("separation", 8)
	sdx.add_child(col_dx)
	# ---- ingrandimento delle carte
	zoom = UI.pannello(Color(0.10, 0.07, 0.05, 0.97), UI.OCRA)
	zoom.visible = false
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.z_index = 50
	add_child(zoom)
	var zv := VBoxContainer.new()
	zv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.add_child(zv)
	zoom_titolo = UI.titolo("", 34, UI.OCRA)
	zoom_titolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zv.add_child(zoom_titolo)
	zoom_img = UI.immagine(null, 286, 440)
	zv.add_child(zoom_img)
	zoom_testo = RichTextLabel.new()
	zoom_testo.bbcode_enabled = true
	zoom_testo.fit_content = true
	zoom_testo.custom_minimum_size = Vector2(300, 10)
	zoom_testo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_testo.add_theme_font_size_override("normal_font_size", 18)
	zoom_testo.add_theme_font_size_override("bold_font_size", 18)
	zv.add_child(zoom_testo)
	# dadi
	overlay_dadi = CenterContainer.new()
	overlay_dadi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_dadi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_dadi.z_index = 40
	add_child(overlay_dadi)


# =====================================================================================
# AGGIORNAMENTO
# =====================================================================================

func _segna_aggiornamento() -> void:
	if not _da_aggiornare:
		_da_aggiornare = true
		call_deferred("_aggiorna")


func _aggiorna() -> void:
	_da_aggiornare = false
	if motore == null:
		return
	barra_giorno.text = "Giorno %d — %s" % [motore.giorno, {"giorno": "si esplora", "notte": "notte", "fine": "fine", "preparazione": "preparazione"}.get(motore.fase, "")]
	_svuota(box_teschi)
	for k in 5:
		var t := UI.immagine(UI.attrezzo_tex("teschio"), 34, 34)
		if k >= motore.teschi:
			t.modulate = Color(1, 1, 1, 0.18)
		box_teschi.add_child(t)
	_svuota(box_pittura)
	for k in 5:
		var p := UI.immagine(UI.tex("res://assets/segnalini/pittura%d.webp" % (k + 1)), 18, 46)
		if k >= motore.vittorie:
			p.modulate = Color(0.3, 0.25, 0.2, 0.45)
		box_pittura.add_child(p)
	_svuota(box_risorse)
	for r in ["cibo", "legno", "pietra"]:
		box_risorse.add_child(UI.contatore(UI.icona(r), motore.risorse[r], 24, "%s nel campo" % Dati.RISORSE[r]))
	_aggiorna_colonna_sx()
	_aggiorna_colonna_dx()
	_aggiorna_gruppi()
	if tavolo3d != null and vista3d:
		tavolo3d.aggiorna(motore)


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _sezione(dove: VBoxContainer, titolo: String) -> VBoxContainer:
	var p := UI.pannello()
	dove.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UI.titolo(titolo, 30, UI.OCRA))
	return v


func _aggiorna_colonna_sx() -> void:
	_svuota(col_sx)
	# Campo: mazzi
	var v := _sezione(col_sx, "Campo")
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 8)
	v.add_child(hm)
	for x in [["Umani", 1, motore.mazzo_umani.size()], ["Sogni", 2, motore.mazzo_sogni.size()], ["Idee", 3, motore.mazzo_idee.size()]]:
		var cv := VBoxContainer.new()
		var im := _dorso(x[1], 82, 126)
		im.tooltip_text = "%s: %d carte nel mazzo" % [x[0], x[2]]
		cv.add_child(im)
		var l := UI.etichetta("%s %d" % [x[0], x[2]], 16, UI.CENERE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(l)
		hm.add_child(cv)
	if not motore.guerriere.is_empty():
		v.add_child(UI.etichetta("Guerriere di guardia: %d (danni alla prima: %d)" % [motore.guerriere.size(), motore.guerriere_danni], 16, UI.PERGAMENA))
		var hg := HBoxContainer.new()
		for g in motore.guerriere:
			hg.add_child(_carta(g, 60, 92))
		v.add_child(hg)
	# Banco di lavoro
	var b := _sezione(col_sx, "Banco di lavoro")
	for idea in Dati.IDEE_BASE:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(UI.immagine(UI.attrezzo_tex(idea["attrezzo"]), 38, 38))
		h.add_child(UI.etichetta("%s ×%d" % [idea["nome"], motore.banco_attrezzi.get(idea["attrezzo"], 0)], 18, UI.PERGAMENA, true))
		var costo := HBoxContainer.new()
		for r in idea["paga"]:
			for k in int(idea["paga"][r]):
				costo.add_child(UI.immagine(UI.icona(r), 24, 24))
		h.add_child(costo)
		h.tooltip_text = "%s: %s (attrezzo: %s)" % [idea["nome"], motore._testo_paga(idea["paga"]), _testo_attrezzo(idea["attrezzo"])]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		b.add_child(h)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	b.add_child(fl)
	for id in motore.banco:
		var cv := VBoxContainer.new()
		cv.add_child(_carta(id, 88, 135))
		var o: Dictionary = motore.C[id]["opzioni"][0]
		for t in o["attrezzi"]:
			cv.add_child(UI.contatore(UI.attrezzo_tex(t), motore.banco_attrezzi.get(t, 0), 16, Dati.nome_attrezzo(t)))
		fl.add_child(cv)
	if motore.banco.is_empty():
		b.add_child(UI.etichetta("Nessuna idea nuova: trovale nelle Case.", 16, UI.CENERE))
	# Natura: scarti
	var n := _sezione(col_sx, "Natura")
	var hn := HBoxContainer.new()
	hn.add_theme_constant_override("separation", 10)
	n.add_child(hn)
	var cop := VBoxContainer.new()
	var ultimo_cop: int = motore.scarti_coperti[-1] if not motore.scarti_coperti.is_empty() else -1
	cop.add_child(_dorso(int(motore.C[ultimo_cop]["dorso"]) if ultimo_cop >= 0 else 6, 70, 108, ultimo_cop < 0))
	cop.add_child(UI.etichetta("Coperte %d" % motore.scarti_coperti.size(), 15, UI.CENERE))
	hn.add_child(cop)
	var sco := VBoxContainer.new()
	if motore.scarti_scoperti.is_empty():
		sco.add_child(_vuoto(70, 108))
	else:
		sco.add_child(_carta(motore.scarti_scoperti[-1], 70, 108))
	sco.add_child(UI.etichetta("Scoperte %d" % motore.scarti_scoperti.size(), 15, UI.CENERE))
	hn.add_child(sco)
	var cim := VBoxContainer.new()
	if motore.cimitero.is_empty():
		cim.add_child(_vuoto(70, 108))
	else:
		cim.add_child(_carta(motore.cimitero[-1], 70, 108))
	cim.add_child(UI.etichetta("Cimitero %d" % motore.cimitero.size(), 15, UI.CENERE))
	hn.add_child(cim)
	if not motore.fiume.is_empty():
		var fv := VBoxContainer.new()
		fv.add_child(_dorso(int(motore.C[motore.fiume[0]]["dorso"]), 70, 108))
		fv.add_child(UI.etichetta("Grande fiume %d" % motore.fiume.size(), 15, UI.CENERE))
		hn.add_child(fv)


func _aggiorna_colonna_dx() -> void:
	_svuota(col_dx)
	var v := _sezione(col_dx, "Notte")
	v.add_child(UI.etichetta("Missioni (ogni notte, una azione ciascuna):", 16, UI.CENERE))
	var hm := HFlowContainer.new()
	hm.add_theme_constant_override("h_separation", 6)
	v.add_child(hm)
	for m in motore.missioni:
		hm.add_child(_carta(m, 92, 141))
	var sg := "Segreti da scoprire: " + (", ".join(motore.segreti.map(func(x): return str(x))) if not motore.segreti.is_empty() else "nessuno")
	var ls := UI.etichetta(sg, 16, UI.PERGAMENA)
	ls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ls)
	if motore.moduli.has("J"):
		v.add_child(UI.etichetta("La belva è %s." % ("FURIOSA" if motore.belva_furiosa else "calma"), 17, UI.RUGGINE if motore.belva_furiosa else UI.CENERE, true))
		if motore.attesa.has(Dati.segreto_id(22)):
			v.add_child(UI.etichetta("Tigre dai denti a sciabola: %d danni su 5" % motore.tigre_danni, 17, UI.PERGAMENA, true))
	if not motore.attesa.is_empty():
		var a := _sezione(col_dx, "In attesa")
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		a.add_child(fl)
		for id in motore.attesa:
			var cv := VBoxContainer.new()
			cv.add_child(_carta(id, 88, 135))
			var dep: Dictionary = motore.depositi.get(id, {})
			var testo := []
			for k in dep:
				if not String(k).contains("@"):
					testo.append("%d %s" % [dep[k], Dati.RISORSE.get(k, Dati.nome_attrezzo(k)).to_lower()])
			if not testo.is_empty():
				var l := UI.etichetta("Sopra: " + ", ".join(testo), 14, UI.OCRA)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size.x = 88
				cv.add_child(l)
			fl.add_child(cv)
	var r := _sezione(col_dx, "Racconto")
	registro = RichTextLabel.new()
	registro.bbcode_enabled = true
	registro.scroll_following = true
	registro.custom_minimum_size = Vector2(290, 330)
	registro.add_theme_font_size_override("normal_font_size", 16)
	r.add_child(registro)
	var righe: Array = motore.registro.slice(max(0, motore.registro.size() - 60))
	registro.text = "\n".join(righe.map(func(x): return "• " + String(x)))


func _aggiorna_gruppi() -> void:
	_svuota(griglia)
	var n := motore.giocatori.size()
	griglia.columns = 1 if n == 1 else 2
	for i in n:
		griglia.add_child(_area_giocatore(i))


func _area_giocatore(i: int) -> Control:
	var g: Dictionary = motore.giocatori[i]
	var attivo: bool = _richiesta.get("posto", -1) == i and _in_attesa
	var p := UI.pannello(Color(0.22, 0.15, 0.10, 0.92) if not attivo else Color(0.32, 0.20, 0.10, 0.96), UI.OCRA if attivo else UI.OCRA_SCURA)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(UI.titolo(g["nome"], 32, UI.OCRA if attivo else UI.PERGAMENA))
	var info := "  IA" if g["ia"] else ""
	if g["dorme"]:
		info += "  · dorme"
	h.add_child(UI.etichetta(info, 17, UI.CENERE))
	var ab := motore.abilita_permanenti([i])
	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spazio)
	h.add_child(UI.etichetta("Forza %d · Percezione %d · Destrezza %d" % [ab["F"], ab["P"], ab["D"]], 17, UI.PERGAMENA, true))
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 10)
	v.add_child(corpo)
	# mazzo: le prime tre carte grandi, il resto in una striscia
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	corpo.add_child(mv)
	mv.add_child(UI.etichetta("Mazzo: %d carte" % g["mazzo"].size(), 15, UI.CENERE))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", -18)
	mv.add_child(top)
	var quante := 2 if motore.varianti.get("nebbia", false) else 3
	var sceglibile: bool = attivo and _richiesta.get("tipo", "") == "scegli_carta"
	for k in min(quante, g["mazzo"].size()):
		var id: int = g["mazzo"][k]
		var d := _dorso(int(motore.C[id]["dorso"]), 78, 120)
		if sceglibile:
			d.mouse_filter = Control.MOUSE_FILTER_STOP
			d.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			d.modulate = Color(1.15, 1.1, 0.95)
			var kk: int = k
			d.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _scegli_indice_carta(kk))
			d.tooltip_text = "Esplora questo luogo (%s)" % motore._nome_dorso(id)
		top.add_child(d)
	if g["mazzo"].size() > quante:
		var resto := HFlowContainer.new()
		resto.custom_minimum_size.x = 230
		resto.add_theme_constant_override("h_separation", 1)
		resto.add_theme_constant_override("v_separation", 1)
		for k in range(quante, g["mazzo"].size()):
			var id2: int = g["mazzo"][k]
			var dd := _dorso(int(motore.C[id2]["dorso"]), 22, 34)
			dd.tooltip_text = "Carta %d: %s" % [k + 1, motore._nome_dorso(id2)]
			resto.add_child(dd)
		mv.add_child(resto)
	# carta scoperta
	var sv := VBoxContainer.new()
	corpo.add_child(sv)
	sv.add_child(UI.etichetta("Scoperta", 15, UI.CENERE))
	if g["rivelata"] >= 0:
		var c := _carta(g["rivelata"], 128, 197)
		sv.add_child(c)
		if _ultime_rivelate.get(i, -1) != g["rivelata"]:
			c.pivot_offset = Vector2(64, 98)
			c.scale = Vector2(0.05, 1)
			var tw := create_tween()
			tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		sv.add_child(_vuoto(128, 197))
	_ultime_rivelate[i] = g["rivelata"]
	# gruppo
	var gv := VBoxContainer.new()
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(gv)
	gv.add_child(UI.etichetta("Gruppo", 15, UI.CENERE))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 4)
	fl.add_theme_constant_override("v_separation", 4)
	gv.add_child(fl)
	for id in g["gruppo"]:
		fl.add_child(_carta_gruppo(i, id))
	# attrezzi
	var at := HFlowContainer.new()
	at.add_theme_constant_override("h_separation", 6)
	gv.add_child(at)
	for t in g["attrezzi"]:
		var c2 := UI.contatore(UI.attrezzo_tex(t), int(g["attrezzi"][t]), 18, "%s: %s" % [Dati.nome_attrezzo(t), _testo_attrezzo(t)])
		at.add_child(c2)
	return p


func _carta_gruppo(i: int, id: int) -> Control:
	var g: Dictionary = motore.giocatori[i]
	var box := Control.new()
	box.custom_minimum_size = Vector2(84, 129)
	var c := _carta(id, 84, 129)
	box.add_child(c)
	var d: int = int(g["danni"].get(id, 0))
	if d > 0:
		var hb := HBoxContainer.new()
		hb.position = Vector2(2, 100)
		hb.add_theme_constant_override("separation", -4)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in d:
			hb.add_child(UI.immagine(UI.attrezzo_tex("danno"), 26, 26))
		box.add_child(hb)
	return box


func _testo_attrezzo(t: String) -> String:
	var a: Dictionary = Dati.ATTREZZI.get(t, {})
	var parti := []
	for s in a.get("perm", {}):
		parti.append("+%d %s sempre" % [a["perm"][s], Dati.ABILITA[s]])
	for s in a.get("uso", {}):
		if s == "X":
			parti.append("si consuma per +1 a un'abilità a scelta")
		else:
			parti.append("si consuma per +%d %s" % [a["uso"][s], Dati.ABILITA[s]])
	if a.has("para"):
		parti.append("si consuma per parare fino a %d danni" % a["para"])
	if a.has("cura"):
		parti.append("si consuma per curare fino a %d danni" % a["cura"])
	match t:
		"talismano":
			parti.append("si consuma per ignorare un pericolo scoperto")
		"tenda":
			parti.append("riparo richiesto da alcune carte")
		"zattera":
			parti.append("permette di scoprire le carte del Grande fiume")
	return ", ".join(parti)


# =====================================================================================
# CARTE
# =====================================================================================

func _carta(id: int, w: float, h: float) -> TextureRect:
	var r := UI.immagine(UI.carta_tex(id), w, h)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.mouse_entered.connect(_mostra_zoom.bind(id, r))
	r.mouse_exited.connect(_nascondi_zoom)
	return r


func _dorso(n: int, w: float, h: float, vuoto := false) -> TextureRect:
	var r := UI.immagine(UI.dorso_tex(n), w, h)
	if vuoto:
		r.modulate = Color(1, 1, 1, 0.15)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


func _vuoto(w: float, h: float) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(w, h)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.25)
	s.border_color = Color(0.85, 0.55, 0.22, 0.3)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _mostra_zoom(id: int, sorgente: Control) -> void:
	_mostra_zoom_rect(id, sorgente.get_global_rect())


func _mostra_zoom_a(id: int, pos: Vector2) -> void:
	_mostra_zoom_rect(id, Rect2(pos + Vector2(20, 0), Vector2(1, 1)))


func _mostra_zoom_rect(id: int, r: Rect2) -> void:
	var c: Dictionary = motore.C[id]
	zoom_titolo.text = c["nome"]
	zoom_img.texture = UI.carta_tex(id)
	var t := "[b]%s[/b]\n" % _tipo_carta(c)
	t += motore.descrivi_carta(id).replace("\n", "\n• ").insert(0, "• ") if c["tipo"] != "U" else motore.descrivi_carta(id)
	if c.get("spiegazione", false):
		t += "\n[i]%s[/i]" % Spiegazioni.testo(id)
	zoom_testo.text = t
	zoom.visible = true
	zoom.reset_size()
	var vp := get_viewport_rect().size
	var pos := Vector2(r.end.x + 12, r.position.y - 60)
	if pos.x + zoom.size.x > vp.x:
		pos.x = r.position.x - zoom.size.x - 12
	pos.y = clamp(pos.y, 8, max(8.0, vp.y - zoom.size.y - 8))
	pos.x = clamp(pos.x, 8, max(8.0, vp.x - zoom.size.x - 8))
	zoom.position = pos


func _tipo_carta(c: Dictionary) -> String:
	var tipo: String = {"A": "Azione", "P": "Pericolo (non si può ignorare)", "U": "Umano", "M": "Missione notturna", "I": "Idea", "G": "Segreto", "Z": "Carta in attesa"}.get(c["tipo"], "")
	var mod: String = c["modulo"]
	var dove := ""
	if Dati.MODULI.has(mod):
		dove = "modulo %s, %s" % [mod, Dati.MODULI[mod]["nome"]]
	else:
		dove = {"1": "carta base", "2": "umano", "3": "sogno", "4": "idea", "5": "segreto"}.get(mod, "")
	return "%s — %s" % [tipo, dove]


func _nascondi_zoom() -> void:
	zoom.visible = false


# =====================================================================================
# DECISIONI DELLA PERSONA
# =====================================================================================

func chiedi_persona(_m: Motore, posto: int, req: Dictionary) -> int:
	_richiesta = req
	_in_attesa = true
	_mostra_richiesta(posto, req)
	_aggiorna()
	var r: int = await scelta_fatta
	_in_attesa = false
	_richiesta = {}
	_svuota(scelta_opzioni)
	scelta_titolo.text = ""
	scelta_testo.text = ""
	return r


func _mostra_richiesta(posto: int, req: Dictionary) -> void:
	var nome: String = motore.giocatori[posto]["nome"]
	scelta_titolo.text = req.get("titolo", "")
	var piu_persone := 0
	for g in motore.giocatori:
		if not g["ia"]:
			piu_persone += 1
	scelta_testo.text = (("Tocca a %s. " % nome) if piu_persone > 1 else "") + req.get("testo", "")
	_svuota(scelta_opzioni)
	var opz: Array = req.get("opzioni", [])
	if req.get("tipo", "") == "visione":
		var hv := HBoxContainer.new()
		for c in req.get("carte", []):
			hv.add_child(_carta(c, 90, 138))
		scelta_opzioni.add_child(hv)
	for k in opz.size():
		var b := UI.bottone(opz[k]["testo"], 19)
		var testo: String = opz[k]["testo"]
		if testo.begins_with("[negativa]"):
			b.add_theme_color_override("font_color", Color(1.0, 0.72, 0.62))
		b.pressed.connect(_premi.bind(k))
		scelta_opzioni.add_child(b)
	if req.has("carta"):
		var id: int = req["carta"]
		var info := Button.new()
		info.text = "Vedi la carta"
		info.add_theme_font_size_override("font_size", 16)
		info.mouse_entered.connect(_mostra_zoom.bind(id, info))
		info.mouse_exited.connect(_nascondi_zoom)
		scelta_opzioni.add_child(info)


func _premi(k: int) -> void:
	if not _in_attesa:
		return
	_nascondi_zoom()
	scelta_fatta.emit(k)


func _scegli_indice_carta(k: int) -> void:
	var opz: Array = _richiesta.get("opzioni", [])
	for j in opz.size():
		if opz[j].get("k", "") == "carta" and opz[j].get("i", -1) == k:
			_premi(j)
			return


# =====================================================================================
# EVENTI DEL MOTORE
# =====================================================================================

func _al_messaggio(t: String) -> void:
	if registro != null:
		registro.append_text("\n• " + t)


func _al_evento(tipo: String, dati: Dictionary) -> void:
	match tipo:
		"dadi":
			_mostra_dadi(dati["facce"])
		"notte":
			_lampo(UI.NOTTE)
		"danno":
			_lampo(Color(0.6, 0.05, 0.02))
	if tavolo3d != null and vista3d:
		tavolo3d.evento(tipo, dati)


func _lampo(col: Color) -> void:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 30
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.28, 0.12)
	tw.tween_property(r, "color:a", 0.0, 0.45)
	tw.tween_callback(r.queue_free)


func _mostra_dadi(facce: Array) -> void:
	_svuota(overlay_dadi)
	var p := UI.pannello(Color(0.12, 0.08, 0.06, 0.95), UI.OCRA)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_dadi.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UI.titolo("Dadi", 36, UI.OCRA))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for f in facce:
		var idx := 0
		for k in Dati.DADO.size():
			if Dati.DADO[k] == f:
				idx = k
				break
		var im := UI.immagine(UI.icona("dado%d" % idx), 96, 96)
		im.pivot_offset = Vector2(48, 48)
		im.rotation = randf_range(-2.5, 2.5)
		h.add_child(im)
		var tw := create_tween()
		tw.tween_property(im, "rotation", randf_range(-0.15, 0.15), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.add_child(UI.etichetta("I requisiti salgono di: " + motore._descrivi_dadi(facce), 18, UI.PERGAMENA))
	p.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(p, "modulate:a", 1.0, 0.15)
	tw2.tween_interval(1.6)
	tw2.tween_property(p, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(p.queue_free)


func _alla_fine(esito: String) -> void:
	if online != null:
		online.chiudi()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.z_index = 60
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	var p := UI.pannello(Color(0.18, 0.11, 0.07, 0.98), UI.OCRA)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var vinto := esito == "vittoria"
	var t := UI.titolo("La pittura rupestre è completa!" if vinto else "La tribù non ce l'ha fatta", 64, UI.OCRA if vinto else UI.RUGGINE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var hp := HBoxContainer.new()
	hp.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in 5:
		var im := UI.immagine(UI.tex("res://assets/segnalini/pittura%d.webp" % (k + 1)), 50, 140)
		if k >= motore.vittorie:
			im.modulate = Color(0.3, 0.25, 0.2, 0.4)
		hp.add_child(im)
	v.add_child(hp)
	var testo := "Avete resistito %d giorn%s. Teschi: %d su 5. Pezzi di pittura: %d su 5." % [motore.giorno, "o" if motore.giorno == 1 else "i", motore.teschi, motore.vittorie]
	var lt := UI.etichetta(testo, 22, UI.PERGAMENA)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lt)
	var risultati := _conquiste()
	if not risultati.is_empty():
		var lc := UI.etichetta("Conquiste: " + ", ".join(risultati), 20, UI.OCRA)
		lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lc)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	var b1 := UI.bottone("Rivedi il tavolo", 22)
	b1.pressed.connect(fondo.queue_free)
	hb.add_child(b1)
	var b2 := UI.bottone("Torna al menu", 22)
	b2.pressed.connect(_torna_menu)
	hb.add_child(b2)


## Le «Errungenschaften» del foglio dei livelli.
func _conquiste() -> Array:
	var out := []
	if motore.esito != "vittoria":
		return out
	if motore.teschi == 0:
		out.append("nessun teschio")
	if motore.banco.size() >= 6:
		out.append("6 idee nel banco")
	if motore.segreti.is_empty():
		out.append("tutti i segreti scoperti")
	var feriti := false
	for g in motore.giocatori:
		if not g["danni"].is_empty():
			feriti = true
	if not feriti:
		out.append("nessun ferito")
	var ris: int = motore.risorse["cibo"] + motore.risorse["legno"] + motore.risorse["pietra"]
	if ris >= 10:
		out.append("10 risorse nel campo")
	var att := 0
	for g in motore.giocatori:
		for t in g["attrezzi"]:
			att += int(g["attrezzi"][t])
	if att >= 8:
		out.append("8 attrezzi")
	return out


# =====================================================================================
# VISTA 3D, MENU, REGOLE, ONLINE
# =====================================================================================

func _imposta_3d(on: bool) -> void:
	vista3d = on
	var b: Button = find_child("B3D", true, false)
	if b != null and b.button_pressed != on:
		b.set_pressed_no_signal(on)
	if on and tavolo3d == null:
		tavolo3d = preload("res://scripts/ui/tavolo3d.gd").new()
		tavolo3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tavolo3d.vista = self
		centro.add_child(tavolo3d)
	if tavolo3d != null:
		tavolo3d.visible = on
		if on:
			tavolo3d.aggiorna(motore)
	var sc: Control = centro.get_node("ScrollGruppi")
	sc.visible = not on


func _mostra_regole() -> void:
	var w := preload("res://scripts/ui/regole.gd").new()
	w.finestra = true
	w.z_index = 70
	add_child(w)


func _torna_menu() -> void:
	if online != null:
		online.alive = false
	main.show_menu()


func online_attesa(s: int) -> void:
	if s < 0:
		stato_online.text = ""
	else:
		stato_online.text = "In attesa di %s…" % motore.giocatori[s]["nome"]


func online_stato(t: String) -> void:
	stato_online.text = t
