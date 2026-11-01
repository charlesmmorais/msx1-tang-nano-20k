> ⚠️ **Questa traduzione non è aggiornata.** Il progetto è stato riscritto (CPU tv80, SDRAM, nuovo VDP, nuovi pin). Vedere [README.md](README.md) (inglese) o [README.pt-BR.md](README.pt-BR.md) per le informazioni corrette.

<div align="center">

# 🖥️ MSX1 su Tang Nano 20K

### Un computer MSX1 completamente funzionante implementato in Verilog su una scheda FPGA da 20€

[![Licenza: MIT](https://img.shields.io/badge/Licenza-MIT-yellow.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18-orange.svg)](https://www.gowinsemi.com/)

**Leggi in altre lingue:** [🇺🇸 English](README.md) · [🇧🇷 Português](README.pt-BR.md) · [🇪🇸 Español](README.es.md) · [🇫🇷 Français](README.fr.md)

</div>

---

## 🎮 Cos'è il MSX?

Il **MSX** è un'architettura standardizzata di personal computer creata nel **1983** da **ASCII Corporation** e **Microsoft**, ampiamente adottata in Giappone, Paesi Bassi, Italia, Brasile e Medio Oriente.

Lo standard MSX definiva hardware comune affinché il software funzionasse su qualsiasi macchina MSX, indipendentemente dal produttore (Sony, Philips, Panasonic, Yamaha, Sanyo…). In Italia era diffuso con modelli Philips e Sony.

### Specifiche MSX1

| Componente | Specifiche |
|-----------|-----------|
| CPU | Zilog Z80A @ 3,579 MHz |
| Video | Texas Instruments TMS9918A |
| Audio | General Instrument AY-3-8910 |
| RAM | Minimo 8KB (implementiamo 64KB) |
| ROM | 32KB BIOS + 16KB BASIC |
| VRAM | 16KB |
| Colori | 15 + trasparente |
| Risoluzione | 256×192 (grafica) / 40×24 (testo) |
| Sprite | 32 sprite, 8×8 o 16×16 |

---

## ⚡ Cos'è un FPGA?

Un **FPGA** (Field-Programmable Gate Array — Array di Gate Programmabile sul Campo) è un chip che puoi programmare per **diventare qualsiasi circuito digitale** — incluso un computer completo degli anni '80.

Invece di software che gira su un processore fisso, un FPGA implementa la **logica hardware reale** in parallelo. Ogni componente dell'MSX (CPU, VDP, PSG, PPI) funziona simultaneamente, esattamente come nella macchina originale.

---

## 🛒 Componenti Necessari

| Componente | Uso | Costo (aprox.) |
|-----------|-----|----------------|
| Tang Nano 20K | Scheda FPGA principale | ~20€ |
| Tastiera PS/2 (o adattatore USB→PS/2) | Input | ~5€ |
| Monitor o TV HDMI | Display | — |
| Scheda microSD | Archiviazione | ~3€ |
| Breadboard + cavi jumper | Connessioni | ~3€ |
| 2× resistenze 4,7kΩ | Pull-up PS/2 | ~0,10€ |
| 1× 100Ω + 1× 10µF | Filtro audio | ~0,20€ |

---

## 🏗️ Architettura del Sistema

### 🔵 CPU Z80

Il **Zilog Z80** è il cuore di ogni computer MSX. La nostra implementazione è una **macchina a stati multi-ciclo** scritta interamente in Verilog.

#### Cicli Macchina:

```
FETCH (M1):  ┌─T1─┬─T2─┬─T3─┬─T4─┐
              │ PC→ │    │Rfsh│    │  Legge l'opcode dalla memoria
              └────┴────┴────┴────┘

LETTURA:     ┌─T1─┬─T2─┬─T3─┐
              │Ind.│    │Dato│
              └────┴────┴────┘
```

#### Gruppi di Istruzioni:

| Prefisso | Gruppo | Esempi |
|----------|--------|--------|
| (nessuno) | Set principale | `LD A,B` `ADD A,n` `JP nn` |
| `CB` | Operazioni bit | `RLC r` `BIT b,r` `SET b,r` |
| `DD` | Registro IX | `LD IX,nn` `LD r,(IX+d)` |
| `FD` | Registro IY | `LD IY,nn` `LD (IY+d),r` |
| `ED` | Esteso | `LDIR` `LDDR` `IM 2` `ADC HL,rp` |

---

### 🟢 VDP TMS9918A

#### Modalità Video:

| Modalità | BASIC | Descrizione |
|----------|-------|-------------|
| Screen 0 | `SCREEN 0` | Testo 40×24 colonne |
| Screen 1 | `SCREEN 1` | Grafica I, tile 32×24 |
| Screen 2 | `SCREEN 2` | Bitmap 256×192 px (giochi) |
| Screen 3 | `SCREEN 3` | Multicolore 64×48 blocchi |

#### Tavolozza 15 Colori:

```
 0: Trasparente    4: Blu scuro      8: Rosso medio   12: Verde scuro
 1: Nero           5: Blu chiaro     9: Rosso chiaro  13: Magenta
 2: Verde medio    6: Rosso scuro   10: Giallo scuro  14: Grigio
 3: Verde chiaro   7: Ciano         11: Giallo chiaro 15: Bianco
```

---

### 🔴 PSG AY-3-8910

3 canali ad onda quadra + generatore di rumore LFSR 17 bit + inviluppo.

```
Formula frequenza: f = f_clk / (16 × N)
f_clk = 1,789 MHz (standard MSX)
Esempio La (440 Hz): N ≈ 254
```

---

### 🟠 Sistema di Slot Memoria

```
Pagina 3 (0xC000–0xFFFF): PPI_A[7:6] → RAM (Slot 3)
Pagina 2 (0x8000–0xBFFF): PPI_A[5:4] → BASIC ROM (Slot 0)
Pagina 1 (0x4000–0x7FFF): PPI_A[3:2] → BIOS ROM alta (Slot 0)
Pagina 0 (0x0000–0x3FFF): PPI_A[1:0] → BIOS ROM bassa (Slot 0)
```

---

## ⏱️ Architettura del Clock

```
Cristallo 27 MHz
    ├── PLL1 × 4 = 108 MHz (sistema)
    │       ├── ÷30 = 3,6 MHz → CPU Z80
    │       ├── ÷60 = 1,8 MHz → PSG
    │       └── ÷4  = 27 MHz  → Pixel VDP
    └── PLL2 × 5 = 135 MHz → TMDS HDMI seriale
```

---

## 🚀 Per Iniziare

### Passo 1 — Installare Gowin EDA
🔗 https://www.gowinsemi.com/en/support/download_eda/

### Passo 2 — Ottenere il BIOS (C-BIOS, open source)

```bash
wget https://sourceforge.net/projects/cbios/files/cbios-0.29a.zip
unzip cbios-0.29a.zip
python3 tools/convert_rom.py cbios_main_msx1.rom bios/cbios_main_msx1.mem
```

### Passo 3 — Clonare e compilare

```bash
git clone https://github.com/TUO_UTENTE/msx1-tang-nano-20k.git
cd msx1-tang-nano-20k
```

Aprire `msx1_tang20k.gprj` in Gowin EDA → Synthesize → Place & Route → Program.

---

## 🔌 Connessioni Hardware

### Tastiera PS/2 (PMOD1)

```
PS/2 Pin 5 (CLK)  ── 4,7kΩ ──┬── PMOD1 Pin 1
                              └── 3,3V (pull-up)

PS/2 Pin 1 (DATA) ── 4,7kΩ ──┬── PMOD1 Pin 2
                              └── 3,3V (pull-up)
```

> ⚠️ **Le resistenze di pull-up 4,7kΩ sono obbligatorie!**

### Audio (PMOD1 Pin 3)

```
Pin FPGA ── 100Ω ──┬── Jack 3,5mm (+)
                  10µF
                  GND ── Jack 3,5mm (-)
```

---

## 📊 Mappa Porte I/O

| Porta | Dispositivo | Accesso | Descrizione |
|-------|-------------|---------|-------------|
| `0x98` | VDP | R/W | Dati VRAM |
| `0x99` | VDP | R/W | Registro / Stato |
| `0xA0`–`0xA2` | PSG | R/W | Audio AY-3-8910 |
| `0xA8`–`0xAB` | PPI | R/W | Tastiera + slot |
| `0x40`–`0x47` | SD Card | R/W | Scheda SD SPI |

---

## ⚠️ Limitazioni Note

| Funzionalità | Stato |
|--------------|-------|
| CPU Z80 completa | ✅ Tutti i gruppi |
| Schermi 0–3 | ✅ Implementati |
| Sprite | ✅ 32 sprite |
| PSG (audio) | ✅ 3 canali |
| Tastiera PS/2 | ✅ Tasti principali |
| HDMI 720×480p | ✅ Funzionante |
| SD Card | ✅ Lettura SPI |
| MSX-DOS / Nextor | ❌ Non implementato |
| Slot cartuccia | ❌ Ritorna 0xFF |
| Porta joystick | ❌ Non implementato |

---

## 📚 Riferimenti

- [MSX Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/)
- [C-BIOS](https://cbios.sourceforge.net/)
- [Tang Nano 20K Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

---

<div align="center">

**Realizzato con ❤️ per la comunità MSX e FPGA**

⭐ Se questo progetto ti ha aiutato, metti una stella su GitHub! ⭐

</div>
