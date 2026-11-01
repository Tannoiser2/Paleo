extends SubViewportContainer
## Il tavolo in 3D, disposto come nel modulo Tabletop Simulator: stesse posizioni e misure dei tabelloni
## (Notte, Natura, Campo da sinistra a destra, ruotati di 90 gradi), del banco di lavoro e delle carte.
## Coordinate: x e altezza come in TTS, z invertita (in TTS i giocatori stanno a -z, qui a +z).
## Comandi: trascina con il tasto sinistro per ruotare, con il destro (o il centrale, o Maiusc+sinistro)
## per spostare la vista; rotellina o pizzico per avvicinare; due dita sul trackpad per spostare;
## frecce o WASD per spostare, R per tornare alla vista iniziale.

var vista
var sv: SubViewport
var cam: Camera3D
var perno: Node3D
var dinamici: Node3D
var luce: OmniLight3D
var _mat := {}
var _rot := Vector2(-0.95, 0.0)     # inclinazione, rotazione
var _dist := 36.0
var _ruota := false
var _sposta := false
var _ultimo_id := -1
var _t := 0.0
var _n_giocatori := 0

# carta TTS a scala 1 (larghezza, altezza)
const CARTA := Vector2(2.1, 3.0)
const CENTRO_VISTA := Vector3(3.0, 0.0, 8.0)

# Tabelloni: centro (x, z) da TTS, misure dell'immagine in unità TTS (larghezza, altezza dell'immagine
# verticale). In TTS sono ruotati di 90 gradi: l'alto dell'immagine va verso +x, la sinistra verso il fondo.
const CAMPO := Vector3(14.52, 0.0, 2.79)
const DIM_CAMPO := Vector2(9.19, 10.99)
const NATURA := Vector3(2.72, 0.0, 3.99)
const DIM_NATURA := Vector2(6.93, 9.16)
const NOTTE := Vector3(-9.49, 0.0, 2.66)
const DIM_NOTTE := Vector2(9.03, 11.45)
# banco di lavoro (la carta «Werkbank» di TTS) e i suoi tre gruppi di segnalini
const BANCO := Vector3(0.99, 0.0, -5.92)
const DIM_BANCO := Vector2(3.02, 9.18)
## Sui tre cerchi del banco, girato per chi gioca: lancia a sinistra, amigdala al centro, torcia a destra.
const SEGNALINI_BANCO := {"lancia": Vector3(-1.58, 0.0, -6.13), "amigdala": Vector3(0.81, 0.0, -6.13), "torcia": Vector3(3.19, 0.0, -6.13)}
const CIMITERO := Vector3(-11.79, 0.0, -7.24)


## Punto su un tabellone (u, v da 0 a 1 dall'angolo in alto a sinistra dell'immagine verticale).
func _su(centro: Vector3, dim: Vector2, u: float, v: float, y := 0.03) -> Vector3:
	return centro + Vector3(-(v - 0.5) * dim.y, y, (u - 0.5) * dim.x)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.035, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.5, 0.42)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.05, 0.03)
	e.fog_density = 0.004
	env.environment = e
	sv.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-58, 28, 0)
	sole.light_energy = 0.8
	sole.light_color = Color(1.0, 0.92, 0.8)
	sole.shadow_enabled = true
	sv.add_child(sole)
	luce = OmniLight3D.new()
	luce.position = Vector3(20.0, 7.0, 1.0)
	luce.light_color = Color(1.0, 0.58, 0.25)
	luce.light_energy = 2.0
	luce.omni_range = 34.0
	sv.add_child(luce)
	perno = Node3D.new()
	sv.add_child(perno)
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 400
	perno.add_child(cam)
	perno.position = CENTRO_VISTA
	_aggiorna_camera()
	# lastra di pietra
	var lastra := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(80, 1.0, 56)
	lastra.mesh = bm
	lastra.position = Vector3(3, -0.52, 6)
	var ml := StandardMaterial3D.new()
	ml.albedo_texture = UI.tex("res://assets/ui/roccia.webp")
	ml.uv1_scale = Vector3(6, 6, 6)
	ml.roughness = 0.95
	lastra.material_override = ml
	sv.add_child(lastra)
	# tabelloni
	_tabellone(UI.tex("res://assets/plance/campo.webp"), CAMPO, DIM_CAMPO)
	_tabellone(UI.tex("res://assets/plance/natura.webp"), NATURA, DIM_NATURA)
	_tabellone(UI.tex("res://assets/plance/notte.webp"), NOTTE, DIM_NOTTE)
	# banco di lavoro: la carta «Werkbank» di TTS (scala 3,06), stessa posizione, girata verso chi gioca
	var b := _piano(UI.tex("res://assets/plance/banco_tts.webp"), BANCO + Vector3(0, 0.02, 0), DIM_BANCO, -PI / 2)
	b.name = "Banco"
	_costruisci_cimitero()
	dinamici = Node3D.new()
	sv.add_child(dinamici)
	var aiuto := UI.etichetta("Tasto sinistro: ruota  |  destro o Maiusc + sinistro: sposta  |  rotellina: avvicina  |  frecce: sposta  |  doppio clic o R: vista iniziale", 15, UI.CENERE)
	aiuto.position = Vector2(12, 8)
	aiuto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(aiuto)


