extends SubViewportContainer
## Il tavolo in 3D: i tabelloni Campo, Natura e Notte su una lastra di pietra, alla luce del fuoco,
## con le carte, le risorse di legno e i segnalini. Si ruota trascinando, si avvicina con la rotellina.

var vista
var sv: SubViewport
var cam: Camera3D
var perno: Node3D
var dinamici: Node3D
var fuoco: OmniLight3D
var _mat := {}
var _rot := Vector2(-0.95, 0.0)     # inclinazione, rotazione
var _dist := 18.0
var _trascina := false
var _ultimo_id := -1
var _due_file := false
var _t := 0.0

const CARTA := Vector2(1.04, 1.6)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.physics_object_picking = false
	add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.035, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.45, 0.38)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.05, 0.03)
	e.fog_density = 0.012
	env.environment = e
	sv.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-58, 28, 0)
	sole.light_energy = 0.75
	sole.light_color = Color(1.0, 0.9, 0.78)
	sole.shadow_enabled = true
	sv.add_child(sole)
	fuoco = OmniLight3D.new()
	fuoco.position = Vector3(-9.5, 3.0, -2.0)
	fuoco.light_color = Color(1.0, 0.55, 0.22)
	fuoco.light_energy = 2.2
	fuoco.omni_range = 16.0
	sv.add_child(fuoco)
	perno = Node3D.new()
	sv.add_child(perno)
	cam = Camera3D.new()
	cam.fov = 45
	perno.add_child(cam)
	_aggiorna_camera()
	# lastra di pietra
	var lastra := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(34, 0.6, 28)
	lastra.mesh = bm
	lastra.position = Vector3(-1, -0.31, 3.5)
	var ml := StandardMaterial3D.new()
	ml.albedo_texture = UI.tex("res://assets/ui/roccia.webp")
	ml.uv1_scale = Vector3(3, 3, 3)
	ml.roughness = 0.95
	lastra.material_override = ml
	sv.add_child(lastra)
	# focolare (pietre + brace) accanto al campo
	_focolare(Vector3(-9.5, 0, -2.0))
	# tabelloni fissi
	_piano(UI.tex("res://assets/plance/campo.webp"), Vector3(-5.6, 0.01, -3.2), Vector2(4.24, 5.12), 0.0)
	_piano(UI.tex("res://assets/plance/natura.webp"), Vector3(-1.2, 0.01, -3.2), Vector2(3.84, 5.12), 0.0)
	_piano(UI.tex("res://assets/plance/notte.webp"), Vector3(3.2, 0.01, -3.2), Vector2(4.24, 5.2), 0.0)
	_piano(UI.tex("res://assets/plance/banco.webp"), Vector3(-8.6, 0.02, -3.0), Vector2(1.3, 4.0), 0.0)
	dinamici = Node3D.new()
	sv.add_child(dinamici)


func _focolare(p: Vector3) -> void:
	for k in 8:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.3
		s.mesh = sm
		var a := TAU * k / 8.0
		s.position = p + Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6)
		s.material_override = _colore(Color(0.42, 0.40, 0.38))
		sv.add_child(s)
	var brace := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.5
	cm.height = 0.12
	brace.mesh = cm
	brace.position = p + Vector3(0, 0.06, 0)
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(1.0, 0.45, 0.12)
	mb.emission_enabled = true
	mb.emission = Color(1.0, 0.4, 0.1)
	mb.emission_energy_multiplier = 2.0
	brace.material_override = mb
	sv.add_child(brace)


func _process(delta: float) -> void:
	_t += delta
	if fuoco != null:
		fuoco.light_energy = 2.0 + 0.35 * sin(_t * 7.3) + 0.2 * sin(_t * 13.1)


func _aggiorna_camera() -> void:
	_rot.x = clamp(_rot.x, -1.45, -0.35)
	_dist = clamp(_dist, 7.0, 30.0)
	perno.position = Vector3(-1.0, 0, 1.2 + (2.2 if _due_file else 0.0))
	perno.rotation = Vector3(0, _rot.y, 0)
	cam.position = Vector3(0, -sin(_rot.x) * _dist, cos(_rot.x) * _dist)
	cam.look_at(perno.global_position, Vector3.UP)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_dist *= 0.9
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_dist *= 1.1
			_aggiorna_camera()
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_trascina = ev.pressed
	elif ev is InputEventMouseMotion:
		if _trascina:
			_rot.y -= ev.relative.x * 0.006
			_rot.x -= ev.relative.y * 0.004
			_aggiorna_camera()
			vista._nascondi_zoom()
		else:
			_puntamento(ev.position)
	elif ev is InputEventPanGesture:
		_dist *= 1.0 + ev.delta.y * 0.05
		_aggiorna_camera()
	elif ev is InputEventMagnifyGesture:
		_dist /= ev.factor
		_aggiorna_camera()


