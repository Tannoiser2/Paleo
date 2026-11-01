extends SceneTree
## Una partita salvata (seme + scelte) si ricostruisce identica.
func _impronta(m: Motore) -> String:
	return "%s g%d T%d V%d %s cim%d" % [m.esito, m.giorno, m.teschi, m.vittorie, str(m.risorse), m.cimitero.size()]

func _init() -> void:
	var ok := 0
	for k in 6:
		var cfg := {"giocatori": [{"nome": "A", "ia": true}, {"nome": "B", "ia": true}, {"nome": "C", "ia": true}], "moduli": Dati.LIVELLI[k]["moduli"], "seme": 900 + k, "varianti": {"grande_tribu": k % 2 == 0}}
		var a := Motore.new()
		get_root().add_child(a)
		var ia := IA.new()
		a.controllori = [ia, ia, ia]
		await a.prepara(cfg)
		await a.gioca()
		var b := Motore.new()
		get_root().add_child(b)
		b.controllori = [null, null, null]
		b.da_rigiocare = a.storia.duplicate()
		await b.prepara(cfg)
		await b.gioca()
		var same := _impronta(a) == _impronta(b)
		if same:
			ok += 1
		print(k, " ", _impronta(a), " | ", _impronta(b), " ", "OK" if same else "DIVERSA")
	print("FINE ripresa %d/6" % ok)
	quit()
