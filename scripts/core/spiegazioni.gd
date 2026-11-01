class_name Spiegazioni
## Chiarimenti sulle carte con l'asterisco (dal foglio aggiuntivo del regolamento, pagine 4–6).

const TESTI := {
	36: "Dai una delle tre risorse e ricevi una ciascuna delle altre due.",
	31: "Le 3 carte in cima agli scarti coperti tornano, nello stesso ordine, sul tuo mazzo. Possono tornare anche carte rosse già scartate: non sempre conviene avere coraggio. Come ogni carta blu, puoi ignorarla.",
	35: "Le 3 carte in cima agli scarti coperti tornano, nello stesso ordine, sul tuo mazzo. Possono tornare anche carte rosse già scartate: non sempre conviene avere coraggio. Come ogni carta blu, puoi ignorarla.",
	60: "Se un compagno ti aiuta, gli umani dei due gruppi non si sommano: conta solo il gruppo di chi riceve l'umano.",
	69: "Se un compagno ti aiuta, gli umani dei due gruppi non si sommano: conta solo il gruppo di chi riceve l'umano.",
	71: "Se un compagno ti aiuta, gli umani dei due gruppi non si sommano: conta solo il gruppo di chi riceve l'umano.",
	75: "Se un compagno ti aiuta, gli umani dei due gruppi non si sommano: conta solo il gruppo di chi riceve l'umano.",
	26: "Scegli una carta qualsiasi del tuo mazzo (non solo fra le prime tre) e mettila negli scarti coperti. Se è rossa non subisci danni.",
	29: "Scegli una carta qualsiasi del tuo mazzo (non solo fra le prime tre) e mettila negli scarti coperti. Se è rossa non subisci danni.",
	21: "Guardi le prime 3 carte del mazzo senza fare azioni e puoi spostarle in fondo, per esempio quelle rosse.",
	28: "Guardi le prime 3 carte del mazzo senza fare azioni e puoi spostarle in fondo, per esempio quelle rosse.",
	118: "Guardi le prime 3 carte del mazzo senza fare azioni e puoi spostarle in fondo, per esempio quelle rosse.",
	225: "La Visione resta nel tuo gruppo. Quando il «Fungo velenoso» è nel cimitero puoi dare un talismano: la Visione è distrutta e ricevete un pezzo di pittura e il copricapo dello sciamano (totem).",
	224: "Resta nell'attesa. Quando qualcuno scopre il «Branco di lupi», invece delle sue azioni può usare quella della Battuta: 7 Forza, 1 dado, scarta 3 carte e distruggi il Branco: ottieni 4 cibo e un pezzo di pittura.",
	221: "Una volta per carta scoperta danno +2 Forza per un requisito, anche se l'azione non dà cibo; se lo dà, ne ricevi 2 in meno. Non sono umani: di notte non mangiano.",
	223: "Aiutando Darca (anche insieme a un compagno) e scartando 1 carta, chi aiuta riceve un nuovo umano.",
	233: "Se non scegli un'azione che lo distrugge, va negli scarti come una carta normale e tornerà nei mazzi del giorno dopo.",
	237: "Non ha azioni: è solo un indizio. Al vecchio sciamano piacciono molto queste bacche.",
	240: "Invece delle azioni puoi ignorarla e metterla negli scarti.",
	241: "I 6 artigli vengono mescolati nei mazzi. Da ora, quando ricevereste un pezzo di pittura, potete togliere un teschio al suo posto. Se la tigre dai denti a sciabola viene distrutta, avete vinto.",
	238: "Cerca nel cimitero fino a 3 animali e mettili coperti sul tuo mazzo. Puoi anche ignorarla.",
	236: "Sulla carta si mette solo il cibo ottenuto dalle bacche indicate (anche più di uno dalla stessa carta).",
	226: "Una volta per carta scoperta puoi scartare una lancia per +3 Forza (la lancia smette però di dare il suo +1).",
	227: "Quando subisci danni scegli se li prende un umano o il costume. Il danno non si divide e quello in più va perso.",
	149: "Ogni umano del gruppo che ha già almeno un danno ne subisce un altro (si può parare). Se un compagno ti aiuta, vale anche per i feriti del suo gruppo.",
	228: "Aiutando Jhula puoi dare 1 cibo per togliere 1 danno a un umano del tuo gruppo.",
	229: "Aiutando Orru costruisci 1 idea del banco di lavoro, pagandone i requisiti.",
	230: "Aiutando Ahab scarti senza effetti il pericolo scoperto da un compagno, anche dopo i suoi dadi.",
	242: "Ha 5 punti vita: le carte con la tigre le infliggono danni. Al quinto danno è distrutta e avete vinto.",
	110: "Se puoi scegliere solo l'azione negativa ma non hai carte montagna nel mazzo, la carta va nel cimitero senza altri effetti.",
	138: "Se nel mazzo non hai carte neve devi subire 2 danni. Altrimenti scarti la Nevicata e scopri la prossima carta neve del tuo mazzo, da risolvere normalmente.",
	139: "Se nel mazzo non hai carte neve devi subire 2 danni. Altrimenti scarti la Nevicata e scopri la prossima carta neve del tuo mazzo, da risolvere normalmente.",
	144: "Se nel mazzo non hai carte neve devi subire 2 danni. Altrimenti scarti la Nevicata e scopri la prossima carta neve del tuo mazzo, da risolvere normalmente.",
	134: "Va risolta prima di tutte le altre carte: chi ha scoperto un bosco lo scarta senza effetti.",
	164: "Ti aiuta un compagno con la zattera: uno dei due la consegna e rimetti 2 carte coperte dagli scarti sul tuo mazzo. Poi decidete chi prende il bottino.",
	166: "Ti aiuta un compagno con la zattera: uno dei due la consegna e rimetti 2 carte coperte dagli scarti sul tuo mazzo. Poi decidete chi prende il bottino.",
	102: "Puoi mettere negli scarti coperti, senza effetti, una carta rossa qualsiasi del tuo mazzo.",
	197: "Invece del danno puoi scegliere questa azione se un compagno ha scoperto un animale: il compagno distrugge quella carta e non fa azioni.",
	170: "Va nel tuo gruppo: è un umano a tutti gli effetti, va nutrito, può essere ferito e ha addirittura due abilità.",
}


static func testo(id: int) -> String:
	return TESTI.get(id, "")
