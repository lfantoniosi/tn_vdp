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

-- Implements the main VRAM multiplexer.  The host-CPU interface always has
-- access on one port, the tiles and sprites share the other port since their
-- FSMs are triggered sequentially during each scan line.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity f18a_vram is
   port (
      clk         : in  std_logic;
      rst_n       : in  std_logic;
-- CPU Interface
      cpu_din     : in  std_logic_vector(0 to 7);
      cpu_we      : in  std_logic;
      cpu_addr    : in  std_logic_vector(0 to 13);
      cpu_dout    : out std_logic_vector(0 to 7);
-- TILE Interface
      tile_active : in  std_logic;
      tile_addr   : in  std_logic_vector(0 to 13);
      tile_dout   : out std_logic_vector(0 to 7);
-- SPRITE Interface
      sprt_addr   : in  std_logic_vector(0 to 13)
   );
end f18a_vram;

architecture rtl of f18a_vram is

   signal addr_mux : std_logic_vector(0 to 13);

begin

   -- Main RAM
   inst_ram : entity work.f18a_single_port_ram
      port map (
         clk   => clk,
         we    => cpu_we,
         addr  => cpu_addr,
         addr2 => addr_mux,
         din   => cpu_din,
         dout  => cpu_dout,
         dout2 => tile_dout
      );

   addr_mux <= tile_addr when tile_active = '1' else sprt_addr;

end rtl;
