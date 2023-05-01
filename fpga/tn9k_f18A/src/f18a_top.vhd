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

-- Top module to set up the F18A core for use as a stand-alone VDP in a real
-- host computer.  To use the F18A in a larger FPGA-base SoC, this file is
-- not needed and the F18A core should be interfaced directly.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- For Xilinx specific primitives.
--library unisim;
--use unisim.vcomponents.all;


entity f18a_top is
   port (
      --clk_50m0_net   : in  std_logic;
      clk_100m0_s    : in std_logic;
      clk_25m0_s     : in std_logic;

      -- 9918A to Host interface
      reset_n_net    : in  std_logic;
      mode_net       : in  std_logic;
      csw_n_net      : in  std_logic;
      csr_n_net      : in  std_logic;
      int_n_net      : out std_logic;
      clk_grom_net   : out std_logic;  -- 447.443KHz GROMCLK
      clk_cpu_net    : out std_logic;  -- 3.5795MHz CPUCLK
      cd_net         : inout std_logic_vector(0 to 7);

      -- Video generation
      hsync_net      : out std_logic;
      vsync_net      : out std_logic;
      red_net        : out std_logic_vector(0 to 3);
      grn_net        : out std_logic_vector(0 to 3);
      blu_net        : out std_logic_vector(0 to 3);
      blank_net      : out std_logic;

      -- User header for feature selection
      usr1_net       : in std_logic;   -- Sprite max
      usr2_net       : in std_logic;   -- Simulated scan lines
      usr3_net       : in std_logic;   -- CPU CLK out pin selection
      usr4_net       : in std_logic;   -- CPU CLK out enable

      -- SPI
      spi_cs_net     : out std_logic;
      spi_mosi_net   : out std_logic;
      spi_miso_net   : in  std_logic;
      spi_clk_net    : out std_logic
   );
end f18a_top;

architecture rtl of f18a_top is

   -- Main clock generation.
--   signal clkdv_buf_s      : std_logic;
--   signal clkfb_in_s       : std_logic;
--   signal clkfx_buf_s      : std_logic;
--   signal clkin_ibufg_s    : std_logic;
--   signal clk0_buf_s       : std_logic;
--   signal clk_100m0_s      : std_logic;
--   signal clk_25m0_s       : std_logic;


   -- Power-On Reset generation.

   -- Reset input synchronizer.
   signal reset_n_i_r1     : std_logic := '0';
   signal reset_n_i_r      : std_logic := '0';

   -- Power-On Reset counter.
   signal reset_por_r      : std_logic := '0';
   signal reset_cnt_r      : unsigned(0 to 2) := "000";

   -- Final reset register.
   signal reset_n_r        : std_logic := '0';

   -- Output routing.
   signal cd_out_s         : std_logic_vector(0 to 7);

   -- Output GROM and CPU clock generation.
   signal cpuclk_r         : std_logic := '0';
   signal gromclk_r        : std_logic := '0';
   signal cpudiv_r         : unsigned(0 to 3) := (others => '0');
   signal gromdiv_r        : unsigned(0 to 6) := (others => '0');
   signal scanlines        : std_logic := '0';

begin

   --
   -- Power-On Reset
   --

   -- Synchronize the real input reset signal.
   process (clk_100m0_s) begin if rising_edge(clk_100m0_s) then
      reset_n_i_r1 <= reset_n_net;
      reset_n_i_r  <= reset_n_i_r1;
      --reset_n_r <= reset_n_net;
   end if; end process;

   -- Some systems have a short Power-On Reset time and are out of reset before
   -- the FPGA is done loading the bit-stream.  In these cases, the F18A still
   -- needs a clean reset which is provided by this counter.  The counter is
   -- initialized to a known value by the bit-stream, so a clean reset can be
   -- generated once the FPGA is operational.
   --
   -- The count is 0..7 to be long enough for the vga_clk (25MHz) to cycle
   -- at least once, ensuring any resets based on the vga_clk have time to
   -- complete.  This also helps during simulation to get valid signals.
   process (clk_100m0_s) begin if rising_edge(clk_100m0_s) then
      if reset_cnt_r = "011" then
         reset_por_r <= '1';
      else
         reset_por_r <= '0';
         reset_cnt_r <= reset_cnt_r + 1;
      end if;

