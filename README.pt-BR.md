<div align="center">

# MSX1 na Tang Nano 20K

### Um computador MSX1 em Verilog para a Sipeed Tang Nano 20K (Gowin GW2AR-18C)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![HDL](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18C-orange.svg)](https://www.gowinsemi.com/)
[![Board](https://img.shields.io/badge/Board-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

**Leia em:** [English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Italiano](README.it.md)

</div>

---

## Situação

| Verificação | Resultado |
|---|---|
| Síntese + place & route (Gowin EDA 1.9.12) | ✅ bitstream gerado, timing atendido (Fmax 54 MHz para um projeto de 27 MHz) |
| Simulação do sistema (Icarus Verilog, `sim/run.sh`) | ✅ passa: RAM, pilha, VRAM, imagem do VDP, sprites, PSG, PPI, teclado, interrupções |
| Boot do C-BIOS na placa real | ⏳ **ainda não testado** |

O projeto compila e simula, mas ainda não rodou numa placa. Relatos de quem
testar são muito bem-vindos (abra uma Issue).

## O que tem dentro

| Parte | Implementação |
|---|---|
| CPU | Z80 a 3,579545 MHz — núcleo [tv80](https://github.com/hutch31/tv80) (porte em Verilog do T80, MIT). Um wait state no M1, como num MSX real. |
| Vídeo | TMS9918A: Graphics I, Graphics II, Multicolor, Texto. 32 sprites (8×8/16×16, ampliados, early clock), 4 por linha, flags de 5º sprite e colisão. |
| Saída de vídeo | HDMI/DVI 720×480p 59,94 Hz. A imagem de 256×192 é dobrada para 512×384 e centralizada. |
| Som | AY-3-8910 (3 tons, ruído, envelope) + clique de tecla, saída sigma-delta (PDM) em 1 pino |
| PPI | i8255: seleção de slot, matriz de teclado, LED de CAPS, clique |
| ROM | 48 KB em block RAM, slot 0 (C-BIOS principal + logo, ou BIOS+BASIC de um MSX1) |
| RAM | 64 KB na SDRAM embutida do GW2AR, slot 3 |
| Teclado | PS/2, mapeado na matriz internacional do MSX |
| microSD | porta SPI simples (o protocolo do cartão fica com o software do MSX; ainda sem driver de disco) |

## Hardware

- Sipeed Tang Nano 20K
- Monitor/TV HDMI (aceitando 720×480p)
- Teclado PS/2 (ou um teclado USB que ainda fale PS/2, com adaptador)
- Áudio: um filtro RC no pino de áudio (ex.: 1 kΩ + 10 nF) e um capacitor de acoplamento (ex.: 1 µF) até um amplificador
- Opcional: cartão microSD

## Pinos

Tudo em [constraints/tang_nano_20k.cst](constraints/tang_nano_20k.cst).

| Sinal | Pino | Observação |
|---|---|---|
| Clock 27 MHz | 4 | na placa |
| Reset (S1) | 88 | botão da placa |
| LEDs 0–5 | 15–20 | CAPS, SD, HALT, SDRAM não pronta, pulsação, reset |
| HDMI | 33–40 | conector da placa |
| microSD | 81–84 | slot da placa |
| PS/2 clock | 76 | **barra de pinos lateral — confira antes de ligar** |
| PS/2 dados | 77 | **barra de pinos lateral — confira antes de ligar** |
| Áudio PDM | 75 | **barra de pinos lateral — confira antes de ligar** |

A Tang Nano 20K não tem conector PMOD. Os pinos de PS/2 e áudio são GPIOs
livres de 3,3 V nas barras laterais; confira com a pinagem da Sipeed para a
revisão da sua placa e ajuste o `.cst` se precisar. Teclados PS/2 são de 5 V:
a maioria funciona a 3,3 V; se o seu não funcionar, use um conversor de nível.

## Como usar

### 1. Gerar a imagem da ROM

A ROM não vem no repositório. O [C-BIOS](https://cbios.sourceforge.net/) é uma BIOS de MSX livre:

```bash
python3 tools/make_rom.py cbios_main_msx1.rom cbios_logo_msx1.rom
```

Ou, se você tiver a ROM de sistema de um MSX1 (32 KB, BIOS + BASIC):

```bash
python3 tools/make_rom.py msx1.rom
```

Os dois geram `bios/msx_rom.mem`, que o build lê.

### 2. Compilar

Pelo Gowin EDA IDE: abra `msx1_tang20k.gprj` e rode *Place & Route*.
Em *Project → Configuration → Dual-Purpose Pin*, habilite MSPI, SSPI, READY e DONE como I/O comum.

Ou pela linha de comando (com o Gowin EDA instalado):

```bash
gw_sh scripts/build.tcl
```

O bitstream fica em `impl/pnr/msx1_tang20k.fs`.

### 3. Gravar na placa

Com o [openFPGALoader](https://github.com/trabucayre/openFPGALoader):

```bash
openFPGALoader -b tangnano20k impl/pnr/msx1_tang20k.fs
```

Acrescente `-f` para gravar na flash e manter depois de desligar. O Gowin
Programmer também funciona.

### 4. Simular (opcional)

Precisa do [Icarus Verilog](https://steveicarus.github.io/iverilog/) e Python 3:

```bash
sh sim/run.sh
```

Roda um pequeno programa Z80 de teste ([sim/make_test_rom.py](sim/make_test_rom.py))
na máquina inteira, com um modelo da SDRAM, e salva um quadro HDMI em
`sim/frame.ppm`. O mesmo teste roda no GitHub Actions a cada push.

## Como funciona

### Clocks

```
cristal 27 MHz ─► rPLL ─► 135 MHz ──────────────► OSER10 (serializadores HDMI)
                             └─► CLKDIV /5 ─► 27 MHz  = clock de pixel = clock do sistema
                                                ├─ clock enable da CPU  3,579545 MHz
                                                ├─ clock enable do PSG  1,789773 MHz
                                                └─ clock da SDRAM (invertido)
```

Tudo roda num único domínio de 27 MHz, sem cruzamento de domínios de clock.
O clock enable da CPU vem de um acumulador de fase, então a média é
exatamente 3,579545 MHz.

### Mapa de memória (slots primários, selecionados pela porta A do PPI / I/O A8h)

| Página | Slot 0 | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|---|
| 0000–3FFF | ROM | – | – | RAM |
| 4000–7FFF | ROM | – | – | RAM |
| 8000–BFFF | ROM (logo / BASIC) | – | – | RAM |
| C000–FFFF | – | – | – | RAM |

Espaço vazio lê FFh. Slots expandidos não estão implementados.

### Mapa de I/O

| Porta | Dispositivo |
|---|---|
| 40h–41h | SPI do microSD (dados, controle/status) — veja [src/sdcard/sd_spi.v](src/sdcard/sd_spi.v) |
| 98h–99h | VDP (dados da VRAM, controle/status) |
| A0h–A2h | PSG (endereço, escrita, leitura) |
| A8h–ABh | PPI (slots, teclado, porta C, controle) |

### SDRAM

O GW2AR-18C traz uma SDRAM de 64 Mbit no mesmo encapsulamento. Os pinos dela
têm nomes fixos (`O_sdram_*`, `IO_sdram_dq`) e não precisam de constraints.
[src/memory/sdram_ctrl.v](src/memory/sdram_ctrl.v) faz um byte por acesso
(ACTIVATE + READ/WRITE com auto-precharge, CAS latency 2) e faz refresh a cada
14 µs. A CPU fica em WAIT até cada acesso terminar. Na simulação um acesso
cabe dentro do ciclo normal de barramento do Z80, então a RAM não acrescenta
wait states (só o primeiro acesso espera ~0,3 ms pela inicialização da SDRAM).

### VDP

Os 16 KB de VRAM são uma block RAM de duas portas (CPU numa porta, o
renderizador na outra). Cada linha do TMS é desenhada numa pequena memória de
linha durante as duas linhas HDMI anteriores (primeiro o fundo, depois até 4
sprites), então a VRAM é lida um byte por clock, em vez de muitos bytes de uma vez.

### Recursos do FPGA (Gowin EDA 1.9.12)

| Recurso | Usado | Disponível |
|---|---|---|
| Lógica (LUT/ALU) | 5.235 | 20.736 (26%) |
| Registradores | 1.666 | 15.915 (11%) |
| Block RAM (BSRAM) | 33 | 46 (72%) |
| rPLL | 1 | 2 |

## Arquivos

```
src/top.v                  topo, decodificação de I/O, clocks/reset
src/pll_135m.v             rPLL 27→135 MHz + CLKDIV /5
src/cpu/tv80_msx.v         wrapper do Z80 com clock enable
src/cpu/tv80/              núcleo tv80 (MIT, Guy Hutchison)
src/memory/slot_ctrl.v     decodificador de slots primários
src/memory/sdram_ctrl.v    controlador da SDRAM embutida
src/vdp/tms9918a.v         TMS9918A
src/video/                 codificador TMDS + serializador HDMI
src/psg/ay8910.v           AY-3-8910
src/ppi/ppi8255.v          i8255
src/keyboard/              receptor PS/2 + mapa de teclas MSX
src/sdcard/sd_spi.v        porta SPI do slot microSD
src/audio/pdm_dac.v        DAC de áudio sigma-delta
constraints/               pinagem
scripts/build.tcl          build pela linha de comando
sim/                       testbench, modelo da SDRAM, programa de teste
tools/make_rom.py          gera bios/msx_rom.mem
```

## Limitações conhecidas

- Ainda não testado em hardware (veja Situação).
- Sem slots de cartucho, sem slots expandidos, sem driver Nextor/MSX-DOS para o SD.
- Sem joystick nem interface de cassete.
- VDP: sem os limites de temporização de acesso à VRAM (software que dependa
  de VRAM lenta pode se comportar diferente); o bit 4/16 KB é ignorado.
- As teclas PS/2 seguem as teclas do MSX (layout internacional), não as do PC.

## Próximos passos

1. Dar boot no C-BIOS numa placa e corrigir o que aparecer.
2. Carregar ROMs de cartucho (do SD ou da flash) no slot 1.
3. Driver Nextor para a porta SD.
4. Joystick (DB9) e entrada de áudio de cassete.

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md). Rode `sh sim/run.sh` antes de enviar
uma mudança no RTL.

## Créditos

- [tv80](https://github.com/hutch31/tv80) de Guy Hutchison, baseado no T80 de Daniel Wallner (MIT)
- Equipe do [C-BIOS](https://cbios.sourceforge.net/), por uma BIOS de MSX livre
- Sipeed e a comunidade Tang Nano pela documentação da placa

## Referências

- [MSX2 Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) (cobre também o hardware do MSX1)
- [Manual do TMS9918A](http://www.unige.ch/medecine/nouspikel/ti99/tms9918a.htm)
- [Wiki da Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- [Documentação do Gowin GW2AR-18](https://www.gowinsemi.com/en/support/database/)
