# PC audio 2.1 – Mythos Four + Velodyne SPL II

> 🐕 **Nový počítač? Jdi na [NAVOD.md](NAVOD.md)** – jedno tlačítko (`./setup.sh`) a průvodce laděním (`./kalibrace.sh`).
>
> 💬 Vzniklo v konverzaci s Claude Code (T3 Code), **session `94846fb0-055b-4bed-afb2-8d2e216158ce`** (2026-11-25 – 2026-11-27).
> Navázat: v T3 Code otevři vlákno „vidíš moje audio nastavení…“, nebo v terminálu
> `cd ~/.t3/scratch/2026-11-25-vidis-moje-audio-nastaveni-mam-ca81a3db && claude --resume 94846fb0-055b-4bed-afb2-8d2e216158ce`.

Nastavení a poznatky z ladění 2.1 sestavy na Fedora / PipeWire (2026-11-25).

## Sestava

```
PC (Realtek ALC1220, profil Analog Surround 2.1, hlasitost PC natrvalo 100 %)
 ├─ zelený jack (FL/FR) ──► Ceratec Penta INPUT FRONT ──► 2× Definitive Technology Mythos Four (sloupy)
 └─ oranžový jack ──┬─ hrot  / bílý cinch  = Center (v 2.1 prázdný) ──► Penta vstup centre
                    └─ kroužek / červený cinch = LFE ──► Penta vstup subwoofer
                                                         Penta SUBWOOFER OUT ──Y kabel──► Velodyne SPL Series II 1000W (oba line vstupy)
```

- Mythos Four jsou štíhlé sloupy, basy mají omezené: Sound & Vision naměřil **−3 dB @ 104 Hz, −6 dB @ 90 Hz** (výrobce udává 35 Hz – 30 kHz, měření tomu neodpovídá).
- **Sub jde přes Pentu** – SUBWOOFER OUT Penty má úroveň řízenou hlavní hlasitostí (ověřeno), takže **knob / dálkový ovladač Penty ovládá sloupy i sub současně** a poměr drží.
- Y kabel do obou line vstupů Velodyne: sub L+R sčítá → o ~6 dB vyšší úroveň, srovnáno knobem subu.
- Bílý cinch (prázdný centr) je ve vstupu centre Penty jen kvůli pořádku; na výstup centre speaker nic nepřipojovat.

### Hlasitost

- **PC natrvalo 100 %**, hlasitost se ovládá **jen Pentou** (knob nebo dálkový ovladač z postele).
- Penta má vysokou citlivost (plný výkon od 200 mV); kdyby hlasité pasáže zkreslovaly, snížit jednou natrvalo hlasitost PC (např. 70–80 %).
- Downmix v mpv ztlumí filmy cca o 6 dB (rezerva proti ořezu) – vyrovná se Pentou.
- mpv má `volume-max=100` – zesílení nad 100 % by šlo za limiter a mohlo ořezávat.

### Z manuálů

- **Penta:** 5× 80 W (max 120 W) @ 4 Ω, citlivost 200 mV–1,5 V, vstupní impedance 47 kΩ, THD+N 0,08 %, SNR 96 dB, PRE LEVEL trimry vzadu, SUBWOOFER OUT řízený hlasitostí.
- **Velodyne SPL II:** low-pass 40–120 Hz (12 dB/okt. počáteční, 48 dB/okt. konečný), bypass „Subwoofer Direct“ pro externě filtrovaný signál; pro malé reproduktory doporučuje dělení 100–120 Hz; všechny vstupy se sčítají; optimum výkonu typicky v rohu.

## Režimy 2.1 / 3.1

`./setup.sh 2.1`, `./setup.sh 3.1` nebo `./setup.sh 5.1` (pamatuje si poslední volbu v `~/.config/pc-audio-mode`). Funkční 2.1 je navíc zamrazený jako git tag **`v2.1`**.