## Quale carta c'è sotto il mouse (senza fisica: controllo dei rettangoli delle carte).
func _puntamento(pos: Vector2) -> void:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best := -1
	var best_d := 1e9
	for n in dinamici.get_children():
		if not n.has_meta("carta"):
			continue
		var piano := Plane(Vector3.UP, n.global_position.y + 0.01)
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


## Una carta distesa (faccia o dorso) alta y; restituisce il nodo, cliccabile per lo zoom se faccia.
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
	var h: float = 0.018 * n
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CARTA.x * scala, h, CARTA.y * scala)
	mi.mesh = bm
	mi.position = pos + Vector3(0, h / 2.0, 0)
	mi.material_override = _colore(Color(0.92, 0.88, 0.80))
	dinamici.add_child(mi)
	_piano(UI.dorso_tex(dorso), pos + Vector3(0, h + 0.002, 0), CARTA * scala, 0.0, dinamici)


func _segnalino(t: Texture2D, pos: Vector3, r := 0.28) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.08
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.04, 0)
	mi.material_override = _colore(Color(0.93, 0.92, 0.88))
	dinamici.add_child(mi)
	_piano(t, pos + Vector3(0, 0.085, 0), Vector2(r * 2.0, r * 2.0), 0.0, dinamici)


func _risorsa(r: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	match r:
		"cibo":
			var cm := CapsuleMesh.new()
			cm.radius = 0.11
			cm.height = 0.42
			mi.mesh = cm
			mi.rotation = Vector3(0, 0, PI / 2)
			mi.material_override = _colore(Color(0.78, 0.16, 0.12))
		"legno":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.46, 0.14, 0.16)
			mi.mesh = bm
			mi.material_override = _colore(Color(0.55, 0.32, 0.16))
		"pietra":
			var sm := SphereMesh.new()
			sm.radius = 0.15
			sm.height = 0.2
			mi.mesh = sm
			mi.material_override = _colore(Color(0.55, 0.56, 0.58))
	mi.position = pos + Vector3(0, 0.1, 0)
	dinamici.add_child(mi)


func evento(_tipo: String, _dati: Dictionary) -> void:
	pass


