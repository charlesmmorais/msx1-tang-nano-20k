<div align="center">

# 🖥️ MSX1 na Tang Nano 20K

### Um computador MSX1 totalmente funcional implementado em Verilog numa placa FPGA de $20

[![Licença: MIT](https://img.shields.io/badge/Licença-MIT-yellow.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18-orange.svg)](https://www.gowinsemi.com/)
[![Placa](https://img.shields.io/badge/Placa-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

**Leia em outros idiomas:** [🇺🇸 English](README.md) · [🇪🇸 Español](README.es.md) · [🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md)

</div>

---

## 🎮 O que é MSX?

O **MSX** é uma arquitetura padronizada de microcomputador criada em **1983** pela **ASCII Corporation** e **Microsoft**, amplamente adotada no Japão, Brasil (pela Gradiente, Sharp, Ciel e outros), Europa e Oriente Médio.

O MSX definiu um padrão comum de hardware para que o software rodasse em qualquer máquina MSX, independentemente do fabricante. No Brasil, o MSX foi extremamente popular nos anos 1980 e 1990.

### Especificações do MSX1

| Componente | Especificação |
|------------|--------------|
| CPU | Zilog Z80A @ 3,579 MHz |
| Vídeo | Texas Instruments TMS9918A |
| Áudio | General Instrument AY-3-8910 |
| RAM | Mínimo 8KB (implementamos 64KB) |
| ROM | 32KB BIOS + 16KB BASIC |
| VRAM | 16KB |
| Cores | 15 + transparente |
| Resolução | 256×192 (gráficos) / 40×24 (texto) |
| Sprites | 32 sprites, 8×8 ou 16×16 |

---

## ⚡ O que é uma FPGA?

Uma **FPGA** (Field-Programmable Gate Array — Arranjo de Portas Programável em Campo) é um chip que você pode programar para **se tornar qualquer circuito digital** — incluindo um computador completo dos anos 1980.

Em vez de software rodando num processador fixo, uma FPGA implementa a **lógica de hardware real** em paralelo. Cada componente do MSX (CPU, VDP, PSG, PPI) funciona simultaneamente, exatamente como na máquina original.

A **Tang Nano 20K** da Sipeed usa uma FPGA **Gowin GW2AR-18C** com:
- **20.736** Look-Up Tables (LUTs) — os blocos básicos de construção
- **15.552** Flip-Flops (registradores)
- **96** Block RAMs (18Kbit cada)
- **2** PLLs para geração de clock
- Conector **HDMI** onboard
- Slot **microSD** onboard
- Preço: ~R$ 100–120

---

## 🛒 Componentes Necessários

| Item | Finalidade | Custo (aprox.) |
|------|-----------|----------------|
| Tang Nano 20K | Placa FPGA principal | ~R$ 110 |
| Teclado PS/2 (ou adaptador USB→PS/2) | Entrada | ~R$ 20 |
| Monitor ou TV HDMI | Display | — |
| Cartão microSD | Armazenamento | ~R$ 15 |
| Protoboard + jumpers | Conexões | ~R$ 10 |
| 2× resistores 4,7kΩ | Pull-up PS/2 | ~R$ 0,50 |
| 1× resistor 100Ω + 1× capacitor 10µF | Filtro de áudio | ~R$ 1 |

**Total: menos de R$ 160!**

---

## 🏗️ Visão Geral da Arquitetura

### 🔵 CPU Z80

O **Zilog Z80** é o coração de todo computador MSX. Nossa implementação é uma **máquina de estados multi-ciclo** escrita completamente em Verilog — nenhum núcleo proprietário.

#### Como o Z80 funciona:

Cada instrução passa por **Ciclos de Máquina (M-ciclos)**, compostos por **T-estados** (ciclos de clock):

```
FETCH (M1):  ┌─T1─┬─T2─┬─T3─┬─T4─┐
              │ PC→ │    │Rfsh│    │  Lê opcode da memória
              └────┴────┴────┴────┘

LEITURA:     ┌─T1─┬─T2─┬─T3─┐
              │ End│    │Dado│  Lê 1 byte da memória
              └────┴────┴────┘

ESCRITA:     ┌─T1─┬─T2─┬─T3─┐
              │ End│Dado│    │  Escreve 1 byte na memória
              └────┴────┴────┘
```

#### Bancos de Registradores:

```
Banco Principal:    Banco Alternado (EXX):
┌────┬────┐         ┌─────┬─────┐
│ A  │ F  │ ←──────▶│  A' │  F' │  (EX AF,AF')
├────┼────┤         ├─────┼─────┤
│ B  │ C  │ ←──────▶│  B' │  C' │
├────┼────┤         ├─────┼─────┤  (EXX)
│ D  │ E  │ ←──────▶│  D' │  E' │
├────┼────┤         ├─────┼─────┤
│ H  │ L  │ ←──────▶│  H' │  L' │
└────┴────┘         └─────┴─────┘

Índice: IX[15:0]  IY[15:0]
Pilha:  SP[15:0]  PC[15:0]
Especial: I[7:0]  R[7:0]  IFF1  IFF2  IM[1:0]
```

#### Registrador de Flags (F):

```
Bit:  7    6    5    4    3    2    1    0
      S    Z    Y    H    X    PV   N    C
      │    │    │    │    │    │    │    │
      │    │    │    │    │    │    │    └─ Carry (Vai-um)
      │    │    │    │    │    │    └───── Add/Subtract
      │    │    │    │    │    └────────── Paridade/Overflow
      │    │    │    │    └─────────────── (não documentado, bit 3)
      │    │    │    └──────────────────── Half Carry (Vai-um interno)
      │    │    └───────────────────────── (não documentado, bit 5)
      │    └────────────────────────────── Zero (resultado = 0)
      └─────────────────────────────────── Sinal (bit 7 do resultado)
```

---

### 🟢 TMS9918A — Processador de Vídeo

O **TMS9918A** da Texas Instruments gera vídeo de forma independente da CPU. Possui sua própria **VRAM de 16KB**.

#### Modos de Vídeo:

| Modo | BASIC | Resolução | Características |
|------|-------|-----------|----------------|
| Screen 0 | `SCREEN 0` | 40×24 chars | Texto puro, 1 cor |
| Screen 1 | `SCREEN 1` | 32×24 tiles | 2 cores por grupo de 8 chars |
| Screen 2 | `SCREEN 2` | 256×192 px | Bitmap completo, jogos MSX |
| Screen 3 | `SCREEN 3` | 64×48 blocos | Multicolor simples |

#### Paleta de 15 Cores MSX:

```
┌───┬─────────────────┐  ┌───┬─────────────────┐
│ 0 │ Transparente    │  │ 8 │ Vermelho Médio  │
│ 1 │ Preto           │  │ 9 │ Vermelho Claro  │
│ 2 │ Verde Médio     │  │10 │ Amarelo Escuro  │
│ 3 │ Verde Claro     │  │11 │ Amarelo Claro   │
│ 4 │ Azul Escuro     │  │12 │ Verde Escuro    │
│ 5 │ Azul Claro      │  │13 │ Magenta         │
│ 6 │ Vermelho Escuro │  │14 │ Cinza           │
│ 7 │ Ciano           │  │15 │ Branco          │
└───┴─────────────────┘  └───┴─────────────────┘
```

---

### 🔴 AY-3-8910 — Chip de Som

O **PSG** (Programmable Sound Generator) gera áudio em 3 canais de onda quadrada, ruído e envelope. É o mesmo chip usado no ZX Spectrum, Atari ST e muitas máquinas arcade.

#### Fórmula de Frequência de Tom:
```
f_tom = f_clock / (16 × N)
f_clock = 1,789 MHz (padrão MSX)

Exemplo: Nota Lá (440 Hz)
N = 1.789.000 / (16 × 440) ≈ 254
→ R0 = 0xFE, R1 = 0x00
```

---

### 🟡 Intel 8255 PPI

A **PPI** (Programmable Peripheral Interface) conecta a CPU à **matriz de teclado** e ao **sistema de slots**:

- **Porta A** → seleção de slots por página (4 páginas × 2 bits = 4 possíveis slots)
- **Porta B** ← leitura das colunas do teclado
- **Porta C** → seleção de linha do teclado + LED Caps Lock + cassete

---

### 🟠 Sistema de Memória e Slots

O MSX usa um elegante **sistema de slots** que permite diferentes hardware no mesmo espaço de 64KB:

```
Espaço de Endereços da CPU (64KB)
┌──────────────────────────────────────────┐
│ Página 3: 0xC000–0xFFFF │ PPI_A[7:6]   │ → RAM (Slot 3)
├──────────────────────────────────────────┤
│ Página 2: 0x8000–0xBFFF │ PPI_A[5:4]   │ → BASIC ROM (Slot 0)
├──────────────────────────────────────────┤
│ Página 1: 0x4000–0x7FFF │ PPI_A[3:2]   │ → BIOS alta (Slot 0)
├──────────────────────────────────────────┤
│ Página 0: 0x0000–0x3FFFh│ PPI_A[1:0]   │ → BIOS baixa (Slot 0)
└──────────────────────────────────────────┘
```

---

## ⏱️ Arquitetura de Clock

```
Cristal 27 MHz
       │
       ├── PLL #1 × 4 = 108 MHz (lógica do sistema)
       │        ├── ÷30 = 3,6 MHz → Clock enable da CPU Z80
       │        ├── ÷60 = 1,8 MHz → Clock enable do PSG
       │        └── ÷4  = 27 MHz  → Pixel clock do VDP
       │
       └── PLL #2 × 5 = 135 MHz → Clock TMDS serial do HDMI
```

---

## 🚀 Primeiros Passos

### Passo 1 — Instalar o Gowin EDA

Baixe no site oficial (requer cadastro gratuito):
🔗 https://www.gowinsemi.com/en/support/download_eda/

### Passo 2 — Obter a BIOS

A BIOS original do MSX é proprietária. Recomendamos o **C-BIOS** (open source, LGPL):

```bash
# Baixar C-BIOS
wget https://sourceforge.net/projects/cbios/files/cbios-0.29a.zip
unzip cbios-0.29a.zip

# Converter para formato hex
python3 tools/convert_rom.py cbios_main_msx1.rom bios/cbios_main_msx1.mem
```

### Passo 3 — Clonar e compilar

```bash
git clone https://github.com/SEU_USUARIO/msx1-tang-nano-20k.git
cd msx1-tang-nano-20k
cp /caminho/para/cbios_main_msx1.mem bios/
```

Abrir `msx1_tang20k.gprj` no Gowin EDA → Synthesize → Place & Route → Program.

---

## 🔌 Conexões de Hardware

### Teclado PS/2 (PMOD1)

```
Conector Mini-DIN 6 (PS/2)    Cabeçalho PMOD1
Pin 5 (CLK)  ─── 4,7kΩ ───┬─ Pino 1 do PMOD1
                           └─ 3,3V

Pin 1 (DATA) ─── 4,7kΩ ───┬─ Pino 2 do PMOD1
                           └─ 3,3V

Pin 4 (VCC)  ──────────────── Pino 6 do PMOD1 (+3,3V)
Pin 3 (GND)  ──────────────── Pino 5 do PMOD1 (GND)
```

> ⚠️ **Os resistores pull-up de 4,7kΩ são obrigatórios!** Sem eles o teclado não funcionará.

### Saída de Áudio (Pino 3 do PMOD1)

```
Pino FPGA ── 100Ω ──┬── Jack P2 (ponta)
                    │
                   10µF
                    │
                   GND ── Jack P2 (anel)
```

### HDMI

Use diretamente o **conector HDMI onboard** da placa Tang Nano 20K.

### SD Card

Use o **slot microSD onboard** da placa.

---

## 📊 Mapa de Portas I/O

| Porta | Dispositivo | Acesso | Descrição |
|-------|-------------|--------|-----------|
| `0x40`–`0x47` | SD Card | R/W | Dados SPI, CS, leitura de setor |
| `0x98` | VDP | R/W | Dado de/para VRAM |
| `0x99` | VDP | R/W | Escreve registrador / Lê status |
| `0xA0` | PSG | W | Escreve dado no registrador latchado |
| `0xA1` | PSG | W | Latch do endereço do registrador |
| `0xA2` | PSG | R | Lê registrador latchado |
| `0xA8` | PPI | R/W | Porta A: seleção de slot |
| `0xA9` | PPI | R | Porta B: colunas do teclado |
| `0xAA` | PPI | R/W | Porta C: linha teclado + controle |
| `0xAB` | PPI | W | Palavra de controle da PPI |

---

## ⚠️ Limitações Conhecidas

| Funcionalidade | Status |
|----------------|--------|
| CPU Z80 completa | ✅ Todos os grupos de instruções |
| Screen 0, 1, 2, 3 | ✅ Implementados |
| Sprites | ✅ 32 sprites (simplificado) |
| PSG (som) | ✅ 3 canais + ruído + envelope |
| Teclado PS/2 | ✅ Teclas principais |
| HDMI 720×480p | ✅ Funcionando |
| SD Card (leitura) | ✅ Leitura de setores SPI |
| MSX-DOS / Nextor | ❌ Não implementado |
| Slot de cartucho | ❌ Retorna 0xFF |
| Porta de joystick | ❌ Não implementado |
| Interface cassete | ❌ Não implementado |
| MSX2 / V9938 | ❌ Trabalho futuro |

---

## 📚 Referências

- [MSX Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) — Referência definitiva do MSX
- [C-BIOS](https://cbios.sourceforge.net/) — BIOS MSX open source
- [Z80 CPU User Manual](https://www.zilog.com/docs/z80/um0080.pdf)
- [Tang Nano 20K Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

---

<div align="center">

**Feito com ❤️ para a comunidade MSX e FPGA**

⭐ Se este projeto te ajudou, deixe uma estrela no GitHub! ⭐

</div>