func _tabellone(t: Texture2D, centro: Vector3, dim: Vector2) -> void:
	_piano(t, centro + Vector3(0, 0.01, 0), dim, -PI / 2)


## Il cimitero (dalle scansioni): il vassoio delle carte distrutte e il teschio di mammut in piedi dietro.
func _costruisci_cimitero() -> void:
	var c := CIMITERO
	_piano(UI.tex("res://assets/plance/cimitero_base.webp"), c + Vector3(0, 0.012, 0), Vector2(5.4, 5.4 * 1309.0 / 1400.0), 0.0)
	_verticale(UI.tex("res://assets/plance/cimitero_teschio.webp"), c + Vector3(0.2, 2.1, -2.35), Vector2(3.3, 3.3 * 1040.0 / 806.0))


## Un pezzo di cartone in piedi, visibile da entrambi i lati.
func _verticale(t: Texture2D, pos: Vector3, dim: Vector2, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = dim
	mi.mesh = qm
	var m := _mat_tex(t).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	sv.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if luce != null:
		luce.light_energy = 1.9 + 0.3 * sin(_t * 7.3) + 0.15 * sin(_t * 13.1)
	if not visible or not has_focus():
		return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1
	if d != Vector2.ZERO:
		_sposta_vista(d * delta * _dist * 0.8)


func _aggiorna_camera() -> void:
	_rot.x = clamp(_rot.x, -1.5, -0.3)
	_dist = clamp(_dist, 6.0, 90.0)
	perno.position.x = clamp(perno.position.x, -40.0, 45.0)
	perno.position.z = clamp(perno.position.z, -30.0, 35.0)
	perno.rotation = Vector3(0, _rot.y, 0)
	cam.position = Vector3(0, -sin(_rot.x) * _dist, cos(_rot.x) * _dist)
	cam.look_at(perno.global_position, Vector3.UP)


## Sposta il centro della vista nel piano del tavolo; d in unità, x verso destra e y verso il basso dello schermo.
func _sposta_vista(d: Vector2) -> void:
	var destra := Vector3(cos(_rot.y), 0, -sin(_rot.y))
	var giu := Vector3(sin(_rot.y), 0, cos(_rot.y))
	perno.position += destra * d.x + giu * d.y
	_aggiorna_camera()


func reimposta_vista() -> void:
	_rot = Vector2(-0.95, 0.0)
	_dist = 36.0 if _n_giocatori <= 2 else (44.0 if _n_giocatori == 3 else 52.0)
	perno.position = CENTRO_VISTA
	_aggiorna_camera()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_dist *= 0.9
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_dist *= 1.1
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				grab_focus()
				if ev.shift_pressed:
					_sposta = true
				else:
					_ruota = true
			else:
				_ruota = false
				_sposta = false
			if ev.double_click:
				reimposta_vista()
		elif ev.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_sposta = ev.pressed
			if ev.pressed:
				grab_focus()
		accept_event()
	elif ev is InputEventMouseMotion:
		if _sposta:
			var k: float = _dist / max(1.0, size.y) * 0.85
			_sposta_vista(-ev.relative * k)
			vista._nascondi_zoom()
		elif _ruota:
			_rot.y -= ev.relative.x * 0.006
			_rot.x -= ev.relative.y * 0.004
			_aggiorna_camera()
			vista._nascondi_zoom()
		else:
			_puntamento(ev.position)
	elif ev is InputEventPanGesture:
		_sposta_vista(ev.delta * _dist * 0.02)
		accept_event()
	elif ev is InputEventMagnifyGesture:
		_dist /= ev.factor
		_aggiorna_camera()
		accept_event()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_R:
		reimposta_vista()


## Quale carta c'è sotto il mouse (senza fisica: controllo dei rettangoli delle carte).
func _puntamento(pos: Vector2) -> void:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best := -1
	var best_d := 1e9
	for n in dinamici.get_children():
		if not n.has_meta("carta"):
			continue
		var piano := Plane(Vector3.UP, n.global_position)
		var hit = piano.intersects_ray(from, dir)
		if hit == null:
			continue
		var loc: Vector3 = n.global_transform.affine_inverse() * hit
		var half: Vector2 = n.get_meta("mezza")
		if abs(loc.x) <= half.x and abs(loc.z) <= half.y:
			var d: float = from.distance_to(hit)
			if d < best_d:
				best_d = d
				best = int(n.get_meta("carta"))
	if best != _ultimo_id:
		_ultimo_id = best
		if best >= 0:
			vista._mostra_zoom_a(best, get_global_rect().position + pos)
		else:
			vista._nascondi_zoom()


func _mat_tex(t: Texture2D) -> StandardMaterial3D:
	if t == null:
		return _colore(Color(0.5, 0.4, 0.3))
	if not _mat.has(t):
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		m.roughness = 0.85
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.3
		_mat[t] = m
	return _mat[t]


func _colore(c: Color) -> StandardMaterial3D:
	var k := "c" + c.to_html()
	if not _mat.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		_mat[k] = m
	return _mat[k]


func _piano(t: Texture2D, pos: Vector3, dim: Vector2, rot: float, genitore: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = dim
	mi.mesh = pm
	mi.material_override = _mat_tex(t)
	mi.position = pos
	mi.rotation.y = rot
	(genitore if genitore != null else sv).add_child(mi)
	return mi


## Una carta distesa, dritta per chi gioca (faccia o dorso); con la faccia mostra lo zoom al passaggio.
func _carta(id: int, pos: Vector3, faccia := true, scala := 1.0, rot := 0.0) -> MeshInstance3D:
	var dim := CARTA * scala
	var t: Texture2D = UI.carta_tex(id) if faccia else UI.dorso_tex(int(vista.motore.C[id]["dorso"]))
	var mi := _piano(t, pos, dim, rot, dinamici)
	if faccia:
		mi.set_meta("carta", id)
		mi.set_meta("mezza", dim / 2.0)
	return mi


## Pila di carte coperte: un parallelepipedo con il dorso in cima.
func _pila(n: int, dorso: int, pos: Vector3, scala := 1.0) -> void:
	if n <= 0:
		return
	var h: float = 0.025 * n
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CARTA.x * scala * 0.98, h, CARTA.y * scala * 0.98)
	mi.mesh = bm
	mi.position = pos + Vector3(0, h / 2.0, 0)
	mi.material_override = _colore(Color(0.92, 0.88, 0.80))
	dinamici.add_child(mi)
	_piano(UI.dorso_tex(dorso), pos + Vector3(0, h + 0.003, 0), CARTA * scala, 0.0, dinamici)


## Segnalino rotondo di cartone (come i «Custom_Token» di TTS a scala 0,29).
func _segnalino(t: Texture2D, pos: Vector3, r := 0.42) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.1
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.05, 0)
	mi.material_override = _colore(Color(0.93, 0.92, 0.88))
	dinamici.add_child(mi)
	_piano(t, pos + Vector3(0, 0.105, 0), Vector2(r * 2.0, r * 2.0), 0.0, dinamici)


