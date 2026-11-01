<div align="center">

# MSX1 su Tang Nano 20K

### Un computer MSX1 in Verilog per la Sipeed Tang Nano 20K (Gowin GW2AR-18C)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![HDL](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18C-orange.svg)](https://www.gowinsemi.com/)
[![Board](https://img.shields.io/badge/Board-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

**Leggi in:** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · [Français](README.fr.md)

</div>

---

## Stato

| Verifica | Risultato |
|---|---|
| Sintesi + place & route (Gowin EDA 1.9.12) | ✅ bitstream generato, timing rispettato (Fmax 54 MHz per un progetto a 27 MHz) |
| Simulazione del sistema (Icarus Verilog, `sim/run.sh`) | ✅ superata: RAM, stack, VRAM, immagine del VDP, sprite, PSG, PPI, tastiera, interrupt |
| Avvio di C-BIOS su hardware reale | ⏳ **non ancora testato** |

Il progetto si compila e si simula, ma non è ancora stato eseguito su una
scheda. Le segnalazioni di chi lo prova sono molto gradite (aprite una Issue).

## Cosa contiene

| Parte | Implementazione |
|---|---|
| CPU | Z80 a 3,579545 MHz — core [tv80](https://github.com/hutch31/tv80) (porting Verilog del T80, MIT). Uno stato di attesa su M1, come su un vero MSX. |
| Video | TMS9918A: Graphics I, Graphics II, Multicolor, Testo. 32 sprite (8×8/16×16, ingranditi, early clock), 4 per riga, flag del 5° sprite e di collisione. |
| Uscita video | HDMI/DVI 720×480p 59,94 Hz. L'immagine 256×192 viene raddoppiata a 512×384 e centrata. |
| Audio | AY-3-8910 (3 toni, rumore, inviluppo) + click dei tasti, uscita sigma-delta (PDM) su 1 pin |
| PPI | i8255: selezione slot, matrice tastiera, LED CAPS, click |
| ROM | 48 KB in block RAM, slot 0 (C-BIOS principale + logo, oppure BIOS+BASIC di un MSX1) |
| RAM | 64 KB nella SDRAM integrata del GW2AR, slot 3 |
| Tastiera | PS/2, mappata sulla matrice internazionale MSX |
| microSD | porta SPI semplice (il protocollo della scheda lo gestisce il software MSX; ancora nessun driver disco) |

## Hardware

- Sipeed Tang Nano 20K
- Monitor/TV HDMI (che accetti 720×480p)
- Tastiera PS/2 (o una tastiera USB che parli ancora PS/2, con adattatore)
- Audio: un filtro RC sul pin audio (es. 1 kΩ + 10 nF) e un condensatore di accoppiamento (es. 1 µF) verso un amplificatore
- Opzionale: scheda microSD

## Pin

Tutto in [constraints/tang_nano_20k.cst](constraints/tang_nano_20k.cst).

| Segnale | Pin | Note |
|---|---|---|
| Clock 27 MHz | 4 | sulla scheda |
| Reset (S1) | 88 | pulsante della scheda |
| LED 0–5 | 15–20 | CAPS, SD, HALT, SDRAM non pronta, battito, reset |
| HDMI | 33–40 | connettore della scheda |
| microSD | 81–84 | slot della scheda |
| PS/2 clock | 76 | **connettore laterale — verificare prima di collegare** |
| PS/2 dati | 77 | **connettore laterale — verificare prima di collegare** |
| Audio PDM | 75 | **connettore laterale — verificare prima di collegare** |

La Tang Nano 20K non ha connettori PMOD. I pin PS/2 e audio sono GPIO liberi
a 3,3 V sui connettori laterali; verificateli con il pinout Sipeed della
revisione della vostra scheda e modificate il `.cst` se serve. Le tastiere
PS/2 sono dispositivi a 5 V: la maggior parte funziona a 3,3 V; altrimenti
usate un traslatore di livello.

## Per iniziare

### 1. Creare l'immagine della ROM

La ROM non è nel repository. [C-BIOS](https://cbios.sourceforge.net/) è un BIOS MSX libero:

```bash
python3 tools/make_rom.py cbios_main_msx1.rom cbios_logo_msx1.rom
```

Oppure, se possedete la ROM di sistema di un MSX1 (32 KB, BIOS + BASIC):

```bash
python3 tools/make_rom.py msx1.rom
```

Entrambi scrivono `bios/msx_rom.mem`, che viene letto dal build.

### 2. Compilare

Con l'IDE Gowin EDA: aprite `msx1_tang20k.gprj` ed eseguite *Place & Route*.
In *Project → Configuration → Dual-Purpose Pin*, abilitate MSPI, SSPI, READY e DONE come I/O normali.

Oppure da riga di comando (con Gowin EDA installato):

```bash
gw_sh scripts/build.tcl
```

Il bitstream è `impl/pnr/msx1_tang20k.fs`.

### 3. Programmare la scheda

Con [openFPGALoader](https://github.com/trabucayre/openFPGALoader):

```bash
openFPGALoader -b tangnano20k impl/pnr/msx1_tang20k.fs
```

Aggiungete `-f` per scriverlo nella flash e mantenerlo dopo lo spegnimento.
Funziona anche il Gowin Programmer.

### 4. Simulare (opzionale)

Servono [Icarus Verilog](https://steveicarus.github.io/iverilog/) e Python 3:

```bash
sh sim/run.sh
```

Esegue un piccolo programma Z80 di test ([sim/make_test_rom.py](sim/make_test_rom.py))
su tutta la macchina, con un modello della SDRAM, e salva un fotogramma HDMI
in `sim/frame.ppm`. Lo stesso test gira su GitHub Actions a ogni push.

## Come funziona

### Clock

```
quarzo 27 MHz ─► rPLL ─► 135 MHz ──────────────► OSER10 (serializzatori HDMI)
                            └─► CLKDIV /5 ─► 27 MHz  = clock pixel = clock di sistema
                                               ├─ clock enable della CPU  3,579545 MHz
                                               ├─ clock enable del PSG    1,789773 MHz
                                               └─ clock della SDRAM (invertito)
```

Tutto gira in un unico dominio di clock a 27 MHz, senza attraversamenti tra
domini. Il clock enable della CPU deriva da un accumulatore di fase, quindi
la frequenza media è esattamente 3,579545 MHz.

### Mappa di memoria (slot primari, scelti con la porta A del PPI / I/O A8h)

| Pagina | Slot 0 | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|---|
| 0000–3FFF | ROM | – | – | RAM |
| 4000–7FFF | ROM | – | – | RAM |
| 8000–BFFF | ROM (logo / BASIC) | – | – | RAM |
| C000–FFFF | – | – | – | RAM |

Lo spazio vuoto si legge come FFh. Gli slot espansi non sono implementati.

### Mappa di I/O

| Porta | Dispositivo |
|---|---|
| 40h–41h | SPI della microSD (dati, controllo/stato) — vedere [src/sdcard/sd_spi.v](src/sdcard/sd_spi.v) |
| 98h–99h | VDP (dati VRAM, controllo/stato) |
| A0h–A2h | PSG (indirizzo, scrittura, lettura) |
| A8h–ABh | PPI (slot, tastiera, porta C, controllo) |

### SDRAM

Il GW2AR-18C contiene una SDRAM da 64 Mbit nello stesso package. I suoi pin
hanno nomi fissi (`O_sdram_*`, `IO_sdram_dq`) e non richiedono vincoli.
[src/memory/sdram_ctrl.v](src/memory/sdram_ctrl.v) esegue un byte per accesso
(ACTIVATE + READ/WRITE con auto-precharge, CAS latency 2) e fa il refresh ogni
14 µs. La CPU resta in WAIT finché ogni accesso non termina. In simulazione un
accesso rientra nel normale ciclo di bus dello Z80, quindi la RAM non aggiunge
stati di attesa (solo il primissimo accesso attende ~0,3 ms l'avvio della SDRAM).

### VDP

I 16 KB di VRAM sono una block RAM a doppia porta (la CPU su una porta, il
renderer sull'altra). Ogni riga TMS viene disegnata in un piccolo buffer di
riga durante le due righe HDMI precedenti (prima lo sfondo, poi fino a 4
sprite), così la VRAM viene letta un byte per ciclo invece di molti insieme.

### Risorse FPGA (Gowin EDA 1.9.12)

| Risorsa | Usate | Disponibili |
|---|---|---|
| Logica (LUT/ALU) | 5.235 | 20.736 (26%) |
| Registri | 1.666 | 15.915 (11%) |
| Block RAM (BSRAM) | 33 | 46 (72%) |
| rPLL | 1 | 2 |

## File

```
src/top.v                  livello superiore, decodifica I/O, clock/reset
src/pll_135m.v             rPLL 27→135 MHz + CLKDIV /5
src/cpu/tv80_msx.v         wrapper dello Z80 con clock enable
src/cpu/tv80/              core tv80 (MIT, Guy Hutchison)
src/memory/slot_ctrl.v     decodificatore degli slot primari
src/memory/sdram_ctrl.v    controller della SDRAM integrata
src/vdp/tms9918a.v         TMS9918A
src/video/                 encoder TMDS + serializzatore HDMI
src/psg/ay8910.v           AY-3-8910
src/ppi/ppi8255.v          i8255
src/keyboard/              ricevitore PS/2 + mappa tasti MSX
src/sdcard/sd_spi.v        porta SPI dello slot microSD
src/audio/pdm_dac.v        DAC audio sigma-delta
constraints/               vincoli dei pin
scripts/build.tcl          build da riga di comando
sim/                       testbench, modello SDRAM, programma di test
tools/make_rom.py          genera bios/msx_rom.mem
```

## Limitazioni note

- Non ancora testato su hardware (vedere Stato).
- Nessuno slot cartuccia, nessuno slot espanso, nessun driver Nextor/MSX-DOS per la SD.
- Nessun joystick né interfaccia cassetta.
- VDP: nessun limite di temporizzazione sugli accessi alla VRAM (il software
  che dipende da una VRAM lenta può comportarsi diversamente); il bit 4/16 KB è ignorato.
- I tasti PS/2 seguono i tasti MSX (layout internazionale), non quelli del PC.

## Prossimi passi

1. Avviare C-BIOS su una scheda e correggere ciò che emerge.
2. Caricamento di ROM cartuccia (da SD o flash) nello slot 1.
3. Driver Nextor per la porta SD.
4. Joystick (DB9) e ingresso audio cassetta.

## Contribuire

Vedere [CONTRIBUTING.md](CONTRIBUTING.md). Eseguite `sh sim/run.sh` prima di
inviare una modifica all'RTL.

## Crediti

- [tv80](https://github.com/hutch31/tv80) di Guy Hutchison, basato su T80 di Daniel Wallner (MIT)
- Il team di [C-BIOS](https://cbios.sourceforge.net/), per un BIOS MSX libero
- Sipeed e la comunità Tang Nano per la documentazione della scheda

## Riferimenti

- [MSX2 Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) (copre anche l'hardware MSX1)
- [Manuale del TMS9918A](http://www.unige.ch/medecine/nouspikel/ti99/tms9918a.htm)
- [Wiki della Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- [Documentazione del Gowin GW2AR-18](https://www.gowinsemi.com/en/support/database/)
