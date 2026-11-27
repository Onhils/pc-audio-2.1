# PC audio 2.1 – Mythos Four + Velodyne SPL II

Nastavení a poznatky z ladění 2.1 sestavy na Fedora / PipeWire (2026-11-25).

## Sestava

```
PC (Realtek ALC1220, profil Analog Surround 2.1)
 ├─ zelený jack (FL/FR) ──► Ceratec Penta ──► 2× Definitive Technology Mythos Four (sloupy)
 └─ oranžový jack ──┬─ hrot  / bílý cinch  = Center (v 2.1 prázdný)
                    └─ kroužek / červený cinch = LFE ──► Velodyne SPL Series II 1000W (vstup LFE)
```

- Mythos Four jsou štíhlé sloupy, basy mají omezené: Sound & Vision naměřil **−3 dB @ 104 Hz, −6 dB @ 90 Hz** (výrobce udává 35 Hz – 30 kHz, měření tomu neodpovídá).
- **Penta knob ovládá jen sloupy** – sub jde z PC napřímo. Penta proto zůstává na pevné poloze a celková hlasitost se ovládá v PC (mění obojí stejně).

### Hlasitost (filmy mají různou výchozí hlasitost)

1. Pentu nastavit „nahoru“ na pevnou polohu: nejtišší film při hlasitosti PC 100 % = nejhlasitěji, jak kdy chceme poslouchat.
2. Při této poloze Penty jednou srovnat sub z postele (`scripts/tones.py align`).
3. Dál už jen hlasitost v PC (klávesy / GNOME) – sloupy i sub se mění stejně a poměr drží. Platí pro filmy i hudbu se subem.
4. mpv má `volume-max=100` – zesílení nad 100 % by šlo za limiter a mohlo ořezávat.

Downmix v mpv filmy ztlumí cca o 6 dB (rezerva proti ořezu) – proto je potřeba Penta výš než dřív.

## Místnost

```
              stěna se sloupy
   ┌────────────────────────────────────┐
   │ [stůl]  ▮Mythos   [SUB]   Mythos▮  │
   │                                    │
   │                                  okno
   │                                    │
dveře                                   │
   │            [ postel ]              │
   └────────────────────────────────────┘
```

- Čtvercová místnost → módy v obou osách na stejných frekvencích, velké rozdíly basů podle místa (u okna hodně, u dveří málo).
- Hlavní poslechové místo: **postel** (filmy, projektor Optoma UHD40 na stěnu se sloupy).

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
| PipeWire | `channelmix.upmix = true`, `channelmix.lfe-cutoff = 200` (reálně ~100 Hz) – [`config/pipewire`](config/pipewire) |
| mpv | 5.1/7.1 → stereo downmix (centr/surroundy −3 dB, LFE stopa +3 dB) + `alimiter` 0.9; basy do subu pak dělá PipeWire stejně jako u hudby – [`config/mpv/mpv.conf`](config/mpv/mpv.conf) |
| Velodyne | vstup **LFE**, **Subwoofer Direct** (bez interního crossoveru), fáze **180°**, hlasitost srovnaná se sloupy na 90 Hz z postele |
| Ceratec Penta | pevná poloha knobu |
| EasyEffects | nepoužívá se (smazáno) |

Instalace: `./install.sh`

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
- `scripts/measure-lfe-response.sh 100 200 250` – potichu změří LFE odezvu pro dané hodnoty `lfe-cutoff`.
- `scripts/record-levels.sh 30` – změří úrovně a ořez toho, co právě hraje.

## Software vs. interní crossover na subu

Zvolen **softwarový** (PipeWire) + Subwoofer Direct:
- PipeWire nejde nastavit „bez filtru“: `lfe-cutoff = 0` znamená žádné LFE. Interní crossover by tedy vždy byl druhý filtr v řadě; aby nepřekážel, musel by být PipeWire na vysoké hodnotě (~400+) a do subu by šlo i to, co tam nepatří.
- Softwarové dělení je změřené a opakovatelné; knob na subu nemá přesnou stupnici.
- Prakticky by dobře nastavené obojí znělo podobně – rozhodující je hlasitost, fáze a umístění subu, ne typ filtru.

## Otevřené body

- Basy na posteli jsou slabé i po přidání subu → pravděpodobně módové minimum (čtvercová místnost). Plán: pomalý sweep 30–120 Hz (`scripts/tones.py sweep`) z postele, pak zkusit posunout sub o 50–100 cm ze středu stěny / blíž k rohu a porovnat.
- Případně ekvalizace jen LFE (filter-chain v PipeWire) na zkrocení dunivého módu.
- LFE stopa u filmů je na +3 dB (kino norma +10 dB); výš jen s ohledem na limiter.

## Zdroje

- [Sound & Vision – Mythos Four HT Labs Measures](https://www.soundandvision.com/content/definitive-technology-mythos-four-speaker-system-ht-labs-measures)
