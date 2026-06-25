<div align="center">

# 🖥️ MSX1 sur Tang Nano 20K

### Un ordinateur MSX1 entièrement fonctionnel implémenté en Verilog sur une carte FPGA à 20€

[![Licence: MIT](https://img.shields.io/badge/Licence-MIT-yellow.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18-orange.svg)](https://www.gowinsemi.com/)

**Lire dans d'autres langues:** [🇺🇸 English](README.md) · [🇧🇷 Português](README.pt-BR.md) · [🇪🇸 Español](README.es.md) · [🇮🇹 Italiano](README.it.md)

</div>

---

## 🎮 Qu'est-ce que le MSX ?

Le **MSX** est une architecture d'ordinateur personnel standardisée créée en **1983** par **ASCII Corporation** et **Microsoft**, largement adoptée au Japon, aux Pays-Bas, en France, au Brésil et au Moyen-Orient.

Le standard MSX définissait un matériel commun afin que les logiciels fonctionnent sur n'importe quelle machine MSX, quel que soit le fabricant (Philips, Sony, Panasonic, Yamaha…). En France, les machines Philips VG-8020 et VG-8235 étaient populaires.

### Spécifications du MSX1

| Composant | Spécification |
|-----------|--------------|
| CPU | Zilog Z80A @ 3,579 MHz |
| Vidéo | Texas Instruments TMS9918A |
| Audio | General Instrument AY-3-8910 |
| RAM | Minimum 8Ko (nous implémentons 64Ko) |
| ROM | 32Ko BIOS + 16Ko BASIC |
| VRAM | 16Ko |
| Couleurs | 15 + transparent |
| Résolution | 256×192 (graphiques) / 40×24 (texte) |
| Sprites | 32 sprites, 8×8 ou 16×16 |

---

## ⚡ Qu'est-ce qu'un FPGA ?

Un **FPGA** (Field-Programmable Gate Array — Réseau de Portes Programmable sur le Terrain) est une puce que vous pouvez programmer pour **devenir n'importe quel circuit numérique** — y compris un ordinateur complet des années 80.

Au lieu d'un logiciel s'exécutant sur un processeur fixe, un FPGA implémente la **logique matérielle réelle** en parallèle. Chaque composant du MSX (CPU, VDP, PSG, PPI) fonctionne simultanément, exactement comme dans la machine d'origine.

---

## 🛒 Matériel Nécessaire

| Composant | Utilisation | Coût (approx.) |
|-----------|-------------|----------------|
| Tang Nano 20K | Carte FPGA principale | ~20€ |
| Clavier PS/2 (ou adaptateur USB→PS/2) | Saisie | ~5€ |
| Moniteur ou TV HDMI | Affichage | — |
| Carte microSD | Stockage | ~3€ |
| Breadboard + fils jumper | Connexions | ~3€ |
| 2× résistances 4,7kΩ | Pull-up PS/2 | ~0,10€ |
| 1× 100Ω + 1× 10µF | Filtre audio | ~0,20€ |

---

## 🏗️ Architecture du Système

### 🔵 CPU Z80

Le **Zilog Z80** est le cœur du MSX. Notre implémentation est une **machine à états multi-cycles** en Verilog pur.

#### Registres:

```
Banque Principale:    Banque Alternée (EXX):
┌────┬────┐           ┌─────┬─────┐
│ A  │ F  │ ◀────────▶│  A' │  F' │  (EX AF,AF')
├────┼────┤           ├─────┼─────┤
│ B  │ C  │ ◀────────▶│  B' │  C' │
├────┼────┤           ├─────┼─────┤  (EXX)
│ D  │ E  │ ◀────────▶│  D' │  E' │
├────┼────┤           ├─────┼─────┤
│ H  │ L  │ ◀────────▶│  H' │  L' │
└────┴────┘           └─────┴─────┘
```

#### Modes d'Interruption:

| Mode | Fonctionnement | Usage MSX |
|------|---------------|-----------|
| IM 0 | Le périphérique met RST sur le bus | Rare |
| **IM 1** | **Saut à l'adresse 0x0038** | **VSync VDP (60 Hz)** |
| IM 2 | Table de sauts via registre I | Logiciels avancés |

---

### 🟢 VDP TMS9918A

#### Modes Vidéo:

| Mode | BASIC | Description |
|------|-------|-------------|
| Screen 0 | `SCREEN 0` | Texte 40×24 colonnes |
| Screen 1 | `SCREEN 1` | Graphiques I, tuiles 32×24 |
| Screen 2 | `SCREEN 2` | Bitmap 256×192 px (jeux) |
| Screen 3 | `SCREEN 3` | Multicouleur 64×48 blocs |

#### Palette 15 Couleurs:

```
 0: Transparent    4: Bleu foncé     8: Rouge moyen   12: Vert foncé
 1: Noir           5: Bleu clair     9: Rouge clair   13: Magenta
 2: Vert moyen     6: Rouge foncé   10: Jaune foncé   14: Gris
 3: Vert clair     7: Cyan          11: Jaune clair   15: Blanc
```

---

### 🔴 PSG AY-3-8910

3 canaux d'onde carrée + générateur de bruit LFSR 17 bits + enveloppe.

```
Formule de fréquence : f = f_clk / (16 × N)
f_clk = 1,789 MHz (standard MSX)
Exemple La (440 Hz) : N ≈ 254
```

---

### 🟠 Système de Slots Mémoire

```
Page 3 (0xC000–0xFFFF): PPI_A[7:6] → RAM (Slot 3)
Page 2 (0x8000–0xBFFF): PPI_A[5:4] → BASIC ROM (Slot 0)
Page 1 (0x4000–0x7FFF): PPI_A[3:2] → BIOS ROM haute (Slot 0)
Page 0 (0x0000–0x3FFF): PPI_A[1:0] → BIOS ROM basse (Slot 0)
```

---

## ⏱️ Architecture d'Horloge

```
Cristal 27 MHz
    ├── PLL1 × 4 = 108 MHz (système)
    │       ├── ÷30 = 3,6 MHz → CPU Z80
    │       ├── ÷60 = 1,8 MHz → PSG
    │       └── ÷4  = 27 MHz  → Pixel VDP
    └── PLL2 × 5 = 135 MHz → TMDS HDMI série
```

---

## 🚀 Démarrage Rapide

### Étape 1 — Installer Gowin EDA
🔗 https://www.gowinsemi.com/en/support/download_eda/

### Étape 2 — Obtenir le BIOS (C-BIOS, open source)

```bash
wget https://sourceforge.net/projects/cbios/files/cbios-0.29a.zip
unzip cbios-0.29a.zip
python3 tools/convert_rom.py cbios_main_msx1.rom bios/cbios_main_msx1.mem
```

### Étape 3 — Cloner et compiler

```bash
git clone https://github.com/VOTRE_UTILISATEUR/msx1-tang-nano-20k.git
cd msx1-tang-nano-20k
```

Ouvrir `msx1_tang20k.gprj` dans Gowin EDA → Synthesize → Place & Route → Program.

---

## 🔌 Connexions Matérielles

### Clavier PS/2 (PMOD1)

```
PS/2 Pin 5 (CLK)  ── 4,7kΩ ──┬── PMOD1 Pin 1
                              └── 3,3V (pull-up)

PS/2 Pin 1 (DATA) ── 4,7kΩ ──┬── PMOD1 Pin 2
                              └── 3,3V (pull-up)
```

> ⚠️ **Les résistances de pull-up 4,7kΩ sont obligatoires !**

### Audio (PMOD1 Pin 3)

```
Pin FPGA ── 100Ω ──┬── Jack 3,5mm (+)
                  10µF
                  GND ── Jack 3,5mm (-)
```

---

## 📊 Carte des Ports I/O

| Port | Dispositif | Accès | Description |
|------|------------|-------|-------------|
| `0x98` | VDP | R/W | Données VRAM |
| `0x99` | VDP | R/W | Registre / Statut |
| `0xA0`–`0xA2` | PSG | R/W | Son AY-3-8910 |
| `0xA8`–`0xAB` | PPI | R/W | Clavier + slots |
| `0x40`–`0x47` | SD Card | R/W | Carte SD SPI |

---

## ⚠️ Limitations Connues

| Fonctionnalité | État |
|----------------|------|
| CPU Z80 complète | ✅ Tous les groupes |
| Écrans 0–3 | ✅ Implémentés |
| Sprites | ✅ 32 sprites |
| PSG (son) | ✅ 3 canaux |
| Clavier PS/2 | ✅ Touches principales |
| HDMI 720×480p | ✅ Fonctionnel |
| SD Card | ✅ Lecture SPI |
| MSX-DOS / Nextor | ❌ Non implémenté |
| Slot cartouche | ❌ Retourne 0xFF |
| Port joystick | ❌ Non implémenté |

---

<div align="center">

**Fait avec ❤️ pour la communauté MSX et FPGA**

⭐ Si ce projet vous a aidé, mettez-lui une étoile sur GitHub ! ⭐

</div>
