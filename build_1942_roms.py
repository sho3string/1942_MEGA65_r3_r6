#!/usr/bin/env python3
"""Build six MEGA65 1942 ROM files from MAME 1942.zip.

Uses Jotego's mame2mra.toml sequence, reverse, and bus-width layout.
Optionally applies JTFRAME gfx_sort=hvvvvxx to the object ROM.
The matching FPGA address remap must be present when using sorted data.
"""
import argparse
from pathlib import Path
from zipfile import ZipFile
import zlib

PROM_CHIPS = ['sb-5.e8','sb-6.e9','sb-7.e10','sb-0.f1','sb-4.d6',
              'sb-8.k3','sb-2.d1','sb-3.d2',None,'sb-1.k6']

def interleave(chunks, width):
    """Width in bits; successive chips fill consecutive byte lanes."""
    lanes = width // 8
    assert len(chunks) % lanes == 0
    result = bytearray()
    for i in range(0, len(chunks), lanes):
        group = chunks[i:i+lanes]
        assert len({len(x) for x in group}) == 1, 'Lane chips have different lengths'
        for col in zip(*group):
            result.extend(col)
    return bytes(result)

def sort_object_hvvvvxx(data):
    """JTFRAME gfx16c, b0=2: remapBits(addr, 2, [4,0,1,2,3])."""
    result = bytearray(len(data))
    for src, value in enumerate(data):
        dst = (src & ~0x7c) | ((src & 0x40) >> 4) | ((src & 0x3c) << 1)
        result[dst] = value
    return bytes(result)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('zip', nargs='?', default='1942.zip')
    ap.add_argument('-o', '--out', default='arcade/1942')
    ap.add_argument('--sort-objects', action='store_true',
                    help='Apply JTFRAME hvvvvxx sorting to 1942_obj.rom')
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.zip) as z:
        def chip(name):
            return z.read(name)
        # maincpu sequence=[0,1,2,3,3,4]: the fourth chip is 8 KiB,
        # repeated to fill the 16 KiB bank before the fifth chip.
        mainrom = b''.join(chip(n) for n in ('srb-03.m3','srb-04.m4','srb-05.m5'))
        mainrom += chip('srb-06.m6') * 2 + chip('srb-07.m7')
        snd = chip('sr-01.c11')
        # Jotego gfx1 reverse=true: swap bytes within each 16-bit word.
        char = swap_byte_pairs(chip('sr-02.f2'))
        objchips = [
                        chip(f"sr-{n}.{('l' if n in (14, 15) else 'n')}{1 if n % 2 == 0 else 2}")
                        for n in (14, 15, 16, 17)
                    ]
        obj = interleave([objchips[i] for i in (2,0,3,1)], 16)
        if args.sort_objects:
            obj = sort_object_hvvvvxx(obj)
        tiles = [chip(f'sr-{n:02d}.a{n-7}') for n in range(8,14)]
        scr = interleave([tiles[i] for i in (0,2,4,4,1,3,5,5)], 32)
        prom = b''.join(chip(n) if n else bytes(256) for n in PROM_CHIPS)
        files = {'1942_main.rom':mainrom,'1942_sound.rom':snd,
                 '1942_char.rom':char,'1942_obj.rom':obj,
                 '1942_scr.rom':scr,'1942_prom.rom':prom}
        expected = [0x14000,0x4000,0x2000,0x10000,0x10000,0xA00]
        for (name, data), size in zip(files.items(), expected):
            assert len(data) == size, (name, len(data), size)
            (out / name).write_bytes(data)
            print(f'{name:20} {len(data):7} bytes  CRC32 {zlib.crc32(data):08X}')
    print('Object sorting:', 'hvvvvxx' if args.sort_objects else 'none')
    
def swap_byte_pairs(data):
    if len(data) % 2:
        raise ValueError("ROM length must be even")

    result = bytearray(data)

    for i in range(0, len(result), 2):
        result[i], result[i + 1] = result[i + 1], result[i]

    return bytes(result)

if __name__ == '__main__':
    main()