| | 2.1 | 3.1 (centr Mythos Three) |
|---|---|---|
| profil karty | Analog Surround 2.1 | Analog Surround 5.1 (zadní kanály nepoužité; karta 3.1 neumí) |
| centr | zamíchán do sloupů (mpv, −3 dB) | oranžový jack hrot → bílý cinch → Penta CENTRE → Mythos Three |
| bass management | PipeWire upmix `lfe-cutoff = 200` (jen stereo), mpv míchá 5.1 do sterea | filtr „3.1 EQ“: LFE = LR4 100 Hz z (0,5·FL + 0,5·FR) + LR4 80 Hz z 0,707·FC + LFE stopa; centr LR4 horní propust **80 Hz** (se 100 Hz zněly dialogy dutě); PipeWire upmix vypnutý |
| mpv | `pan=stereo` + alimiter 0,7 | `pan=3.1` (FL/FR + surroundy, FC, LFE 0,7) + alimiter 0,7; klávesy **F1/F2/F3** = dialogy centr / sloupy / mix (A/B) |
| konfigurace | [`modes/2.1`](modes/2.1) | [`modes/3.1`](modes/3.1) |

**5.1** ([`modes/5.1`](modes/5.1), připraveno, naživo zatím nevyzkoušeno): navíc 2× Mythos Five (černý jack → Penta INPUT REAR → SPEAKER OUT REAR). Zadní: LR4 horní propust 100 Hz (basy do subu), zpoždění `REAR_DELAY_MS` (uloženo v `~/.config/pc-audio-rear-delay-ms`), zap/vyp za běhu přes `mpv-ovladac zadni-zap|zadni-vyp` (pw-cli parametry filtru; vyp = přimíchat do sloupů −3 dB). mpv předává 5.1 beze změny (`pan=5.1`, LFE 0,7, alimiter 0,7). Ověřeno potichu: zadní 1 kHz jen do RL, zadní 50 Hz do subu, zpoždění přesně 8,00 ms, přepínač funguje.

- PipeWire `lfe-cutoff` filtr je přesně **LR4 na cutoff/2** (změřeno: 50/70/90/110/150 Hz = −0,5/−1,9/−4,4/−7,8/−15,6 dB pro 200), proto 3.1 filtr (LR4 @ 100 Hz) dává subu stejnou křivku a úroveň – kalibrace subu i fáze platí v obou režimech.
- Ověřeno potichu (`scripts/selftest.sh`): stereo 1 kHz do centru nejde, centr 1 kHz jen do centru, centr 50 Hz jde hlavně do subu, LFE stopa do subu.

### Kalibrace 3.1 (2026-11-27, telefon uprostřed postele)

| krok | levý | centr | pravý | pozn. |
|---|---|---|---|---|
| start (PRE LEVEL CENTRE výchozí, tiše) | 41 | 35 | 42 | moc potichu na měření |
| Penta hlasitěji, CENTRE +¼ otáčky | 70 | 67 | 70 | CENTRE už na maximu |
| PRE LEVEL FRONT dolů | 68 | 66,5 | 68 | |
| PRE LEVEL FRONT ještě maličko dolů | **67** | **66,5** | **65** | ✓ |

- **PRE LEVEL CENTRE = max**, **PRE LEVEL FRONT ≈ pod 80 %** (stažen, aby se sloupy srovnaly s centrem).
- Sub pak přeladěn na nové sloupy (90 Hz): 67/61 → 64/61 → 63/61 → **62/61** ✓ (knob subu dolů). Fáze 180° beze změny (dělení subu je stejné).
- Poměr sub/sloupy platí i pro `./setup.sh 2.1` – zpět na 2.1 jde bez nové kalibrace.

## Hlavní zjištění

1. **PipeWire ve výchozím stavu neposílá do LFE nic ze stereo zdrojů.** `channelmix.lfe-cutoff = 0` = žádné LFE. Musí se nastavit nenulová hodnota.
2. **Hodnota `lfe-cutoff` neodpovídá reálnému dělení.** Změřeno přes virtuální sink (PipeWire 1.6.11), úroveň LFE vůči FL:

   | lfe-cutoff | 30 Hz | 50 Hz | 70 Hz | 90 Hz | 110 Hz | 150 Hz | reálné −6 dB |
   |---|---|---|---|---|---|---|---|
   | 100 | −1.1 | −6.0 | −13.6 | −21.0 | −27.1 | −35.5 | **~50 Hz** |
   | 150 | −0.2 | −1.6 | −4.9 | −9.7 | −14.9 | −24.3 | ~75 Hz |
   | **200** | −0.1 | −0.6 | −1.9 | −4.4 | −7.8 | −15.6 | **~100 Hz** ✓ |
   | 250 | 0.0 | −0.2 | −0.8 | −2.1 | −4.1 | −9.7 | ~125 Hz |
   | 300 | 0.0 | −0.1 | −0.4 | −1.1 | −2.2 | −6.0 | ~150 Hz |

   Zhruba: **reálné dělení ≈ lfe-cutoff / 2**. S hodnotou 100 hrál sub jen pod 50 Hz – „cítím, že hraje, ale neslyším ho“.
