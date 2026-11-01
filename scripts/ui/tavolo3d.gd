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
# tabelloni (centro e misure; le immagini sono le scansioni nel verso giusto)
const CAMPO := Vector3(-6.2, 0.01, -3.2)
const DIM_CAMPO := Vector2(4.28, 5.12)
const NATURA := Vector3(-1.6, 0.01, -3.2)
const DIM_NATURA := Vector2(3.88, 5.12)
const NOTTE := Vector3(3.0, 0.01, -3.2)
const DIM_NOTTE := Vector2(4.04, 5.12)
# banco di lavoro (struttura di cartone montata) e cimitero
const BANCO := Vector3(-6.2, 0.0, -7.9)
const BANCO_L := 3.9
const CIMITERO := Vector3(7.4, 0.0, -2.6)


## Punto su un tabellone: u, v da 0 a 1 partendo dall'angolo in alto a sinistra dell'immagine.
func _su(centro: Vector3, dim: Vector2, u: float, v: float, y := 0.02) -> Vector3:
	return centro + Vector3((u - 0.5) * dim.x, y, (v - 0.5) * dim.y)


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
	_piano(UI.tex("res://assets/plance/campo.webp"), CAMPO, DIM_CAMPO, 0.0)
	_piano(UI.tex("res://assets/plance/natura.webp"), NATURA, DIM_NATURA, 0.0)
	_piano(UI.tex("res://assets/plance/notte.webp"), NOTTE, DIM_NOTTE, 0.0)
	_costruisci_banco()
	_costruisci_cimitero()
	dinamici = Node3D.new()
	sv.add_child(dinamici)


