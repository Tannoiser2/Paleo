extends Control
## Regolamento in italiano (tradotto dal regolamento originale tedesco), in breve.

var main
var finestra := false

const REGOLE := """[font_size=30][color=#d98c38]Lo scopo[/color][/font_size]
Paleo è cooperativo: tutta la tribù vince o perde insieme. Vincete appena completate la [b]pittura rupestre[/b] con 5 pezzi; perdete appena prendete il [b]quinto teschio[/b]. Se nello stesso momento arrivano il quinto teschio e il quinto pezzo di pittura, vincete. Come trovare i pezzi di pittura lo dovete scoprire giocando!

[font_size=30][color=#d98c38]La preparazione[/color][/font_size]
Ogni partita usa due moduli (un livello). Ogni modulo porta la sua missione notturna, a volte segreti, idee o carte in attesa. Le carte dei moduli si mescolano con le 32 carte base e si dividono coperte fra i gruppi. Ogni gruppo comincia con 2 umani e i loro attrezzi; nel campo ci sono 5 cibo (in solitario nessuno). Sul banco di lavoro ci sono sempre torcia, amigdala e lancia.

[font_size=30][color=#d98c38]Il giorno[/color][/font_size]
Il giorno è fatto di turni. In ogni turno:
[b]1. Scegliere.[/b] Ognuno sceglie, guardando solo i [b]dorsi[/b], una delle prime 3 carte del proprio mazzo: è il luogo che il gruppo esplora. Il dorso suggerisce che cosa c'è dietro: il bosco dà soprattutto legno e cibo, il fiume cibo e pelli, la montagna pietra e pelli, la casa permette di costruire attrezzi e di trovare umani, sogni e idee. I dorsi rossi nascondono spesso pericoli (ma non sempre!). Si possono guardare in ogni momento i dorsi di tutto il proprio mazzo, senza cambiarne l'ordine.
Invece di scegliere puoi [b]andare a dormire prima[/b]: tutto il tuo mazzo va negli scarti coperti senza effetti.
[b]2. Scoprire.[/b] Tutti scoprono insieme la carta scelta.
[b]3. Agire.[/b] Ognuno usa esattamente un'opzione della propria carta, nell'ordine che decidete insieme: un'[b]azione[/b], [b]aiutare[/b] un compagno o una carta, oppure [b]ignorare[/b] la carta. Poi la carta va negli scarti scoperti (o nel cimitero, se va distrutta).
Quando hai finito le carte, il tuo gruppo dorme. Quando dormono tutti arriva la notte.

[font_size=30][color=#d98c38]Le azioni[/color][/font_size]
Per fare un'azione servono i [b]requisiti[/b] (abilità: [b]Forza[/b], [b]Percezione[/b], [b]Destrezza[/b], che si sommano su tutto il gruppo; non si consumano) e i [b]costi[/b]: dare risorse dal campo, dare attrezzi, scartare carte e a volte distruggere la carta. Poi si prende subito il [b]bottino[/b]: le risorse vanno nel campo comune.
[b]Scartare carte[/b] significa mettere negli scarti coperti le prime carte del proprio mazzo, senza guardarle: il tempo passa. [b]Ogni carta con il dorso rosso scartata fa 1 danno[/b] a un umano.
I [b]dadi[/b] alzano i requisiti: si tirano dopo aver deciso chi aiuta. Se non bastano, si deve scegliere un'altra azione.

[font_size=30][color=#d98c38]I pericoli[/color][/font_size]
Le carte rosse (con il punto esclamativo) [b]non si possono ignorare[/b]: se non riesci a fare un'azione buona devi scegliere un'azione negativa, fra quelle che puoi eseguire; danni e teschi si possono sempre subire. Il [b]talismano[/b] permette di ignorare un pericolo, anche dopo i dadi.

[font_size=30][color=#d98c38]Aiutare[/color][/font_size]
Invece di usare la propria carta si può aiutare un compagno: i due gruppi sommano abilità e attrezzi, possono dividersi il bottino e chi aiuta può prendere su di sé i danni. Chi aiuta non scarta carte al posto tuo. Alcune carte nel gruppo o nell'attesa hanno azioni che si fanno solo [b]aiutando la carta[/b]: per usarle serve l'opzione «aiutare» della propria carta scoperta.

[font_size=30][color=#d98c38]Danni[/color][/font_size]
Il danno di una sola fonte va tutto su un solo umano. Un umano con tutti i cuori feriti che subisce un altro danno [b]muore[/b]: va nel cimitero e la tribù prende un teschio (il danno in più va perso). Se muore l'ultimo umano di un gruppo, ne arriva subito uno nuovo. Pelle e vestiti si consumano per parare il danno; la radice curativa cura fino a 3 danni.

[font_size=30][color=#d98c38]La notte[/color][/font_size]
[b]1.[/b] Ogni umano mangia 1 cibo; per ogni umano affamato prendete un teschio (gli umani non muoiono).
[b]2.[/b] Ogni missione chiede una delle sue azioni: di solito dare qualcosa oppure prendere un teschio. Le missioni restano e tornano ogni notte.
[b]3.[/b] Le carte con la luna nei gruppi chiedono anch'esse una delle loro azioni.
[b]4.[/b] Si mescolano tutti gli scarti e si ridistribuiscono coperti: comincia un nuovo giorno.

[font_size=30][color=#d98c38]Costruire, umani, sogni, idee, segreti[/color][/font_size]
[b]Costruire[/b] (nelle case): costruisci una o due idee del banco di lavoro pagandone i costi. Torcia: 1 legno. Amigdala: 1 pietra. Lancia: 1 legno e 1 pietra. Le altre idee si trovano con le carte idea.
[b]Umano[/b]: entra nel tuo gruppo con il suo attrezzo; dà abilità ma va nutrito.
[b]Sogno[/b]: una carta del mazzo dei sogni va coperta in cima al tuo mazzo.
[b]Idea[/b]: una nuova idea entra nel banco di lavoro (al massimo 6).
[b]Segreto[/b]: si legge il segreto con quel numero, se è ancora sul tabellone Notte.

[font_size=30][color=#d98c38]Gli attrezzi[/color][/font_size]
Lancia: +1 Forza. Amigdala: +1 Destrezza. Ascia: +1 Forza e +1 Destrezza. Lupo addomesticato: +1 Percezione. Totem: +2 Percezione. Si consumano: torcia (+1 Percezione), corda (+1 a scelta), trappola (+2 Forza), pelle (para 1 danno), vestiti (parano fino a 3 danni), radice curativa (cura 3), talismano (ignora un pericolo). La tenda serve a certe carte; la zattera fa scoprire le carte del Grande fiume.

[font_size=30][color=#d98c38]Solitario[/color][/font_size]
Con un solo gruppo si comincia senza cibo e con tutte le carte. Una volta per carta scoperta puoi [b]chiedere aiuto[/b]: scarta 2 carte per tirare 1 dado, o 4 carte per 2 dadi, e somma le abilità uscite alle tue.

[font_size=30][color=#d98c38]In questa versione[/color][/font_size]
Passa il mouse su una carta per vederla grande con il testo in italiano. Le scelte compaiono nel pannello in basso; nella fase di scelta puoi anche cliccare direttamente sui dorsi del tuo mazzo. Gli attrezzi monouso necessari ai requisiti vengono usati in automatico, nel modo più economico. Nella fase delle azioni agiscono prima le persone, poi i compagni IA: se vuoi vedere prima che cosa fanno gli altri (o usare le risorse che trovano), scegli «Aspetta». Quando un compagno chiede il tuo aiuto ti viene chiesto se sei d'accordo. La partita si salva da sola: dal menu puoi continuarla.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if finestra:
		var fondo := ColorRect.new()
		fondo.color = Color(0, 0, 0, 0.6)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 160)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	add_child(m)
	var p := UI.pannello(Color(0.16, 0.11, 0.08, 0.98), UI.OCRA)
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(UI.titolo("Regole di Paleo", 56))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var b := UI.bottone("Chiudi" if finestra else "Torna al menu", 22)
	b.pressed.connect(_chiudi)
	h.add_child(b)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("normal_font_size", 21)
	t.add_theme_font_size_override("bold_font_size", 21)
	t.text = REGOLE
	v.add_child(t)


func _chiudi() -> void:
	if finestra:
		queue_free()
	else:
		main.show_menu()
