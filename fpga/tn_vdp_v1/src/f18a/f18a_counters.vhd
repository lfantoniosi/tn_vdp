--
-- F18A
--   A pin-compatible enhanced replacement for the TMS9918A VDP family.
--   https://dnotq.io
--

-- Released under the 3-Clause BSD License:
--
-- Copyright 2011-2018 Matthew Hagerty (matthew <at> dnotq <dot> io)
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its
-- contributors may be used to endorse or promote products derived from this
-- software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

-- Version history.  See README.md for details.
--
--   V1.9 Dec 31, 2018
--   V1.8 Aug 24, 2016
--   V1.7 Jan  1, 2016
--   V1.6 May  3, 2014 .. Apr 26, 2015
--   V1.5 Jul 23, 2013
--   V1.4 Mar 20, 2013 .. Apr 26, 2013
--   V1.3 Jul 26, 2012, Release firmware

-- Counters for tile and sprite address generation.  Tightly bound to the VGA
-- raster display parameters.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_counters is
   port (
      clk            : in std_logic;
      vga_clk        : in std_logic;
      rst_n          : in std_logic;            -- reset active low
      raster_x       : in unsigned(0 to 9);
      raster_y       : in unsigned(0 to 9);
      y_tick         : in std_logic;
      y_max          : in std_logic;
      sprt_yreal     : in std_logic;            -- 1 to use real sprite location, 0 for original off-by-one
      gmode          : in unsigned(0 to 3);
      row30          : in std_logic;            -- 1 when 30 rows
      blank_in       : in std_logic;            -- VGA blanking signal in
      sl_blank       : out std_logic;           -- scan line blanking signal out
      intr_en        : out std_logic;           -- interrupt tick
      sp_cf_en       : out std_logic;           -- sprite collision flag tick
      scanline       : out unsigned(0 to 7);    -- current horz scan line location
      in_margin      : out std_logic;
      y_margin_n     : out std_logic;
      x_pixel_max    : out unsigned(0 to 8);    -- max pixel count
      x_pixel_pos    : out unsigned(0 to 8);    -- current x location for tiles
      x_sprt_pos     : out unsigned(0 to 7);    -- current x location for sprites
      y_next         : out unsigned(0 to 8);    -- next y location for tiles
      y_sprt_pos     : out unsigned(0 to 7);    -- next y location for sprites
      prescan_start  : out std_logic
   );
end f18a_counters;

architecture rtl of f18a_counters is

   -- Start and end points to center the display on the VGA screen.
   -- Anything outside of this area will be border color.
   -- Values are inclusive to the active area.

   -- 0 to 63 (left 64px margin), 64 to 575 (512px), 576 to 639 (right 64px margin)
   -- 0 to 79 (left 80px margin), 80 to 559 (480px), 560 to 639 (right 80px margin)
   constant XSTART   : integer := 64;     -- X start
   constant XSTART2  : integer := 80;     -- X start for text mode
   constant XEND     : integer := 575;    -- X end
   constant XEND2    : integer := 559;    -- X end for text mode

   -- 32/40 x 24 tiles = 256/240 x 192 2x-pixels = 512 x 384 1x-pixels
   -- 0 to 47 (top 48px margin), 48 to 431 (384px), 432 to 479 (bottom 48px margin)
   constant YPRESCAN : integer := 47;
   constant YSTART   : integer := 48;
   constant YEND     : integer := 431;

   constant SL_RESET1: integer := 46;
   constant SL_RESET2: integer := 523;

   -- 32 x 30 tiles = 256 x 240 2x-pixels = 512 x 480 1x-pixels
   -- No top or bottom margin
   -- YPRESCAN2 *MUST* match VMAX from the VGA controller
   constant YPRESCAN2: integer := 524;
   constant YSTART2  : integer := 0;
   constant YEND2    : integer := 479;

   -- Margin indicators
   signal xmargin    : std_logic;
   signal ymargin    : std_logic;

   signal xstart_mux : unsigned(0 to 9);
   signal xend_mux   : unsigned(0 to 9);
   signal ystart_mux : unsigned(0 to 9);
   signal yend_mux   : unsigned(0 to 9);

   signal margin_next: std_logic;
   signal margin_reg : std_logic;
   signal y_margin_reg : std_logic;

   signal row30reg   : std_logic;
   signal y_count_en : std_logic;

   signal x_pixel_pos_reg  : unsigned(0 to 8);     -- current x location for tiles
   signal x_pixel_pos_next : unsigned(0 to 8);
   signal x_sprt_pos_reg   : unsigned(0 to 7);     -- current x location for sprites
   signal x_sprt_pos_next  : unsigned(0 to 7);

   -- Interrupt
   signal intr_ff       : std_logic;
   signal valid_y       : std_logic;
   signal valid_y_last  : std_logic;

   signal vga_clk_logic : std_logic := '0';
   signal vga_clk_last  : std_logic;
   signal sprt_cf_ff    : std_logic;

   -- X 1x-pixels
   signal x480 : unsigned(0 to 9);  -- text modes (8x6 tiles)
   signal x512 : unsigned(0 to 9);  -- graphics modes (8x8 tiles)

   -- X 2x-pixels
   signal x240 : unsigned(0 to 7);
   signal x256 : unsigned(0 to 7);


   -- Y 1x-pixels
   signal y_count : unsigned(0 to 8);  -- 0 to 480 == 9-bits

   -- Y 2x-pixels
   signal y_half : unsigned(0 to 7);

   -- Scan line counter
   signal scanline_cnt     : unsigned(0 to 8);
   signal scanline_reset   : std_logic;

