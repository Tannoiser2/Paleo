extends Control
## Menu iniziale: livello o moduli, gruppi (persone o IA), varianti, vista 2D/3D e gioco online.

var main
var livello := 0
var moduli_liberi := {}
var usa_livello := true
var gruppi: Array = []
var varianti := {}
var vista3d := false
var ritardo := 0.7

var box_gruppi: VBoxContainer
var box_moduli: Control
var lbl_moduli: Label
var opt_livello: OptionButton
var messaggio: Label
var on_code: LineEdit
var on_nome: LineEdit
var on_start: Button
var pannello_online: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	livello = st.get("livello", 0)
	usa_livello = st.get("usa_livello", true)
	moduli_liberi = st.get("moduli_liberi", {"A": true, "B": true})
	gruppi = st.get("gruppi", [{"nome": "Stefano", "ia": false}, {"nome": "Ayla", "ia": true}])
	varianti = st.get("varianti", {})
	vista3d = st.get("vista3d", false)
	ritardo = st.get("ritardo", 0.7)
	_costruisci()
	if not main.lobby.is_empty():
		_pannello_online.call_deferred()


func _salva() -> void:
	main.menu_state = {"livello": livello, "usa_livello": usa_livello, "moduli_liberi": moduli_liberi, "gruppi": gruppi,
		"varianti": varianti, "vista3d": vista3d, "ritardo": ritardo}


