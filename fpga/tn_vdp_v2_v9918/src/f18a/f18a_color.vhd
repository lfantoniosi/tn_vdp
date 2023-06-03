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

-- Final pixel selection and color lookup table.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_color is
   port (
      clk         : in std_logic;
      vga_clk     : in std_logic;
      we1         : in std_logic;
      addr1       : in std_logic_vector(0 to 5);
      din         : in std_logic_vector(0 to 11);
      dout1       : out std_logic_vector(0 to 11);    -- to the GPU

      tile_color  : in  std_logic_vector(0 to 7);
      sprt_color  : in  std_logic_vector(0 to 7);
      bg_color    : in  std_logic_vector(0 to 5);
      show_bg     : in  std_logic;
      tile_r      : out std_logic_vector(0 to 3);
      tile_g      : out std_logic_vector(0 to 3);
      tile_b      : out std_logic_vector(0 to 3)
   );
end f18a_color;

architecture rtl of f18a_color is

   type colrom_t is array (0 to 15) of std_logic_vector(0 to 3);

   -- 64 palette registers of 12 bit color.
   type colram_t is array (0 to 63) of std_logic_vector(0 to 11);
   signal colram : colram_t :=
   (
   -- Palette 0, original 9918A NTSC color approximations
   x"000", --  0 Transparent
   x"000", --  1 Black
   x"2C3", --  2 Medium Green
   x"5D6", --  3 Light Green
   x"54F", --  4 Dark Blue
   x"76F", --  5 Light Blue
   x"D54", --  6 Dark Red
   x"4EF", --  7 Cyan
   x"F54", --  8 Medium Red
   x"F76", --  9 Light Red
   x"DC3", -- 10 Dark Yellow
   x"ED6", -- 11 Light Yellow
   x"2B2", -- 12 Dark Green
   x"C5C", -- 13 Magenta
   x"CCC", -- 14 Gray
   x"FFF", -- 15 White

   -- Palette 1, ECM1 (0 index is always 000) version of palette 0
   x"000", --  0 Black
   x"2C3", --  1 Medium Green
   x"000", --  2 Black
   x"54F", --  3 Dark Blue
   x"000", --  4 Black
   x"D54", --  5 Dark Red
   x"000", --  6 Black
   x"4EF", --  7 Cyan
   x"000", --  8 Black
   x"CCC", --  9 Gray
   x"000", -- 10 Black
   x"DC3", -- 11 Dark Yellow
   x"000", -- 12 Black
   x"C5C", -- 13 Magenta
   x"000", -- 14 Black
   x"FFF", -- 15 White

   -- Palette 2, CGA colors
   x"000", --  0 >000000 (  0   0   0) black
   x"00A", --  1 >0000AA (  0   0 170) blue
   x"0A0", --  2 >00AA00 (  0 170   0) green
   x"0AA", --  3 >00AAAA (  0 170 170) cyan
   x"A00", --  4 >AA0000 (170   0   0) red
   x"A0A", --  5 >AA00AA (170   0 170) magenta
   x"A50", --  6 >AA5500 (170  85   0) brown
   x"AAA", --  7 >AAAAAA (170 170 170) light gray
   x"555", --  8 >555555 ( 85  85  85) gray
   x"55F", --  9 >5555FF ( 85  85 255) light blue
   x"5F5", -- 10 >55FF55 ( 85 255  85) light green
   x"5FF", -- 11 >55FFFF ( 85 255 255) light cyan
   x"F55", -- 12 >FF5555 (255  85  85) light red
   x"F5F", -- 13 >FF55FF (255  85 255) light magenta
   x"FF5", -- 14 >FFFF55 (255 255  85) yellow
   x"FFF", -- 15 >FFFFFF (255 255 255) white

   -- Palette 3, ECM1 (0 index is always 000) version of palette 2
   x"000", --  0 >000000 (  0   0   0) black
   x"555", --  1 >555555 ( 85  85  85) gray
   x"000", --  2 >000000 (  0   0   0) black
   x"00A", --  3 >0000AA (  0   0 170) blue
   x"000", --  4 >000000 (  0   0   0) black
   x"0A0", --  5 >00AA00 (  0 170   0) green
   x"000", --  6 >000000 (  0   0   0) black
   x"0AA", --  7 >00AAAA (  0 170 170) cyan
   x"000", --  8 >000000 (  0   0   0) black
   x"A00", --  9 >AA0000 (170   0   0) red
   x"000", -- 10 >000000 (  0   0   0) black
   x"A0A", -- 11 >AA00AA (170   0 170) magenta
   x"000", -- 12 >000000 (  0   0   0) black
   x"A50", -- 13 >AA5500 (170  85   0) brown
   x"000", -- 14 >000000 (  0   0   0) black
   x"FFF"  -- 15 >FFFFFF (255 255 255) white
   );

   signal addr2         : std_logic_vector(0 to 5);
   signal addr2_next    : std_logic_vector(0 to 5);
   signal dout2         : std_logic_vector(0 to 11);
   signal dout1_reg     : std_logic_vector(0 to 11);
   signal sprt_pix      : std_logic;
   signal sprt_en       : std_logic;
   signal tile_en       : std_logic;

begin

   process (clk)
   begin
      if rising_edge(clk) then
         if we1 = '1' then
            colram(to_integer(unsigned(addr1))) <= din;
         end if;

         -- to the GPU! :-)
         dout1_reg <= colram(to_integer(unsigned(addr1)));
      end if;
   end process;

   -- Infer distributed RAM.
   dout1 <= dout1_reg;
   dout2 <= colram(to_integer(unsigned(addr2)));

   -- Color format:
   --    0     1     2     3     4     5     6     7
   -- | PIX | PRI |      6-bit color address           |
   --
   -- PIX = if there is a pixel or not.  If PIX = 1 for tiles
   --       then the 6-bit color address is valid and PRI should
   --       be considered to determine the final color.
   -- PRI = priority over sprites.  1 = priority
   --

   -- Sprite / tile / background address selector
   -- If the sprite does not have a pixel, or if there is a tile and
   -- it has priority, the color will be that of the tile.
   sprt_pix <= sprt_color(0) and (not (tile_color(0) and tile_color(1)));


   -- The blank bit and margin override any sprite or tile pixels.
   sprt_en <= sprt_pix and not show_bg;
   tile_en <= tile_color(0) and not show_bg;

   addr2_next <=
      sprt_color(2 to 7) when sprt_en = '1' else
      tile_color(2 to 7) when tile_en = '1' else
      bg_color;

   -- Register at the VGA clock.  Matches the in_margin register
   -- in the counters module.
   process (vga_clk) begin if rising_edge(vga_clk) then
      addr2 <= addr2_next;
   end if; end process;


   tile_r <= dout2(0 to 3);
   tile_g <= dout2(4 to 7);
   tile_b <= dout2(8 to 11);

end rtl;