3. **Upmix se aplikuje jen na stereo.** Má-li zdroj vlastní LFE (5.1 film), PipeWire nedělá bass management: sub dostane jen LFE stopu, basy z FL/FR/FC/SL/SR jdou jen do sloupů.
4. **Downmix 5.1 → 2.1 v PipeWire ořezává** – centr a surroundy se přičítají do FL/FR (−3 dB) bez normalizace, Iron Man (DTS 5.1) měl špičky na 0 dBFS.
5. **Sloupy hrají vždy plné pásmo** (Penta nemá horní propust) → s vypnutým subem se nic neztrácí.

## Nastavení

| Část | Hodnota |
|---|---|
| PipeWire | `channelmix.upmix = true`, `channelmix.lfe-cutoff = 200` (reálně ~100 Hz) – [`modes/2.1/90-lfe-sub.conf`](modes/2.1/90-lfe-sub.conf) |
| mpv | 5.1/7.1 → stereo downmix (centr/surroundy −3 dB, LFE stopa +3 dB) + `alimiter` 0.7; basy do subu pak dělá PipeWire stejně jako u hudby – [`modes/2.1/mpv.conf`](modes/2.1/mpv.conf) |
| Velodyne | line vstupy (Y kabel z Penta SUB OUT), **Subwoofer Direct**, fáze **180°** (z postele hlasitější na 80/100 Hz), hlasitost srovnaná se sloupy na 90 Hz z postele (2026-11-27, po přepojení přes Pentu) |
| Ceratec Penta | hlavní ovládání hlasitosti (sloupy i sub) |
| Hlasitost PC | 100 % natrvalo |
| EasyEffects | nepoužívá se (smazáno) |
| Room EQ | virtuální výstup „2.1 EQ (místnost)“ (výchozí): 70 Hz −9 dB (Q5), 120 Hz −10 dB (Q4) na FL/FR/LFE – [`modes/*/91-room-eq.conf.in`](modes) |
| Uspávání výstupu | vypnuto pro analog 2.1 (WirePlumber) – [`51-analog-no-suspend.conf`](common/51-analog-no-suspend.conf) |

Instalace: `./setup.sh [2.1|3.1]` (najde kartu, nastaví vše, potichu ověří) – viz [NAVOD.md](NAVOD.md). Ladění: `./kalibrace.sh`.

### Ověření mpv (Iron Man, hlučná scéna, 30 s)

| | RMS | nejhlasitější 1 s | špička | ořez |
|---|---|---|---|---|
| FL | −21.6 | −11.6 | −0.9 | 0 |
| FR | −22.0 | −12.2 | −1.1 | 0 |
| LFE | −23.1 | −12.6 | −3.7 | 0 |

## Postup ladění

1. **Ověřit LFE kanál** – `scripts/tones.py lfe lfe.wav` a přehrát 3kanálově; sub musí hučet z červeného cinche.
2. **Srovnat hlasitost sub/sloupy** na poslechovém místě – `scripts/tones.py align a.wav --minutes 3 --lead 20` (2 s sloupy / 2 s sub na reálné úrovni, jakou sub dostává z hudby). Točit jen knobem subu. **Ladit tam, kde se poslouchá** – u okna je basů mnohem víc než u postele/stolu.
3. **Fáze** – `scripts/tones.py phase p.wav --freq 90` přehrát při 0° a 180°, nechat hlasitější. Smysl má až po kroku 2; když sub sloupy přehlušuje, rozdíl není slyšet.