begin

   -- Register row30 to allow more efficient routing.
   process (vga_clk) begin if rising_edge(vga_clk) then
      row30reg <= row30;
   end if; end process;

   -- Indexes for tile and sprite output line buffers.
   -- Tile index is 0 - 255 or 0 - 511 depending on the graphics mode.
   -- Keep the output x position at zero until the raster is in range
   -- to keep the line buffers on a zero index.  Otherwise the last
   -- few buffer tiles are being accessed and the propagation delay
   -- causes a thin line of the last pixel color to appear on the left
   -- edge of the margin-to-active area boundary.
   x512 <= raster_x - XSTART;
   x480 <= raster_x - XSTART2;
   x256 <= x512(1 to 8);
   x240 <= x480(1 to 8);
   x_pixel_max <=
      "011101111" when gmode = 1 else  -- 239 for text1 mode
      "111011111" when gmode = 9 else  -- 479 for text2 mode
      "111111111" when gmode > 9 else  -- 511 for 9938 modes
      "011111111";                     -- 255 for gm1, gm2, mcm

   x_pixel_pos_next <=
      x512(1 to 9) when gmode > 9 else    -- hi-res 1x pixel modes
      x480(1 to 9) when gmode = 9 else    -- text2 mode
      '0' & x240 when gmode = 1 else      -- text1 mode
      '0' & x256;                         -- gm1, gm2, mcm

   x_sprt_pos_next <= x256;               -- sprites are always on a 0 to 255 grid

   process (vga_clk) begin if rising_edge(vga_clk) then
      if xmargin = '1' then
         x_pixel_pos_reg <= (others => '0');
         x_sprt_pos_reg <= (others => '0');
      else
         x_pixel_pos_reg <= x_pixel_pos_next;
         x_sprt_pos_reg <= x_sprt_pos_next;
      end if;
   end if; end process;

   x_pixel_pos <= x_pixel_pos_reg;
   x_sprt_pos <= x_sprt_pos_reg;


   -- Trigger the prescan for tiles and sprites.
   prescan_start <= '1' when raster_x = 1 and y_count_en = '1' else '0';

   -- Normalized Y counter.
   process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if y_max = '1' then
            -- Reset the counter to zero outside the active area.
            y_count <= (others => '0');
            y_count_en <= '0';
         elsif y_tick = '1' and (y_count_en = '1' or scanline_reset = '1') then
            y_count_en <= '1';
            y_count <= y_count + 1;
         end if;
      end if;
   end process;

   -- Divide the 1x line by 2 to make a 2x line.
   y_half <= y_count(0 to 7);
   y_next <= '0' & y_half when gmode < 10 else y_count;

   -- Horizontal scan line output.
   scanline_reset <= '1' when
      (raster_y = SL_RESET1 and row30reg = '0') or
      (raster_y = SL_RESET2 and row30reg = '1') else '0';

   process (vga_clk) begin if rising_edge(vga_clk) then
      if raster_x = 1 then
         -- Reset 2 rasters before the visible area.
         if scanline_reset = '1' then
            scanline_cnt <= (others => '0');
         -- Stick at the max until reset.
         elsif scanline_cnt /= "111111111" then
            scanline_cnt <= scanline_cnt + 1;
         end if;
      end if;
   end if; end process;

   scanline <= scanline_cnt(0 to 7);

   -- The blank signal is on the odd VGA scan line, 1 scan line after
   -- the scan line value changed.
   sl_blank <= scanline_cnt(8) and blank_in;

   -- Sprites are always a 0 to 191 grid and 1 line behind the raster.
   -- Sprites are not affected by the scrolling.
   y_sprt_pos <= y_half - 1 when sprt_yreal = '0' else y_half;


   -- Indicate when the raster is in the margin.  The margin is NOT the
   -- same as the blanking area, which is controlled by the VGA controller.
   -- Mux the consistent data and slow changing data first, then feed
   -- the comparators below.
   process (gmode, row30reg) begin
      if gmode = 1 or gmode = 9 then
         xstart_mux <= to_unsigned(XSTART2, 10);
         xend_mux <= to_unsigned(XEND2, 10);
      else
         xstart_mux <= to_unsigned(XSTART, 10);
         xend_mux <= to_unsigned(XEND, 10);
      end if;

      if row30reg = '0' then
         ystart_mux <= to_unsigned(YSTART, 10);
         yend_mux <= to_unsigned(YEND, 10);
      else
         ystart_mux <= to_unsigned(YSTART2, 10);
         yend_mux <= to_unsigned(YEND2, 10);
      end if;
   end process;

   margin_next <= '1' when
       raster_x < xstart_mux or raster_x > xend_mux or
       raster_y < ystart_mux or raster_y > yend_mux else '0';
   xmargin <= '1' when raster_x < xstart_mux or raster_x > xend_mux else '0';
   ymargin <= '1' when raster_y < ystart_mux or raster_y > yend_mux else '0';

   -- Register the margin indicator to prevent vertical lines in
   -- the output due to combinatorial logic switching noise.
   -- Switch at the VGA clock to match the 1-pixel delay in the
   -- color module.
   -- The y_margin_n signal is needed in the sprite module to prevent
   -- collision detection of off-screen sprites.
   process (vga_clk) begin if rising_edge(vga_clk) then
      margin_reg <= margin_next;
      y_margin_reg <= not ymargin;
   end if; end process;
   in_margin <= margin_reg;
   y_margin_n <= y_margin_reg;

   -- The VDP interrupt does NOT happen at vsync, it happens after the last
   -- line of the active display area.
   valid_y <= '1' when
      (raster_y = (YEND  + 1) and row30reg = '0') or
      (raster_y = (YEND2 + 1) and row30reg = '1')
      else '0';

   -- Interrupt edge detector for one clock tick.
   process (clk) begin if rising_edge(clk) then
      intr_ff <= '0';
      valid_y_last <= valid_y;

      if valid_y = '1' and valid_y_last = '0' then
         intr_ff <= '1';
      end if;
   end if; end process;

   intr_en <= intr_ff;


   --         __    __    __    __    __    __
   -- clk1 __|  |__|  |__|  |__|  |__|  |__|  |__
   --
   --         ___________             ___________
   -- clk2 __|           |___________|           |_
   --
   --               _____                   _____
   -- tick ________|     |_________________|     |_

   -- Convert the vga_clk into logic so it can be used
   -- to make a 100MHz tick.
   process (vga_clk) begin
      if rising_edge(vga_clk) then
         -- This toggles at 12.5MHz, so both edges will be detected
         -- to restore the 25MHz VGA clk.
         vga_clk_logic <= not vga_clk_logic;
      end if;
   end process;

   -- Some events like sprite collisions must only be reported at the
   -- virtual scan line, not the doubled VGA scan line rate.
   process (clk) begin if rising_edge(clk) then
      vga_clk_last <= vga_clk_logic;

      -- Make a 10ns tick once per VGA clock on even scan lines.
      -- Transitions of the vga_clk_logic happen for every rising edge of vga_clk.
      sprt_cf_ff <= (vga_clk_logic xor vga_clk_last) and (not scanline_cnt(8));
   end if; end process;

   sp_cf_en <= sprt_cf_ff;

end rtl;
