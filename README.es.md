<div align="center">

# 🖥️ MSX1 en Tang Nano 20K

### Un ordenador MSX1 completamente funcional implementado en Verilog en una placa FPGA de $20

[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18-orange.svg)](https://www.gowinsemi.com/)

**Leer en otros idiomas:** [🇺🇸 English](README.md) · [🇧🇷 Português](README.pt-BR.md) · [🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md)

</div>

---

## 🎮 ¿Qué es el MSX?

El **MSX** es una arquitectura de microordenador estandarizada creada en **1983** por **ASCII Corporation** y **Microsoft**, ampliamente adoptada en Japón, España, Países Bajos, Brasil y Oriente Medio.

El estándar MSX definió hardware común para que el software funcionara en cualquier máquina MSX, sin importar el fabricante (Sony, Philips, Panasonic, Canon, Toshiba…). En España fue especialmente popular, con modelos de Philips y Sony.

### Especificaciones del MSX1

| Componente | Especificación |
|------------|---------------|
| CPU | Zilog Z80A @ 3,579 MHz |
| Vídeo | Texas Instruments TMS9918A |
| Audio | General Instrument AY-3-8910 |
| RAM | Mínimo 8KB (implementamos 64KB) |
| ROM | 32KB BIOS + 16KB BASIC |
| VRAM | 16KB |
| Colores | 15 + transparente |
| Resolución | 256×192 (gráficos) / 40×24 (texto) |
| Sprites | 32 sprites, 8×8 ó 16×16 |

---

## ⚡ ¿Qué es una FPGA?

Una **FPGA** (Field-Programmable Gate Array — Matriz de Puertas Programable en Campo) es un chip que puedes programar para **convertirse en cualquier circuito digital** — incluyendo un ordenador completo de los años 80.

En lugar de software ejecutándose en un procesador fijo, una FPGA implementa la **lógica de hardware real** en paralelo. Cada componente del MSX (CPU, VDP, PSG, PPI) funciona simultáneamente, exactamente como en la máquina original.

---

## 🛒 Componentes Necesarios

| Componente | Uso | Coste (aprox.) |
|------------|-----|----------------|
| Tang Nano 20K | Placa FPGA principal | ~20€ |
| Teclado PS/2 (o adaptador USB→PS/2) | Entrada | ~5€ |
| Monitor o TV HDMI | Pantalla | — |
| Tarjeta microSD | Almacenamiento | ~3€ |
| Protoboard + cables jumper | Conexiones | ~3€ |
| 2× resistencias 4,7kΩ | Pull-up PS/2 | ~0,10€ |
| 1× 100Ω + 1× 10µF | Filtro de audio | ~0,20€ |

---

## 🏗️ Arquitectura del Sistema

### 🔵 CPU Z80

El **Zilog Z80** es el corazón del MSX. Nuestra implementación es una **máquina de estados multi-ciclo** en Verilog puro.

#### Ciclos de Máquina:

```
FETCH (M1):  ┌─T1─┬─T2─┬─T3─┬─T4─┐
              │ PC→ │    │Rfsh│    │  Lee opcode de memoria
              └────┴────┴────┴────┘

LECTURA:     ┌─T1─┬─T2─┬─T3─┐
              │ Dir│    │Dato│
              └────┴────┴────┘

E/S:         ┌─T1─┬─T2─┬─TW─┬─T3─┬─T4─┐
              │Puerto│  │Esp.│Dato│    │
              └────┴────┴────┴────┴────┘
```

#### Grupos de Instrucciones:

| Prefijo | Grupo | Ejemplos |
|---------|-------|---------|
| (ninguno) | Conjunto principal | `LD A,B` `ADD A,n` `JP nn` |
| `CB` | Operaciones de bits | `RLC r` `BIT b,r` `SET b,r` |
| `DD` | Registro IX | `LD IX,nn` `LD r,(IX+d)` |
| `FD` | Registro IY | `LD IY,nn` `LD (IY+d),r` |
| `ED` | Extendido | `LDIR` `LDDR` `IM 2` `ADC HL,rp` |

### 🟢 VDP TMS9918A

#### Modos de Vídeo:

| Modo | BASIC | Descripción |
|------|-------|-------------|
| Screen 0 | `SCREEN 0` | Texto 40×24 columnas |
| Screen 1 | `SCREEN 1` | Gráficos I, tiles 32×24 |
| Screen 2 | `SCREEN 2` | Mapa de bits 256×192 px |
| Screen 3 | `SCREEN 3` | Multicolor 64×48 bloques |

#### Paleta de 15 Colores:

```
 0: Transparente   4: Azul oscuro    8: Rojo medio    12: Verde oscuro
 1: Negro          5: Azul claro     9: Rojo claro    13: Magenta
 2: Verde medio    6: Rojo oscuro   10: Amarillo osc  14: Gris
 3: Verde claro    7: Cian          11: Amarillo cla  15: Blanco
```

### 🔴 PSG AY-3-8910

3 canales de onda cuadrada + generador de ruido LFSR 17 bits + envolvente.

```
Fórmula de frecuencia: f = f_clk / (16 × N)
f_clk = 1,789 MHz
Ejemplo La (440 Hz): N ≈ 254
```

### 🟡 PPI Intel 8255

- **Puerto A** → Selección de slot por página
- **Puerto B** ← Columnas del teclado MSX (lectura)
- **Puerto C** → Fila del teclado + LED Caps + casete

### 🟠 Sistema de Slots

```
Página 3 (0xC000–0xFFFF): PPI_A[7:6] → normalmente RAM
Página 2 (0x8000–0xBFFF): PPI_A[5:4] → normalmente BASIC ROM
Página 1 (0x4000–0x7FFF): PPI_A[3:2] → BIOS ROM alta
Página 0 (0x0000–0x3FFF): PPI_A[1:0] → BIOS ROM baja
```

---

## ⏱️ Arquitectura de Reloj

```
Cristal 27 MHz
    ├── PLL1 × 4 = 108 MHz (sistema)
    │       ├── ÷30 = 3,6 MHz → Z80 CPU
    │       ├── ÷60 = 1,8 MHz → PSG
    │       └── ÷4  = 27 MHz  → VDP pixel
    └── PLL2 × 5 = 135 MHz → TMDS HDMI
```

---

## 🚀 Primeros Pasos

### Paso 1 — Instalar Gowin EDA
🔗 https://www.gowinsemi.com/en/support/download_eda/

### Paso 2 — Obtener la BIOS (C-BIOS, open source)

```bash
wget https://sourceforge.net/projects/cbios/files/cbios-0.29a.zip
unzip cbios-0.29a.zip
python3 tools/convert_rom.py cbios_main_msx1.rom bios/cbios_main_msx1.mem
```

### Paso 3 — Clonar y compilar

```bash
git clone https://github.com/TU_USUARIO/msx1-tang-nano-20k.git
cd msx1-tang-nano-20k
```

Abrir `msx1_tang20k.gprj` en Gowin EDA → Synthesize → Place & Route → Program.

---

## 🔌 Conexiones de Hardware

### Teclado PS/2 (PMOD1)

```
PS/2 Pin 5 (CLK)  ── 4,7kΩ ──┬── PMOD1 Pin 1
                              └── 3,3V (pull-up)

PS/2 Pin 1 (DATA) ── 4,7kΩ ──┬── PMOD1 Pin 2
                              └── 3,3V (pull-up)

PS/2 Pin 4 (VCC)  ─────────────── PMOD1 Pin 6 (+3,3V)
PS/2 Pin 3 (GND)  ─────────────── PMOD1 Pin 5 (GND)
```

### Audio (PMOD1 Pin 3)

```
Pin FPGA ── 100Ω ──┬── Jack 3,5mm (+)
                   10µF
                   GND ── Jack 3,5mm (-)
```

---

## 📊 Mapa de Puertos I/O

| Puerto | Dispositivo | Acceso | Descripción |
|--------|-------------|--------|-------------|
| `0x98` | VDP | R/W | Datos VRAM |
| `0x99` | VDP | R/W | Registro / Estado |
| `0xA0`–`0xA2` | PSG | R/W | Sonido AY-3-8910 |
| `0xA8`–`0xAB` | PPI | R/W | Teclado + slots |
| `0x40`–`0x47` | SD Card | R/W | Tarjeta SD SPI |

---

## ⚠️ Limitaciones Conocidas

| Función | Estado |
|---------|--------|
| CPU Z80 completa | ✅ Todos los grupos |
| Pantallas 0–3 | ✅ Implementadas |
| Sprites | ✅ 32 sprites |
| PSG (sonido) | ✅ 3 canales |
| Teclado PS/2 | ✅ Teclas principales |
| HDMI 720×480p | ✅ Funcionando |
| SD Card | ✅ Lectura SPI |
| MSX-DOS / Nextor | ❌ No implementado |
| Ranura de cartucho | ❌ Devuelve 0xFF |
| Puerto joystick | ❌ No implementado |

---

## 📚 Referencias

- [MSX Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/)
- [C-BIOS](https://cbios.sourceforge.net/)
- [Tang Nano 20K Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

<div align="center">

**Hecho con ❤️ para la comunidad MSX y FPGA**

⭐ ¡Si este proyecto te ha ayudado, dale una estrella en GitHub! ⭐

</div>
