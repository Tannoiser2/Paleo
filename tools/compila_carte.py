#!/usr/bin/env python3
"""Compila la trascrizione delle carte (tools/carte_src.txt) in data/carte.json.

La trascrizione è fatta a mano dalle immagini del modulo TTS (edizione tedesca), tradotta in italiano.
Uso: python3 tools/compila_carte.py
"""
import json, os, re, sys

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.dirname(QUI)
SRC = os.path.join(QUI, "carte_src.txt")
DORSI = os.path.join(QUI, "dorsi.json")   # indice carta -> numero del dorso (ricavato dal modulo TTS)

TIPO_DORSO = {
    1: "umano", 2: "sogno", 3: "idea", 4: "fiume", 5: "montagna", 6: "bosco", 7: "casa", 8: "rosso",
    9: "fiume", 10: "missione", 11: "orme", 12: "montagna", 13: "idea", 14: "rosso", 15: "rosso", 16: "rosso",
    17: "sogno", 18: "rosso", 19: "montagna", 20: "bosco", 21: "sogno", 22: "sogno", 23: "sogno", 24: "sogno",
    25: "neve", 26: "idea", 35: "idea", 36: "rosso", 37: "rosso", 38: "montagna", 39: "sogno",
}
for b in range(27, 35):
    TIPO_DORSO[b] = "bosco"
for b in range(40, 62):
    TIPO_DORSO[b] = "segreto"

RIS = ("cibo", "legno", "pietra")


def opzione(testo):
    """Converte un'opzione compatta in dizionario."""
    o = {"neg": False, "req": {}, "carte": 0, "distruggi": False, "paga": {}, "paga_attrezzi": {},
         "cond": [], "guadagna": {}, "attrezzi": {}, "danno": 0, "teschi": 0, "speciali": [],
         "stato": "", "aiuto_carta": False, "deposito": False}
    t = testo.strip()
    if t.startswith("~"):
        o["neg"] = True
        t = t[1:].strip()
    if t.startswith("h ") or t == "h":
        o["aiuto_carta"] = True
        t = t[1:].strip()
    m = re.match(r"\[(\w+)\]\s*(.*)", t)
    if m:
        o["stato"] = m.group(1)
        t = m.group(2)
    if ">" in t:
        sx, dx = t.split(">", 1)
    else:
        sx, dx = t, ""
        # nelle azioni negative senza ">" gli effetti sono tutti "di costo/danno"
    def parse_req(tok):
        mm = re.fullmatch(r"([FPDW])(\d+)", tok)
        if mm:
            o["req"][mm.group(1)] = o["req"].get(mm.group(1), 0) + int(mm.group(2))
            return True
        mm = re.fullmatch(r"c(\d+)", tok)
        if mm:
            o["carte"] += int(mm.group(1)); return True
        if tok == "X":
            o["distruggi"] = True; return True
        mm = re.fullmatch(r"-(cibo|legno|pietra|any)(\d+)", tok)
        if mm:
            o["paga"][mm.group(1)] = o["paga"].get(mm.group(1), 0) + int(mm.group(2)); return True
        mm = re.fullmatch(r"-t:(\w+?)(\d*)", tok)
        if mm:
            n = int(mm.group(2) or 1)
            o["paga_attrezzi"][mm.group(1)] = o["paga_attrezzi"].get(mm.group(1), 0) + n; return True
        if tok.startswith("?"):
            o["cond"].append(tok[1:]); return True
        if tok == "$deposito":
            o["deposito"] = True; return True
        mm = re.fullmatch(r"B(\d+)", tok)
        if mm:
            o["guadagna"]["costruisci"] = int(mm.group(1)); return True
        return False
    def parse_gain(tok):
        mm = re.fullmatch(r"(cibo|legno|pietra)(\d+)", tok)
        if mm:
            o["guadagna"][mm.group(1)] = o["guadagna"].get(mm.group(1), 0) + int(mm.group(2)); return True
        mm = re.fullmatch(r"t:(\w+)", tok)
        if mm:
            o["attrezzi"][mm.group(1)] = o["attrezzi"].get(mm.group(1), 0) + 1; return True
        if tok in ("U", "S", "I", "V"):
            o["guadagna"][tok] = o["guadagna"].get(tok, 0) + 1; return True
        mm = re.fullmatch(r"I(\d+)", tok)
        if mm:
            o["guadagna"]["I"] = o["guadagna"].get("I", 0) + int(mm.group(1)); return True
        mm = re.fullmatch(r"G(\d+)", tok)
        if mm:
            o["guadagna"].setdefault("G", []).append(int(mm.group(1))); return True
        if tok == "K-":
            o["guadagna"]["K"] = o["guadagna"].get("K", 0) + 1; return True
        mm = re.fullmatch(r"cura(\d+)", tok)
        if mm:
            o["guadagna"]["cura"] = int(mm.group(1)); return True
        mm = re.fullmatch(r"!d(\d+)", tok)
        if mm:
            o["danno"] += int(mm.group(1)); return True
        mm = re.fullmatch(r"!k(\d+)", tok)
        if mm:
            o["teschi"] += int(mm.group(1)); return True
        if tok.startswith("@"):
            o["speciali"].append(tok[1:]); return True
        return False
    # le condizioni "?carta:Nome con spazi" vanno ricomposte
    def tokens(s):
        out = []
        for tok in s.split():
            if out and out[-1].startswith("?") and ":" in out[-1] and not re.fullmatch(r"([FPDW]\d+|c\d+|X|-.*|\$.*|B\d+|h|@.*)", tok):
                out[-1] += " " + tok
            else:
                out.append(tok)
        return out
    for tok in tokens(sx):
        if not parse_req(tok) and not parse_gain(tok):
            sys.exit("token sconosciuto %r in %r" % (tok, testo))
    for tok in tokens(dx):
        if not parse_gain(tok):
            sys.exit("bottino sconosciuto %r in %r" % (tok, testo))
    return o


