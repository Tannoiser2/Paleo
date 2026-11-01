# Paleo — versione digitale

Versione digitale amatoriale di **Paleo** (Peter Rustemeyer, Hans im Glück, 2020) per la ludoteca:
un gioco cooperativo in cui la tribù esplora l'età della pietra carta dopo carta, guardando solo i
dorsi, per sopravvivere alle notti e completare la pittura rupestre.

Si gioca nel browser: https://tannoiser2.github.io/Paleo/

## Che cosa c'è

- **Regole complete** del gioco base: fase del giorno (scelta dal dorso, scoperta, azione / aiuto /
  ignora), danni e morte degli umani, carte rosse scartate, dadi, talismano, costruire, umani, sogni,
  idee e segreti; fase della notte (cibo, missioni, carte notturne, ridistribuzione).
- **Tutti i 10 moduli (A–J) e i 7 livelli** consigliati, oppure combinazioni libere; le regole speciali
  dei moduli (lupi, desideri, tempesta di neve, febbre, Grande fiume con la zattera, guerriere delle
  Mani Bianche, la belva e la tigre dai denti a sciabola).
- **Varianti**: Grande tribù, Provviste, Lavoro di squadra, Nebbia, Debolezza, Lunghe strade e il
  **solitario** (con «chiedere aiuto» ai dadi).
- **Compagni IA** per giocare da soli con una tribù intera, **hotseat** e **partite online** con gli
  amici (Firebase, radice `paleo/rooms`).
- **Tavolo 3D** con i tabelloni Campo, Natura e Notte, le carte, le risorse di legno e i segnalini,
  alla luce del fuoco; si ruota trascinando e si avvicina con la rotellina.
- **Carte e dorsi dalle scansioni dell'edizione italiana**, con i nomi italiani ufficiali; passando il
  mouse su una carta compare grande con il testo e i chiarimenti per le carte con l'asterisco.
  Quattro carte del modulo G (bacche) non erano nelle scansioni e restano per ora in tedesco.
- **Tavolo 3D disposto come nel modulo TTS**: tabelloni (dalle scansioni) con le posizioni, le misure
  e la rotazione di TTS, banco di lavoro come in TTS con i segnalini sui cerchi, mazzi e carte sugli
  spazi stampati, cimitero con il teschio di mammut. Si ruota con il tasto sinistro, si sposta con il
  destro (o Maiusc + sinistro, o le frecce), si avvicina con la rotellina.

## Struttura

- `tools/carte_src.txt` — trascrizione a mano di tutte le 222 carte, in un formato compatto;
  `tools/compila_carte.py` la trasforma in `data/carte.json`.
- `scripts/core/motore.gd` — il motore delle regole (deterministico: stesso seme e stesse scelte,
  stessa partita, anche online).
- `scripts/core/ia.gd` — i compagni IA.
- `scripts/ui/` — menu, vista della partita, tavolo 3D, regole in italiano.
- `scripts/net/` — gioco online in lockstep su Firebase.
- `tests/` — partite automatiche (`sim.gd`), partita con l'interfaccia e schermate (`vivo.gd`).

## Prove

```
godot --headless --path . -s tests/sim.gd -- 21          # 21 partite solo IA su tutti i livelli
xvfb-run godot --path . -s tests/vivo.gd -- /tmp/vivo 3d # partita con l'interfaccia + schermate
python3 tools/controlla_glifi.py                          # nessun carattere mancante nei font
```

## Pubblicazione

Il workflow `Pubblica` parte solo a mano (Actions → Pubblica → Run workflow) oppure con un commit
su `main` il cui messaggio contiene `[pubblica]`. Pubblica su GitHub Pages e, se ci sono i segreti
`CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`, sulla ludoteca privata (`paleo.ludoteca-digitale.com`).

## Materiale

Immagini dalle scansioni dell'edizione italiana (e, per quattro carte, dal modulo Tabletop Simulator «Paleo German»). Font: Amatic SC, Alegreya
Sans e Rubik Dirt (SIL Open Font License). Uso personale e non commerciale.