Pomocné skripty:
- `scripts/selftest.sh` – potichu ověří nainstalovaný režim (kam jdou basy, výšky, centr).
- `scripts/measure-lfe-response.sh 100 200` – potichu porovná hodnoty PipeWire `lfe-cutoff` (2.1).
- `scripts/record-levels.sh 30` – změří úrovně a ořez toho, co právě hraje.

## Měření z postele (telefon OnePlus Nord 3, Sound Meter, bez vážení A)

Krokové tóny 8 s, stereo cestou jako hudba (sloupy + sub), Penta ~1 hodina.

| Hz | 30 | 35 | 40 | 45 | 50 | 60 | 70 | 80 | 90 | 100 | 120 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| EQ −4@70, −6@120 | 64 | 69 | 70 | 67 | 62 | 65 | **73** | 68 | 67 | 66 | **72,5** |
| EQ −9@70, −10@120 | 66 | 70 | 71 | 67,8 | 63 | 64 | 68 | 67 | 66,5 | 65 | 68,5 |

- 70 a 120 Hz srovnané (±2 dB = přesnost telefonu).
- 35–40 Hz +4–5 dB (zesílení místností) – nejdřív ponecháno. Po hodinách poslechu „hluboce dunělo“ → přeměřeno **mikrofonem** (Focusrite Solo + CM25, `scripts/mereni-mikrofonem.py`, krokový sinus 1/24 okt., opakovatelnost ±0,1 dB): 28–42 Hz +5–9 dB, 53–58 Hz +8 dB nad úrovní 60–100 Hz → **38 Hz −7 dB Q2** a **56 Hz −5 dB Q8**. Teď 27–75 Hz v ±2 dB (jen 45–52 Hz díra −3 až −5). Zbývá 106–131 Hz +5–7 dB (zatím nechané). Data a graf v `mereni/`.
- 50 Hz díra −3 dB – EQ nezvedá (minimum místnosti), řešitelné jen přesunem subu/postele.
- Sub uprostřed stěny je ve čtvercové místnosti dobrá poloha (roh by módy zesílil) – nestěhováno.

### Finální srovnání po EQ (Penta 12 h, telefon)

| | sub | sloupy |
|---|---|---|
| místo 1 na posteli | 62,5 dB | 62,5 dB |
| místo 2 na posteli | 64 dB | 61 dB |

Fáze (telefon uprostřed postele):

| | 80 Hz | 100 Hz |
|---|---|---|
| 0° | 60 dB | 60 dB |
| **180°** | **68 dB** | **63 dB** |

→ fáze **180°** (+8 dB na 80 Hz, +3 dB na 100 Hz = sub a sloupy se na dělení sčítají).

## Rušení ze sloupů v tichu

- Příčina: tuned nastavuje `snd_hda_intel power_save = 10` → po 10 s ticha PipeWire zavře výstup a kodek se uspí; citlivá Penta pak zesiluje rušení z nezatíženého výstupu.
- Ověřeno: 60 s digitálního ticha rušení odstranilo.
- Řešení: WirePlumber výstup neuspává (`session.suspend-timeout-seconds = 0`), kodek zůstává zapnutý. Bez sudo.
- Kabely zapojené vzadu do desky (ASUS ROG Strix B550-F Gaming, SupremeFX S1220A).

## Software vs. interní crossover na subu

Zvolen **softwarový** (PipeWire) + Subwoofer Direct:
- PipeWire nejde nastavit „bez filtru“: `lfe-cutoff = 0` znamená žádné LFE. Interní crossover by tedy vždy byl druhý filtr v řadě; aby nepřekážel, musel by být PipeWire na vysoké hodnotě (~400+) a do subu by šlo i to, co tam nepatří.
- Softwarové dělení je změřené a opakovatelné; knob na subu nemá přesnou stupnici.
- Prakticky by dobře nastavené obojí znělo podobně – rozhodující je hlasitost, fáze a umístění subu, ne typ filtru.

## Otevřené body

- Případně přesnější měření: USB měřicí mikrofon (UMIK-1) + REW.
- LFE stopa u filmů je na +3 dB (kino norma +10 dB); výš jen s ohledem na limiter.

## Zdroje

- [Sound & Vision – Mythos Four HT Labs Measures](https://www.soundandvision.com/content/definitive-technology-mythos-four-speaker-system-ht-labs-measures)