def main():
    dorsi = json.load(open(DORSI))
    carte = {}
    for riga in open(SRC, encoding="utf-8"):
        riga = riga.strip()
        if not riga or riga.startswith("#"):
            continue
        idx, mod, tipo, nome, resto = [x.strip() for x in riga.split("|", 4)]
        idx = int(idx)
        c = {"id": idx, "modulo": mod, "tipo": tipo, "nome": nome, "dorso": dorsi[str(idx)],
             "dorso_tipo": TIPO_DORSO.get(dorsi[str(idx)], "base"), "opzioni": [], "aiuto": False,
             "notte": [], "zona": "", "passivo": "", "abilita": [], "vita": 0, "attrezzo": "",
             "deposito": {}, "distruggi_alla_scoperta": "", "spiegazione": nome.endswith("*")}
        c["nome"] = nome.rstrip("*")
        if tipo == "U":
            parti = resto.split()
            ab = parti[0]
            c["abilita"] = [] if ab == "-" else list(ab)
            c["vita"] = int(parti[1])
            c["attrezzo"] = "" if parti[2] == "-" else parti[2]
            if len(parti) > 3 and parti[3] == "*":
                c["zona"] = "gruppo"
            carte[idx] = c
            continue
        if tipo == "I":
            c["opzioni"].append(opzione(resto))
            carte[idx] = c
            continue
        for pezzo in [p.strip() for p in resto.split(" ; ")]:
            if pezzo == "H":
                c["aiuto"] = True
            elif pezzo.startswith("="):
                k, _, v = pezzo[1:].partition(" ")
                if k in ("gruppo", "attesa"):
                    c["zona"] = k
                elif k == "passivo":
                    c["passivo"] = v
                elif k == "abilita":
                    c["abilita"] = list(v)
                elif k == "vita":
                    c["vita"] = int(v)
                elif k == "distruggi":
                    c["distruggi_alla_scoperta"] = v
                elif k == "deposito":
                    dep = {}
                    for t in v.split():
                        mm = re.fullmatch(r"(\w+?)(\d+)(?:@(.+))?", t)
                        risorsa, n, fonti = mm.group(1), int(mm.group(2)), mm.group(3)
                        dep.setdefault(risorsa, []).append({"n": n, "fonti": [f.replace("_", " ") for f in fonti.split(",")] if fonti else []})
                    c["deposito"] = dep
                else:
                    sys.exit("chiave sconosciuta " + k)
            elif pezzo.startswith("n "):
                o = opzione(pezzo[2:])
                o["neg"] = True
                c["notte"].append(o)
            else:
                c["opzioni"].append(opzione(pezzo))
        carte[idx] = c
    # correzioni: i nomi composti delle condizioni "Lanciatore|Costume da capo"
    out = [carte[k] for k in sorted(carte)]
    os.makedirs(os.path.join(RADICE, "data"), exist_ok=True)
    json.dump(out, open(os.path.join(RADICE, "data", "carte.json"), "w"), ensure_ascii=False, indent=0)
    print(len(out), "carte")
    from collections import Counter
    print(Counter(c["dorso_tipo"] for c in out))


if __name__ == "__main__":
    main()
