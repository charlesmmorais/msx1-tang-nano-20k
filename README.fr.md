<div align="center">

# MSX1 sur Tang Nano 20K

### Un ordinateur MSX1 en Verilog pour la Sipeed Tang Nano 20K (Gowin GW2AR-18C)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![HDL](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18C-orange.svg)](https://www.gowinsemi.com/)
[![Board](https://img.shields.io/badge/Board-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

**Lire en :** [English](README.md) · [Português](README.pt-BR.md) · [Español](README.es.md) · [Italiano](README.it.md)

</div>

---

## État

| Vérification | Résultat |
|---|---|
| Synthèse + placement-routage (Gowin EDA 1.9.12) | ✅ bitstream généré, timing respecté (Fmax 54 MHz pour un design à 27 MHz) |
| Simulation du système (Icarus Verilog, `sim/run.sh`) | ✅ réussie : RAM, pile, VRAM, image du VDP, sprites, PSG, PPI, clavier, interruptions |
| Démarrage de C-BIOS sur le matériel réel | ⏳ **pas encore testé** |

Le design se compile et se simule, mais il n'a pas encore tourné sur une
carte. Les retours de ceux qui l'essaient sont les bienvenus (ouvrez une Issue).

## Contenu

| Élément | Implémentation |
|---|---|
| CPU | Z80 à 3,579545 MHz — cœur [tv80](https://github.com/hutch31/tv80) (portage Verilog du T80, MIT). Un état d'attente sur M1, comme sur un vrai MSX. |
| Vidéo | TMS9918A : Graphics I, Graphics II, Multicolor, Texte. 32 sprites (8×8/16×16, agrandis, early clock), 4 par ligne, drapeaux de 5e sprite et de collision. |
| Sortie vidéo | HDMI/DVI 720×480p 59,94 Hz. L'image de 256×192 est doublée en 512×384 et centrée. |
| Son | AY-3-8910 (3 tons, bruit, enveloppe) + clic clavier, sortie sigma-delta (PDM) sur 1 broche |
| PPI | i8255 : sélection de slot, matrice clavier, LED CAPS, clic |
| ROM | 48 Ko en block RAM, slot 0 (C-BIOS principal + logo, ou BIOS+BASIC d'un MSX1) |
| RAM | 64 Ko dans la SDRAM intégrée du GW2AR, slot 3 |
| Clavier | PS/2, associé à la matrice internationale du MSX |
| microSD | port SPI brut (le protocole de la carte est géré par le logiciel MSX ; pas encore de pilote disque) |

## Matériel

- Sipeed Tang Nano 20K
- Écran/TV HDMI (acceptant le 720×480p)
- Clavier PS/2 (ou un clavier USB qui parle encore PS/2, via un adaptateur)
- Audio : un filtre RC sur la broche audio (par ex. 1 kΩ + 10 nF) et un condensateur de liaison (par ex. 1 µF) vers un amplificateur
- Optionnel : carte microSD

## Broches

Tout est dans [constraints/tang_nano_20k.cst](constraints/tang_nano_20k.cst).

| Signal | Broche | Remarque |
|---|---|---|
| Horloge 27 MHz | 4 | sur la carte |
| Reset (S1) | 88 | bouton de la carte |
| LED 0–5 | 15–20 | CAPS, SD, HALT, SDRAM pas prête, battement, reset |
| HDMI | 33–40 | connecteur de la carte |
| microSD | 81–84 | lecteur de la carte |
| PS/2 horloge | 76 | **connecteur latéral — à vérifier avant de câbler** |
| PS/2 données | 77 | **connecteur latéral — à vérifier avant de câbler** |
| Audio PDM | 75 | **connecteur latéral — à vérifier avant de câbler** |

La Tang Nano 20K n'a pas de connecteur PMOD. Les broches PS/2 et audio sont
des GPIO 3,3 V libres sur les connecteurs latéraux ; vérifiez-les avec le
brochage Sipeed de votre révision de carte et modifiez le `.cst` si besoin.
Les claviers PS/2 sont des périphériques 5 V : la plupart fonctionnent en
3,3 V ; sinon, utilisez un adaptateur de niveau.

## Démarrage

### 1. Créer l'image ROM

La ROM n'est pas dans le dépôt. [C-BIOS](https://cbios.sourceforge.net/) est un BIOS MSX libre :

```bash
python3 tools/make_rom.py cbios_main_msx1.rom cbios_logo_msx1.rom
```

Ou, si vous possédez la ROM système d'un MSX1 (32 Ko, BIOS + BASIC) :

```bash
python3 tools/make_rom.py msx1.rom
```

Les deux écrivent `bios/msx_rom.mem`, que lit le build.

### 2. Compiler

Avec l'IDE Gowin EDA : ouvrez `msx1_tang20k.gprj` et lancez *Place & Route*.
Dans *Project → Configuration → Dual-Purpose Pin*, activez MSPI, SSPI, READY et DONE comme E/S normales.

Ou en ligne de commande (Gowin EDA installé) :

```bash
gw_sh scripts/build.tcl
```

Le bitstream est `impl/pnr/msx1_tang20k.fs`.

### 3. Programmer la carte

Avec [openFPGALoader](https://github.com/trabucayre/openFPGALoader) :

```bash
openFPGALoader -b tangnano20k impl/pnr/msx1_tang20k.fs
```

Ajoutez `-f` pour l'écrire en flash et le conserver après une coupure
d'alimentation. Le Gowin Programmer fonctionne aussi.

### 4. Simuler (optionnel)

Nécessite [Icarus Verilog](https://steveicarus.github.io/iverilog/) et Python 3 :

```bash
sh sim/run.sh
```

Il exécute un petit programme Z80 de test ([sim/make_test_rom.py](sim/make_test_rom.py))
sur toute la machine, avec un modèle de la SDRAM, et enregistre une image HDMI
dans `sim/frame.ppm`. Le même test tourne dans GitHub Actions à chaque push.

## Fonctionnement

### Horloges

```
quartz 27 MHz ─► rPLL ─► 135 MHz ──────────────► OSER10 (sérialiseurs HDMI)
                            └─► CLKDIV /5 ─► 27 MHz  = horloge pixel = horloge système
                                               ├─ clock enable du CPU  3,579545 MHz
                                               ├─ clock enable du PSG  1,789773 MHz
                                               └─ horloge de la SDRAM (inversée)
```

Tout tourne dans un seul domaine d'horloge à 27 MHz, sans passage entre
domaines. Le clock enable du CPU vient d'un accumulateur de phase, donc sa
fréquence moyenne est exactement 3,579545 MHz.

### Carte mémoire (slots primaires, choisis par le port A du PPI / E/S A8h)

| Page | Slot 0 | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|---|
| 0000–3FFF | ROM | – | – | RAM |
| 4000–7FFF | ROM | – | – | RAM |
| 8000–BFFF | ROM (logo / BASIC) | – | – | RAM |
| C000–FFFF | – | – | – | RAM |

L'espace vide se lit FFh. Les slots étendus ne sont pas implémentés.

### Carte des E/S

| Port | Périphérique |
|---|---|
| 40h–41h | SPI de la microSD (données, contrôle/état) — voir [src/sdcard/sd_spi.v](src/sdcard/sd_spi.v) |
| 98h–99h | VDP (données VRAM, contrôle/état) |
| A0h–A2h | PSG (adresse, écriture, lecture) |
| A8h–ABh | PPI (slots, clavier, port C, contrôle) |

### SDRAM

Le GW2AR-18C intègre une SDRAM de 64 Mbit dans le même boîtier. Ses broches
ont des noms fixes (`O_sdram_*`, `IO_sdram_dq`) et ne nécessitent pas de
contraintes. [src/memory/sdram_ctrl.v](src/memory/sdram_ctrl.v) fait un octet
par accès (ACTIVATE + READ/WRITE avec auto-precharge, CAS latency 2) et
rafraîchit toutes les 14 µs. Le CPU est maintenu en WAIT jusqu'à la fin de
chaque accès. En simulation, un accès tient dans le cycle de bus normal du
Z80 : la RAM n'ajoute donc aucun état d'attente (seul le tout premier accès
attend ~0,3 ms le démarrage de la SDRAM).

### VDP

Les 16 Ko de VRAM sont une block RAM double port (le CPU sur un port, le
moteur de rendu sur l'autre). Chaque ligne TMS est dessinée dans un petit
tampon de ligne pendant les deux lignes HDMI qui la précèdent (d'abord le
fond, puis jusqu'à 4 sprites) : la VRAM est donc lue un octet par cycle au
lieu de plusieurs à la fois.

### Ressources FPGA (Gowin EDA 1.9.12)

| Ressource | Utilisé | Disponible |
|---|---|---|
| Logique (LUT/ALU) | 5 235 | 20 736 (26 %) |
| Registres | 1 666 | 15 915 (11 %) |
| Block RAM (BSRAM) | 33 | 46 (72 %) |
| rPLL | 1 | 2 |

## Fichiers

```
src/top.v                  niveau supérieur, décodage E/S, horloges/reset
src/pll_135m.v             rPLL 27→135 MHz + CLKDIV /5
src/cpu/tv80_msx.v         enveloppe du Z80 avec clock enable
src/cpu/tv80/              cœur tv80 (MIT, Guy Hutchison)
src/memory/slot_ctrl.v     décodeur des slots primaires
src/memory/sdram_ctrl.v    contrôleur de la SDRAM intégrée
src/vdp/tms9918a.v         TMS9918A
src/video/                 encodeur TMDS + sérialiseur HDMI
src/psg/ay8910.v           AY-3-8910
src/ppi/ppi8255.v          i8255
src/keyboard/              récepteur PS/2 + table de touches MSX
src/sdcard/sd_spi.v        port SPI du lecteur microSD
src/audio/pdm_dac.v        DAC audio sigma-delta
constraints/               contraintes de broches
scripts/build.tcl          build en ligne de commande
sim/                       testbench, modèle de SDRAM, programme de test
tools/make_rom.py          génère bios/msx_rom.mem
```

## Limitations connues

- Pas encore testé sur matériel (voir État).
- Pas de slots cartouche, pas de slots étendus, pas de pilote Nextor/MSX-DOS pour la SD.
- Pas de joystick ni d'interface cassette.
- VDP : pas de limites de timing d'accès à la VRAM (un logiciel qui dépend
  d'une VRAM lente peut se comporter différemment) ; le bit 4/16 Ko est ignoré.
- Les touches PS/2 suivent les touches du MSX (disposition internationale), pas celles du PC.

## Feuille de route

1. Démarrer C-BIOS sur une carte et corriger ce qui apparaît.
2. Chargement de ROM cartouche (depuis la SD ou la flash) dans le slot 1.
3. Pilote Nextor pour le port SD.
4. Joystick (DB9) et entrée audio cassette.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). Lancez `sh sim/run.sh` avant
d'envoyer une modification du RTL.

## Crédits

- [tv80](https://github.com/hutch31/tv80) de Guy Hutchison, basé sur T80 de Daniel Wallner (MIT)
- L'équipe [C-BIOS](https://cbios.sourceforge.net/), pour un BIOS MSX libre
- Sipeed et la communauté Tang Nano pour la documentation de la carte

## Références

- [MSX2 Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) (couvre aussi le matériel MSX1)
- [Manuel du TMS9918A](http://www.unige.ch/medecine/nouspikel/ti99/tms9918a.htm)
- [Wiki de la Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- [Documentation du Gowin GW2AR-18](https://www.gowinsemi.com/en/support/database/)
