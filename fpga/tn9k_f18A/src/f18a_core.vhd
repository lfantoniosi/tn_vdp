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

-- Main F18A core.
--   TODO:
--
--     Register mode_i and cd_i in the host-interface (CPU) module.
--
--     The host interface module needs to renamed and split up, it is too big.
--
--     Rewrite sprite layer and remove sprite linking.
--
--     Rewrite GPU module and fix memory interface to not block.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity f18a_core is
   port (
      clk_100m0_i          : in  std_logic;
      clk_25m0_i           : in  std_logic;

      -- 9918A to Host System Interface
      reset_n_i            : in  std_logic;  -- Must be active for at least one 25MHz clock cycle
      mode_i               : in  std_logic;
      csw_n_i              : in  std_logic;
      csr_n_i              : in  std_logic;
      int_n_o              : out std_logic;
      cd_i                 : in  std_logic_vector(0 to 7);
      cd_o                 : out std_logic_vector(0 to 7);

      -- Video Output
      blank_o              : out std_logic;
      hsync_o              : out std_logic;
      vsync_o              : out std_logic;
      red_o                : out std_logic_vector(0 to 3);
      grn_o                : out std_logic_vector(0 to 3);
      blu_o                : out std_logic_vector(0 to 3);

      -- Feature Selection
      sprite_max_i         : in std_logic;   -- Default sprite max, '0' = 32, '1' = 4
      scanlines_i          : in std_logic;   -- Simulated scan lines, '0' = no, '1' = yes

      -- SPI to GPU
      spi_clk_o            : out std_logic;
      spi_cs_o             : out std_logic;
      spi_mosi_o           : out std_logic;
      spi_miso_i           : in  std_logic
   );
end f18a_core;

