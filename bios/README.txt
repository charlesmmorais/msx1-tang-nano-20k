BIOS ROM — C-BIOS para MSX1
============================

O arquivo cbios_main_msx1.mem NÃO está incluído neste repositório.
Você precisa baixar o C-BIOS (firmware MSX open source) e convertê-lo.

PASSO 1: Baixar C-BIOS
  https://cbios.sourceforge.net/
  ou via pacote de qualquer emulador MSX (openMSX, fMSX)

PASSO 2: Converter .ROM para .mem (formato hex para $readmemh)
  python3 convert_rom.py cbios_main_msx1.rom cbios_main_msx1.mem

PASSO 3: Tamanho esperado
  cbios_main_msx1.rom = 32768 bytes (32KB)
  cbios_sub.rom       = 16384 bytes (16KB) — opcional

Script de conversão incluso em tools/convert_rom.py
