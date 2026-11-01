extends SceneTree
## Schermate di controllo: regole, ingrandimento di una carta, fine partita.
func _init() -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	main.show_rules()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("/tmp/s_regole.png")
	main.start_game({"giocatori": [{"nome": "Stefano", "ia": false}, {"nome": "Ayla", "ia": true}], "moduli": ["E", "F"], "ritardo_ia": 0.0, "seme": 3})
	await create_timer(2.0).timeout
	var v = main.current
	v._mostra_zoom_a(225, Vector2(700, 300))
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/s_zoom.png")
	v._nascondi_zoom()
	v.motore.vittorie = 5
	v.motore.esito = "vittoria"
	v._alla_fine("vittoria")
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/s_fine.png")
	quit()
