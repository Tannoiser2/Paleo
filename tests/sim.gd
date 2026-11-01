extends SceneTree
## Partite automatiche con sole IA: controlla che il motore arrivi sempre in fondo senza errori.
## Uso: godot --headless --path . -s tests/sim.gd -- [partite] [livello]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 10
	var solo_livello := int(args[1]) if args.size() > 1 else -1
	var stat := {}
	for k in n:
		var liv: int = solo_livello if solo_livello >= 0 else k % Dati.LIVELLI.size()
		var ng: int = 1 + (k % 4)
		var m := Motore.new()
		get_root().add_child(m)
		var gg := []
		for i in ng:
			gg.append({"nome": "IA %d" % (i + 1), "ia": true})
		var ia := IA.new()
		for i in ng:
			m.controllori.append(ia)
		await m.prepara({"giocatori": gg, "moduli": Dati.LIVELLI[liv]["moduli"], "seme": 1000 + k})
		var t0 := Time.get_ticks_msec()
		var guardia := [0]
		m.messaggio.connect(func(_t): guardia[0] += 1; if OS.get_environment("LOGSIM") != "": print("  ", _t))
		await m.gioca()
		var chiave := "%s %dg" % [Dati.LIVELLI[liv]["nome"], ng]
		stat[chiave] = stat.get(chiave, []) + ["%s g%d V%d T%d" % [m.esito, m.giorno, m.vittorie, m.teschi]]
		print("partita %d: %s, %d giocatori -> %s dopo %d giorni (pittura %d, teschi %d, %d msg, %d ms)" % [k, Dati.LIVELLI[liv]["nome"], ng, m.esito, m.giorno, m.vittorie, m.teschi, guardia[0], Time.get_ticks_msec() - t0])
		m.queue_free()
	var vinte := 0
	for c in stat:
		for e in stat[c]:
			if String(e).begins_with("vittoria"):
				vinte += 1
	print("FINE: %d partite, %d vinte" % [n, vinte])
	quit()