--       Combine both reset signals.
      reset_n_r <= reset_n_i_r and reset_por_r;

   end if; end process;

   --
   -- F18A core
   --

   inst_f18a : entity work.f18a_core
   port map (
      clk_100m0_i    => clk_100m0_s,   -- in  std_logic;
      clk_25m0_i     => clk_25m0_s,    -- in  std_logic;

      -- 9918A to Host System Interface
      reset_n_i      => reset_n_r,     -- in  std_logic;
      mode_i         => mode_net,      -- in  std_logic;
      csw_n_i        => csw_n_net,     -- in  std_logic;
      csr_n_i        => csr_n_net,     -- in  std_logic;
      int_n_o        => int_n_net,     -- out std_logic;
      cd_i           => cd_net,        -- in  std_logic_vector(0 to 7);
      cd_o           => cd_out_s,      -- out std_logic_vector(0 to 7);

      -- Video Output
      blank_o        => blank_net,     -- out std_logic;
      hsync_o        => hsync_net,     -- out std_logic;
      vsync_o        => vsync_net,     -- out std_logic;
      red_o          => red_net,       -- out std_logic_vector(0 to 3);
      grn_o          => grn_net,       -- out std_logic_vector(0 to 3);
      blu_o          => blu_net,       -- out std_logic_vector(0 to 3);

      -- Feature Selection
      sprite_max_i   => usr1_net,      -- in std_logic;   -- Default sprite max, '0' = 32, '1' = 4
      scanlines_i    => scanlines,      -- in std_logic;   -- Simulated scan lines, '0' = no, '1' = yes

      -- SPI to GPU
      spi_clk_o      => spi_clk_net,   -- out std_logic;
      spi_cs_o       => spi_cs_net,    -- out std_logic;
      spi_mosi_o     => spi_mosi_net,  -- out std_logic;
      spi_miso_i     => spi_miso_net   -- in  std_logic
   );

   scanlines <= not usr2_net;

   -- Host interface data bus tristate.
   cd_net <= cd_out_s when csr_n_net = '0' else (others => 'Z');


   -- GROM and CPU clock generation.
   --
   -- The original 9918A signals were generated by diving the 10.7MHz
   -- clock signal (from the crystal or other external source).
   --
   -- 3.5795MHz CPUCLK  (10.7386MHz / 3)
   -- 447.44KHz GROMCLK (10.7386MHz / 24)
   --
   -- Using the 100MHz clock allows a very close approximation:
   --
   -- 100MHz / 3.5795MHz =  27.93, use  28 (3.5714MHz)
   -- 100MHz / 447.44KHz = 223.49, use 224 (446.428KHz)

   ext_clock_gen :
   process (clk_100m0_s)
   begin if rising_edge(clk_100m0_s) then
      -- 224 / 2 = 112, count 0..111 to generate 50% GROMCLK period.
      if gromdiv_r = 55 then
         gromclk_r <= (not gromclk_r) and reset_n_r;
         gromdiv_r <= (others => '0');
      else
         gromdiv_r <= gromdiv_r + 1;
      end if;

      -- 28 / 2 = 14, count 0..13 to generate 50% CPUCLK period.
      if cpudiv_r = 6 then
         cpuclk_r <= (not cpuclk_r) and reset_n_r;
         cpudiv_r <= (others => '0');
      else
         cpudiv_r <= cpudiv_r + 1;
      end if;
   end if;
   end process;


   -- User header.  Pull-up in the FPGA, a jumper in place will pull to ground.
   --
   --  User Jumper          |  On  | Off
   -- --------------------------------------
   --  1 Sprite max default |  32  | 4
   --  2 Scan lines         |  No  | Yes
   --  3 CPUCLK pin         | P38  | P37
   --  4 CPUCLK en          | HI-Z | CPUCLK

   -- USR3 CPUCLK pin.  Provides support for the 9128/9129 that output CPUCLK on pin37.
   -- USR3 and USR4 - CPUCLK pin and CPUCLK Enable.
   --        _________
   -- RAS  =|1   U  40|= XTAL1    9918A   9928A/29A  9118   9128/29 F18A
   -- CAS  =|2      39|= XTAL2   ======== ========= ======= ======= ====
   -- AD7  =|3      38|= ....... CPUCLK   R-Y       CPUCLK  R-Y     HI-Z / CPUCLK
   -- AD6  =|4      37|= ....... GROMCLK  GROMCLK   NC      CPUCLK  GROMCLK / CPUCLK
   -- AD5  =|5      36|= ....... COMVID   Y         COMVID  Y       NC
   -- AD4  =|6      35|= ....... EXTVDP   B-Y       EXTVDP  B-Y     NC
   --

   -- Basically:
   --             USR3 USR4
   -- TI-99/4A     on   on    -- The 99/4A does not use the CPUCLK, but this is NOT the default of the 9918A
   -- 9928/29      on   on    -- CPUCLK on pin38 disabled so it does not cram 3.5MHz into the R-Y circuit
   -- 9918A/9118   on  off    -- CPUCLK output, GROMCLK output (pin37 is not connected on the 9118)
   -- 9128/29     off   on    -- CPUCLK on pin37 enabled, CPUCLK output on pin38 disabled
   -- not used    off  off    -- CPUCLK output on both pin37 and pin38

   -- USR3 selects GROMCLK or CPUCLK on pin37.
   clk_grom_net <= gromclk_r when usr3_net = '0' else cpuclk_r;

   -- USR4 controls if pin38 outputs the CPUCLK or not.
   clk_cpu_net <= cpuclk_r when usr4_net = '0' else 'Z';

end rtl;
