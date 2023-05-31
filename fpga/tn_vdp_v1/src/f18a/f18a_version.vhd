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

-- Implements the F18A power-on version banner ROM.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_version is
   port (
      clk         : in std_logic;
      rst_n_i     : in std_logic;
      vga_clk     : in std_logic;
      intr_en_i   : in std_logic;         -- Frame interrupt tick, 100MHz clock
      raster_x    : in unsigned(0 to 9);
      raster_y    : in unsigned(0 to 9);
      blank_i     : in std_logic;

      override_o  : out std_logic;
      red_o       : out std_logic_vector(0 to 3);
      grn_o       : out std_logic_vector(0 to 3);
      blu_o       : out std_logic_vector(0 to 3)
   );
end f18a_version;

architecture rtl of f18a_version is

   -- 8 4 2 1 | 32 16  8  4  2  1
   -- Y Y Y Y |  X  X  X  X  X  X
   --
   --           1         2         3         4         5          6
   -- 012345678901234567890123456789012345678901234567890123456|7890123
   -- .........................................................| unused
   -- ..#####################################################..
   -- .#.....................................................#.
   -- .#.#####...#....####...####....#.....#...#.......####..#.
   -- .#.#......##...#....#.#....#...#.....#..##......#....#.#.
   -- .#.#.....#.#...#....#.#....#...#.....#.#.#......#....#.#.
   -- .#.#.......#....####..######...#.....#...#.......#####.#.
   -- .#.####....#...#....#.#....#....#...#....#...........#.#.
   -- .#.#.......#...#....#.#....#....#...#....#...........#.#.
   -- .#.#.......#...#....#.#....#.....#.#.....#...##.....#..#.
   -- .#.#.....#####..####..#....#......#....#####.##..###...#.
   -- .#.....................................................#.
   -- ..#####################################################..
   -- .........................................................

   constant XMAX : integer := 58;   -- The pixel is delayed by 1-pixel period, so give an extra pixel for each side.
   constant YMAX : integer := 14;

   --  64 x 16 bitmap.  MUST BE PADDED TO 64 pixels per line!
   type verrom_t is array (0 to 1023) of std_logic;
   signal verrom : verrom_t :=
   (
	'0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', '0','0','0','0','0','0','0',
	'0','0','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','0','0', '0','0','0','0','0','0','0',
	'0','1','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','1','1','1','1','0','0','0','1','0','0','0','0','1','1','1','1','0','0','0','1','1','1','1','0','0','0','0','1','0','0','0','0','0','1','0','0','0','1','0','0','0','0','0','0','0','1','1','1','1','0','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','0','0','0','0','0','0','1','1','0','0','0','1','0','0','0','0','1','0','1','0','0','0','0','1','0','0','0','1','0','0','0','0','0','1','0','0','1','1','0','0','0','0','0','0','1','0','0','0','0','1','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','0','0','0','0','0','1','0','1','0','0','0','1','0','0','0','0','1','0','1','0','0','0','0','1','0','0','0','1','0','0','0','0','0','1','0','1','0','1','0','0','0','0','0','0','1','0','0','0','0','1','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','0','0','0','0','0','0','0','1','0','0','0','0','1','1','1','1','0','0','1','1','1','1','1','1','0','0','0','1','0','0','0','0','0','1','0','0','0','1','0','0','0','0','0','0','0','1','1','1','1','1','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','1','1','1','0','0','0','0','1','0','0','0','1','0','0','0','0','1','0','1','0','0','0','0','1','0','0','0','0','1','0','0','0','1','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','1','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','0','0','0','0','0','0','0','1','0','0','0','1','0','0','0','0','1','0','1','0','0','0','0','1','0','0','0','0','1','0','0','0','1','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','1','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','0','0','0','0','0','0','0','1','0','0','0','1','0','0','0','0','1','0','1','0','0','0','0','1','0','0','0','0','0','1','0','1','0','0','0','0','0','1','0','0','0','1','1','0','0','0','0','0','1','0','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','1','0','0','0','0','0','1','1','1','1','1','0','0','1','1','1','1','0','0','1','0','0','0','0','1','0','0','0','0','0','0','1','0','0','0','0','1','1','1','1','1','0','1','1','0','0','1','1','1','0','0','0','1','0', '0','0','0','0','0','0','0',
	'0','1','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0', '0','0','0','0','0','0','0',
	'0','0','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','0','0', '0','0','0','0','0','0','0',
	'0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0', '0','0','0','0','0','0','0',
   others => '0');

   signal addr_r, addr_x : std_logic_vector(0 to 9);
   signal pixel_s : std_logic;
   signal in_version_s : std_logic;

   signal timer_r, timer_x : std_logic_vector(0 to 8) := "000000000";
   signal display_r : std_logic := '1';

begin

   -- 8 4 2 1 | 32 16  8  4  2  1
   -- Y Y Y Y |  X  X  X  X  X  X
   -- 0 1 2 3    4  5  6  7  8  9 address
   addr_x <= std_logic_vector(raster_y(6 to 9)) & std_logic_vector(raster_x(4 to 9));

   -- Register at the VGA clock.  Matches the in_margin register
   -- in the counters module.
   process (vga_clk) begin if rising_edge(vga_clk) then
      addr_r <= addr_x;
   end if; end process;

   -- Infer distributed ROM since all the RAM blocks are used up.
   pixel_s <= verrom(to_integer(unsigned(addr_r)));

   --   RGB
   -- x"2B2", -- 12 Dark Green
   -- x"FFF", -- 15 White

   red_o <=
      x"0" when blank_i = '1' else
      x"F" when pixel_s = '1' else
      x"2";

   grn_o <=
      x"0" when blank_i = '1' else
      x"F" when pixel_s = '1' else
      x"B";

   blu_o <=
      x"0" when blank_i = '1' else
      x"F" when pixel_s = '1' else
      x"2";

   -- Version display timer.
   timer_x <= timer_r + 1;

   process (clk) begin if rising_edge(clk) then
      if rst_n_i = '0' then
         timer_r <= (others => '0');
         display_r <= '1';
      else
         if intr_en_i = '1' then
            timer_r <= timer_x;
         end if;

         if timer_r(0) = '1' and timer_r(1) = '1' then
            display_r <= '0';
         end if;
      end if;
   end if; end process;

   in_version_s <= '1' when ((raster_x < XMAX) and (raster_y < YMAX)) else '0';
   override_o <= blank_i or (in_version_s and display_r);

end rtl;
