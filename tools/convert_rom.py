#!/usr/bin/env python3
"""
Converte arquivo .ROM binário para formato hex $readmemh do Verilog.
Uso: python3 convert_rom.py input.rom output.mem
"""
import sys

def convert(infile, outfile):
    with open(infile, 'rb') as f:
        data = f.read()
    with open(outfile, 'w') as f:
        for i, byte in enumerate(data):
            f.write(f'{byte:02x}\n')
    print(f'Convertido: {len(data)} bytes de {infile} → {outfile}')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Uso: python3 convert_rom.py input.rom output.mem')
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
