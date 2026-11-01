<div align="center">

# MSX1 en Tang Nano 20K

### Un ordenador MSX1 en Verilog para la Sipeed Tang Nano 20K (Gowin GW2AR-18C)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![HDL](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18C-orange.svg)](https://www.gowinsemi.com/)
[![Board](https://img.shields.io/badge/Board-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

**Leer en:** [English](README.md) · [Português](README.pt-BR.md) · [Français](README.fr.md) · [Italiano](README.it.md)

</div>

---

## Estado

| Comprobación | Resultado |
|---|---|
| Síntesis + place & route (Gowin EDA 1.9.12) | ✅ bitstream generado, timing cumplido (Fmax 54 MHz para un diseño de 27 MHz) |
| Simulación del sistema (Icarus Verilog, `sim/run.sh`) | ✅ pasa: RAM, pila, VRAM, imagen del VDP, sprites, PSG, PPI, teclado, interrupciones |
| Arranque de C-BIOS en hardware real | ⏳ **todavía no probado** |

El diseño compila y simula, pero aún no se ha ejecutado en una placa.
Los informes de quien lo pruebe son muy bienvenidos (abra una Issue).

## Qué incluye

| Parte | Implementación |
|---|---|
| CPU | Z80 a 3,579545 MHz — núcleo [tv80](https://github.com/hutch31/tv80) (port en Verilog del T80, MIT). Un estado de espera en M1, como en un MSX real. |
| Vídeo | TMS9918A: Graphics I, Graphics II, Multicolor, Texto. 32 sprites (8×8/16×16, ampliados, early clock), 4 por línea, flags de 5º sprite y colisión. |
| Salida de vídeo | HDMI/DVI 720×480p 59,94 Hz. La imagen de 256×192 se duplica a 512×384 y se centra. |
| Sonido | AY-3-8910 (3 tonos, ruido, envolvente) + clic de teclado, salida sigma-delta (PDM) en 1 pin |
| PPI | i8255: selección de slot, matriz de teclado, LED de CAPS, clic |
| ROM | 48 KB en block RAM, slot 0 (C-BIOS principal + logo, o BIOS+BASIC de un MSX1) |
| RAM | 64 KB en la SDRAM integrada del GW2AR, slot 3 |
| Teclado | PS/2, mapeado a la matriz internacional del MSX |
| microSD | puerto SPI simple (el protocolo de la tarjeta lo hace el software del MSX; aún sin driver de disco) |

## Hardware

- Sipeed Tang Nano 20K
- Monitor/TV HDMI (que acepte 720×480p)
- Teclado PS/2 (o un teclado USB que todavía hable PS/2, con adaptador)
- Audio: un filtro RC en el pin de audio (p. ej. 1 kΩ + 10 nF) y un condensador de acoplo (p. ej. 1 µF) hacia un amplificador
- Opcional: tarjeta microSD

## Pines

Todo en [constraints/tang_nano_20k.cst](constraints/tang_nano_20k.cst).

| Señal | Pin | Notas |
|---|---|---|
| Reloj 27 MHz | 4 | en la placa |
| Reset (S1) | 88 | botón de la placa |
| LEDs 0–5 | 15–20 | CAPS, SD, HALT, SDRAM no lista, latido, reset |
| HDMI | 33–40 | conector de la placa |
| microSD | 81–84 | ranura de la placa |
| PS/2 reloj | 76 | **tira de pines lateral — compruébelo antes de cablear** |
| PS/2 datos | 77 | **tira de pines lateral — compruébelo antes de cablear** |
| Audio PDM | 75 | **tira de pines lateral — compruébelo antes de cablear** |

La Tang Nano 20K no tiene conector PMOD. Los pines de PS/2 y audio son GPIO
libres de 3,3 V en las tiras laterales; compruébelos con el pinout de Sipeed
para la revisión de su placa y cambie el `.cst` si hace falta. Los teclados
PS/2 son de 5 V: la mayoría funciona a 3,3 V; si el suyo no, use un
adaptador de nivel.

## Primeros pasos

### 1. Crear la imagen de la ROM

La ROM no está en el repositorio. [C-BIOS](https://cbios.sourceforge.net/) es una BIOS de MSX libre:

```bash
python3 tools/make_rom.py cbios_main_msx1.rom cbios_logo_msx1.rom
```

O, si tiene la ROM de sistema de un MSX1 (32 KB, BIOS + BASIC):

```bash
python3 tools/make_rom.py msx1.rom
```

Ambos generan `bios/msx_rom.mem`, que lee el build.

### 2. Compilar

Con el IDE de Gowin EDA: abra `msx1_tang20k.gprj` y ejecute *Place & Route*.
En *Project → Configuration → Dual-Purpose Pin*, habilite MSPI, SSPI, READY y DONE como E/S normal.

O desde la línea de comandos (con Gowin EDA instalado):

```bash
gw_sh scripts/build.tcl
```

El bitstream queda en `impl/pnr/msx1_tang20k.fs`.

### 3. Programar la placa

Con [openFPGALoader](https://github.com/trabucayre/openFPGALoader):

```bash
openFPGALoader -b tangnano20k impl/pnr/msx1_tang20k.fs
```

Añada `-f` para grabarlo en la flash y conservarlo al apagar. El Gowin
Programmer también sirve.

### 4. Simular (opcional)

Necesita [Icarus Verilog](https://steveicarus.github.io/iverilog/) y Python 3:

```bash
sh sim/run.sh
```

Ejecuta un pequeño programa Z80 de prueba ([sim/make_test_rom.py](sim/make_test_rom.py))
en toda la máquina, con un modelo de la SDRAM, y guarda un cuadro HDMI en
`sim/frame.ppm`. La misma prueba se ejecuta en GitHub Actions en cada push.

## Cómo funciona

### Relojes

```
cristal 27 MHz ─► rPLL ─► 135 MHz ──────────────► OSER10 (serializadores HDMI)
                             └─► CLKDIV /5 ─► 27 MHz  = reloj de píxel = reloj del sistema
                                                ├─ clock enable de la CPU  3,579545 MHz
                                                ├─ clock enable del PSG    1,789773 MHz
                                                └─ reloj de la SDRAM (invertido)
```

Todo funciona en un único dominio de 27 MHz, sin cruces entre dominios de
reloj. El clock enable de la CPU sale de un acumulador de fase, así que su
media es exactamente 3,579545 MHz.

### Mapa de memoria (slots primarios, elegidos con el puerto A del PPI / E/S A8h)

| Página | Slot 0 | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|---|
| 0000–3FFF | ROM | – | – | RAM |
| 4000–7FFF | ROM | – | – | RAM |
| 8000–BFFF | ROM (logo / BASIC) | – | – | RAM |
| C000–FFFF | – | – | – | RAM |

El espacio vacío se lee como FFh. Los slots expandidos no están implementados.

### Mapa de E/S

| Puerto | Dispositivo |
|---|---|
| 40h–41h | SPI de la microSD (datos, control/estado) — vea [src/sdcard/sd_spi.v](src/sdcard/sd_spi.v) |
| 98h–99h | VDP (datos de VRAM, control/estado) |
| A0h–A2h | PSG (dirección, escritura, lectura) |
| A8h–ABh | PPI (slots, teclado, puerto C, control) |

### SDRAM

El GW2AR-18C lleva una SDRAM de 64 Mbit en el mismo encapsulado. Sus pines
tienen nombres fijos (`O_sdram_*`, `IO_sdram_dq`) y no necesitan constraints.
[src/memory/sdram_ctrl.v](src/memory/sdram_ctrl.v) hace un byte por acceso
(ACTIVATE + READ/WRITE con auto-precharge, CAS latency 2) y refresca cada
14 µs. La CPU queda en WAIT hasta que termina cada acceso. En simulación un
acceso cabe dentro del ciclo de bus normal del Z80, así que la RAM no añade
estados de espera (solo el primer acceso espera ~0,3 ms al arranque de la SDRAM).

### VDP

Los 16 KB de VRAM son una block RAM de doble puerto (la CPU en un puerto, el
renderizador en el otro). Cada línea del TMS se dibuja en un pequeño búfer de
línea durante las dos líneas HDMI anteriores (primero el fondo, luego hasta 4
sprites), así que la VRAM se lee un byte por ciclo en lugar de muchos a la vez.

### Recursos de la FPGA (Gowin EDA 1.9.12)

| Recurso | Usado | Disponible |
|---|---|---|
| Lógica (LUT/ALU) | 5.235 | 20.736 (26%) |
| Registros | 1.666 | 15.915 (11%) |
| Block RAM (BSRAM) | 33 | 46 (72%) |
| rPLL | 1 | 2 |

## Archivos

```
src/top.v                  nivel superior, decodificación de E/S, relojes/reset
src/pll_135m.v             rPLL 27→135 MHz + CLKDIV /5
src/cpu/tv80_msx.v         envoltorio del Z80 con clock enable
src/cpu/tv80/              núcleo tv80 (MIT, Guy Hutchison)
src/memory/slot_ctrl.v     decodificador de slots primarios
src/memory/sdram_ctrl.v    controlador de la SDRAM integrada
src/vdp/tms9918a.v         TMS9918A
src/video/                 codificador TMDS + serializador HDMI
src/psg/ay8910.v           AY-3-8910
src/ppi/ppi8255.v          i8255
src/keyboard/              receptor PS/2 + mapa de teclas MSX
src/sdcard/sd_spi.v        puerto SPI de la ranura microSD
src/audio/pdm_dac.v        DAC de audio sigma-delta
constraints/               asignación de pines
scripts/build.tcl          build desde la línea de comandos
sim/                       testbench, modelo de SDRAM, programa de prueba
tools/make_rom.py          genera bios/msx_rom.mem
```

## Limitaciones conocidas

- Aún no probado en hardware (vea Estado).
- Sin slots de cartucho, sin slots expandidos, sin driver Nextor/MSX-DOS para la SD.
- Sin joystick ni interfaz de casete.
- VDP: sin los límites de temporización de acceso a la VRAM (el software que
  dependa de una VRAM lenta puede comportarse distinto); el bit 4/16 KB se ignora.
- Las teclas PS/2 siguen las teclas del MSX (distribución internacional), no las del PC.

## Hoja de ruta

1. Arrancar C-BIOS en una placa y corregir lo que aparezca.
2. Cargar ROMs de cartucho (desde la SD o la flash) en el slot 1.
3. Driver Nextor para el puerto SD.
4. Joystick (DB9) y entrada de audio de casete.

## Contribuir

Vea [CONTRIBUTING.md](CONTRIBUTING.md). Ejecute `sh sim/run.sh` antes de
enviar un cambio en el RTL.

## Créditos

- [tv80](https://github.com/hutch31/tv80) de Guy Hutchison, basado en T80 de Daniel Wallner (MIT)
- Equipo de [C-BIOS](https://cbios.sourceforge.net/), por una BIOS de MSX libre
- Sipeed y la comunidad Tang Nano por la documentación de la placa

## Referencias

- [MSX2 Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) (cubre también el hardware del MSX1)
- [Manual del TMS9918A](http://www.unige.ch/medecine/nouspikel/ti99/tms9918a.htm)
- [Wiki de la Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- [Documentación del Gowin GW2AR-18](https://www.gowinsemi.com/en/support/database/)
