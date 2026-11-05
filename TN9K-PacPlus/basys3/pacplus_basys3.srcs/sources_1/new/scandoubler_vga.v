//
// scandoubler.v
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 

// scandoubler_vga: copy of scandoubler_new.v for the 640x480 VGA output of the Basys 3
// port of the Pac-Man hardware (Pac-Man, Ms. Pac-Man, Pac-Man Plus). The original stays
// unchanged in the core, so the Tang Nano build is not affected.
//
// Why: the original output keeps the source line length, 384 clocks per line at
// 32 kHz. LCD monitors detect it as 640x480 and sample 800 points per line, so they
// need a manual auto adjust and cut off edge columns.
//
// What changed: the output runs on its own clock clk_vid (25/24 x clk_sys from the
// same MMCM) with standard VGA 640x480 timing (800 x 528, negative syncs), locked to
// the source once per frame. A 320 x 240 window of the source (H_START, V_START) fills
// the 640 x 480 area from a 4-line buffer, each pixel and line shown twice.


module scandoubler_vga
#(
	// window: source pixels from the hsync falling edge, lines from the vsync rising edge
	parameter H_START = 18,
	parameter V_START = 16
)
(
	// system interface
	input            clk_sys,
	input            clk_vid,

	// scanlines (00-none 01-25% 10-50% 11-75%)
	input      [1:0] scanlines,

	// shifter video interface
	input            hs_in,
	input            vs_in,
	input      [5:0] r_in,
	input      [5:0] g_in,
	input      [5:0] b_in,

	// output interface
	output reg       hs_out,
	output reg       vs_out,
	output reg [5:0] r_out,
	output reg [5:0] g_out,
	output reg [5:0] b_out
);

// try to detect changes in input signal and lock input clock gate
// it

reg [1:0] i_div;
wire ce_x1 = (i_div == 2'b01);

reg last_hs_in;
always @(posedge clk_sys) begin
	last_hs_in <= hs_in;
	if(last_hs_in & !hs_in) begin
		i_div <= 2'b00;
	end else begin
		i_div <= i_div + 2'd1;
	end
end	


// --------------------- create output signals -----------------
// latch everything once more to make it glitch free and apply scanline effect
reg scanline;
always @(posedge clk_vid) begin
	begin
		hs_out <= hs_sd;
		vs_out <= vs_sd;

		// if no scanlines or not a scanline
		if(!scanline || !scanlines) begin
			r_out <= { sd_out[17:12] };
			g_out <= { sd_out[11:6] };
			b_out <= { sd_out[5:0] };

		end else begin
			case(scanlines)
				1: begin // reduce 25% = 1/2 + 1/4
					r_out <= {1'b0, sd_out[16:13], 1'b0} + {2'b00, sd_out[16:13]};
					g_out <= {1'b0, sd_out[10:7],  1'b0} + {2'b00, sd_out[10:7] };
					b_out <= {1'b0, sd_out[4:1],  1'b0} + {2'b00, sd_out[4:1]  };
				end

				2: begin // reduce 50% = 1/2
					r_out <= {1'b0, sd_out[16:13], 1'b0};
					g_out <= {1'b0, sd_out[10:7],  1'b0};
					b_out <= {1'b0, sd_out[4:1],  1'b0};
				end

				3: begin // reduce 75% = 1/4
					r_out <= {2'b00, sd_out[16:13]};
					g_out <= {2'b00, sd_out[10:7]};
					b_out <= {2'b00, sd_out[4:1]};
				end
			endcase
		end
	end
end

// scan doubler output register
reg [17:0] sd_out;

// ==================================================================
// ======================== the line buffers ========================
// ==================================================================

// 4 lines of 512 pixels 3*6 bit RGB, written at clk_sys, read at clk_vid
(* ramstyle = "no_rw_check" *) reg [17:0] sd_buffer[0:2047];

// source line from the vsync rising edge, its low bits select the buffer line
reg  [8:0] vline = 9'd511;
reg        vs_line = 1'b0;
// toggles at the start of the first window line (frame start for the output)
reg        frame_tgl = 1'b0;

reg  [9:0] hcnt;

reg hsD = 1'b0;
always @(posedge clk_sys) begin

	if(ce_x1) begin
		hsD <= hs_in;

		// falling edge of hsync indicates start of line
		if(hsD && !hs_in) begin
			hcnt <= 0;
			vs_line <= vs_in;
			if(vs_in && !vs_line) vline <= 0;
			else if(vline != 9'd511) vline <= vline + 1'd1;
			if((vs_in && !vs_line ? 9'd0 : vline + 1'd1) == V_START) frame_tgl <= !frame_tgl;
		end else if(hcnt != 10'd1023) begin
			hcnt <= hcnt + 1'd1;
		end

		if(!hcnt[9]) sd_buffer[{vline[1:0], hcnt[8:0]}] <= {r_in, g_in, b_in};
	end
end

// ==================================================================
// ==================== output timing generation ====================
// ==================================================================

// VGA 640x480: H sync 96, back porch 48, active 640, front porch 16 (800)
// V sync 2, back porch 33, active 480, front porch 13 (528, source 264 lines x 2)
localparam H_ACT = 10'd144;
localparam V_ACT = 10'd35;
// set at the frame start: two output lines (one source line) before the first active
// line, H_LOAD covers the synchronizer delay
localparam V_LOAD = 10'd33;
localparam H_LOAD = 10'd3;

reg  [9:0] h = 10'd0;
reg  [9:0] v = 10'd0;
reg [10:0] rd_addr;
reg [17:0] sd_rd;
reg  [1:0] hs_p, vs_p, sl_p, de_p;
reg        hs_sd, vs_sd;

(* ASYNC_REG = "TRUE" *) reg tgl_meta = 1'b0;
(* ASYNC_REG = "TRUE" *) reg tgl_s = 1'b0;
reg tgl_d = 1'b0;

// in lock, h is H_LOAD - 1 at the frame start: no load within one clock of it
wire load = (tgl_s != tgl_d) && (v != V_LOAD || h < H_LOAD - 10'd2 || h > H_LOAD);
wire [9:0] hx = h - H_ACT;
wire [9:0] vy = v - V_ACT;
wire de = (h >= H_ACT) && (h < H_ACT + 10'd640) && (v >= V_ACT) && (v < V_ACT + 10'd480);
wire [8:0] wl = V_START + vy[9:1];
wire [8:0] wx = H_START + hx[9:1];

always @(posedge clk_vid) begin
	tgl_meta <= frame_tgl;
	tgl_s <= tgl_meta;
	tgl_d <= tgl_s;

	if(load) begin
		h <= H_LOAD;
		v <= V_LOAD;
	end else if(h == 10'd799) begin
		h <= 0;
		v <= (v == 10'd527) ? 10'd0 : v + 1'd1;
	end else begin
		h <= h + 1'd1;
	end

	// stage 1: read address, stage 2: read data from line sd_buffer, stage 3: blanking
	rd_addr <= {wl[1:0], wx};
	sd_rd <= sd_buffer[rd_addr];
	sd_out <= de_p[1] ? sd_rd : 18'd0;

	hs_p <= {hs_p[0], h >= 10'd96};
	vs_p <= {vs_p[0], v >= 10'd2};
	de_p <= {de_p[0], de};
	sl_p <= {sl_p[0], vy[0]};
	hs_sd <= hs_p[1];
	vs_sd <= vs_p[1];
	// second line of each output line pair
	scanline <= sl_p[1];
end

endmodule
