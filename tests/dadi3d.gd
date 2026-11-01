extends SceneTree
## Dadi 3D: lancio con le facce originali, schermata in volo e a terra (deve uscire la faccia giusta).
func _init() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	main.start_game({"giocatori": [{"nome": "A", "ia": false}, {"nome": "B", "ia": true}], "moduli": ["A", "B"], "vista3d": true, "ritardo_ia": 0.0, "seme": 1})
	await create_timer(2.0).timeout
	var t = main.current.tavolo3d
	t._dist = 14.0
	t._rot = Vector2(-1.0, 0.0)
	t._aggiorna_camera()
	t.evento("dadi", {"facce": [Dati.DADO[2], Dati.DADO[5]]})
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/dadi_volo.png")
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/dadi_terra.png")
	quit()