## Pila di segnalini uguali con il numero accanto.
func _pila_segnalini(t: String, n: int, pos: Vector3, r := 0.42) -> void:
	for k in range(min(n, 6)):
		_segnalino(UI.attrezzo_tex(t), pos + Vector3(0, k * 0.11, 0), r)
	if n > 1:
		_scritta("%d" % n, pos + Vector3(r + 0.35, 0.05, r * 0.6), 70, UI.PERGAMENA)


func _scritta(testo: String, pos: Vector3, size := 110, col := UI.OCRA, titolo := false) -> void:
	var lab := Label3D.new()
	lab.text = testo
	lab.font = UI.font_titolo if titolo else UI.font_grassetto
	lab.font_size = size
	lab.pixel_size = 0.01
	lab.modulate = col
	lab.outline_size = 14
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.rotation = Vector3(-PI / 2, 0, 0)
	lab.position = pos
	dinamici.add_child(lab)


func _risorsa(r: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	match r:
		"cibo":
			var cm := CapsuleMesh.new()
			cm.radius = 0.17
			cm.height = 0.5
			mi.mesh = cm
			mi.rotation = Vector3(0, 0, PI / 2)
			mi.material_override = _colore(Color(0.78, 0.16, 0.12))
		"legno":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.2, 0.2)
			mi.mesh = bm
			mi.material_override = _colore(Color(0.55, 0.32, 0.16))
		"pietra":
			var sm := SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.3
			mi.mesh = sm
			mi.material_override = _colore(Color(0.55, 0.56, 0.58))
	mi.position = pos + Vector3(0, 0.15, 0)
	dinamici.add_child(mi)


