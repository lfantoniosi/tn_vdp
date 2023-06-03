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

-- Implements the basic VGA horizontal and vertical counters.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity f18a_vga_cont_640_60 is
   port(
      vga_clk  : in std_logic;
      rst_n    : in std_logic;
      hsync    : out std_logic;
      vsync    : out std_logic;
      raster_x : out unsigned(0 to 9);
      raster_y : out unsigned(0 to 9);
      y_tick   : out std_logic;
      y_max    : out std_logic;
      blank    : out std_logic
   );
end f18a_vga_cont_640_60;

architecture rtl of f18a_vga_cont_640_60 is

   --
   -- The "counters" module has knowledge of these values.  Any changes here
   -- must be considered in the counters module as well.
   --

   -- A 640x480 display is really 800x525 including the porches and sync pulses.
   -- The real VGA pixel clock is 39.682us, but the FPGA clock is 40ns.  This
   -- error has to be accounted for or the total frame time will be 59Hz instead
   -- of 60Hz.
   --
   -- Total line time is: 1/60/525 = 31.746us per line
   -- When divided by the 40ns pixel clock, that is a total of 793.65 pixels.
   -- 794 * 40ns = 31.76us * 525 = 16.674ms
   -- 1 / 16.674ms = 59.973Hz
--   constant HMAX  : integer := 799;    -- 0 to 799 == 800 pixels
   constant HMAX  : integer := 799;    -- 0 to 799 == 800 pixels
   constant VMAX  : integer := 524;    -- 0 to 524 == 525 lines

   -- 640x480 display size.
   constant HSIZE : integer := 640;
   constant VSIZE : integer := 480;

   -- Front porch is 16px, followed by a 96px hsync, then a 48px back porch.
   -- 640 + 16 + 96 + 48 = 800
--   constant HFP   : integer := 656;    -- Horz end of front porch (16px)
--   constant HSP   : integer := 752;    -- Horz end of sync pulse (96px)
   constant HFP   : integer := 652;    -- Horz end of front porch (16px)
   constant HSP   : integer := 748;    -- Horz end of sync pulse (96px)

   -- 'px' here means vertical 'lines'
   -- Front proch is 11px, followed by a 2px vsync, then a 30px back porch.
   -- 480 + 11 + 2 + 32 = 525
   constant VFP   : integer := 490;    -- Vert end of front porch (11px)
   constant VSP   : integer := 492;    -- Vert end of sync pulse (2px)

   -- Polarity of the horizontal and vertical sync pulse
   -- only one polarity used, because for this resolution they coincide.
   constant SPP   : std_logic := '0';

   -- Horizontal and vertical counters
   signal hcounter : unsigned(0 to 9);
   signal vcounter : unsigned(0 to 9);

   signal blank_reg : std_logic;

begin

   -- Increment horizontal counter at the vga clock rate
   -- until HMAX is reached, then reset.
   h_count: process (vga_clk)
   begin
      if rising_edge(vga_clk) then
      if rst_n = '0' then
         hcounter <= (others => '0');
      else
         if hcounter = HMAX then
            hcounter <= (others => '0');
         else
            hcounter <= hcounter + 1;
         end if;
      end if;
      end if;
   end process h_count;

   -- Increment vertical counter after each horizontal raster
   -- until VMAX is reached, then reset.
   v_count: process (vga_clk)
   begin
      if rising_edge(vga_clk) then
      if rst_n = '0' then
         vcounter <= (others => '0');
      else
         if hcounter = HMAX then
            if vcounter = VMAX then
               vcounter <= (others => '0');
            else
               vcounter <= vcounter + 1;
            end if;
         end if;
      end if;
      end if;
   end process v_count;

   -- Generate the horizontal sync pulse when horizontal counter
   -- is between where the front porch ends and the sync pulse ends.
   -- The HS is active (with polarity SPP) for a total of HFP - HSP pixels.
   do_hs: process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if hcounter >= HFP and hcounter < HSP then
            hsync <= SPP;
         else
            hsync <= not SPP;
         end if;
      end if;
   end process do_hs;

   -- Generate the vertical sync pulse when vertical counter
   -- is between where the front porch ends and the sync pulse ends.
   -- The VS is active (with polarity SPP) for a total of VFP - VSP video lines.
   do_vs: process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if vcounter >= VFP and vcounter < VSP then
            vsync <= SPP;
         else
            vsync <= not SPP;
         end if;
      end if;
   end process do_vs;

   -- Output horizontal and vertical raster locations.
   raster_x <= hcounter;
   raster_y <= vcounter;

   y_tick <= '1' when hcounter = HMAX else '0';
   y_max <= '1' when vcounter = VSIZE else '0';

   -- Blank is active when the raster is outside visible screen area.
   -- Registered to prevent thin, top to bottom, vertical artifacts on the screen.
   process (vga_clk) begin if rising_edge(vga_clk) then
      if (hcounter < HSIZE and vcounter < VSIZE) then
         blank_reg <= '0';
      else
         blank_reg <= '1';
      end if;
   end if; end process;
   blank <= blank_reg;

end rtl;
