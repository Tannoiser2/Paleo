extends SceneTree
## Viste del tavolo 3D: intero, tabelloni, banco di lavoro, gruppi.
func _init() -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	var ng := int(OS.get_environment("NG")) if OS.get_environment("NG") != "" else 2
	var gg := [{"nome": "Stefano", "ia": false}]
	for i in ng - 1:
		gg.append({"nome": ["Ayla", "Oog", "Brun"][i], "ia": true})
	main.start_game({"giocatori": gg, "moduli": ["D", "E"], "vista3d": true, "ritardo_ia": 0.0, "seme": 11, "varianti": {"provviste": true}})
	await create_timer(3.0).timeout
	var t = main.current.tavolo3d
	var viste := [["intero", Vector3(3, 0, 8), 36.0 if ng <= 2 else 44.0, Vector2(-0.95, 0.0)], ["tabelloni", Vector3(3, 0, 2), 26.0, Vector2(-1.25, 0.0)], ["banco", Vector3(0, 0, -7), 14.0, Vector2(-0.8, 0.0)], ["gruppi", Vector3(3, 0, 17), 30.0, Vector2(-1.1, 0.0)]]
	for v in viste:
		t._dist = v[2]
		t._rot = v[3]
		t.perno.position = v[1]
		t._aggiorna_camera()
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("/tmp/3d_%s.png" % v[0])
	quit()
