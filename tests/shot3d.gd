extends SceneTree
## Primi piani del tavolo 3D: banco di lavoro, cimitero, tabelloni.
func _init() -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	main.start_game({"giocatori": [{"nome": "Stefano", "ia": false}, {"nome": "Ayla", "ia": true}], "moduli": ["B", "D"], "vista3d": true, "ritardo_ia": 0.0, "seme": 11, "varianti": {"provviste": true}})
	await create_timer(3.0).timeout
	var t = main.current.tavolo3d
	var viste := [["banco", Vector3(-6.2, 0, -7.4), 7.0, Vector2(-0.45, 0.0)], ["cimitero", Vector3(7.2, 0, -2.6), 6.0, Vector2(-0.6, -0.3)], ["tabelloni", Vector3(-1.5, 0, -3.5), 11.0, Vector2(-1.1, 0.0)], ["intero", Vector3(-1.0, 0, -1.0), 21.0, Vector2(-0.95, 0.0)]]
	for v in viste:
		t._dist = v[2]
		t._rot = v[3]
		t._aggiorna_camera()
		t.perno.position = v[1]
		t.cam.look_at(t.perno.global_position, Vector3.UP)
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("/tmp/3d_%s.png" % v[0])
	quit()