architecture rtl of f18a_core is

   -- Output video registers.
   signal blank_r          : std_logic := '0';
   signal hsync_r          : std_logic := '0';
   signal vsync_r          : std_logic := '0';
   signal red_r, red_s     : std_logic_vector(0 to 3) := "0000";
   signal grn_r, grn_s     : std_logic_vector(0 to 3) := "0000";
   signal blu_r, blu_s     : std_logic_vector(0 to 3) := "0000";

   -- Video signals
   -- blank here is NOT the same as the soft_blank signal from the CPU I/O
   signal blank_s          : std_logic;                  -- VGA blanking
   signal sl_blank_s       : std_logic;                  -- scan line blanking for GPU
   signal vsync_s          : std_logic;
   signal hsync_s          : std_logic;
   signal raster_x_s       : unsigned(0 to 9);
   signal raster_y_s       : unsigned(0 to 9);
   signal y_tick_s         : std_logic;
   signal y_max_s          : std_logic;

   -- Counter signals
   signal in_margin_s      : std_logic;
   signal y_margin_n_s     : std_logic;
   signal x_pixel_max_s    : unsigned(0 to 8);
   signal x_pixel_pos_s    : unsigned(0 to 8);
   signal x_sprt_pos_s     : unsigned(0 to 7);
   signal y_next_s         : unsigned(0 to 8);
   signal y_sprt_pos_s     : unsigned(0 to 7);
   signal prescan_start_s  : std_logic;
   signal sprite_start_s   : std_logic;

   -- Scroll support
   signal t1ntba_s         : std_logic_vector(0 to 3);   -- tile1 name table base address
   signal t1ctba_s         : std_logic_vector(0 to 7);   -- tile1 color table base address
   signal t1hsize_s        : std_logic;                  -- tile1 horz page size (1 page or 2 pages)
   signal t1vsize_s        : std_logic;                  -- tile1 vert page size (1 page or 2 pages)
   signal t1horz_s         : std_logic_vector(0 to 7);   -- tile1 horz scroll
   signal t1vert_s         : std_logic_vector(0 to 7);   -- tile1 vert scroll
   signal t2_en_s          : std_logic;                  -- tile2 enable
   signal t2_pri_en_s      : std_logic;                  -- tile2 priority enable (0 = TL2 always on top)
   signal t2ntba_s         : std_logic_vector(0 to 3);   -- tile2 name table base address
   signal t2ctba_s         : std_logic_vector(0 to 7);   -- tile2 color table base address
   signal t2hsize_s        : std_logic;                  -- tile2 horz page size (1 page or 2 pages)
   signal t2vsize_s        : std_logic;                  -- tile2 vert page size (1 page or 2 pages)
   signal t2horz_s         : std_logic_vector(0 to 7);   -- tile2 horz scroll
   signal t2vert_s         : std_logic_vector(0 to 7);   -- tile2 vert scroll

   -- Bitmap layer
   signal bmlba_s          : std_logic_vector(0 to 7);   -- bitmap layer base address
   signal bml_x_s          : std_logic_vector(0 to 7);
   signal bml_y_s          : std_logic_vector(0 to 7);
   signal bml_w_s          : std_logic_vector(0 to 7);
   signal bml_h_s          : std_logic_vector(0 to 7);
   signal bml_ps_s         : std_logic_vector(0 to 3);   -- bitmap layer palette select
   signal bml_en_s         : std_logic;                  -- '1' to enable the bitmap layer
   signal bml_pri_s        : std_logic;                  -- '1' when bitmap has priority over tiles
   signal bml_trans_s      : std_logic;                  -- '1' to set "00" pixels transparent
   signal bml_fat_s        : std_logic;

   -- Tile and sprite output
   signal tile_color_s     : std_logic_vector(0 to 7);
   signal sprt_color_s     : std_logic_vector(0 to 7);
   signal bg_color_s       : std_logic_vector(0 to 5);

   -- Color palette access
   signal col_we_s         : std_logic;
   signal col_addr_cpu_s   : std_logic_vector(0 to 5);
   signal col_din_s        : std_logic_vector(0 to 11);
   signal col_dout_s       : std_logic_vector(0 to 11);

   -- Color output
   signal tile_r_s         : std_logic_vector(0 to 3);
   signal tile_g_s         : std_logic_vector(0 to 3);
   signal tile_b_s         : std_logic_vector(0 to 3);

   signal show_bg          : std_logic;

   -- CPU outputs
   signal pgba_s           : std_logic_vector(0 to 2);
   signal gmode_s          : unsigned(0 to 3);
   signal textfg_s         : std_logic_vector(0 to 3);
   signal textbg_s         : std_logic_vector(0 to 3);

   signal unlocked_s       : std_logic;
   signal row30_s          : std_logic;
   signal tile_ecm_s       : unsigned(0 to 1);
   signal sprt_ecm_s       : unsigned(0 to 1);

   signal tl1_off_s        : std_logic;
   signal pos_attr_s       : std_logic;
   signal tpgsize_s        : std_logic_vector(0 to 1);
   signal spgsize_s        : std_logic_vector(0 to 1);

   signal tile_ps_s        : std_logic_vector(0 to 3);
   signal sprt_ps_s        : std_logic_vector(0 to 1);
   signal sprt_yreal_s     : std_logic;
   signal reportmax_s      : std_logic;

   signal soft_blank_s     : std_logic;
   signal size_bit_s       : std_logic;
   signal mag_bit_s        : std_logic;
   signal satba_s          : std_logic_vector(0 to 6);
   signal spgba_s          : std_logic_vector(0 to 2);
   signal sp_cf_s          : std_logic;
   signal sp_5s_s          : std_logic;
   signal sp_5th_s         : std_logic_vector(0 to 4);

   signal intr_en_s        : std_logic;
   signal sp_cf_en_s       : std_logic;
   signal scanline_s       : unsigned(0 to 7);
   signal vscanln_en_s     : std_logic;   -- Virtual scan line enable

   -- CPU to VRAM
   signal cpu_din_s        : std_logic_vector(0 to 7);
   signal cpu_we_s         : std_logic;
   signal cpu_addr_s       : std_logic_vector(0 to 13);
   signal cpu_dout_s       : std_logic_vector(0 to 7);

   -- Tile to VRAM
   signal tile_active_s    : std_logic;
   signal tile_addr_s      : std_logic_vector(0 to 13);
   signal tile_dout_s      : std_logic_vector(0 to 7);

   signal override_s       : std_logic;
   signal override_r_s     : std_logic_vector(0 to 3);
   signal override_g_s     : std_logic_vector(0 to 3);
   signal override_b_s     : std_logic_vector(0 to 3);

   -- Sprite to VRAM
   signal sprt_addr_s      : std_logic_vector(0 to 13);


   -- Internal options
   signal stop_sprt_s      : unsigned(0 to 5);
   signal sprite_max_s     : unsigned(0 to 4);  -- From VDP register, do not confuse with sprite_max_r

   -- Register external inputs.
   signal reset_n_r        : std_logic := '1';
   signal scanlines_r      : std_logic := '0';
   signal sprite_max_r     : std_logic_vector(0 to 4) := "11111";

