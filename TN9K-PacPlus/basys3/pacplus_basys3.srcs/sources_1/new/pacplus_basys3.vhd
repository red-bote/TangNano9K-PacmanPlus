---------------------------------------------------------------------------------
-- Basys 3 top level for Pac-Man Plus
-- Source: TN9K-Pacplus.vhd by pinballwiz.org
--   (https://github.com/pinballwizz/TangNano9K-PacmanPlus). See that file for its
--   history.
-- Core: MikeJ (www.fpgaarcade.com), ROM descrambler: d18c7db
---------------------------------------------------------------------------------
--
-- 11/04/2026: initial Basys 3 release by Red~Bote
--
---------------------------------------------------------------------------------
-- License:
--  - Basys 3 changes: MIT (see LICENSE)
--  - Code from TN9K-Pacplus.vhd: no license stated
--  - Core (pacman*.vhd): (c) MikeJ, ROM descrambler (c) d18c7db, terms as
--    stated in the file headers
---------------------------------------------------------------------------------
--
-- Main features:
--  Connections:
--   VGA monitor, 640x480 at 31 kHz. 15 kHz RGB with sw13 up (not tested)
--   USB keyboard on the USB-HID host connector (MAME default keys)
--   Atari-type joystick on Pmod JA, pins 1/2/3/4 = right/left/down/up
--   PmodAMP2 with speaker on Pmod JXADC, pins 1/2/4
--  Controls       keyboard       stick          button
--   move          arrows         stick
--   coin          5                             btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 scanlines, sw13 15 kHz RGB, sw12 test mode,
--   sw0-sw7 DIP
--  DIP bits: coinage 1:0, lives 3:2, bonus 5:4, difficulty 6, ghost names 7,
--   switch down = default
--  Clock: 1 MMCM from 100 MHz, 24.571 MHz system, 25.595 MHz VGA output (25:24)
--
-- DIP values and other details: see basys3/README.md
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

---------------------------------------------------------------------------------
entity pacplus_basys3 is
port(
    clk         : in  std_logic;
    btnC        : in  std_logic;
    btnU        : in  std_logic;
    btnD        : in  std_logic;
    btnL        : in  std_logic;
    btnR        : in  std_logic;
    sw          : in  std_logic_vector(15 downto 0);
    vga_r       : out std_logic_vector(3 downto 0);
    vga_g       : out std_logic_vector(3 downto 0);
    vga_b       : out std_logic_vector(3 downto 0);
    hsync       : out std_logic;
    vsync       : out std_logic;
    ps2_clk     : in  std_logic;
    ps2_dat     : inout std_logic;
    JA          : in  std_logic_vector(4 downto 0);
    JXADC       : out std_logic_vector(3 downto 0);
    led         : out std_logic_vector(15 downto 0)
);
end pacplus_basys3;

------------------------------------------------------------------------------
architecture struct of pacplus_basys3 is

    signal clk_sys         : std_logic;
    signal clk_vid         : std_logic;
    signal locked          : std_logic;
    signal mmcm_reset      : std_logic := '0';
    --
    --
    signal native_r        : std_logic_vector(2 downto 0);
    signal native_g        : std_logic_vector(2 downto 0);
    signal native_b        : std_logic_vector(1 downto 0);
    signal native_csync_l  : std_logic;
    signal native_hs       : std_logic;
    signal native_vs       : std_logic;
    --
    signal sd_r_in         : std_logic_vector(5 downto 0);
    signal sd_g_in         : std_logic_vector(5 downto 0);
    signal sd_b_in         : std_logic_vector(5 downto 0);
    signal vga640_r        : std_logic_vector(5 downto 0);
    signal vga640_g        : std_logic_vector(5 downto 0);
    signal vga640_b        : std_logic_vector(5 downto 0);
    signal vga640_hs       : std_logic;
    signal vga640_vs       : std_logic;
    signal tv_r            : std_logic_vector(3 downto 0);
    signal tv_g            : std_logic_vector(3 downto 0);
    signal tv_b            : std_logic_vector(3 downto 0);
    signal tv_csync_l      : std_logic;
    --
    signal audio           : std_logic;
    --
    signal reset           : std_logic;
    --
    signal kbd_intr        : std_logic;
    signal kbd_scancode    : std_logic_vector(7 downto 0);
    signal joy_BBBBFRLDU   : std_logic_vector(8 downto 0);
    signal ps2_clk_meta    : std_logic;
    signal ps2_clk_s       : std_logic;
    signal ps2_dat_meta    : std_logic;
    signal ps2_dat_s       : std_logic;
    signal kbd_joy         : std_logic_vector(8 downto 0);
    signal btn_meta        : std_logic_vector(3 downto 0);
    signal btn_s           : std_logic_vector(3 downto 0);
    signal stick_meta      : std_logic_vector(4 downto 0);
    signal stick_s         : std_logic_vector(4 downto 0);
    attribute ASYNC_REG    : string;
    attribute ASYNC_REG of btn_meta, btn_s, stick_meta, stick_s : signal is "TRUE";
    attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
    --
    constant CLOCK_FREQ    : integer := 27E6;
    signal counter_clk     : std_logic_vector(25 downto 0);
    signal clock_4hz       : std_logic;
    signal AD              : std_logic_vector(15 downto 0);
    signal dip_sw          : std_logic_vector(7 downto 0);
    signal scanlines       : std_logic_vector(1 downto 0);

---------------------------------------------------------------------------
begin

    -- btnC reset, held until the MMCM locks
    reset <= btnC or (not locked);

---------------------------------------------------------------------------
    -- Clock: MMCM from the 100 MHz board clock. 24.571 MHz system clock, 25.595 MHz VGA
    -- clock (25/24 of the system clock, same VCO)
    clk_wiz_0 : entity work.clk_wiz_0
    port map (
        reset    => mmcm_reset,
        clk_in1  => clk,
        clk_out1 => clk_sys,
        clk_out2 => clk_vid,
        locked   => locked
    );

---------------------------------------------------------------------------
    -- DIP switches: switch up inverts the default bit
    dip_sw <= "11001001" xor sw(7 downto 0);

    -- sw14 up: scanlines, alternate lines at 50 % brightness (31 kHz output only)
    scanlines <= "10" when sw(14) = '1' else "00";

---------------------------------------------------------------------------
    pacplus : entity work.pacman
    port map (
        CLK_24MHz     => clk_sys,
        I_RESET       => reset,
        O_VIDEO_R     => open,
        O_VIDEO_G     => open,
        O_VIDEO_B     => open,
        O_HSYNC       => open,
        O_VSYNC       => open,
        O_AUDIO_L     => audio,
        O_AUDIO_R     => open,
        SW_LEFT       => joy_BBBBFRLDU(2),
        SW_RIGHT      => joy_BBBBFRLDU(3),
        SW_UP         => joy_BBBBFRLDU(0),
        SW_DOWN       => joy_BBBBFRLDU(1),
        I_COIN1       => joy_BBBBFRLDU(7),
        I_1P_START    => joy_BBBBFRLDU(5),
        I_2P_START    => joy_BBBBFRLDU(6),
        AD            => AD,
        O_R           => native_r,
        O_G           => native_g,
        O_B           => native_b,
        O_COMP_SYNC_L => native_csync_l,
        I_DIP_SW      => dip_sw,
        I_SCANLINES   => scanlines,
        O_HSYNC_NAT   => native_hs,
        O_VSYNC_NAT   => native_vs,
        I_TEST_L      => not sw(12) -- sw12 up: service mode (test screens)
    );

-----------------------------------------------------------------
    -- vga outputs

    -- VGA output: standard 640x480 timing on the VGA clock
    sd_r_in <= native_r & native_r;
    sd_g_in <= native_g & native_g;
    sd_b_in <= native_b & native_b & native_b;

    vga640 : entity work.scandoubler_vga
    port map (
        clk_sys   => clk_sys,
        clk_vid   => clk_vid,
        scanlines => scanlines,
        hs_in     => native_hs,
        vs_in     => native_vs,
        r_in      => sd_r_in,
        g_in      => sd_g_in,
        b_in      => sd_b_in,
        hs_out    => vga640_hs,
        vs_out    => vga640_vs,
        r_out     => vga640_r,
        g_out     => vga640_g,
        b_out     => vga640_b
    );

    -- sw13 up: 15 kHz TV with composite sync on HS
    process(clk_sys)
    begin
        if rising_edge(clk_sys) then
            tv_r       <= native_r & native_r(2);
            tv_g       <= native_g & native_g(2);
            tv_b       <= native_b & native_b;
            tv_csync_l <= native_csync_l;
        end if;
    end process;

    -- switches are static: the output select is not synchronized
    vga_r <= vga640_r(5 downto 2) when sw(13) = '0' else tv_r;
    vga_g <= vga640_g(5 downto 2) when sw(13) = '0' else tv_g;
    vga_b <= vga640_b(5 downto 2) when sw(13) = '0' else tv_b;
    hsync <= vga640_hs when sw(13) = '0' else tv_csync_l;
    vsync <= vga640_vs when sw(13) = '0' else '1';

-----------------------------------------------------------------
    -- sound: 1-bit DAC output of the core to the PmodAMP2

    JXADC(0) <= audio;
    JXADC(1) <= '1';        -- PmodAMP2 GAIN (JXADC2), active low: fixed low gain
    JXADC(2) <= '0';
    JXADC(3) <= not sw(15); -- PmodAMP2 SHUTD (JXADC4), active low: sw15 up = audio off

-----------------------------------------------------------------
    -- get scancode from keyboard

    process(clk_sys)
    begin
        if rising_edge(clk_sys) then
            ps2_clk_meta <= ps2_clk;
            ps2_clk_s    <= ps2_clk_meta;
            ps2_dat_meta <= ps2_dat;
            ps2_dat_s    <= ps2_dat_meta;
        end if;
    end process;

    keyboard : entity work.io_ps2_keyboard
    port map (
        clk       => clk_sys,
        kbd_clk   => ps2_clk_s,
        kbd_dat   => ps2_dat_s,
        interrupt => kbd_intr,
        scancode  => kbd_scancode
    );

-----------------------------------------------------------------
    -- translate scancode to joystick

    joystick : entity work.kbd_joystick
    port map (
        clk           => clk_sys,
        kbdint        => kbd_intr,
        kbdscancode   => std_logic_vector(kbd_scancode),
        joy_BBBBFRLDU => kbd_joy
    );

-----------------------------------------------------------------
    -- buttons and JA joystick (active low, pins 1/2/3/4 = R/L/D/U):
    -- 2-FF synchronizers, ORed with the keyboard
    process(clk_sys)
    begin
        if rising_edge(clk_sys) then
            btn_meta   <= btnU & btnD & btnL & btnR;
            btn_s      <= btn_meta;
            stick_meta <= JA;
            stick_s    <= stick_meta;
        end if;
    end process;

    joy_BBBBFRLDU(0) <= kbd_joy(0) or not stick_s(3); -- up
    joy_BBBBFRLDU(1) <= kbd_joy(1) or not stick_s(2); -- down
    joy_BBBBFRLDU(2) <= kbd_joy(2) or not stick_s(1); -- left
    joy_BBBBFRLDU(3) <= kbd_joy(3) or not stick_s(0); -- right
    joy_BBBBFRLDU(4) <= kbd_joy(4);
    joy_BBBBFRLDU(5) <= kbd_joy(5) or btn_s(1); -- start 1: btnL
    joy_BBBBFRLDU(6) <= kbd_joy(6) or btn_s(0); -- start 2: btnR
    joy_BBBBFRLDU(7) <= kbd_joy(7) or btn_s(3) or btn_s(2); -- coin: btnU, btnD
    joy_BBBBFRLDU(8) <= kbd_joy(8);

-----------------------------------------------------------------
    -- debug

    led(15 downto 6) <= (others => '0');

    process(reset, clk_sys)
    begin
        if reset = '1' then
            clock_4hz <= '0';
            counter_clk <= (others => '0');
        else
            if rising_edge(clk_sys) then
                if counter_clk = CLOCK_FREQ/8 then
                    counter_clk <= (others => '0');
                    clock_4hz <= not clock_4hz;
                    led(5 downto 0) <= not AD(9 downto 4);
                else
                    counter_clk <= counter_clk + 1;
                end if;
            end if;
        end if;
    end process;

------------------------------------------------------------------------
end struct;
