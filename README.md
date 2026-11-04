# Tang Nano 9K - Pacman Plus
![Model](TN9K-Pacplus.jpg)

Pacman Plus Arcade vhdl code ported to a Tang Nano 9K FPGA Board by Pinballwiz.org.  
Works with VGA Monitor. Code from MikeJ.

## Basys 3 port

Digilent Basys 3 version on branch `Port-to-Basys-3`, tested on hardware: see
[TN9K-PacPlus/basys3/README.md](TN9K-PacPlus/basys3/README.md).

The port changes core files shared with the Tang Nano 9K project: DIP switch, video
and scanlines ports (defaults keep the Tang Nano 9K settings), two Vivado
compatibility fixes and the sprite line buffer read enable. The Tang Nano 9K project
builds with the Gowin EDA, but has not been tested on Tang Nano 9K hardware.
