# 1942 - for MEGA65

1942 is Capcom's 1984 vertically scrolling shoot-'em-up arcade game.
The player pilots a Lockheed P-38 Lightning over the Pacific, fighting enemy
aircraft and avoiding incoming fire while progressing through a series of
missions.

This project ports the **1942** FPGA core from **Jotego's JTCORES project**
to the MEGA65.

The upstream 1942 core used as the basis of this port is:

[Jotego JTCORES - 1942](https://github.com/jotego/jtcores/tree/master/cores/1942)

The original 1942 FPGA implementation, JTFRAME infrastructure and associated
supporting cores are the work of **Jotego and the JTCORES contributors**.

The MEGA65 port uses the
[MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and
[QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for integration with the
MEGA65, including FAT32 ROM loading and the on-screen menu.

## Credits

1942 was originally developed and released by **Capcom** in 1984.

This MEGA65 core would not exist without the work of **Jotego and the
JTCORES contributors**. The MEGA65 version is based on the JTCORES 1942
implementation linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65
contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA integration
used by this port.

## How to install the core

### 1. Obtain the 1942 ROM set

You need the MAME **1942** ROM set:

`1942.zip`

ROM files are **not included** with this repository.

The ROM conversion scripts expect the ZIP to contain these files:

```text
srb-03.m3
srb-04.m4
srb-05.m5
srb-06.m6
srb-07.m7
sr-01.c11
sr-02.f2
sr-14.l1
sr-15.l2
sr-16.n1
sr-17.n2
sr-08.a1
sr-09.a2
sr-10.a3
sr-11.a4
sr-12.a5
sr-13.a6
sb-5.e8
sb-6.e9
sb-7.e10
sb-0.f1
sb-4.d6
sb-8.k3
sb-2.d1
sb-3.d2
sb-1.k6
```

The conversion will stop if a required file is missing or if a generated
ROM has an unexpected size. The scripts display CRC32 checksums of the
generated images; they do **not** verify the input chips against a fixed
list of MAME CRCs.

### 2. Generate the MEGA65 ROM images

Three ROM conversion scripts are provided:

- `build_1942_roms.py` - Python
- `1942.ps1` - Windows PowerShell
- `1942.sh` - Linux/macOS Bash

The scripts read the files directly from `1942.zip`; you do **not** need
to extract the MAME ZIP first.

The conversion follows the JTCORES ROM layout, including program ROM
bank repetition, character byte swapping, graphics ROM interleaving,
PROM padding, and the JTFRAME `hvvvvxx` object/sprite address transformation.

**Important:** The Bash and PowerShell scripts enable `hvvvvxx` object
sorting by default. The Python script requires `--sort-objects` to produce
the same sorted object ROM. The matching FPGA object-ROM address remapping
must be present when using sorted data.

#### Windows / PowerShell

Place `1942.ps1` and `1942.zip` in the project directory and run:

```powershell
.\1942.ps1
```

If Windows displays a warning because the script was downloaded from the
Internet, unblock it first:

```powershell
Unblock-File .\1942.ps1
```

#### Linux / macOS

Place `1942.sh` and `1942.zip` in the project directory.

Make the script executable if necessary:

```bash
chmod +x 1942.sh
```

Then run:

```bash
./1942.sh
```

The Bash version requires `bash`, `perl` (including the
`IO::Uncompress::Unzip` and `Compress::Raw::Zlib` modules), and `unzip`.

#### Python

Run the Python version with object sorting explicitly enabled:

```bash
python3 build_1942_roms.py 1942.zip --sort-objects
```

The Python script requires Python 3 and uses standard-library modules.

### 3. Generated ROM files

By default, the scripts create the directory:

```text
arcade/1942
```

containing:

```text
1942_main.rom
1942_sound.rom
1942_char.rom
1942_obj.rom
1942_scr.rom
1942_prom.rom
```

The expected ROM sizes and CRC32 checksums for the tested `1942.zip`
set, with **sorted** objects, are:

| File | Size (hex) | Size (bytes) | CRC32 |
|---|---:|---:|---|
| `1942_main.rom` | `0x14000` | 81920 | `0EA41B9C` |
| `1942_sound.rom` | `0x04000` | 16384 | `BD87F06B` |
| `1942_char.rom` | `0x02000` | 8192 | `BD7804EE` |
| `1942_obj.rom` | `0x10000` | 65536 | `371309D4` |
| `1942_scr.rom` | `0x10000` | 65536 | `1290A167` |
| `1942_prom.rom` | `0x00A00` | 2560 | `82CAFD1B` |

If object sorting is disabled, `1942_obj.rom` instead has CRC32
`B5F0D2A6` for the same ROM set. The other generated files are unchanged.

### 4. Copy the ROMs to the MEGA65 SD card

Copy the six generated ROM files to this directory on your MEGA65 SD card:

```text
/arcade/1942
```

Also copy the supplied 1942 configuration file to this directory.

Both the bottom SD card slot and rear SD card slot can be used. As with
other MEGA65 cores, the rear SD card takes precedence when both are
present.

Install the 1942 `.cor` file using the normal MEGA65 core installation
procedure.

## Game setup

Press the **HELP** key while the core is running to open the
MiSTer2MEGA65 on-screen menu.

The menu provides display, control and DIP-switch settings for the core.

### Video output

1942 is a vertically oriented arcade game. The MEGA65 port uses the
MiSTer2MEGA65 rotation/frame-buffer support to present the arcade display
in the correct orientation.

Available digital and analog video options depend on the build and
MiSTer2MEGA65 configuration. The VGA menu can provide standard output,
retro 15 kHz with separate HS/VS, and retro 15 kHz with CSYNC.

### Controls

1942 uses an eight-way joystick and two action buttons:

- **Fire** - shoot enemy aircraft.
- **Loop** - perform a defensive looping manoeuvre (limited uses).

The MEGA65 joystick ports provide directional control. Where configured
by the core, the second action button can use the joystick POTX/POTY
second-button input. Check the on-screen menu for the available
second-button selection and polarity settings.

### DIP switches

The original 1942 arcade DIP-switch settings can be configured through
the on-screen menu where exposed by the port. These govern game options
such as difficulty, lives, and coin settings.

## Upstream projects

This port builds upon the work of several open-source FPGA projects:

- [Jotego JTCORES](https://github.com/jotego/jtcores)
- [1942 core in JTCORES](https://github.com/jotego/jtcores/tree/master/cores/1942)
- [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
- [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)

Please support the upstream projects and developers whose work made this
MEGA65 port possible.

## Status

This is an initial MEGA65 port of the 1942 core.

Please report MEGA65-specific problems through the 1942 MEGA65 project
rather than to the upstream JTCORES project unless the problem has also
been reproduced on the original upstream implementation.

## KNOWN ISSUES
If you enable flip mode and wait for the CAPCOM logo screen to appear for the second time, the animation will not be displayed correctly. This occurs because that logo is printed using two sprites right at the limit of the vertical split line (schematics 5/8). This is a genuine bug of the original hardware. The CAPCOM logo works correctly when not in flip mode.
