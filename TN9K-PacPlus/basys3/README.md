# Pac-Man Plus - Digilent Basys 3

Pac-Man Plus (1982 Midway), FPGA core by MikeJ (www.fpgaarcade.com), ROM descrambler by
d18c7db, based on Tang Nano 9K port by pinballwiz.org
(<https://github.com/pinballwizz/TangNano9K-PacmanPlus>).

## Hardware

- Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`).
- VGA monitor (640x480, 31 kHz), or a 15 kHz TV/CRT (sw13, not tested).
- USB keyboard on the Basys 3 USB-HID host port.
- Optional: Atari-style joystick on Pmod JA, Digilent PmodAMP2 on Pmod JXADC.

## Build

Requirements:

- Vivado 2020.2, gcc, make, unzip, openFPGALoader.
- Romset `pacplus.zip`. The program ROMs stay encrypted, the core decrypts them
  (`src/pacman_rom_descrambler.vhd`).

```
make roms        # compile make_vhdl_prom, unzip ~/roms/pacplus.zip, generate PROM VHDL
make bitstream   # Vivado batch build of basys3/pacplus_basys3.xpr
make load        # program the xc7 in JTAG mode (jumper JP1 in the JTAG position)
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

The VGA output uses standard 640x480 timing (32.0 kHz, 60.6 Hz) from `scandoubler_vga.v`,
a modified copy of the core scan doubler on a second MMCM clock (25.595 MHz, 25/24 of the
system clock). The core scan doubler outputs 384 clocks per line, which LCD monitors
sample incorrectly at 640x480.

## Core changes for the Basys 3 port

Changes to the core files in `src/` (shared with the Tang Nano 9K project):

- DIP switch input, native video and timing outputs and scanlines input of `pacman` for
  the Basys 3 top (`pacman.vhd`).
- Vivado elaboration error: palette PROM address connected in full
  (`pacman_video.vhd`).
- Vivado synthesis error: scan doubler `scanlines` input through a signal
  (`pacman.vhd`).
- Sprite errors (sprites one pixel early, errors where sprites overlap): sprite line
  buffer read on the pixel enable, as the original design (`dpram.vhd`,
  `pacman_video.vhd`).

## Third-party additions

- `tools/tools_prom_src/src/make_vhdl_prom.c` (darfpga): PROM-to-VHDL converter,
  unmodified, from <https://github.com/pinballwizz/DE2-Xevious>.
- `basys3/pacplus_basys3.srcs/sources_1/new/scandoubler_vga.v` (Till Harbaum): 640x480 VGA
  scan doubler, a modified copy of the MiST scan doubler `src/scandoubler_new.v` of the
  core, changes listed in its header.

## License

- The additions and changes made for the Basys 3 port are MIT licensed.
- Core files (`src/pacman*.vhd`): (c) MikeJ, ROM descrambler
  (`src/pacman_rom_descrambler.vhd`) (c) d18c7db, terms as stated in their headers.
  Other code keeps the terms stated in its files. `make_vhdl_prom.c` states no license.
- `scandoubler_vga.v`: GPL-3.0 or later, like the MiST scan doubler it is copied from.
  This includes the Basys 3 changes.
- Roms and anything generated from them (PROM VHDL, bitstreams) are not distributed.