begin

   -- Register external inputs other than those associated with data (which
   -- are registered in the host interface).
   process (clk_100m0_i) begin
   if rising_edge(clk_100m0_i) then
      reset_n_r      <= reset_n_i;
      scanlines_r    <= scanlines_i;

      -- Select the power-on / reset default maximum number of sprites per line.
      -- The max sprites can also be changed after power-on via a VDP register.
      if sprite_max_i = '0' then
         sprite_max_r <= "11111";
      else
         sprite_max_r <= "00100";
      end if;
   end if; end process;


   -- Dual-port 16K VRAM
   inst_vram : entity work.f18a_vram
   port map (
      clk            => clk_100m0_i,
      rst_n          => reset_n_r,
   -- CPU Interface
      cpu_din        => cpu_din_s,
      cpu_we         => cpu_we_s,
      cpu_addr       => cpu_addr_s,
      cpu_dout       => cpu_dout_s,
   -- Tile Interface
      tile_active    => tile_active_s,
      tile_addr      => tile_addr_s,
      tile_dout      => tile_dout_s,
   -- Sprite Interface
      sprt_addr      => sprt_addr_s
   );


   -- Host CPU interface
   inst_cpu : entity work.f18a_cpu
   port map (
      clk            => clk_100m0_i,
      rst_n          => reset_n_r,
      mode           => mode_i,
      csw_n          => csw_n_i,
      csr_n          => csr_n_i,
      cd_i           => cd_i,
      cd_o           => cd_o,
      sp_cf          => sp_cf_s,
      sp_5s          => sp_5s_s,
      sp_5th         => sp_5th_s,
      intr_en        => intr_en_s,
      sp_cf_en       => sp_cf_en_s,
      scanline       => scanline_s,
      vscanln_en     => vscanln_en_s,     -- Virtual scan line enable
      blank          => sl_blank_s,
   -- VRAM Interface
      vdin           => cpu_dout_s,       -- In to CPU from *out* of VRAM
      vwe            => cpu_we_s,
      vaddr          => cpu_addr_s,
      vdout          => cpu_din_s,        -- Out from CPU goes *in* to VRAM
   -- PRAM Interface
      pwe            => col_we_s,
      paddr          => col_addr_cpu_s,
      pdout          => col_din_s,        -- Out from CPU goes *in* to PRAM
      pdin           => col_dout_s,       -- in to the GPU
   -- Outputs
      intr_n         => int_n_o,
      gmode          => gmode_s,
      soft_blank     => soft_blank_s,
      size_bit       => size_bit_s,
      mag_bit        => mag_bit_s,
      pgba           => pgba_s,
      satba          => satba_s,
      spgba          => spgba_s,
      textfg         => textfg_s,
      textbg         => textbg_s,
   -- F18A specific
      unlocked       => unlocked_s,
      row30          => row30_s,
      tl1_off_o      => tl1_off_s,        -- '1' to disable tile layer 1
      pos_attr_o     => pos_attr_s,       -- '1' to use position-based tile attributes
      tpgsize_o      => tpgsize_s,        -- tile pattern table offset size
      spgsize_o      => spgsize_s,        -- sprite pattern table offset size
      tile_ecm       => tile_ecm_s,
      sprt_ecm       => sprt_ecm_s,
      tile_ps        => tile_ps_s,
      sprt_ps        => sprt_ps_s,
      sprt_yreal     => sprt_yreal_s,
   -- Sprite max
      usr_sprite_max => sprite_max_r,     -- Jumper setting, used at reset
      sprite_max     => sprite_max_s,     -- Register setting overrides jumper
      stop_sprt      => stop_sprt_s,      -- Stop Sprite to limit sprite processing
      reportmax_o    => reportmax_s,      -- Report max sprite ('1') or 5th sprite ('0')
   -- Scroll support
      t1ntba         => t1ntba_s,         -- tile1 name table base address
      t1ctba         => t1ctba_s,         -- tile1 color table base address
      t1hsize        => t1hsize_s,        -- tile1 horz page size (1 page or 2 pages)
      t1vsize        => t1vsize_s,        -- tile1 vert page size (1 page or 2 pages)
      t1horz         => t1horz_s,         -- tile1 horz scroll
      t1vert         => t1vert_s,         -- tile1 vert scroll
      t2_en          => t2_en_s,          -- tile2 enable
      t2_pri_en      => t2_pri_en_s,      -- tile2 priority enable (0 = TL2 always on top)
      t2ntba         => t2ntba_s,         -- tile2 name table base address
      t2ctba         => t2ctba_s,         -- tile2 color table base address
      t2hsize        => t2hsize_s,        -- tile2 horz page size (1 page or 2 pages)
      t2vsize        => t2vsize_s,        -- tile2 vert page size (1 page or 2 pages)
      t2horz         => t2horz_s,         -- tile2 horz scroll
      t2vert         => t2vert_s,         -- tile2 vert scroll

   -- Bitmap layer
      bmlba          => bmlba_s,
      bml_x          => bml_x_s,
      bml_y          => bml_y_s,
      bml_w          => bml_w_s,
      bml_h          => bml_h_s,
      bml_ps         => bml_ps_s,
      bml_en         => bml_en_s,
      bml_pri        => bml_pri_s,
      bml_trans      => bml_trans_s,
      bml_fat_o      => bml_fat_s,
   -- SPI Interface
      spi_clk        => spi_clk_o,
      spi_cs         => spi_cs_o,
      spi_mosi       => spi_mosi_o,
      spi_miso       => spi_miso_i
   );


   -- Video controller
   inst_vga_cont : entity work.f18a_vga_cont_640_60
   port map (
      vga_clk        => clk_25m0_i,
      rst_n          => reset_n_r,
      hsync          => hsync_s,
      vsync          => vsync_s,
      raster_x       => raster_x_s,
      raster_y       => raster_y_s,
      y_tick         => y_tick_s,
      y_max          => y_max_s,
      blank          => blank_s
   );


   -- Video counters
   inst_counters : entity work.f18a_counters
   port map (
      clk            => clk_100m0_i,
      vga_clk        => clk_25m0_i,
      rst_n          => reset_n_r,
      raster_x       => raster_x_s,
      raster_y       => raster_y_s,
      y_tick         => y_tick_s,
      y_max          => y_max_s,
      sprt_yreal     => sprt_yreal_s,
      gmode          => gmode_s,
      row30          => row30_s,
      blank_in       => blank_s,          -- VGA blank input
      sl_blank       => sl_blank_s,       -- Scan line blank output
      intr_en        => intr_en_s,
      sp_cf_en       => sp_cf_en_s,
      scanline       => scanline_s,
   -- Sprite and pixel counters
      in_margin      => in_margin_s,
      y_margin_n     => y_margin_n_s,
      x_pixel_max    => x_pixel_max_s,
      x_pixel_pos    => x_pixel_pos_s,
      x_sprt_pos     => x_sprt_pos_s,
      y_next         => y_next_s,
      y_sprt_pos     => y_sprt_pos_s,
      prescan_start  => prescan_start_s
   );


   -- Tile layer
   inst_tiles : entity work.f18a_tiles
      port map (
      clk            => clk_100m0_i,
      rst_n          => reset_n_r,
      x_pixel_max    => x_pixel_max_s,
      x_pixel_pos    => x_pixel_pos_s,
      y_next_in      => y_next_s,
      prescan_start  => prescan_start_s,
   -- Table base addresses
      pgba           => pgba_s,
      gmode          => gmode_s,
      row30          => row30_s,
      textfg         => textfg_s,
      textbg         => textbg_s,
   -- F18A specific
      unlocked       => unlocked_s,
      ecm            => tile_ecm_s,
      tl1_off_i      => tl1_off_s,        -- '1' to disable tile layer 1
      pos_attr_i     => pos_attr_s,
      tpgsize_i      => tpgsize_s,        -- tile pattern table offset size
      tile_ps        => tile_ps_s,
   -- Scroll support
      t1ntba         => t1ntba_s,         -- tile1 name table base address
      t1ctba         => t1ctba_s,         -- tile1 color table base address
      t1hsize        => t1hsize_s,        -- tile1 horz page size (1 page or 2 pages)
      t1vsize        => t1vsize_s,        -- tile1 vert page size (1 page or 2 pages)
      t1horz         => t1horz_s,         -- tile1 horz scroll
      t1vert         => t1vert_s,         -- tile1 vert scroll
      t2_en          => t2_en_s,          -- tile2 enable
      t2_pri_en      => t2_pri_en_s,      -- tile2 priority enable (0 = TL2 always on top)
      t2ntba         => t2ntba_s,         -- tile2 name table base address
      t2ctba         => t2ctba_s,         -- tile2 color table base address
      t2hsize        => t2hsize_s,        -- tile2 horz page size (1 page or 2 pages)
      t2vsize        => t2vsize_s,        -- tile2 vert page size (1 page or 2 pages)
      t2horz         => t2horz_s,         -- tile2 horz scroll
      t2vert         => t2vert_s,         -- tile2 vert scroll

   -- Bitmap layer
      bmlba          => bmlba_s,
      bml_x          => bml_x_s,
      bml_y          => bml_y_s,
      bml_w          => bml_w_s,
      bml_h          => bml_h_s,
      bml_ps         => bml_ps_s,
      bml_en         => bml_en_s,
      bml_pri        => bml_pri_s,
      bml_trans      => bml_trans_s,
      bml_fat_i      => bml_fat_s,
   -- VRAM Interface
      tile_active    => tile_active_s,    -- 1 when tiles are active, otherwise 0
      vdin           => tile_dout_s,      -- In to Tile from *out* of VRAM
      vaddr          => tile_addr_s,
   -- Outputs
      sprite_start   => sprite_start_s,
      tile_color     => tile_color_s
   );


   -- Sprite layer
   inst_sprites : entity work.f18a_sprites
   port map (
      clk            => clk_100m0_i,
      rst_n          => reset_n_r,
      x_sprt_pos     => x_sprt_pos_s,
      y_sprt_pos     => y_sprt_pos_s,
      y_next_in      => y_next_s,
      y_margin_n     => y_margin_n_s,
      prescan_start  => prescan_start_s,
      sprite_start   => sprite_start_s,
      sprite_max     => sprite_max_s,
      stop_sprt      => stop_sprt_s,
   -- Table base addresses
      size_bit       => size_bit_s,
      mag_bit        => mag_bit_s,
      satba          => satba_s,
      spgba          => spgba_s,
      gmode          => gmode_s,
   -- F18A specific
      unlocked       => unlocked_s,
      row30          => row30_s,
      spgsize_i      => spgsize_s,        -- sprite pattern table offset size
      sprt_ps        => sprt_ps_s,
      ecm            => sprt_ecm_s,
   -- VRAM Interface
      vdin           => tile_dout_s,      -- In to Sprite from *out* of VRAM
      vaddr          => sprt_addr_s,
   -- Outputs
      sprt_color     => sprt_color_s,
      sprt_cf        => sp_cf_s,
      sprt_5s        => sp_5s_s,
      sprt_5th       => sp_5th_s,
      reportmax_i    => reportmax_s
   );


   -- Color RAM and output pixel selection
   inst_color : entity work.f18a_color
   port map (
      clk            => clk_100m0_i,
      vga_clk        => clk_25m0_i,
      we1            => col_we_s,
      addr1          => col_addr_cpu_s,
      din            => col_din_s,
      dout1          => col_dout_s,       -- to the GPU! :-)
      tile_color     => tile_color_s,
      sprt_color     => sprt_color_s,
      bg_color       => bg_color_s,
      show_bg        => show_bg,
      tile_r         => tile_r_s,
      tile_g         => tile_g_s,
      tile_b         => tile_b_s
   );


   -- Version ROM and banner generation
   inst_version : entity work.f18a_version
   port map (
      clk            => clk_100m0_i,
      rst_n_i        => reset_n_r,
      vga_clk        => clk_25m0_i,
      intr_en_i      => intr_en_s,
      raster_x       => raster_x_s,
      raster_y       => raster_y_s,
      blank_i        => blank_s,
      -- outputs
      override_o     => override_s,
      red_o          => override_r_s,
      grn_o          => override_g_s,
      blu_o          => override_b_s
   );


   -- Use TL1 as the background color palette selector.
   bg_color_s <= (tile_ps_s(2 to 3) & textbg_s);

   -- soft_blank_s == VR1 blank bit and '0' means blank to background color
   show_bg <= in_margin_s or (not soft_blank_s);

   -- Simulated scan lines every other VGA line when scanlines_i = '1'.
   -- The odd scan lines have their color value reduced by 50%.
   red_s <=
      override_r_s when override_s = '1' else
      "0" & tile_r_s(0 to 2) when ((scanlines_r = '1' or vscanln_en_s = '1') and raster_y_s(9) = '1') else
      tile_r_s;

   grn_s <=
      override_g_s when override_s = '1' else
      "0" & tile_g_s(0 to 2) when ((scanlines_r = '1' or vscanln_en_s = '1') and raster_y_s(9) = '1') else
      tile_g_s;

   blu_s <=
      override_b_s when override_s = '1' else
      "0" & tile_b_s(0 to 2) when ((scanlines_r = '1' or vscanln_en_s = '1') and raster_y_s(9) = '1') else
      tile_b_s;


   -- Register the VGA outputs.
   process (clk_25m0_i) begin if rising_edge(clk_25m0_i) then
      blank_r  <= blank_s;
      hsync_r  <= hsync_s;
      vsync_r  <= vsync_s;
      red_r    <= red_s;
      grn_r    <= grn_s;
      blu_r    <= blu_s;
   end if; end process;

   blank_o     <= blank_r;
   hsync_o     <= hsync_r;
   vsync_o     <= vsync_r;
   red_o       <= red_r;
   grn_o       <= grn_r;
   blu_o       <= blu_r;

end rtl;