func _costruisci() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 36)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	m.add_child(h)
	# ---- colonna del titolo
	var sx := VBoxContainer.new()
	sx.custom_minimum_size.x = 560
	sx.add_theme_constant_override("separation", 10)
	h.add_child(sx)
	var logo := Label.new()
	logo.text = "PALEO"
	logo.add_theme_font_override("font", UI.font_logo)
	logo.add_theme_font_size_override("font_size", 150)
	logo.add_theme_color_override("font_color", UI.OCRA)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	logo.add_theme_constant_override("shadow_offset_x", 5)
	logo.add_theme_constant_override("shadow_offset_y", 5)
	sx.add_child(logo)
	var sott := UI.titolo("Un nuovo giorno nell'età della pietra", 46, UI.PERGAMENA)
	sx.add_child(sott)
	var intro := UI.etichetta("La vostra tribù lotta insieme per sopravvivere e per completare la pittura rupestre. Esplorate boschi, fiumi e montagne, cacciate, inventate attrezzi... e attenti a belve, tempeste e tribù nemiche.", 21, UI.CENERE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 520
	sx.add_child(intro)
	var pitt := HBoxContainer.new()
	pitt.add_theme_constant_override("separation", 0)
	for k in 5:
		pitt.add_child(UI.immagine(UI.tex("res://assets/segnalini/pittura%d.webp" % (k + 1)), 62, 170))
	sx.add_child(pitt)
	var bt := VBoxContainer.new()
	bt.add_theme_constant_override("separation", 10)
	sx.add_child(bt)
	var b_gioca := UI.bottone("Inizia la partita", 30)
	b_gioca.custom_minimum_size = Vector2(360, 64)
	b_gioca.pressed.connect(_inizia)
	bt.add_child(b_gioca)
	var sav: Dictionary = preload("res://scripts/ui/partita.gd").salvataggio()
	if not sav.is_empty() and sav.get("config", {}) is Dictionary:
		var cf: Dictionary = sav["config"]
		var mods: Array = cf.get("moduli", [])
		var b_cont := UI.bottone("Continua la partita (giorno %d, moduli %s)" % [int(sav.get("giorno", 1)), " + ".join(mods)], 22)
		b_cont.custom_minimum_size = Vector2(360, 52)
		b_cont.pressed.connect(func():
			var cfg2: Dictionary = cf.duplicate()
			cfg2["storia"] = sav.get("storia", [])
			main.start_game(cfg2))
		bt.add_child(b_cont)
	var b_on := UI.bottone("Gioca online", 24)
	b_on.custom_minimum_size = Vector2(360, 52)
	b_on.pressed.connect(_pannello_online)
	bt.add_child(b_on)
	var b_reg := UI.bottone("Regole", 24)
	b_reg.custom_minimum_size = Vector2(360, 52)
	b_reg.pressed.connect(func(): main.show_rules())
	bt.add_child(b_reg)
	messaggio = UI.etichetta("", 18, UI.OCRA)
	messaggio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	messaggio.custom_minimum_size.x = 520
	sx.add_child(messaggio)
	var cred := UI.etichetta("Paleo di Peter Rustemeyer — Hans im Glück. Versione digitale amatoriale per la ludoteca.", 15, Color(0.7, 0.62, 0.52))
	cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cred.custom_minimum_size.x = 520
	cred.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cred.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sx.add_child(cred)
	# ---- colonna delle impostazioni
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	var dx := VBoxContainer.new()
	dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dx.add_theme_constant_override("separation", 12)
	sc.add_child(dx)
	# livello / moduli
	var p1 := UI.pannello()
	dx.add_child(p1)
	var v1 := VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	p1.add_child(v1)
	v1.add_child(UI.titolo("Avventura", 38))
	var hl := HBoxContainer.new()
	hl.add_theme_constant_override("separation", 10)
	v1.add_child(hl)
	var cb_liv := CheckBox.new()
	cb_liv.text = "Livello consigliato"
	cb_liv.button_pressed = usa_livello
	hl.add_child(cb_liv)
	opt_livello = OptionButton.new()
	for k in Dati.LIVELLI.size():
		var L: Dictionary = Dati.LIVELLI[k]
		opt_livello.add_item("%s — %s" % [L["nome"], " + ".join(L["moduli"].map(func(x): return Dati.MODULI[x]["nome"]))], k)
	opt_livello.select(livello)
	opt_livello.item_selected.connect(func(i): livello = i; _aggiorna_moduli())
	hl.add_child(opt_livello)
	cb_liv.toggled.connect(func(on): usa_livello = on; _aggiorna_moduli())
	lbl_moduli = UI.etichetta("", 18, UI.CENERE)
	lbl_moduli.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v1.add_child(lbl_moduli)
	box_moduli = GridContainer.new()
	box_moduli.columns = 2
	v1.add_child(box_moduli)
	_aggiorna_moduli()
	# gruppi
	var p2 := UI.pannello()
	dx.add_child(p2)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	p2.add_child(v2)
	v2.add_child(UI.titolo("La tribù", 38))
	var nota := UI.etichetta("Ogni giocatore guida un gruppo di umani. Da 1 a 4 gruppi; i compagni IA collaborano con voi. Con un solo gruppo si usa la variante in solitario.", 17, UI.CENERE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v2.add_child(nota)
	box_gruppi = VBoxContainer.new()
	box_gruppi.add_theme_constant_override("separation", 6)
	v2.add_child(box_gruppi)
	_aggiorna_gruppi()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v2.add_child(hb)
	var b_add := UI.bottone("+ Gruppo", 18)
	b_add.pressed.connect(func():
		if gruppi.size() < 4:
			gruppi.append({"nome": ["Ayla", "Oog", "Brun", "Iza"][gruppi.size() % 4], "ia": true})
			_aggiorna_gruppi())
	hb.add_child(b_add)
	var b_rem := UI.bottone("− Gruppo", 18)
	b_rem.pressed.connect(func():
		if gruppi.size() > 1:
			gruppi.pop_back()
			_aggiorna_gruppi())
	hb.add_child(b_rem)
	# varianti
	var p3 := UI.pannello()
	dx.add_child(p3)
	var v3 := VBoxContainer.new()
	v3.add_theme_constant_override("separation", 6)
	p3.add_child(v3)
	v3.add_child(UI.titolo("Varianti", 38))
	var gv := GridContainer.new()
	gv.columns = 2
	v3.add_child(gv)
	for k in Dati.VARIANTI:
		var V: Dictionary = Dati.VARIANTI[k]
		var cb := CheckBox.new()
		cb.text = "%s (%s)" % [V["nome"], "più facile" if V["facile"] else "più difficile"]
		cb.tooltip_text = V["testo"]
		cb.button_pressed = varianti.get(k, false)
		cb.toggled.connect(func(on): varianti[k] = on)
		gv.add_child(cb)
	# vista
	var p4 := UI.pannello()
	dx.add_child(p4)
	var v4 := HBoxContainer.new()
	v4.add_theme_constant_override("separation", 16)
	p4.add_child(v4)
	v4.add_child(UI.titolo("Tavolo", 38))
	var cb3 := CheckBox.new()
	cb3.text = "Inizia con il tavolo in 3D"
	cb3.button_pressed = vista3d
	cb3.toggled.connect(func(on): vista3d = on)
	v4.add_child(cb3)
	var ov := OptionButton.new()
	ov.add_item("IA veloce", 0)
	ov.add_item("IA normale", 1)
	ov.add_item("IA lenta", 2)
	ov.select(0 if ritardo < 0.4 else (1 if ritardo < 1.0 else 2))
	ov.item_selected.connect(func(i): ritardo = [0.2, 0.7, 1.4][i])
	v4.add_child(ov)


func _aggiorna_moduli() -> void:
	opt_livello.disabled = not usa_livello
	for c in box_moduli.get_children():
		c.queue_free()
	var mods := _moduli_scelti()
	var righe := []
	for x in mods:
		var M: Dictionary = Dati.MODULI[x]
		righe.append("%s — %s (%s): %s" % [x, M["nome"], M["difficolta"], M["storia"]])
	lbl_moduli.text = "\n".join(righe)
	box_moduli.visible = not usa_livello
	if not usa_livello:
		for x in Dati.MODULI:
			var cb := CheckBox.new()
			cb.text = "%s — %s (%s)" % [x, Dati.MODULI[x]["nome"], Dati.MODULI[x]["difficolta"]]
			cb.button_pressed = moduli_liberi.get(x, false)
			cb.toggled.connect(func(on): moduli_liberi[x] = on; _aggiorna_moduli.call_deferred())
			box_moduli.add_child(cb)


func _moduli_scelti() -> Array:
	if usa_livello:
		return Dati.LIVELLI[livello]["moduli"].duplicate()
	var out := []
	for x in Dati.MODULI:
		if moduli_liberi.get(x, false):
			out.append(x)
	return out


func _aggiorna_gruppi() -> void:
	for c in box_gruppi.get_children():
		c.queue_free()
	for i in gruppi.size():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		box_gruppi.add_child(h)
		h.add_child(UI.etichetta("Gruppo %d" % (i + 1), 18, UI.OCRA, true))
		var le := LineEdit.new()
		le.text = gruppi[i]["nome"]
		le.custom_minimum_size.x = 260
		le.max_length = 20
		le.text_changed.connect(func(t): gruppi[i]["nome"] = t)
		h.add_child(le)
		var ob := OptionButton.new()
		ob.add_item("Persona", 0)
		ob.add_item("IA", 1)
		ob.select(1 if gruppi[i]["ia"] else 0)
		ob.item_selected.connect(func(k): gruppi[i]["ia"] = k == 1)
		h.add_child(ob)


func _config() -> Dictionary:
	var gg := []
	for g in gruppi:
		var nm: String = String(g["nome"]).strip_edges()
		gg.append({"nome": nm if nm != "" else "Gruppo", "ia": g["ia"]})
	var v := {}
	for k in varianti:
		if varianti[k]:
			v[k] = true
	return {"giocatori": gg, "moduli": _moduli_scelti(), "varianti": v, "vista3d": vista3d, "ritardo_ia": ritardo}


func _inizia() -> void:
	var cfg := _config()
	if cfg["moduli"].size() < 1:
		messaggio.text = "Scegli almeno un modulo (di solito due)."
		return
	_salva()
	main.start_game(cfg)


# =================================================================== online

func _pannello_online() -> void:
	if pannello_online != null:
		pannello_online.queue_free()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	pannello_online = UI.pannello(Color(0.18, 0.12, 0.08, 0.98), UI.OCRA)
	pannello_online.custom_minimum_size.x = 760
	cc.add_child(pannello_online)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pannello_online.add_child(v)
	v.add_child(UI.titolo("Gioca online", 46))
	var spieg := UI.etichetta("Chi crea la stanza sceglie avventura, gruppi (le persone sono i posti per gli amici) e varianti in questo menu, poi crea la stanza e dà il codice. Ognuno gioca il proprio gruppo; i posti rimasti liberi li gioca l'IA.", 18, UI.CENERE)
	spieg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(spieg)
	var hn := HBoxContainer.new()
	v.add_child(hn)
	hn.add_child(UI.etichetta("Il tuo nome:", 19))
	on_nome = LineEdit.new()
	on_nome.custom_minimum_size.x = 280
	var net: Net = main.get_net()
	on_nome.text = String(net.load_session().get("name", gruppi[0]["nome"]))
	hn.add_child(on_nome)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", 10)
	v.add_child(hc)
	var b_crea := UI.bottone("Crea una stanza", 20)
	b_crea.pressed.connect(_online_crea)
	hc.add_child(b_crea)
	on_code = LineEdit.new()
	on_code.placeholder_text = "Codice"
	on_code.max_length = 4
	on_code.custom_minimum_size.x = 120
	hc.add_child(on_code)
	var b_entra := UI.bottone("Entra", 20)
	b_entra.pressed.connect(_online_entra)
	hc.add_child(b_entra)
	on_start = UI.bottone("Inizia online", 22)
	on_start.visible = main.lobby.get("role", "") == "host"
	on_start.pressed.connect(_online_avvia)
	v.add_child(on_start)
	var stato := UI.etichetta("", 18, UI.OCRA)
	stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stato.name = "Stato"
	v.add_child(stato)
	var b_chiudi := UI.bottone("Chiudi", 18)
	b_chiudi.pressed.connect(func():
		main.lobby = {}
		fondo.queue_free()
		pannello_online = null)
	v.add_child(b_chiudi)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		_lobby_poll(main.lobby["code"])
	else:
		var sess := net.load_session()
		var vecchia := String(sess.get("room", ""))
		if vecchia != "":
			on_code.text = vecchia
			_di("Eri nella stanza %s: premi Entra per rientrare." % vecchia)


func _di(t: String) -> void:
	if pannello_online != null:
		var l: Label = pannello_online.find_child("Stato", true, false)
		if l != null:
			l.text = t


func _online_crea() -> void:
	var cfg := _config()
	var nm := on_nome.text.strip_edges()
	if nm == "":
		_di("Scrivi il tuo nome.")
		return
	var seats := []
	for i in cfg["giocatori"].size():
		if not cfg["giocatori"][i]["ia"]:
			seats.append(i)
	if seats.is_empty():
		_di("Imposta almeno un gruppo come Persona: sono i posti della stanza.")
		return
	_salva()
	var net: Net = main.get_net()
	_di("Creo la stanza…")
	var code := await net.create_room(nm, seats)
	if code == "":
		_di("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	on_code.text = code
	on_start.visible = true
	_lobby_poll(code)


func _online_entra() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_nome.text.strip_edges()
	if code.length() != 4 or nm == "":
		_di("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	var net: Net = main.get_net()
	_di("Entro nella stanza %s…" % code)
	var seat := await net.join_room(code, nm)
	if seat < 0:
		_di("Stanza %s non trovata, piena, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") == "playing" and room.has("game"):
		_avvia(room["game"], true)
		return
	on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_di("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		var seats := Net._as_dict(room.get("seats", {}))
		var nomi := []
		for k in seats:
			nomi.append("%s (gruppo %d)" % [seats[k].get("name", "?"), int(k) + 1])
		if main.lobby["role"] == "host":
			_di("Stanza [ %s ]: dai il codice ai tuoi amici.\nPresenti: %s.\nQuando ci siete tutti premi Inizia online." % [code, ", ".join(nomi)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_avvia(room["game"], false)
				return
			_di("Sei nella stanza [ %s ] (gruppo %d). Presenti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, int(main.lobby["seat"]) + 1, ", ".join(nomi)])
		await get_tree().create_timer(2.0).timeout


func _online_avvia() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_di("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in cfg["giocatori"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["giocatori"][i]["ia"]:
			cfg["giocatori"][i]["nome"] = str(seats_db[k].get("name", cfg["giocatori"][i]["nome"]))
		else:
			cfg["giocatori"][i]["ia"] = true
	cfg["seme"] = 1 + randi() % 2000000000
	cfg.erase("vista3d")
	cfg.erase("ritardo_ia")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_di("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_avvia(g, false)


func _avvia(g: Dictionary, rientro: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rientro:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_di("Configurazione della partita non valida.")
		return
	var ses := SessioneOnline.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	cfg["vista3d"] = vista3d
	cfg["ritardo_ia"] = ritardo
	main.lobby = {}
	main.start_game(cfg)