func evento(_tipo: String, _dati: Dictionary) -> void:
	pass


## Centri delle aree dei giocatori, lungo il lato vicino del tavolo (come le mani di TTS a -z).
func _centri(n: int) -> Array:
	match n:
		1:
			return [3.0]
		2:
			return [-5.0, 11.0]
		3:
			return [-12.0, 3.0, 18.0]
	return [-17.0, -3.5, 10.0, 23.5]


func aggiorna(m: Motore) -> void:
	if dinamici == null:
		return
	if _n_giocatori != m.giocatori.size():
		_n_giocatori = m.giocatori.size()
		reimposta_vista()
	for c in dinamici.get_children():
		c.queue_free()
	# --- Campo: mazzi di idee, sogni e umani sui loro spazi (come i mazzi di TTS), risorse nel deposito
	_pila(m.mazzo_idee.size(), 3, _su(CAMPO, DIM_CAMPO, 0.26, 0.233, 0.02))
	_pila(m.mazzo_sogni.size(), 2, _su(CAMPO, DIM_CAMPO, 0.26, 0.48, 0.02))
	_pila(m.mazzo_umani.size(), 1, _su(CAMPO, DIM_CAMPO, 0.26, 0.73, 0.02))
	var i := 0
	for r in ["pietra", "legno", "cibo"]:
		for k in min(int(m.risorse[r]), 20):
			_risorsa(r, _su(CAMPO, DIM_CAMPO, 0.64 + (k % 5) * 0.065, 0.80 + i * 0.055 + (k / 5) * 0.012, 0.02))
		i += 1
	if not m.guerriere.is_empty():
		_carta(m.guerriere[0], CAMPO + Vector3(7.2, 0.03, 0.5))
		_scritta("Guerriere: %d" % m.guerriere.size(), CAMPO + Vector3(7.2, 0.05, -1.9), 60, UI.PERGAMENA)
	# --- banco di lavoro: segnalini delle tre idee base sui loro cerchi
	for t in SEGNALINI_BANCO:
		_pila_segnalini(t, int(m.banco_attrezzi.get(t, 0)), SEGNALINI_BANCO[t] + Vector3(0, 0.03, 0))
	# idee nuove «infilate» nel banco: in fila dietro, con i loro segnalini davanti
	for k in m.banco.size():
		var x := -5.0 + k * 2.4
		_carta(m.banco[k], Vector3(x, 0.03, -10.2))
		var o: Dictionary = m.C[m.banco[k]]["opzioni"][0]
		for t in o["attrezzi"]:
			_pila_segnalini(t, int(m.banco_attrezzi.get(t, 0)), Vector3(x - 0.3, 0.03, -8.05), 0.36)
	# --- Natura: scarti coperti a sinistra, scoperti a destra
	if not m.scarti_coperti.is_empty():
		_pila(m.scarti_coperti.size(), int(m.C[m.scarti_coperti[-1]]["dorso"]), _su(NATURA, DIM_NATURA, 0.44, 0.62, 0.02))
	if not m.scarti_scoperti.is_empty():
		_carta(m.scarti_scoperti[-1], _su(NATURA, DIM_NATURA, 0.44, 0.37, 0.03 + 0.004 * m.scarti_scoperti.size()))
	if not m.fiume.is_empty():
		_pila(m.fiume.size(), int(m.C[m.fiume[0]]["dorso"]), _su(NATURA, DIM_NATURA, 0.82, 0.87, 0.02))
	# carte in attesa: nelle quattro tacche del bordo della Natura
	var tacche := [0.25, 0.45, 0.65, 0.85]
	for k in m.attesa.size():
		var v: float = tacche[k % 4]
		var p := _su(NATURA, DIM_NATURA, 1.0, v, 0.04 + 0.02 * (k / 4))
		_carta(m.attesa[k], p + Vector3(0, 0, 1.05 + 0.7 * (k / 4)))
	# --- cimitero: l'ultima carta distrutta nel vassoio
	if not m.cimitero.is_empty():
		_carta(m.cimitero[-1], CIMITERO + Vector3(0.3, 0.06 + 0.002 * m.cimitero.size(), 0.25), true, 0.95, 0.08)
		_scritta("Cimitero: %d" % m.cimitero.size(), CIMITERO + Vector3(0, 0.05, 3.2), 80, UI.PERGAMENA, true)
	# --- Notte: pittura sulla sagoma del mammut, teschi nelle nicchie, missioni sulla luna, segreti sulla pergamena
	for k in m.vittorie:
		_piano(UI.tex("res://assets/segnalini/pittura%d.webp" % (k + 1)), NOTTE + Vector3(-0.09 + 0.96 * k, 0.04, -2.57), Vector2(0.95, 2.45), 0.0, dinamici)
	var nicchie := [0.11, 0.21, 0.32, 0.42, 0.53]
	for k in m.teschi:
		_segnalino(UI.attrezzo_tex("teschio"), _su(NOTTE, DIM_NOTTE, 0.508, nicchie[k], 0.03), 0.48)
	for k in m.missioni.size():
		_carta(m.missioni[k], _su(NOTTE, DIM_NOTTE, 0.735, 0.30 + 0.20 * (k % 2), 0.04 + 0.02 * (k / 2)) + Vector3(0, 0, 0.5 * (k / 2)))
	if not m.segreti.is_empty():
		_pila(m.segreti.size(), 39 + int(m.segreti[0]), _su(NOTTE, DIM_NOTTE, 0.505, 0.835, 0.02))
	if m.moduli.has("J"):
		_scritta("La belva è %s" % ("FURIOSA" if m.belva_furiosa else "calma"), NOTTE + Vector3(0, 0.05, 6.4), 70, UI.RUGGINE if m.belva_furiosa else UI.PERGAMENA, true)
	# --- i gruppi dei giocatori, lungo il lato vicino
	var centri := _centri(m.giocatori.size())
	for p in m.giocatori.size():
		var g: Dictionary = m.giocatori[p]
		var L: float = centri[p] - 6.3
		var z0 := 14.0
		_scritta(g["nome"] + ("  (dorme)" if g["dorme"] else ""), Vector3(centri[p], 0.05, z0 - 2.6), 130, UI.OCRA, true)
		# mazzo coperto e, sotto, le prime tre carte aperte a ventaglio (si sceglie dal dorso)
		if not g["mazzo"].is_empty():
			_pila(g["mazzo"].size(), int(m.C[g["mazzo"][0]]["dorso"]), Vector3(L + 1.2, 0.0, z0))
			var quante: int = min(3, g["mazzo"].size())
			for k in range(quante - 1, -1, -1):
				_carta(g["mazzo"][k], Vector3(L + 0.9 + 1.25 * k, 0.03 + 0.01 * (3 - k), z0 + 3.4), false, 0.85)
		# carta scoperta
		if g["rivelata"] >= 0:
			_carta(g["rivelata"], Vector3(L + 4.4, 0.04, z0 + 0.6), true, 1.2)
		# gruppo: tre carte per fila
		var k2 := 0
		for id in g["gruppo"]:
			var gx: float = L + 7.2 + (k2 % 3) * 2.3
			var gz: float = z0 + (k2 / 3) * 3.3
			_carta(id, Vector3(gx, 0.03, gz))
			for d in int(g["danni"].get(id, 0)):
				_segnalino(UI.attrezzo_tex("danno"), Vector3(gx - 0.55, 0.04 + d * 0.11, gz - 0.4), 0.26)
			k2 += 1
		# attrezzi in fila sotto
		var k3 := 0
		var righe_gruppo := int(ceil(g["gruppo"].size() / 3.0))
		var zt: float = z0 + max(1, righe_gruppo) * 3.3 + 0.2
		for t in g["attrezzi"]:
			_pila_segnalini(t, int(g["attrezzi"][t]), Vector3(L + 4.0 + (k3 % 6) * 1.6, 0.0, max(zt, z0 + 3.3 + 1.6) + (k3 / 6) * 1.2), 0.42)
			k3 += 1
