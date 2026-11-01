extends SceneTree
## Screenshot della partita: avvia una partita con persone e IA, aspetta e salva l'immagine.
## Uso: godot --path . -s tests/shot.gd -- uscita.png [3d] [secondi] [livello]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/shot.png"
	var tre := args.size() > 1 and args[1] == "3d"
	var sec := float(args[2]) if args.size() > 2 else 4.0
	var liv := int(args[3]) if args.size() > 3 else 0
	root.size = Vector2i(1920, 1080)
	var main = load("res://scripts/ui/main.gd").new()
	root.add_child(main)
	await process_frame
	if out.contains("menu"):
		await create_timer(1.0).timeout
	else:
		main.start_game({"giocatori": [{"nome": "Stefano", "ia": false}, {"nome": "Ayla", "ia": true}, {"nome": "Oog", "ia": true}],
			"moduli": Dati.LIVELLI[liv]["moduli"], "vista3d": tre, "ritardo_ia": 0.05, "seme": 42})
		await create_timer(sec).timeout
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("salvato ", out)
	quit()
