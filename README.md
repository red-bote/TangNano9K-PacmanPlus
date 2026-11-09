# Tang Nano 9K - Pacman Plus

Pacman Plus Arcade vhdl code ported to a Tang Nano 9K FPGA Board by Pinballwiz.org.  
Works with VGA Monitor. Code from MikeJ.

## Basys 3 port

Digilent Basys 3 version on branch `Port-to-Basys-3`, tested on hardware: see
[TN9K-PacPlus/basys3/README.md](TN9K-PacPlus/basys3/README.md).

The Basys 3 version changes some core files shared with the Tang Nano 9K project: new
inputs and outputs for the Basys 3 top (DIP switches, video, syncs, scanlines, test
switch), two Vivado compatibility fixes and the sprite fix. The Tang Nano 9K top leaves
the new outputs unconnected, and the new inputs default to its settings. The Tang Nano
9K project builds with the Gowin EDA, but has not been tested on Tang Nano 9K hardware.
