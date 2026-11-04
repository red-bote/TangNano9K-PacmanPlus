#!/bin/bash
# Generate the PROM VHDL from the Pac-Man Plus romset into ../proms/ (port of
# make_pacplus_proms.bat):
#   1. compile make_vhdl_prom into tools_prom_src/bin/
#   2. unzip ROMZIP (comma-separated) or ${ROMDIR:-~/roms}/pacplus.zip into unzip/
#   3. write the PROM VHDL and the stamp .done into ../proms/
# The program ROMs stay encrypted, the core decrypts them (pacman_rom_descrambler.vhd).
# make_vhdl_prom names the entity after the output file, so it writes into unzip/ and
# the result is moved.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROM_DIR="$HERE/../proms"
UNZIP="$HERE/unzip"
TOOL="$HERE/tools_prom_src/bin/make_vhdl_prom"

if [ -n "${ROMZIP:-}" ]; then
    IFS=, read -r -a romzips <<< "$ROMZIP"
else
    romzips=("${ROMDIR:-$HOME/roms}/pacplus.zip")
fi
for z in "${romzips[@]}"; do
    if [ ! -f "$z" ]; then
        echo "error: romset not found: $z (set ROMDIR or ROMZIP)" >&2
        exit 1
    fi
done

mkdir -p "$(dirname "$TOOL")" "$UNZIP" "$PROM_DIR"
gcc -w "$HERE/tools_prom_src/src/make_vhdl_prom.c" -lm -o "$TOOL"

for z in "${romzips[@]}"; do
    unzip -q -o "$z" -d "$UNZIP"
done
cd "$UNZIP"

prom() {
    "$TOOL" "$1" "$2"
    mv -f "$2" "$PROM_DIR/$2"
}

cat pacplus.5e pacplus.5f > gfx1.bin
prom gfx1.bin GFX1.vhd

cat pacplus.6e pacplus.6f pacplus.6h pacplus.6j > main.bin
prom main.bin ROM_PGM_0.vhd

prom 82s126.1m PROM1_DST.vhd
prom pacplus.4a PROM4_DST.vhd
prom pacplus.7f PROM7_DST.vhd

touch "$PROM_DIR/.done"   # stamp for the Makefile bitstream prerequisite
echo "PROM VHDL in $PROM_DIR:"
ls -1 "$PROM_DIR"
