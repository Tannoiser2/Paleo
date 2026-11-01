extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var liv := int(args[0]); var ng := int(args[1]); var seme := int(args[2])
	var m := Motore.new()
	get_root().add_child(m)
	var gg := []
	for i in ng:
		gg.append({"nome": "IA%d" % (i + 1), "ia": true})
	for i in ng:
		m.controllori.append(IA.new())
	m.messaggio.connect(func(t): print("  ", t))
	await m.prepara({"giocatori": gg, "moduli": Dati.LIVELLI[liv]["moduli"], "seme": seme})
	for g in m.giocatori:
		print(g["nome"], " gruppo ", g["gruppo"].map(func(x): return m.C[x]["nome"]), " attrezzi ", g["attrezzi"], " mazzo ", g["mazzo"].size())
	await m.gioca()
	print("ESITO ", m.esito, " giorno ", m.giorno, " V", m.vittorie, " T", m.teschi)
	quit()