## Un pezzo di cartone in piedi (rivolto verso +z, ruotato di rot_y), visibile da entrambi i lati.
func _verticale(t: Texture2D, pos: Vector3, dim: Vector2, rot_y := 0.0, genitore: Node = null, incl := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = dim
	mi.mesh = qm
	var k := "v" + str(t.get_instance_id()) if t != null else "v0"
	if not _mat.has(k):
		var m := _mat_tex(t).duplicate()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat[k] = m
	mi.material_override = _mat[k]
	mi.position = pos
	mi.rotation = Vector3(-incl, rot_y, 0)
	(genitore if genitore != null else sv).add_child(mi)
	return mi


## Il banco di lavoro montato: due fianchi a triangolo, due scaffali con le finestre per le idee
## (dietro, più alto, e davanti) e il frontale con i fori per torce, amigdale e lance.
func _costruisci_banco() -> void:
	var b := BANCO
	var L := BANCO_L
	var lato_h := 2.5
	var lato_w := lato_h * 733.0 / 1400.0
	_verticale(UI.tex("res://assets/plance/banco_lato1.webp"), b + Vector3(-L / 2.0, lato_h / 2.0, -0.2), Vector2(lato_w, lato_h), PI / 2)
	_verticale(UI.tex("res://assets/plance/banco_lato2.webp"), b + Vector3(L / 2.0, lato_h / 2.0, -0.2), Vector2(lato_w, lato_h), -PI / 2)
	_verticale(UI.tex("res://assets/plance/banco_scaffale2.webp"), b + Vector3(0, 1.0 + 0.6, -0.75), Vector2(L, L * 422.0 / 1400.0))
	_verticale(UI.tex("res://assets/plance/banco_scaffale1.webp"), b + Vector3(0, 0.73, -0.05), Vector2(L, L * 523.0 / 1400.0))
	_verticale(UI.tex("res://assets/plance/banco_fronte.webp"), b + Vector3(0, 0.62, 0.75), Vector2(L, L * 459.0 / 1400.0), 0.0, null, 0.18)


## Il cimitero: il vassoio in cui finiscono le carte distrutte e il teschio di mammut in piedi dietro.
func _costruisci_cimitero() -> void:
	var c := CIMITERO
	_piano(UI.tex("res://assets/plance/cimitero_base.webp"), c + Vector3(0, 0.012, 0), Vector2(2.6, 2.6 * 1309.0 / 1400.0), 0.0)
	_verticale(UI.tex("res://assets/plance/cimitero_teschio.webp"), c + Vector3(0.1, 1.05, -1.15), Vector2(1.62, 1.62 * 1040.0 / 806.0))


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
		var vert: bool = n.get_meta("verticale", false)
		var normale: Vector3 = (n.global_transform.basis.z if vert else n.global_transform.basis.y).normalized()
		var piano := Plane(normale, n.global_position)
		var hit = piano.intersects_ray(from, dir)
		if hit == null:
			continue
		var loc: Vector3 = n.global_transform.affine_inverse() * hit
		var half: Vector2 = n.get_meta("mezza", CARTA * 0.475)
		var lv: float = loc.y if vert else loc.z
		if abs(loc.x) <= half.x and abs(lv) <= half.y:
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
			cm.radius = 0.09
			cm.height = 0.24
			mi.mesh = cm
			mi.rotation = Vector3(0, 0, PI / 2)
			mi.material_override = _colore(Color(0.78, 0.16, 0.12))
		"legno":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.24, 0.1, 0.1)
			mi.mesh = bm
			mi.material_override = _colore(Color(0.55, 0.32, 0.16))
		"pietra":
			var sm := SphereMesh.new()
			sm.radius = 0.1
			sm.height = 0.14
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
	# --- Campo: mazzi sugli spazi di idee, sogni e umani; risorse nell'angolo in basso a destra
	var i := 0
	for r in ["cibo", "legno", "pietra"]:
		for k in min(int(m.risorse[r]), 20):
			_risorsa(r, _su(CAMPO, DIM_CAMPO, 0.70 + (k % 5) * 0.06, 0.66 + i * 0.1 + (k / 5) * 0.025, 0.02))
		i += 1
	_pila(m.mazzo_idee.size(), 3, _su(CAMPO, DIM_CAMPO, 0.25, 0.24, 0.02), 0.95)
	_pila(m.mazzo_sogni.size(), 2, _su(CAMPO, DIM_CAMPO, 0.25, 0.48, 0.02), 0.95)
	_pila(m.mazzo_umani.size(), 1, _su(CAMPO, DIM_CAMPO, 0.25, 0.72, 0.02), 0.95)
	# --- banco di lavoro: idee infilate nelle finestre degli scaffali, attrezzi davanti
	var fin := [-0.27, 0.0, 0.27]
	for k in m.banco.size():
		var fila := 0 if k < 3 else 1
		var x: float = fin[k % 3] * BANCO_L
		var z := -0.12 if fila == 0 else -0.82
		var y := 0.95 if fila == 0 else 1.85
		var carta := _verticale(UI.carta_tex(m.banco[k]), BANCO + Vector3(x, y, z), CARTA * 0.95, 0.0, dinamici)
		carta.set_meta("carta", m.banco[k])
		carta.set_meta("verticale", true)
		var o: Dictionary = m.C[m.banco[k]]["opzioni"][0]
		var q := 0
		for t in o["attrezzi"]:
			for n in min(int(m.banco_attrezzi.get(t, 0)), 5):
				_segnalino(UI.attrezzo_tex(t), BANCO + Vector3(x - 0.3 + q * 0.2, 0.0 + n * 0.09, 0.25 if fila == 0 else 0.42), 0.17)
			q += 1
	# attrezzi delle idee base, nei fori del frontale (lancia, amigdala, torcia)
	var fori := {"lancia": -0.26, "amigdala": 0.0, "torcia": 0.27}
	for t in fori:
		var n: int = int(m.banco_attrezzi.get(t, 0))
		if n > 0:
			var disco := _verticale(UI.attrezzo_tex(t), BANCO + Vector3(float(fori[t]) * BANCO_L, 0.6, 0.79), Vector2(0.5, 0.5), 0.0, dinamici, 0.18)
			disco.position.y += 0.0
			var lab := Label3D.new()
			lab.text = "×%d" % n
			lab.font = UI.font_grassetto
			lab.font_size = 64
			lab.pixel_size = 0.005
			lab.modulate = UI.PERGAMENA
			lab.outline_size = 10
			lab.outline_modulate = Color(0, 0, 0, 0.9)
			lab.position = BANCO + Vector3(float(fori[t]) * BANCO_L + 0.38, 0.35, 0.86)
			dinamici.add_child(lab)
	# --- Natura: scarti coperti (spazio in alto) e scoperti (spazio in basso)
	if not m.scarti_coperti.is_empty():
		_pila(m.scarti_coperti.size(), int(m.C[m.scarti_coperti[-1]]["dorso"]), _su(NATURA, DIM_NATURA, 0.43, 0.37, 0.02))
	if not m.scarti_scoperti.is_empty():
		_carta(m.scarti_scoperti[-1], _su(NATURA, DIM_NATURA, 0.43, 0.62, 0.02 + 0.004 * m.scarti_scoperti.size()))
	if not m.fiume.is_empty():
		_pila(m.fiume.size(), int(m.C[m.fiume[0]]["dorso"]), _su(NATURA, DIM_NATURA, 0.84, 0.86, 0.02), 0.8)
	# carte in attesa: in fila dietro la Natura e la Notte
	for k in m.attesa.size():
		_carta(m.attesa[k], Vector3(-3.1 + k * 1.15, 0.03, -6.75), true, 0.95)
	# --- cimitero: l'ultima carta distrutta nel vassoio
	if not m.cimitero.is_empty():
		_carta(m.cimitero[-1], CIMITERO + Vector3(0.25, 0.05 + 0.002 * m.cimitero.size(), 0.15), true, 0.85, 0.1)
		var lc := Label3D.new()
		lc.text = "Cimitero: %d" % m.cimitero.size()
		lc.font = UI.font_titolo
		lc.font_size = 80
		lc.pixel_size = 0.006
		lc.modulate = UI.PERGAMENA
		lc.outline_size = 12
		lc.outline_modulate = Color(0, 0, 0, 0.85)
		lc.rotation = Vector3(-PI / 2, 0, 0)
		lc.position = CIMITERO + Vector3(0, 0.05, 1.55)
		dinamici.add_child(lc)
	# --- Notte: pittura nella grotta, teschi nelle nicchie, missioni sulla luna, segreti sulla pergamena
	for k in m.vittorie:
		_piano(UI.tex("res://assets/segnalini/pittura%d.webp" % (k + 1)), _su(NOTTE, DIM_NOTTE, 0.14 + k * 0.055, 0.32, 0.03), Vector2(0.22, 0.66), 0.0, dinamici)
	for k in m.teschi:
		_segnalino(UI.attrezzo_tex("teschio"), _su(NOTTE, DIM_NOTTE, 0.52, 0.11 + k * 0.11, 0.02), 0.24)
	for k in m.missioni.size():
		_carta(m.missioni[k], _su(NOTTE, DIM_NOTTE, 0.74 + k * 0.08, 0.40 + k * 0.08, 0.03 + k * 0.01), true, 0.8)
	if not m.segreti.is_empty():
		_pila(m.segreti.size(), 39 + int(m.segreti[0]), _su(NOTTE, DIM_NOTTE, 0.47, 0.84, 0.02), 0.85)
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
