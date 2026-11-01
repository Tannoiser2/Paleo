extends SceneTree
## Esegue ogni opzione di ogni carta (anche negative e notturne) in una partita preparata con tutto
## in abbondanza, per scovare errori nelle regole speciali.
func _init() -> void:
	var C := Dati.carte()
	var n := 0
	for id in C:
		var c: Dictionary = C[id]
		var tutte: Array = c["opzioni"] + c["notte"]
		for k in tutte.size():
			var m := Motore.new()
			get_root().add_child(m)
			var ia := IA.new()
			m.controllori = [ia, ia, ia]
			var mods := ["D", "E", "J"] if not ["A", "B", "C", "F", "G", "H", "I"].has(c["modulo"]) else [c["modulo"], "J"]
			await m.prepara({"giocatori": [{"nome": "A", "ia": true}, {"nome": "B", "ia": true}, {"nome": "C", "ia": true}], "moduli": mods, "seme": id * 10 + k})
			m.risorse = {"cibo": 15, "legno": 10, "pietra": 7}
			for p in 3:
				for t in ["pelle", "torcia", "lancia", "talismano", "tenda", "zattera", "trappola", "corda", "radice"]:
					m.giocatori[p]["attrezzi"][t] = 2
			m.giocatori[0]["rivelata"] = id
			m.giocatori[0]["risolta"] = false
			m.giocatori[1]["rivelata"] = 45
			m.giocatori[1]["risolta"] = false
			var o: Dictionary = tutte[k]
			if k >= c["opzioni"].size():
				await m._risolvi_notturna(id, [o])
			else:
				await m._esegui_opzione(0, id, o, o["aiuto_carta"])
			n += 1
			m.queue_free()
	# segreti uno per uno
	for s in range(1, 23):
		var m := Motore.new()
		get_root().add_child(m)
		var ia := IA.new()
		m.controllori = [ia, ia]
		await m.prepara({"giocatori": [{"nome": "A", "ia": true}, {"nome": "B", "ia": true}], "moduli": ["H", "J"], "seme": s})
		m.segreti.append(s)
		await m._segreto(0, [0], s)
		n += 1
		m.queue_free()
	print("FINE prove speciali: ", n)
	quit()
