# 🐕 Návod: zvuk na novém počítači

Hodný pejsku, tohle zvládneš. Dělej přesně kroky po sobě. Nic nepřeskakuj.

---

## 🔌 Krok 1: Zapoj kabely

Všechno se zapojuje **vzadu do počítače, přímo do základní desky**. Nikdy ne do předního panelu skříně.

| Odkud | Kam |
|---|---|
| 🟢 **zelený** jack v PC | **Penta → INPUT FRONT** (dva cinche, levý a pravý) |
| 🟠 **oranžový** jack v PC: **červený** cinch | **Penta → vstup SUBWOOFER** |
| 🟠 **oranžový** jack v PC: **bílý** cinch | **Penta → vstup CENTRE** (je prázdný, jen ať se nepovaluje) |
| **Penta → SUBWOOFER OUT** | **Y kabel** → oba cinch vstupy na subu |
| **Penta → SPEAKER OUT FRONT** | sloupy Mythos Four (červená na červenou, černá na černou) |

```
PC zelený ─────────────► Penta INPUT FRONT ──► sloupy
PC oranžový ─ červený ─► Penta SUB in
            └ bílý ────► Penta CENTRE in
                         Penta SUB OUT ──Y──► Velodyne (oba vstupy)
```

## 🎛️ Krok 2: Nastav přepínače

**Na subu Velodyne vzadu:**
- `INTERNAL X-OVER / SUBWOOFER DIRECT` → **SUBWOOFER DIRECT**
- `PHASE` → **180**
- `VOLUME` → zhruba na 3–4 tečky od minima. Doladí se v kroku 5.

**Na Pentě vzadu:**
- `PRE LEVEL FRONT` → **asi 80 %**

## 💻 Krok 3: Jedno tlačítko 🔘

1. Zmáčkni klávesu **Windows** (Super), napiš **Terminál** a zmáčkni **Enter**.
2. Zkopíruj celý tenhle řádek, vlož ho do terminálu (**Ctrl+Shift+V**) a zmáčkni **Enter**:

```bash
sudo dnf install -y git && git clone https://github.com/Onhils/pc-audio-2.1 ~/pc-audio-2.1 && ~/pc-audio-2.1/setup.sh
```

3. **Heslo:** zeptá se na heslo k počítači. Napiš ho a zmáčkni Enter. Při psaní se nic nezobrazuje, to je normální. 🙈
4. Počkej, až se objeví **„6/6 HOTOVO 🎉“**. Všechny řádky mají mít zelenou fajfku ✓.

> Když už složka `~/pc-audio-2.1` existuje (spouštíš to podruhé), stačí:
> ```bash
> cd ~/pc-audio-2.1 && git pull && ./setup.sh
> ```

## 🔊 Krok 4: Zkontroluj

- Hlasitost v PC (vpravo nahoře) dej na **100 %** a už na ni nesahej.
- **Hlasitost ovládej jen ovladačem od Penty.** 📺
- Pusť si písničku s basy. **Sub musí hrát.**
- Když jsou zapnuté, zavři a znovu spusť prohlížeč a přehrávač mpv.

## 🎯 Krok 5: Doladění (jen když je potřeba)

Dělá se, když je nový pokoj, posunutý sub nebo basy prostě nesedí. Potřebuješ telefon s aplikací **Sound Meter**.

```bash
cd ~/pc-audio-2.1 && ./kalibrace.sh
```

V nabídce jdi popořadě:
1. **Hraje sub?** Zahraje jen sub. Když nehraje, zkontroluj kabely z kroku 1.
2. **Hlasitost sub/sloupy:** telefon polož na postel tam, kde máš hlavu. Točíš **knobem na subu**, dokud nebude sub i sloupy ukazovat stejně dB.
3. **Fáze:** zapiš 4 čísla. Nech fázi na té poloze, kde vyšla **vyšší** čísla. Naposledy to bylo 180°.
4. **Měření basů:** zapiš 11 čísel a pošli je Claudovi. Upraví ekvalizér.

---

## 🆘 Když něco nejde

| Co se děje | Co udělat |
|---|---|
| Na konci skriptu je ✗ a červený text | Zkopíruj celý výpis a pošli ho Claudovi. Nic se nerozbilo. |
| Sub nehraje | Je zapnutý? Svítí na něm modrá LED? Je červený cinch ve vstupu SUB na Pentě? Je na subu **SUBWOOFER DIRECT**? |
| Ze sloupů je v tichu slyšet rušení nebo bzučení | Spusť znovu `./setup.sh`. Pokud to nepomůže, jsou kabely opravdu vzadu v desce? |
| Hraje jen jeden sloup | Zelený jack není zasunutý celý nebo je uvolněný cinch na Pentě. |
| Je to moc potichu | Ovladač Penty nahoru. Hlasitost v PC musí být na 100 %. |
| Ve hlasitých scénách to chrčí | Penta je na maximu výkonu. Stáhni ji, nebo jednou natrvalo hlasitost PC na 80 %. |
| Film nemá zvuk z centru (dialogy) | Přehrávej filmy v **mpv**, ten je nastavený správně. |

## 🧠 Co ten skript vlastně dělá (pro zvědavé)

- Najde zvukovou kartu a přepne ji na **2.1**.
- Basy pod **~100 Hz** posílá do subu. V konfiguraci je `lfe-cutoff = 200`, protože číslo v PipeWire je dvojnásobek skutečného dělení.
- Zapne **ekvalizér místnosti** (70 Hz −9 dB, 120 Hz −10 dB), změřený v pokoji s postelí.
- Vypne **uspávání zvukové karty**, aby v tichu nebylo slyšet rušení.
- Nastaví **mpv**, aby filmy 5.1 správně smíchal do 2.1 a neořezával zvuk.
- Na konci **potichu ověří**, že do subu jdou basy a výšky ne.
- Staré nastavení předtím zazálohuje do `~/.config/pc-audio-backup-…`.

Podrobnosti a měření jsou v [README.md](README.md).

Hodný pejsek. 🦴