func aggiorna(m: Motore) -> void:
	if dinamici == null:
		return
	if _due_file != (m.giocatori.size() > 2):
		_due_file = m.giocatori.size() > 2
		_dist = 20.5 if _due_file else 18.0
		_aggiorna_camera()
	for c in dinamici.get_children():
		c.queue_free()
	# --- Campo: risorse in alto a sinistra, mazzi a destra
	var base := Vector3(-5.6, 0.02, -3.2)
	var i := 0
	for r in ["cibo", "legno", "pietra"]:
		for k in min(int(m.risorse[r]), 20):
			_risorsa(r, base + Vector3(-1.75 + (k % 5) * 0.32, 0, -2.2 + i * 0.75 + (k / 5) * 0.16))
		i += 1
	_pila(m.mazzo_umani.size(), 1, base + Vector3(0.95, 0, -1.4), 0.95)
	_pila(m.mazzo_sogni.size(), 2, base + Vector3(0.95, 0, 0.1), 0.95)
	_pila(m.mazzo_idee.size(), 3, base + Vector3(0.95, 0, 1.6), 0.95)
	# --- banco di lavoro: attrezzi davanti alle idee
	var b := Vector3(-8.6, 0.03, -3.0)
	var ti := 0
	for t in ["torcia", "amigdala", "lancia"]:
		for k in min(int(m.banco_attrezzi.get(t, 0)), 5):
			_segnalino(UI.attrezzo_tex(t), b + Vector3(-0.95, 0.0 + k * 0.09, -1.3 + ti * 1.35), 0.24)
		ti += 1
	for k in m.banco.size():
		_carta(m.banco[k], Vector3(-11.0 + (k % 2) * 1.15, 0.03, -5.0 + (k / 2) * 1.75), true, 0.95)
	# --- Natura: scarti coperti (in alto) e scoperti (in basso)
	var n := Vector3(-1.2, 0.02, -3.2)
	if not m.scarti_coperti.is_empty():
		_pila(m.scarti_coperti.size(), int(m.C[m.scarti_coperti[-1]]["dorso"]), n + Vector3(0.35, 0, -0.95))
	if not m.scarti_scoperti.is_empty():
		_carta(m.scarti_scoperti[-1], n + Vector3(0.35, 0.02 + 0.004 * m.scarti_scoperti.size(), 1.0))
	# attesa: lungo il lato sinistro della Natura
	for k in m.attesa.size():
		_carta(m.attesa[k], Vector3(-2.6 + k * 1.15, 0.03, -6.75), true, 0.95)
	if not m.fiume.is_empty():
		_pila(m.fiume.size(), int(m.C[m.fiume[0]]["dorso"]), Vector3(-3.0, 0.02, -0.15), 0.9)
	# cimitero
	if not m.cimitero.is_empty():
		_carta(m.cimitero[-1], Vector3(6.4, 0.02, -0.9), true, 0.9, 0.12)
	# --- Notte: missioni, segreti, teschi, pittura
	var nt := Vector3(3.2, 0.02, -3.2)
	for k in m.missioni.size():
		_carta(m.missioni[k], nt + Vector3(-1.55 + k * 0.45, 0.02 + k * 0.01, -0.2 + k * 0.45), true, 0.8)
	if not m.segreti.is_empty():
		_pila(m.segreti.size(), 39 + int(m.segreti[0]), nt + Vector3(0.6, 0, -1.95), 0.85)
	for k in m.teschi:
		_segnalino(UI.attrezzo_tex("teschio"), nt + Vector3(0.3, 0, -0.45 + k * 0.55), 0.24)
	for k in m.vittorie:
		var pz := _piano(UI.tex("res://assets/segnalini/pittura%d.webp" % (k + 1)), nt + Vector3(1.0 + k * 0.17, 0.03, 0.75), Vector2(0.18, 0.55), 0.0, dinamici)
		pz.position.y += 0.01
	# --- i gruppi dei giocatori: due per fila davanti ai tabelloni
	var ng := m.giocatori.size()
	for p in ng:
		var g: Dictionary = m.giocatori[p]
		var fila := p / 2
		var nella_fila: int = min(2, ng - fila * 2)
		var col := p % 2
		var cx: float = -1.0 + (col - (nella_fila - 1) / 2.0) * 9.8
		var L := cx - 4.75
		var z0 := 2.9 + fila * 5.0
		# mazzo coperto e, accanto, le prime tre carte (si scelgono dal dorso)
		if not g["mazzo"].is_empty():
			_pila(g["mazzo"].size(), int(m.C[g["mazzo"][0]]["dorso"]), Vector3(L + 0.7, 0.0, z0))
			for k in range(min(3, g["mazzo"].size()) - 1, -1, -1):
				_carta(g["mazzo"][k], Vector3(L + 0.9 + 0.38 * k, 0.05 + 0.018 * g["mazzo"].size() + 0.012 * (3 - k), z0 + 1.15 + 0.08 * k), false, 0.75, -0.1 * k)
		# carta scoperta
		if g["rivelata"] >= 0:
			_carta(g["rivelata"], Vector3(L + 3.0, 0.04, z0 + 0.4), true, 1.25)
		# gruppo
		var k2 := 0
		for id in g["gruppo"]:
			var gx: float = L + 4.6 + (k2 % 5) * 1.0
			var gz: float = z0 - 0.2 + (k2 / 5) * 1.5
			_carta(id, Vector3(gx, 0.02, gz), true, 0.88)
			for d in int(g["danni"].get(id, 0)):
				_segnalino(UI.attrezzo_tex("danno"), Vector3(gx + 0.22, 0.03 + d * 0.09, gz + 0.48), 0.14)
			k2 += 1
		# attrezzi
		var k3 := 0
		for t in g["attrezzi"]:
			for q in int(g["attrezzi"][t]):
				_segnalino(UI.attrezzo_tex(t), Vector3(L + 4.4 + (k3 % 10) * 0.52, 0.0, z0 + 1.55 + (k3 / 10) * 0.52), 0.22)
				k3 += 1
		# nome del gruppo
		var lab := Label3D.new()
		lab.text = g["nome"] + ("  (dorme)" if g["dorme"] else "")
		lab.font = UI.font_titolo
		lab.font_size = 110
		lab.pixel_size = 0.006
		lab.modulate = UI.OCRA
		lab.outline_size = 14
		lab.outline_modulate = Color(0, 0, 0, 0.85)
		lab.rotation = Vector3(-PI / 2, 0, 0)
		lab.position = Vector3(L + 2.2, 0.03, z0 - 1.25)
		dinamici.add_child(lab)
