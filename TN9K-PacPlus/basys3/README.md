# Pac-Man Plus - Digilent Basys 3

Pac-Man Plus (© 1982 Namco Ltd., Midway license), FPGA core by MikeJ
(www.fpgaarcade.com), ROM descrambler by d18c7db, Tang Nano 9K port by pinballwiz.org
(<https://github.com/pinballwizz/TangNano9K-PacmanPlus>), built here for the Digilent
Basys 3 (Artix-7 `xc7a35tcpg236-1`).

## Hardware

- Digilent Basys 3.
- VGA monitor (640x480, 31 kHz), or a 15 kHz TV/CRT (sw13, not tested).
- USB keyboard on the Basys 3 USB-HID host port.
- Optional: Atari-style joystick on Pmod JA, Digilent PmodAMP2 on Pmod JXADC.

## Build

Requirements:

- Vivado 2020.2, gcc, make, unzip, openFPGALoader.
- Romset `pacplus.zip`, supplied by the user. Roms are not part of this repository.
  The program ROMs stay encrypted, the core decrypts them
  (`src/pacman_rom_descrambler.vhd`).

```
make roms        # compile make_vhdl_prom, unzip ~/roms/pacplus.zip, generate PROM VHDL
make bitstream   # Vivado batch build of basys3/pacplus_basys3.xpr
make load        # program the Basys 3 (SRAM), building first if the bitstream is outdated
make clean       # remove roms, PROM VHDL and Vivado outputs
```

- `ROMDIR=<dir>` or `ROMZIP=<zip>` selects the romset.
- `VIVADO=<path>` selects the Vivado binary.

## IO

| Input           | Function                                      |
|-----------------|-----------------------------------------------|
| Arrow keys      | move                                          |
| 1 / 2           | start 1 player / 2 players                    |
| 5               | coin                                          |
| btnU, btnD      | coin                                          |
| btnL / btnR     | start 1 player / 2 players                    |
| btnC            | reset                                         |
| JA 1/2/3/4      | joystick right/left/down/up (active low)      |
| sw0-sw7         | DIP switches (down = default, see below)      |
| sw12 up         | service mode (self-test, test screens)        |
| sw13 down       | 31 kHz VGA                                    |
| sw13 up         | 15 kHz TV, composite sync on HS (not tested)  |
| sw14 up         | scanlines, alternate lines at 50 %, 31 kHz    |
| sw15 up         | audio off (PmodAMP2 shutdown)                 |

DIP switches (switch up inverts the default bit):

| Bits | Setting     | Default         |
|------|-------------|-----------------|
| 1:0  | coinage     | 1 coin 1 credit |
| 3:2  | lives       | 3               |
| 5:4  | bonus       | 10000           |
| 6    | difficulty  | normal          |
| 7    | ghost names | normal          |

Ghost names up: alternate names ("AAAAAAAA", "BBBBBBBB", ...).

## Clock

The core runs on one 24.571 MHz clock (6.143 MHz pixel rate, original board 6.144 MHz)
with clock enables.

## VGA

The VGA output uses standard 640x480 timing (32.0 kHz, 60.6 Hz).

- The scan doubler in the core outputs 384 clocks per line. LCD monitors detect
  640x480, which has 800, so they sample the picture at the wrong points: it needs auto
  adjust and loses its edge columns, or does not sync at all. It is not used here.
- `scandoubler_vga.v` is a modified copy of that scan doubler. The core file stays
  unchanged for the Tang Nano 9K build. It outputs 800 clocks per line on a second MMCM
  clock, 25.595 MHz, exactly 25/24 of the system clock, so the picture stays locked to
  the core.
- Each pixel and each line is shown twice: the picture is 576 x 448, centred.

## Core changes for the Basys 3 port

Changes to the core files in `src/` (shared with the Tang Nano 9K project):

- DIP switch input, native video and timing outputs and scanlines input of `pacman` for
  the Basys 3 top (`pacman.vhd`). Unconnected in the Tang Nano 9K top, defaults keep its
  settings.
- Vivado elaboration error: palette PROM address connected in full
  (`pacman_video.vhd`).
- Vivado synthesis error: scan doubler `scanlines` input through a signal
  (`pacman.vhd`).
- Sprite errors (sprites one pixel early, errors where sprites overlap): sprite line
  buffer read on the pixel enable, as the original design (`dpram.vhd`,
  `pacman_video.vhd`).

## Third-party additions

PROM tool, unmodified, from <https://github.com/pinballwizz/DE2-Xevious> (commit
`a5d9eed`):

| File                                        | Function                   | Author  |
|---------------------------------------------|----------------------------|---------|
| `tools/tools_prom_src/src/make_vhdl_prom.c` | PROM-to-VHDL converter     | darfpga |

VGA output, a modified copy of the MiST scan doubler `src/scandoubler_new.v` of the core
(in `basys3/pacplus_basys3.srcs/sources_1/new/`, changes listed in its header):

| File                | Function                   | Author       |
|---------------------|----------------------------|--------------|
| `scandoubler_vga.v` | 640x480 VGA scan doubler   | Till Harbaum |

## License

- The additions and changes made for the Basys 3 port are MIT licensed.
- Core files (`src/pacman*.vhd`): (c) MikeJ, ROM descrambler
  (`src/pacman_rom_descrambler.vhd`) (c) d18c7db, terms as stated in their headers.
  Other code keeps the terms stated in its files. `make_vhdl_prom.c` states no license.
- `scandoubler_vga.v`: GPL-3.0 or later, like the MiST scan doubler it is copied from.
  This includes the Basys 3 changes.
- Roms and anything generated from them (PROM VHDL, bitstreams) are not distributed.
