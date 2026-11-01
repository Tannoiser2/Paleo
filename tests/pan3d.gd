extends SceneTree
## Il tavolo 3D si sposta trascinando con il destro, con Maiusc+sinistro, con il gesto a due dita e con le frecce.
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	main.start_game({"giocatori": [{"nome": "A", "ia": false}, {"nome": "B", "ia": true}], "moduli": ["A", "B"], "vista3d": true, "ritardo_ia": 0.0, "seme": 1})
	await create_timer(2.0).timeout
	var t = main.current.tavolo3d
	var p0: Vector3 = t.perno.position
	var b := InputEventMouseButton.new(); b.button_index = MOUSE_BUTTON_RIGHT; b.pressed = true; b.position = Vector2(400, 300)
	t._gui_input(b)
	var mm := InputEventMouseMotion.new(); mm.relative = Vector2(120, 40); mm.position = Vector2(520, 340)
	t._gui_input(mm)
	b.pressed = false; t._gui_input(b)
	var p1: Vector3 = t.perno.position
	var pg := InputEventPanGesture.new(); pg.delta = Vector2(3, 0)
	t._gui_input(pg)
	var p2: Vector3 = t.perno.position
	print("PAN destro: ", p0, " -> ", p1, "  gesto: ", p2, "  ", "OK" if p1.distance_to(p0) > 1.0 and p2.distance_to(p1) > 1.0 else "NO")
	quit()
