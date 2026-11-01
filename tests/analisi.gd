extends SceneTree
func _init() -> void:
	var cause := {}
	var vinte := 0
	var n := 30
	for k in n:
		var liv := k % 2 * 0
		var ng := 2 + k % 3
		var m := Motore.new()
		get_root().add_child(m)
		var gg := []
		for i in ng:
			gg.append({"nome": "IA%d" % i, "ia": true})
			m.controllori.append(IA.new())
		var ultimo := [""]
		m.messaggio.connect(func(t):
			if t.begins_with("Teschi:"):
				var c: String = ultimo[0]
				if c.contains("muore"): c = "morte"
				elif c.contains("affamati"): c = "fame notturna"
				elif c.begins_with("«"): c = "missione " + c.split("»")[0]
				else: c = "altro: " + c.substr(0, 40)
				cause[c] = cause.get(c, 0) + 1
			else:
				ultimo[0] = t)
		await m.prepara({"giocatori": gg, "moduli": Dati.LIVELLI[liv]["moduli"], "seme": 500 + k})
		await m.gioca()
		if m.esito == "vittoria": vinte += 1
		m.queue_free()
	print(cause)
	print("vinte ", vinte, "/", n)
	quit()
