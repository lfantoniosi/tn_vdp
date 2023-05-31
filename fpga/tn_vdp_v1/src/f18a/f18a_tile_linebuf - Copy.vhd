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

-- Uses Xilinx specific primitives to use a single 2K dual-port Block-RAM as a
-- pair of single port 1K RAMs.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;

-- For Xilinx specific primitives.
--library unisim;
--use unisim.vcomponents.all;


--
-- Make two single-port buffers from one dual-port Block RAM
-- This specific configuration can not be inferred, so the
-- Xilinx specific primitives must be used.
--
-- Originally the line buffers were inferred with generic
-- VHDL, but using two Block RAMs for the line buffers was
-- wasteful, especially on the 250K device.
--

-- The tile line buffers are 512 pixels by 8-bits per pixel.
--
--    7     6     5     4     3     2     1     0
-- | PIX | PRI |           6-bit address           |
--
-- PIX = if there is a tile pixel or not, used to facilitate
--       transparent tile pixels.  If PIX = 0 then the tile
--       does not have a pixel for this location.  If PIX = 1
--       then the 6-bit color address is valid and PRI should
--       be considered to determine the final color.
-- PRI = priority over sprites.  1 = priority
--
entity f18a_tile_linebuf is
   generic (
      ADDR_WIDTH : integer := 9;
      DATA_WIDTH : integer := 8
   );
   port (
      clk      : in std_logic;
      we1      : in std_logic;
      addr1    : in std_logic_vector(0 to ADDR_WIDTH - 1);
      din1     : in std_logic_vector(0 to DATA_WIDTH - 1);
      dout1    : out std_logic_vector(0 to DATA_WIDTH - 1);
      we2      : in std_logic;
      addr2    : in std_logic_vector(0 to ADDR_WIDTH - 1);
      din2     : in std_logic_vector(0 to DATA_WIDTH - 1);
      dout2    : out std_logic_vector(0 to DATA_WIDTH - 1)
   );
end f18a_tile_linebuf;

architecture rtl of f18a_tile_linebuf is

   type line_buffer is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector (0 to DATA_WIDTH-1);
   signal linebuf1: line_buffer;
   signal linebuf2: line_buffer;

begin

   -- Line buffer 1
   process (clk)
   begin
      if rising_edge(clk) then
         dout1 <= linebuf1(to_integer(unsigned(addr1)));
         if we1 = '1' then
            linebuf1(to_integer(unsigned(addr1))) <= din1;
         end if;
      end if;
   end process;

   -- Line buffer 2
   process (clk)
   begin
      if rising_edge(clk) then
         dout2 <= linebuf2(to_integer(unsigned(addr2)));
         if we2 = '1' then
            linebuf2(to_integer(unsigned(addr2))) <= din2;
         end if;
      end if;
   end process;

end rtl;
