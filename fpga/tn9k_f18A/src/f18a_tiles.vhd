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

-- Implements the tile layers.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;

entity f18a_tiles is
   port (
      clk            : in  std_logic;
      rst_n          : in  std_logic;
      x_pixel_max    : in  unsigned(0 to 8);
      x_pixel_pos    : in  unsigned(0 to 8);
      y_next_in      : in  unsigned(0 to 8);
      prescan_start  : in  std_logic;
   -- Table base addresses
      pgba           : in  std_logic_vector(0 to 2);
      gmode          : in  unsigned(0 to 3);
      row30          : in  std_logic;                 -- 1 when 30 rows
      textfg         : in  std_logic_vector(0 to 3);
      textbg         : in  std_logic_vector(0 to 3);
   -- F18A specific
      unlocked       : in  std_logic;                 -- '1' when enhanced registers are unlocked
      ecm            : in  unsigned(0 to 1);          -- enhanced color mode
      tl1_off_i      : in  std_logic;                 -- '1' when tile layer 1 is disabled
      pos_attr_i     : in  std_logic;                 -- '1' to use position-based tile attributes
      tpgsize_i      : in  std_logic_vector(0 to 1);  -- Tile pattern generator size offset
      tile_ps        : in  std_logic_vector(0 to 3);  -- tile palette select, T2PS[0..1] T1PS[2..3]
   -- Scrolling and Tile Layers
      t1ntba         : in  std_logic_vector(0 to 3);  -- tile1 name table base address
      t1ctba         : in  std_logic_vector(0 to 7);  -- tile1 color table base address
      t1hsize        : in  std_logic;                 -- tile1 horz page size (1 page or 2 pages)
      t1vsize        : in  std_logic;                 -- tile1 vert page size (1 page or 2 pages)
      t1horz         : in  std_logic_vector(0 to 7);  -- tile1 horz scroll
      t1vert         : in  std_logic_vector(0 to 7);  -- tile1 vert scroll
      t2_en          : in  std_logic;                 -- tile2 enable
      t2_pri_en      : in  std_logic;                 -- tile2 priority enable (0 = TL2 always on top)
      t2ntba         : in  std_logic_vector(0 to 3);  -- tile2 name table base address
      t2ctba         : in  std_logic_vector(0 to 7);  -- tile2 color table base address
      t2hsize        : in  std_logic;                 -- tile2 horz page size (1 page or 2 pages)
      t2vsize        : in  std_logic;                 -- tile2 vert page size (1 page or 2 pages)
      t2horz         : in  std_logic_vector(0 to 7);  -- tile2 horz scroll
      t2vert         : in  std_logic_vector(0 to 7);  -- tile2 vert scroll
   -- Bitmap layer
      bmlba          : in  std_logic_vector(0 to 7);  -- bitmap layer base address
      bml_x          : in  std_logic_vector(0 to 7);
      bml_y          : in  std_logic_vector(0 to 7);
      bml_w          : in  std_logic_vector(0 to 7);
      bml_h          : in  std_logic_vector(0 to 7);
      bml_ps         : in  std_logic_vector(0 to 3);  -- bitmap layer palette select
      bml_en         : in  std_logic;                 -- '1' to enable the bitmap layer
      bml_pri        : in  std_logic;                 -- '1' when bitmap has priority over tiles
      bml_trans      : in  std_logic;                 -- '1' to set "00" pixels transparent
      bml_fat_i      : in  std_logic;                 -- '1' to set BML fat-pixel mode
   -- VRAM Interface
      vdin           : in  std_logic_vector(0 to 7);
      vaddr          : out std_logic_vector(0 to 13);
      tile_active    : out std_logic;
   -- Outputs
      sprite_start   : out std_logic;
      tile_color     : out std_logic_vector(0 to 7)
   );
end f18a_tiles;

architecture rtl of f18a_tiles is

   constant NUM24 : unsigned(0 to 5) := "011000"; -- 24
   constant NUM30 : unsigned(0 to 5) := "011110"; -- 30

   constant ADDR_WIDTH : integer := 9;
   constant DATA_WIDTH : integer := 8;

   -- The tile line buffers are 512 pixels by 8-bits per pixel.
   --
   --    0     1     2     3     4     5     6     7
   -- | PIX | PRI |      6-bit color address           |
   --
   -- PIX = if there is a tile pixel or not, used to facilitate
   --       transparent tile pixels.  If PIX = 0 then the tile
   --       does not have a pixel for this location.  If PIX = 1
   --       then the 6-bit color address is valid and PRI should
   --       be considered to determine the final color.
   -- PRI = priority over sprites.  1 = priority
   --
   -- Tiles with a transparency set will lose priority for "00"
   -- pixels, so the sprite will show through, or the background.
   --

   component f18a_tile_linebuf is
   generic (
      ADDR_WIDTH : integer := 9;
      DATA_WIDTH : integer := 8
   );
   port (
      clk      : in std_logic;
      we1      : in std_logic;
      addr1    : in std_logic_vector(0 to 8);
      din1     : in std_logic_vector(0 to 7);
      dout1    : out std_logic_vector(0 to 7);
      we2      : in std_logic;
      addr2    : in std_logic_vector(0 to 8);
      din2     : in std_logic_vector(0 to 7);
      dout2    : out std_logic_vector(0 to 7)
   );
   end component;

   signal we1     : std_logic;
   signal addr1   : std_logic_vector(0 to ADDR_WIDTH - 1);
   signal din     : std_logic_vector(0 to DATA_WIDTH - 1);
   signal dout1   : std_logic_vector(0 to DATA_WIDTH - 1);

   signal we2     : std_logic;
   signal addr2   : std_logic_vector(0 to ADDR_WIDTH - 1);
   signal dout2   : std_logic_vector(0 to DATA_WIDTH - 1);

   -- FSM trigger
   type trig_type is (TRIG_IDLE, TRIG_WAIT, TRIG_RESTART);
   signal trig_r, trig_x : trig_type;
   signal sprite_en_r, sprite_en_x     : std_logic;
   signal trig_start_r, trig_start_x   : std_logic;
   signal prescan_r                    : std_logic;   -- prescan_start input edge detect

   type tile_type is (
      ST_IDLE, ST_SETUP, ST_ADDR_NAME, ST_ADDR_BML1, ST_ADDR_BML2,
      ST_ADDR_ATTR, ST_ADDR_PTRN1, ST_ADDR_PTRN2, ST_ADDR_PTRN3,
      ST_ADDR_COLR, ST_LOAD_SHIFT);
   signal state_r, state_x : tile_type;

   signal y_next_r      : unsigned(0 to 8);           -- register y_next input
   signal y_pos_r       : std_logic_vector(0 to 8);   -- register y_next input as std_logic_vector
   signal y_pix_row_r   : unsigned(0 to 8);
   signal y_max_rows_r  : unsigned(0 to 5);
   signal y_tile_row_s  : unsigned(0 to 5);
   signal y_tile_dif_s  : unsigned(0 to 5);

   signal name_addr_s   : std_logic_vector(0 to 13);  -- Name table address
   signal attr_addr_r   : std_logic_vector(0 to 13);  -- Tile attribute address
   signal ptrn_addr_s   : std_logic_vector(0 to 13);  -- Original pattern address
   signal ptrn_addr_r   : std_logic_vector(0 to 13);  -- Original pattern address
   signal ptrn2ba_s     : std_logic_vector(0 to 5);   -- Second pattern address
   signal ptrn3ba_s     : std_logic_vector(0 to 4);   -- Third pattern address
   signal colr_addr_s   : std_logic_vector(0 to 13);
   signal bml_addr_r, bml_addr_x : std_logic_vector(0 to 13);
   signal tpgoffset_s   : std_logic_vector(0 to 3);   -- ECM2/3 pattern table offset size

   -- Register gmode input to break up long logic paths.
   signal gmode_r       : unsigned(0 to 3);

   -- Added to the color table base address to select name or position
   -- based attributes for tiles.
   signal attr_name_vs_pos_s : std_logic_vector(0 to 13);

   signal vdin_s : std_logic_vector(0 to 7);    -- VRAM data in bit reversal.
   signal flip_x_sel : std_logic;               -- '1' when VRAM input data should be reversed

   -- Enhanced color support
   signal flip_x_r, flip_x_x        : std_logic;
   signal tile_pri_r, tile_pri_x    : std_logic;   -- Tile priority over sprites
   signal trans_r, trans_x          : std_logic;   -- If a pixel is transparent
   signal pal_sel_r, pal_sel_x      : std_logic_vector(0 to 3);   -- Palette select from tile attribute table
   signal attr_r, attr_x            : std_logic_vector(0 to 7);   -- Tile attribute values
   signal t1ps_r, t2ps_r            : std_logic_vector(0 to 1);   -- Tile layer 1 and 2 palette select from VR24

   signal tile_en_r     : std_logic;                  -- '1' when tile layer 1 is enabled (visible)
   signal layer_sel_r, layer_sel_x : std_logic;       -- '1' tile layer 2 is active
   signal ntba_s        : std_logic_vector(0 to 3);   -- Current name table base address
   signal ctba_s        : std_logic_vector(0 to 7);   -- Current color table base address
   signal hsize_s       : std_logic;                  -- Current horz page size
   signal vsize_s       : std_logic;                  -- Current vert page size
   signal hscroll_s     : std_logic_vector(0 to 7);   -- Current horz scroll
   signal vscroll_s     : std_logic_vector(0 to 7);   -- Current vert scroll
   signal tileps_s      : std_logic_vector(0 to 1);   -- Current tile palette select

   -- Used in building addresses, this holds the X address of the current
   -- tile and is incremented in steps of 8.
   signal textstart_r   : unsigned(0 to 13);                -- Text position start
   signal text_cols_s   : unsigned(0 to 6);
   signal text_ntba_s   : std_logic_vector(0 to 3);
   signal textpos_r, textpos_x : std_logic_vector(0 to 13); -- Text position counter
   signal textattr_r, textattr_x : std_logic_vector(0 to 13); -- Text attribute counter
   signal textmode_r    : std_logic;                        -- '1' when in a text mode

   signal text_cmax_s : std_logic_vector(0 to 6);           -- Max text columns - 1 (39 or 79)
   signal t_horz_off_s : std_logic_vector(0 to 6);          -- Starting text column tile offset (0..39/79)
   signal texttile_r, texttile_x : std_logic_vector(0 to 6);-- Total number of T40/T80 tiles expanded
   signal t40_div6_r : std_logic_vector(0 to 17);           -- result of 9x9x18 multiplier for divide-by-6
   signal t80_div6_r : std_logic_vector(0 to 17);           -- result of 9x9x18 multiplier for divide-by-6
   signal t_ntba_pos_r : std_logic_vector(0 to 13);         -- NTBA + current offset
   signal t_ctba_pos_r : std_logic_vector(0 to 13);         -- CTBA + current offset
   signal t40_hpo_s : std_logic_vector(0 to 2);             -- Scroll offset for T40
   signal t80_hpo_s : std_logic_vector(0 to 2);             -- Scroll offset for T80
   signal text_hpo_s : std_logic_vector(0 to 2);            -- Scroll offset for T40/T80

   signal hto_r, hto_x, hto_s : std_logic_vector(0 to 5);   -- horz page + tile offset (0 to 63 tiles possible)
   signal hpo_r, hpo_x     : unsigned(0 to 2);              -- horz pixel offset
   signal vto_r, vto_x     : std_logic_vector(0 to 5);      -- vert page + tile offset (0 to 60 tiles possible)
   signal vpo_r, vpo_x     : std_logic_vector(0 to 2);      -- vert pixel offset

   signal name_r, name_x   : std_logic_vector(0 to 7);      -- current tile name

   -- GM2 masks
   signal gm2_ptrn_mask1_s : std_logic_vector(0 to 1);
   signal gm2_colr_mask1_s : std_logic_vector(0 to 1);
   signal gm2_colr_mask2_s : std_logic_vector(0 to 7);

   -- Tile patterns and colors
   signal ptrn1_r, ptrn1_x       : std_logic_vector(0 to 7);   -- 1st pattern byte
   signal ptrn2_r, ptrn2_x       : std_logic_vector(0 to 7);   -- 2nd pattern byte
   signal ptrn3_r, ptrn3_x       : std_logic_vector(0 to 7);   -- 3rd pattern byte
   signal colr_fg_r, colr_fg_x   : std_logic_vector(0 to 3);
   signal colr_bg_r, colr_bg_x   : std_logic_vector(0 to 3);
   signal mcm_fg_r, mcm_fg_x     : std_logic_vector(0 to 3);   -- MCM foreground color
   signal mcm_bg_r, mcm_bg_x     : std_logic_vector(0 to 3);   -- MCM background color

   -- Fast pre-buffering
   -- Number of pixels to use from the current tile pattern.  Used for
   -- text modes where only 6 of the 8 pixels in a pattern are used, but
   -- tiles are still addressed on byte boundaries.
   signal x_expand_max_r : integer range 0 to 7 := 7;       -- 5 for text modes, otherwise 7
   signal x_linebuf_r, x_linebuf_x : unsigned(0 to 8);      -- Current x index in line buffer
   signal pixcnt_r, pixcnt_x : natural range 0 to 7 := 0;

   signal we_s       : std_logic;   -- Line buffer write enable
   signal we_sel     : std_logic;   -- Final line buffer write enable based on current tile layer

   -- Pixel shifting
   type shift_type is (
      SHIFT_IDLE, SHIFT_LOAD, SHIFT_EXPAND);
   signal shift_r, shift_x    : shift_type;

   signal done_r, done_x   : std_logic;

   signal p1_r, p1_x    : std_logic_vector(0 to 7);
   signal p2_r, p2_x    : std_logic_vector(0 to 7);
   signal p3_r, p3_x    : std_logic_vector(0 to 7);

   -- Tile pixel selection
   signal pix_colr_s : std_logic_vector(0 to 3);
   signal pix0_s     : std_logic;
   signal pix1_s     : std_logic;
   signal pix2_s     : std_logic;
   signal pix3_s     : std_logic;
   signal tile_din_s : std_logic_vector(0 to 7);


   -- Bitmap layer
   signal bml_state_r, bml_state_x     : shift_type;
   signal wmul_zadj_s                  : std_logic;
   signal wmul9bit_s                   : std_logic_vector(0 to 8);
   signal wmul_s                       : std_logic_vector(0 to 7);
   signal bml_yline_r, bml_yline_x     : std_logic_vector(0 to 7);
   signal bml_yoff_r                   : std_logic_vector(0 to 15);
   signal bml_in_x_s                   : std_logic;
   signal bml_in_y_r, bml_in_y_x       : std_logic;
   signal bml_in_area_s                : std_logic;
   signal bml_xloc_r, bml_xloc_x       : std_logic_vector(0 to 7);
   signal bml_xcnt_r, bml_xcnt_x       : std_logic_vector(0 to 8);
   signal bml_cnt_en_r, bml_cnt_en_x   : std_logic;
   signal mode256_r                    : std_logic;   -- '1' when in a 256-pixel per line mode.

   signal bml_isfat_s                  : std_logic;
   signal bml_fat_r, bml_fat_x         : std_logic_vector(0 to 7);
   signal bml_dinfat_s                 : std_logic_vector(0 to 7);
   signal bml_dinpix_s                 : std_logic_vector(0 to 7);
   signal bml_shift_r, bml_shift_x     : std_logic_vector(0 to 7);

   -- BML pixel selection.
   signal bml_ispix_s         : std_logic;
   signal bml_din_s           : std_logic_vector(0 to 7);
   signal bml_sel             : std_logic;
   signal bml_en_r, bml_en_x  : std_logic;


   -- Bitmap Layer FIFO Register File.  4-bytes deep.
   type fifo_type is array (0 to 3) of std_logic_vector(0 to 7);
   signal fifo : fifo_type;
   signal fifo_wr_cnt_r, fifo_wr_cnt_x : unsigned(0 to 2);
   signal fifo_rd_cnt_r, fifo_rd_cnt_x : unsigned(0 to 2);
   signal fifo_wr_adr_s : unsigned(0 to 1);
   signal fifo_rd_adr_s : unsigned(0 to 1);
   signal fifo_dout_s : std_logic_vector(0 to 7);
   signal fifo_full_s : std_logic;
   signal fifo_we_s : std_logic;                -- Active high
   signal fifo_re_r, fifo_re_x : std_logic;     -- Active high

begin

   -- Tile odd / even line buffers.
   inst_linebuf : f18a_tile_linebuf
   generic map (
      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH
   )
   port map (
      clk      => clk,
      we1      => we1,
      addr1    => addr1,
      din1     => din,
      dout1    => dout1,
      we2      => we2,
      addr2    => addr2,
      din2     => din,
      dout2    => dout2
   );

   -- Color index output alternates every other fat-pixel line.
   tile_color <= dout1 when y_next_r(8) = '1' else dout2;

   -- Final write enable:
   -- Always for tile layer 1, or tile layer 2 and there is a tile pixel.
   we_sel <= we_s and ((not layer_sel_r) or tile_din_s(0));

   -- When y_next_r is even, data goes to linebuf1.
   we1 <= (not y_next_r(8)) and we_sel;
   we2 <= y_next_r(8) and we_sel;

   -- Buffer address mux.  A y_next_r that is odd means the even buffer
   -- (linebuf1) has data to display since it was filled on the even
   -- y_next_r line.
   addr1 <= std_logic_vector(x_linebuf_r) when y_next_r(8) = '0' else
      std_logic_vector(x_pixel_pos);
   addr2 <= std_logic_vector(x_linebuf_r) when y_next_r(8) = '1' else
      std_logic_vector(x_pixel_pos);

   -- Tile layers.
   pix_colr_s <= colr_fg_r when p1_r(0) = '1' else colr_bg_r;
   pix0_s <= '1' when (p1_r(0) = '1' and colr_fg_r > 0) or (p1_r(0) = '0' and colr_bg_r > 0) else '0';
   pix1_s <= (not trans_r) or p1_r(0);
   pix2_s <= (not trans_r) or p2_r(0) or p1_r(0);
   pix3_s <= (not trans_r) or p3_r(0) or p2_r(0) or p1_r(0);

   tile_din_s <=
      pix0_s & tile_pri_r & tileps_s & pix_colr_s when ecm = 0 else              -- Original color mode
      pix1_s & tile_pri_r & tileps_s(0) & pal_sel_r & p1_r(0) when ecm = 1 else  -- 1-bit color
      pix2_s & tile_pri_r & pal_sel_r & p2_r(0) & p1_r(0) when ecm = 2 else      -- 2-bit color
      pix3_s & tile_pri_r & pal_sel_r(0 to 2) & p3_r(0) & p2_r(0) & p1_r(0);     -- 3-bit color

   -- Set a BML pixel based on the transparency setting, just like tile pixels.
   bml_ispix_s <= (not bml_trans) or bml_shift_r(0) or bml_shift_r(1);
   bml_dinpix_s <= bml_ispix_s & '0' & bml_ps & bml_shift_r(0 to 1);

   -- Set a BML fat-pixel based on the transparency setting, just like tile pixels.
   bml_isfat_s <= (not bml_trans) or bml_fat_r(0) or bml_fat_r(1) or bml_fat_r(2) or bml_fat_r(3);
   bml_dinfat_s <= bml_isfat_s & '0' & bml_ps(0 to 1) & bml_fat_r(0 to 3);

   bml_din_s <= bml_dinpix_s when bml_fat_i = '0' else bml_dinfat_s;

   -- Bitmap layer vs tile pixel sel
   -- The bitmap layer has to be enabled and the raster x,y in the bitmap
   -- area, and have either priority over tiles or the current tile pixel
   -- must be transparent.
   -- Pixel transparency can allow a tile to show through a priority BML when
   -- the BML pixel is transparent.
   bml_sel <=
      bml_en_r and bml_in_area_s and bml_din_s(0) and    -- BML must be enabled, and in area, and have a pixel,
      (bml_pri or                                        -- and have priority over tiles,
      ((not bml_pri) and (not tile_din_s(0))));          -- or be under a transparent tile.

   din <=
      bml_din_s when bml_sel = '1' else
      tile_din_s when tile_en_r = '1' else
      x"00";

   process (clk) begin if rising_edge(clk) then
      -- layer_sel_r is '1' when TL2 is active, otherwise tl1_off controls
      -- the visibility of the default GM1, GM2, MCM, T40, T80
      tile_en_r <= layer_sel_r or (not tl1_off_i);
   end if; end process;

   -- VRAM Address Mux
   -- Address selection is based on the next state for two-cycle BRAM access.
   process (state_x, name_addr_s, attr_addr_r, ptrn_addr_r,
   ptrn_addr_s, ptrn2ba_s, ptrn3ba_s, colr_addr_s, bml_addr_r)
   begin
      case state_x is
      when ST_ADDR_NAME    => vaddr <= name_addr_s;
      when ST_ADDR_ATTR    => vaddr <= attr_addr_r;
      when ST_ADDR_PTRN1   => vaddr <= ptrn_addr_s;
      when ST_ADDR_PTRN2   => vaddr <= ptrn2ba_s & ptrn_addr_r(6 to 13);
      when ST_ADDR_PTRN3   => vaddr <= ptrn3ba_s & ptrn_addr_r(5 to 13);
      when ST_ADDR_COLR    => vaddr <= colr_addr_s;
      when others          => vaddr <= bml_addr_r;
      end case;
   end process;

   -- VRAM Data Mirror Mux
   -- Used to flip-X the pattern bits.
   process (flip_x_sel, textmode_r, vdin)
   begin
      vdin_s <= vdin;
      if flip_x_sel = '1' then
         if textmode_r = '0' then
            vdin_s(0) <= vdin(7);
            vdin_s(1) <= vdin(6);
            vdin_s(2) <= vdin(5);
            vdin_s(3) <= vdin(4);
            vdin_s(4) <= vdin(3);
            vdin_s(5) <= vdin(2);
            vdin_s(6) <= vdin(1);
            vdin_s(7) <= vdin(0);
         else
            vdin_s(0) <= vdin(5);
            vdin_s(1) <= vdin(4);
            vdin_s(2) <= vdin(3);
            vdin_s(3) <= vdin(2);
            vdin_s(4) <= vdin(1);
            vdin_s(5) <= vdin(0);
            vdin_s(6) <= '0';
            vdin_s(7) <= '0';
         end if;
      end if;
   end process;

   -- Register the input registers since they don't change during scanning.
   process (clk) begin if rising_edge(clk) then
      t1ps_r <= tile_ps(2 to 3);
      t2ps_r <= tile_ps(0 to 1);
   end if; end process;

   -- Tile layer mux.  Selects registers for tile layer 1 or 2.
   process (layer_sel_r,
   t1ntba, t1ctba, t1ps_r, t1hsize, t1vsize, t1horz, t1vert,
   t2ntba, t2ctba, t2ps_r, t2hsize, t2vsize, t2horz, t2vert)
   begin
      ntba_s   <= t1ntba;
      ctba_s   <= t1ctba;
      hsize_s  <= t1hsize;
      tileps_s <= t1ps_r;

      -- Choose the current and next vertical page based on
      -- the vertical page size.
      if t1vsize = '0' then
         vsize_s <= t1ntba(2);
      else
         vsize_s <= not t1ntba(2);
      end if;

      hscroll_s <= t1horz;
      vscroll_s <= t1vert;

      if layer_sel_r = '1' then
         ntba_s <= t2ntba;
         ctba_s <= t2ctba;
         hsize_s <= t2hsize;
         tileps_s <= t2ps_r;

         -- Choose the current and next vertical page based on
         -- the vertical page size.
         if t2vsize = '0' then
            vsize_s <= t2ntba(2);
         else
            vsize_s <= not t2ntba(2);
         end if;

         hscroll_s <= t2horz;
         vscroll_s <= t2vert;
      end if;
   end process;


   -- Y-Scroll registers and calculations.
   process (clk) begin if rising_edge(clk) then
      y_next_r <= y_next_in;
      y_pos_r <= std_logic_vector(y_next_in);

      y_pix_row_r <= unsigned('0' & vscroll_s) + y_next_in;

      if row30 = '0' then
         y_max_rows_r <= NUM24;
      else
         y_max_rows_r <= NUM30;
      end if ;

      vto_r <= vto_x;
   end if; end process;

   -- Isolate the vertical tile count, 0..63.
   y_tile_row_s <= y_pix_row_r(0 to 5);
   y_tile_dif_s <= y_pix_row_r(0 to 5) - y_max_rows_r;   -- (0 to 47/59) - (24/30)

   -- When the counter increments from 31 to 32, the name table address will
   -- be determined by the vertical page size and the current vertical name table,
   -- as selected above in the vsize_s logic.
   vto_x <=
      ntba_s(2) & std_logic_vector(y_tile_row_s(1 to 5)) when y_tile_row_s < y_max_rows_r  else
      vsize_s   & std_logic_vector(y_tile_dif_s(1 to 5));


   -- GM2 masks.  The difference between GM1 and GM2 is that in GM2 the pattern
   -- and color tables are located with the MSb of VR3 (color) and VR4(pattern)
   -- only, which allows the tables to be at 0K or 8K.  The next two bits of
   -- the address come from the two MSb of the Y counter, which allows for up to
   -- four pattern/color tables.
   --
   --  0  1  2  3  4  5  6  7  8  9 10 11 12 13
   -- VR4|Y0 Y1|       NAME           |Y5 Y6 Y7
   --
   -- The pattern base is 3-bits, the first is used to place the table, the 2nd
   -- and 3rd bits are are logically ANDed with the two Y bits to allow control
   -- over how many pattern tables there are according to the Y location.
   --
   -- Y 01234567
   --   00xxxxxx = lines 0 to 63
   --   01xxxxxx = lines 64 to 127
   --   10xxxxxx = lines 128 to 191
   --   11xxxxxx = lines 192 to 255 (useless table, lines 192 to 255 are off screen)
   --
   -- If VR4 = "x00", then the Y bits would never modify the pattern table, and
   -- all patterns would pull from the same 2K of VRAM.  "x01" and two pattern
   -- tables would be used, one for the 1st and 3rd, another for the 2nd. "x10"
   -- and the 1st and 2nd use the same patterns, the 3rd a separate pattern table.
   -- "x11" and each 1st, 2nd, and 3rd use their own pattern tables.
   --
   -- The color table works the same way as the pattern tables in GM2.
   --
   -- VR3 is usually 8-bits, but in GM2, the top bit locates the table, the
   -- next two mask the color table same as the pattern table.  The last five
   -- are ANDed with the the top 5-bits of the name, which has the effect of
   -- reducing the number of names, which reduces the pattern table sizes.
   --
   -- GM2 does not pick up the page-bit from the MSbit of vto_r.
   --
   gm2_ptrn_mask1_s <= vto_r(1 to 2) and pgba(1 to 2);
   gm2_colr_mask1_s <= vto_r(1 to 2) and ctba_s(1 to 2);
   gm2_colr_mask2_s <= name_r and (ctba_s(3 to 7) & "111");


   -- textpos is 0 - 959  (40x24) or 0 - 1199 (40x30) for text mode 1
   -- textpos is 0 - 1920 (80x24) or 0 - 2399 (80x30) for text mode 2
   name_addr_s <=
      textpos_r when textmode_r = '1' else                                    -- text1, text2
      ntba_s(0 to 1) & vto_r(0) & hto_r(0) & vto_r(1 to 5) & hto_r(1 to 5);   -- gm1, gm2, mcm

   -- Modify the attribute address based on tile name vs tile position.
   process (pos_attr_i, textmode_r, vdin, textattr_r, vto_r, hto_r, vto_r, hto_r, ctba_s)
   begin
--    attr_name_vs_pos_s <= ("000000" & name_r);
      attr_name_vs_pos_s <= (ctba_s & "000000") + ("000000" & vdin);

      if pos_attr_i = '1' then
         if textmode_r = '1' then
            -- text1, text2
            -- textattr_r has the CTBA already added in.
            attr_name_vs_pos_s <= textattr_r;
         else
            -- gm1, gm2, mcm
            -- The position-based attribute table is as big as the configured
            -- name tables.  For two tile layers, with 4x4 name tables, there
            -- is not enough VRAM left for patterns, sprites, or anything else.
            attr_name_vs_pos_s <= (ctba_s & "000000") +
               ("00" & vto_r(0) & hto_r(0) & vto_r(1 to 5) & hto_r(1 to 5));
         end if;
      end if;
   end process;

   -- The tile attribute is the color table base address PLUS the tile name or position.
   process (clk) begin if rising_edge(clk) then
      --attr_addr_r <= (ctba_s & "000000") + attr_name_vs_pos_s;
      attr_addr_r <= attr_name_vs_pos_s;
   end if; end process;

   ptrn_addr_s <=
      pgba(0) & gm2_ptrn_mask1_s & gm2_colr_mask2_s & vpo_r
         when gmode_r = 4 else                              -- gm2
      pgba & name_r & y_pos_r(4 to 6) when gmode_r = 2 else -- mcm
      pgba & name_r & vpo_r;                                -- gm1, text

   -- Register for timing violation.
   process (clk) begin if rising_edge(clk) then
      ptrn_addr_r <= ptrn_addr_s;
   end if; end process;

   -- Extra pattern table offsets.
   --
   -- 8K 4K 2K 1K 512 256 128 64 32 16 8  4  2  1
   -- 0  1  2  3   4   5   6  7  8  9 10 11 12 13
   --          p   p   p   p  p  p  p  p  p  p  p
   --       o  o   o   o
   --    o  o  o   o
   --
   -- Usable      Memory Used
   -- Tiles    ECM0/1  ECM2  ECM3
   -- ---------------------------
   -- 0-31     256     512   768
   -- 0-63     512     1K    1536
   -- 0-127    1K      2K    3K
   -- 0-255    2K      4K    6K
   --
   -- 11 = +256, 10 = +512, 01 = +1K, 00 = +2K (default)
   process (tpgsize_i) begin
   case tpgsize_i is
      when "00" => tpgoffset_s <= "1000";
      when "01" => tpgoffset_s <= "0100";
      when "10" => tpgoffset_s <= "0010";
      when "11" => tpgoffset_s <= "0001";
      when others => null;
   end case; end process;

   ptrn2ba_s <= ptrn_addr_r(0 to 5) + ("00" & tpgoffset_s);
   ptrn3ba_s <= ptrn_addr_r(0 to 4) + ("0" & tpgoffset_s);
--   ptrn2ba_s <= ptrn_addr_s(0 to 2) + "001"; -- +2048
--   ptrn3ba_s <= ptrn_addr_s(0 to 2) + "010"; -- +4096

   colr_addr_s <=
      ctba_s(0) & gm2_colr_mask1_s & gm2_colr_mask2_s & vpo_r
         when gmode_r = 4 else                              -- gm2
      ctba_s & '0' & name_r(0 to 4);                        -- gm1, mcm, text


   -- The number of pixels to use from the current tile pattern depends on
   -- the current graphics mode.  Text modes only use 6 of the 8 pixels.
   -- gmode = m4 m3 m2 m1
   --   gm1   0  0  0  0 = 0
   --   gm2   0  1  0  0 = 4
   --   mcm   0  0  1  0 = 2
   --   txt1  0  0  0  1 = 1
   --   txt2  1  0  0  1 = 9

   -- Register these to help break combinatorial delays.
   process (clk) begin if rising_edge(clk) then
      gmode_r <= gmode;
      if (gmode_r = 1 or gmode_r = 9) then
         textmode_r <= '1'; else
         textmode_r <= '0';
      end if;

      if textmode_r = '1' then
         x_expand_max_r <= 5; else
         x_expand_max_r <= 7;
      end if;

      mode256_r <= not gmode_r(0);
   end if; end process;


   -- 80-column use of VR2:
   -- The 9938 indicates that the LS 2-bits of VR2 must be "11" for 80-column mode.
   -- That means 4K boundaries for 80-column mode since only 2-bits are left of
   -- the NTBA part of VR2, at least for the F18A since it does not have the
   -- expanded memory space and extra address bits.  Since it seems existing software
   -- will set VR2 to "xx11", i.e. "0011" for a 0K offset name table, this condition
   -- is trapped here and the "11" is forced to "00" as if it were ignored.  Otherwise,
   -- the extra bits are used to allow more options for 80-column name table placement.
   --
   -- V1.6 update, May 2, 2014:
   -- In practice it was found that existing software set the LSbits of the name table
   -- to values other than "11", and this enhancement was causing problems because T80
   -- name tables were located at start addresses other than >0000 when the LSbits were
   -- other than "xx11".  Thus, only when the F18A is unlocked (hence new software) can
   -- the T80 name table be located on 1K boundaries.  When locked, the two LSbits will
   -- be forced to "00" as if they were ignored.
   --
   -- The table is 1920 bytes in 80x24 mode, and 2400 bytes in 80x30 mode.
   --
   -- Original 9938 4-bit NTBA of VR2: 00xx = 0K, 01xx = 4K, 10xx = 8K, 11xx = 12K

   process (unlocked, gmode_r, ntba_s, t40_div6_r, t40_hpo_s, t80_div6_r, t80_hpo_s)
   begin
      text_cols_s  <= "0101000";       -- 40
      text_cmax_s  <= "0100111";       -- 39
      text_ntba_s  <= ntba_s;
      -- T40 divide-by-2 after multiply.
      t_horz_off_s <= t40_div6_r(0 to 6);
      text_hpo_s <= t40_hpo_s;

      if gmode_r = 9 then
         text_cols_s  <= "1010000";    -- 80
         text_cmax_s  <= "1001111";    -- 79
         -- T80 scrolls at 2x the pixel size.
         t_horz_off_s <= t80_div6_r(0 to 6);
         text_hpo_s <= t80_hpo_s;

         -- Ignore two LSbits of name table if the F18A is not unlocked.
         if unlocked = '0' then
            text_ntba_s <= ntba_s(0 to 1) & "00";
         end if;
      end if;
   end process;

   -- Use the fraction to convert to a remainder for initial scroll offset.
   process (t40_div6_r) begin
   case t40_div6_r(7 to 9) is
      when "000"         => t40_hpo_s <= "000";    -- R0 = 000 = 0
      when "001"         => t40_hpo_s <= "001";    -- R1 = 001 = .125
      when "010" | "011" => t40_hpo_s <= "010";    -- R2 = 010 = .25 or 011 = .333
      when "100"         => t40_hpo_s <= "011";    -- R3 = 100 = .5
      when "101"         => t40_hpo_s <= "100";    -- R4 = 101 = .625
      when "110" | "111" => t40_hpo_s <= "101";    -- R5 = 110 = .75 or 111 = .833
      when others => null;
   end case; end process;


   -- T80 scroll offset is always 0, 2, or 4.
   t80_hpo_s <= "100" when t80_div6_r(7 to 8) = "11" else (t80_div6_r(7 to 8) & "0");

   -- The text position can not be generated with bit-twiddling because it is
   -- based on a row width (40 or 80) that is not a power of 2.  So, the text
   -- position needs to be counted.
   process (clk) begin if rising_edge(clk) then
      -- 7x7 multiplier, 14-bit result.
      textstart_r <= (("00" & unsigned(vto_r(1 to 5))) * text_cols_s);

      -- Since division is a multi-step process in hardware, and the FPGA has
      -- dedicated multipliers, multiply by the reciprocal to replace the division.

      -- http://embeddedgurus.com/stack-overflow/2009/06/division-of-integers-by-constants/
      -- T40-offset = hscroll / 6
      -- T80-offset = (hscroll * 2) / 6
      -- 1/6 == .001010101010101
      -- Left shift until '1' bit is at decimal point: .101010101010
      -- Two shifts were needed: S
      -- Take the nine MSbits and add 1: 101010110 = 0x156 (342 decimal)
      -- 18-bit Q = 9-bit N * 0x156.
      -- Right-shift the answer 9 + S bits.
      -- 0123456|78901234567
      -- xxxxxxx xxxx0123456|789 <- these bits are the fractional remainder
      -- 0x156 * hscroll_s
      -- 0x156 * (hscroll_s * 2)
      -- 9x9x18 multiplier
      -- Multiply hscroll for both T40 and T80.
      t40_div6_r <= "101010110" * ("0" & hscroll_s);
      t80_div6_r <= "101010110" * (hscroll_s & "0");
      t_ntba_pos_r <= (text_ntba_s & "0000000000") + std_logic_vector(textstart_r);
      t_ctba_pos_r <= (     ctba_s & "000000")     + std_logic_vector(textstart_r);
   end if; end process;


   -- Bitmap Layer registers and calculations.
   --
   -- Byte address determination calculations:
   --
   -- x = current x in bitmap area 0..255
   -- y = current y in bitmap area 0..191
   -- w = width of bitmap in pixels 0..255 = 256,1..255 in width
   -- h = height of bitmap in lines 0..239 = 0..239 in height
   -- wmul = y stride multiplier
   --
   -- wmul = (w+3) / 4 pixels per byte or 64 if w == 0
   -- byte addr offset = (y * wmul) + (x-index / 4)
   -- pixel index in byte = x-index & 0x03

   wmul_zadj_s <= '1' when bml_w = 0 else '0';  -- Force a stride of 64 when bml_w == 0
   wmul9bit_s <= (wmul_zadj_s & bml_w) + 3;     -- w + 3
   wmul_s <= '0' & wmul9bit_s(0 to 6);          -- divide-by-4 and reduce to 8-bit

   -- Bitmap layer active flags.
   -- bml_xcnt_r starts at bml_x and counts down for each x_linebuf_r.  When
   -- it rolls over the MSbit becomes '1' and the current x_linebuf_r is within
   -- a bitmap layer X location.
   -- bml_xloc_r starts at zero and counts the number of bitmap pixels plotted.
   bml_in_x_s <= bml_xcnt_r(0) when (bml_xloc_r < bml_w or bml_w = 0) else '0';
   bml_in_area_s <= bml_in_x_s and bml_in_y_r;

   bml_yline_x <= std_logic_vector(y_pos_r(1 to 8)) - bml_y;
   bml_in_y_x <= '1' when ((y_pos_r >= bml_y) and (bml_yline_r < bml_h)) else '0';

   -- The initial value relies on rescan_start being delayed one VGA clock
   -- cycle after the Y raster value changes.
   bml_addr_x <=
      (bmlba & "000000") + bml_yoff_r(2 to 15) when state_r = ST_IDLE else
      bml_addr_r + 1 when fifo_we_s = '1' else
      bml_addr_r;

   process (clk) begin if rising_edge(clk) then
      -- These calculations MUST BE READY before the prescan_start signal,
      -- which comes at raster_x 1, or about 40ns (4 100MHz cycles) after
      -- the Y raster value changes.
      bml_yline_r <= bml_yline_x;
      bml_in_y_r  <= bml_in_y_x;
      bml_yoff_r  <= bml_yline_r * wmul_s;      -- y_offset from base address, 8x8x16 multiplier
      bml_addr_r  <= bml_addr_x;
   end if; end process;


   -- FIFO Register File as distributed RAM.
   process (clk) begin if rising_edge(clk) then
      if fifo_we_s = '1' then
         -- Input data is always from VRAM.
         fifo(to_integer(fifo_wr_adr_s)) <= vdin;
      end if;
   end if; end process;

   -- Infer distributed RAM by reading asynchronously.
   fifo_dout_s <= fifo(to_integer(fifo_rd_adr_s));

   -- Bitmap Layer FIFO Control
   fifo_wr_adr_s <= fifo_wr_cnt_r(1 to 2);
   fifo_rd_adr_s <= fifo_rd_cnt_r(1 to 2);

   fifo_wr_cnt_x <=
      fifo_wr_cnt_r + 1 when fifo_we_s = '1' and fifo_full_s = '0' else
      fifo_wr_cnt_r;

   -- The MSbits of the counters are used to determine if the write counter has
   -- caught up to the read counter.
   fifo_full_s <=
      '1' when fifo_rd_cnt_r(0) /= fifo_wr_cnt_r(0) and fifo_rd_cnt_r(1 to 2) = fifo_wr_cnt_r(1 to 2) else
      '0';

   -- Write enable when in either BML read data state and the FIFO is not full.
   fifo_we_s <=
      '1' when (state_r = ST_ADDR_BML1 or state_r = ST_ADDR_BML2) and fifo_full_s = '0' else
      '0';

   -- No safety on the read.  There will always be data to read!
   fifo_rd_cnt_x <=
      fifo_rd_cnt_r + 1 when fifo_re_r = '1' else
      fifo_rd_cnt_r;

   -- Bitmap Layer FIFO FSM
   process (clk) begin if rising_edge(clk) then
      -- !! MUST BE A SINGLE TICK !!
      if trig_start_r = '1' then
         fifo_wr_cnt_r <= (others => '0');
         fifo_rd_cnt_r <= (others => '0');
      else
         fifo_wr_cnt_r <= fifo_wr_cnt_x;
         fifo_rd_cnt_r <= fifo_rd_cnt_x;
      end if;
   end if;
   end process;


   -- Trigger controller.
   -- Waits for the prescan_start signal from the counters, as well
   -- as re-triggering the tile scan for the second tile layer.

   process (trig_r, state_r, done_r, layer_sel_r, bml_en_r, sprite_en_r,
   prescan_r, prescan_start, bml_en, t2_en)
   begin

      trig_x         <= trig_r;
      trig_start_x   <= '0';              -- Single tick, edge detect for FIFO reset
      layer_sel_x    <= layer_sel_r;
      bml_en_x       <= bml_en_r;
      sprite_en_x    <= sprite_en_r;

      case trig_r is

      when TRIG_IDLE =>

         -- If TL2 is disabled, then this state is never changed.
         trig_start_x   <= prescan_start and not prescan_r;
         layer_sel_x    <= '0';           -- Start with tile layer 1.
         bml_en_x       <= bml_en;        -- BML is only active with tile layer 1.
         sprite_en_x    <= '1';           -- Sprite start can be enabled after tile layer 1.

         -- If TL2 is enabled, initiate a TL1 / TL2 scan sequence via
         -- the other two states.
         if prescan_start = '1' and t2_en = '1'  then
            trig_x <= TRIG_WAIT;
            sprite_en_x <= '0';           -- Hold sprite enable until after tile layer 2.
         end if;

      when TRIG_WAIT =>

         -- Wait for the single-tick done signal from the tile scan which comes
         -- during the end of the expansion state.
         if done_r = '1' then
            -- If this was the end of the first tile layer, set up for the second
            -- tile layer scan.
            if layer_sel_r = '0' then
               trig_x <= TRIG_RESTART;
               layer_sel_x <= '1';     -- Select the second tile layer.
               bml_en_x <= '0';        -- BML is not active on the second scan.
            else
               trig_x <= TRIG_IDLE;
            end if;
         end if;

      when TRIG_RESTART =>

         -- Wait until the addressing FSM goes idle before triggering the second
         -- tile layer scan, then go back to wait for the scan to finish.
         if state_r = ST_IDLE then
            trig_x <= TRIG_WAIT;
            trig_start_x <= '1';
            sprite_en_x <= '1';        -- Enable sprite start to be active after tile layer 2.
         end if;

      end case;
   end process;

   process (clk) begin if rising_edge(clk) then
      if rst_n = '0' then
         trig_r <= TRIG_IDLE;
      else
         trig_r         <= trig_x;
         trig_start_r   <= trig_start_x;
         prescan_r      <= prescan_start;    -- Edge detect the start signal to make a single tick
         layer_sel_r    <= layer_sel_x;
         bml_en_r       <= bml_en_x;
         sprite_en_r    <= sprite_en_x;
      end if;
   end if;
   end process;


   -- Tile Layer
   -- Sequences the addressing of the tile and BML data.

   process (state_r, shift_r, name_r, layer_sel_r, tile_pri_r,
   vpo_r, flip_x_r, y_pix_row_r, trans_r, pal_sel_r, attr_r,
   ptrn1_r, ptrn2_r, ptrn3_r, colr_fg_r, colr_bg_r,
   mcm_fg_r, mcm_bg_r, sprite_en_r, trig_start_r,
   vdin, vdin_s, textmode_r, ecm, pos_attr_i, gmode_r, textfg, textbg, t2_pri_en)
   begin

      -- Register defaults, stay the same unless it is changed.
      state_x        <= state_r;
      vpo_x          <= vpo_r;         -- Y-Flip affects the y-pixel-offset per-tile.
      name_x         <= name_r;
      attr_x         <= attr_r;
      tile_pri_x     <= tile_pri_r;
      flip_x_x       <= flip_x_r;
      trans_x        <= trans_r;
      pal_sel_x      <= pal_sel_r;
      ptrn1_x        <= ptrn1_r;
      ptrn2_x        <= ptrn2_r;
      ptrn3_x        <= ptrn3_r;
      colr_fg_x      <= colr_fg_r;
      colr_bg_x      <= colr_bg_r;
      mcm_fg_x       <= mcm_fg_r;
      mcm_bg_x       <= mcm_bg_r;

      -- Combinatorial defaults
      flip_x_sel <= '0';
      tile_active <= '1';                 -- VRAM tile / sprite selector
      sprite_start <= '0';


      case state_r is

      when ST_IDLE =>

         tile_active    <= '0';           -- Tile vs. sprite VRAM mux select.

         if trig_start_r = '1' then
            state_x <= ST_SETUP;
            tile_active <= '1';
         end if;

      -- The addressing state order is important, as is the amount of time it takes
      -- which must be more than seven cycles to allow the tile expansion to complete.
      --
      -- The first BML state allows the name_r register to become valid because it
      -- is used in the subsequent attribute and pattern addresses.
      --
      -- The second BML state allows the Y-flip bit to set the vpo_r register before
      -- it is used in the subsequent pattern addresses.

      when ST_SETUP =>
         state_x <= ST_ADDR_NAME;         -- Address the name byte.

      when ST_ADDR_NAME =>
         state_x <= ST_ADDR_BML1;         -- Address the 1st bitmap layer byte.
         name_x <= vdin;                  -- Save the name byte.

      when ST_ADDR_BML1 =>
         state_x <= ST_ADDR_ATTR;         -- Address the attribute byte.

      when ST_ADDR_ATTR =>
         state_x <= ST_ADDR_BML2;         -- Address the 2nd bitmap layer byte.

         -- Save the tile attributes used during expansion until they can be safely
         -- updated, i.e. once tile expansion is complete.
         -- | PRI | FLIP X | FLIP Y | TRANS | PS0 .. PS3 |
         attr_x <= vdin;

         if ecm > 0 then                  -- Only use attribute byte in ECMs.
            flip_x_x <= vdin(1);          -- '1' to flip the X.
         else
            flip_x_x <= '0';
         end if;

         -- No Y-Flip in ECM0, otherwise the Y-Flip bit of the attribute byte
         -- determines the Y pixel row within the tile.
         if ecm = 0 or vdin(2) = '0' then
            vpo_x <= std_logic_vector(y_pix_row_r(6 to 8));
         else
            vpo_x <= (not std_logic_vector(y_pix_row_r(6 to 8)));
         end if;

      when ST_ADDR_BML2 =>
         state_x <= ST_ADDR_PTRN1;        -- Address the 1st pattern byte.

      when ST_ADDR_PTRN1 =>
         state_x <= ST_ADDR_PTRN2;        -- Address the 2nd pattern byte.
         flip_x_sel <= flip_x_r;

         -- In Multicolor mode, each nibble of the pattern *is* the color
         -- index for that 4x4 "pixel".  Set the pattern bits so half
         -- of the pattern uses the foreground color, and the other half
         -- uses the background color.  The real pattern, which contains
         -- the color indexes, will be loaded in to the foreground and
         -- background color registers below.
         if gmode_r = 2 and ecm = 0 then
            ptrn1_x <= "11110000";
         else
            ptrn1_x <= vdin_s;
         end if;

         -- The pattern is the color for MCM.
         mcm_fg_x <= vdin_s(0 to 3);
         mcm_bg_x <= vdin_s(4 to 7);

      when ST_ADDR_PTRN2 =>
         state_x <= ST_ADDR_PTRN3;        -- Address the 3rd pattern byte.
         flip_x_sel <= flip_x_r;
         ptrn2_x <= vdin_s;

      when ST_ADDR_PTRN3 =>
         state_x <= ST_ADDR_COLR;         -- Address the color byte.
         flip_x_sel <= flip_x_r;
         ptrn3_x <= vdin_s;

      when ST_ADDR_COLR =>
         state_x <= ST_LOAD_SHIFT;

         -- Only use normal colors for non ECM text mode, otherwise text
         -- modes can use enhanced colors too.
         if textmode_r = '1' and ecm = 0 then
            -- If position-based attributes are off in T40/T80 ECM0, use
            -- the default fg/bg colors.
            if pos_attr_i = '0' then
               colr_fg_x <= textfg;
               colr_bg_x <= textbg;
            else
               colr_fg_x <= attr_r(0 to 3);
               colr_bg_x <= attr_r(4 to 7);
            end if;

         -- MCM already set the colors based on the 1st pattern.
         elsif gmode_r = 2 then
            colr_fg_x <= mcm_fg_r;
            colr_bg_x <= mcm_bg_r;
         else
            colr_fg_x <= vdin(0 to 3);
            colr_bg_x <= vdin(4 to 7);
         end if;

         -- Expansion is complete, so these registers can be updated now.
         -- | PRI | FLIP-X | FLIP-Y | TRANS | PS0 .. PS3 |

         if ecm = 0 then
            -- For ECM0 TL2 can be above or below sprites.
            tile_pri_x <= layer_sel_r and (not t2_pri_en);
         else
            -- TL2 for ECM1-3 can optionally have tile vs sprite priority.
            -- t2_pri_en = '0' to have TL2 always on top.
            tile_pri_x  <= attr_r(0) or         -- '1' if tile has priority over sprites.
                           (layer_sel_r and (not t2_pri_en));
         end if;
         trans_x     <= attr_r(3);           -- '1' to set 0-index colors to transparent.
         pal_sel_x   <= attr_r(4 to 7);      -- Tile palette select.

      when ST_LOAD_SHIFT =>

         -- The expansion (shift) FSM starts with the same trigger as this
         -- (the addressing) FSM, but waits until this LOAD state.  At this
         -- time the shift FSM loads the data fetched during this FSM and
         -- starts expanding it into the line buffer while the next set of
         -- tile data is addressed in this FSM.
         -- !! Expansion must be fewer states than the addressing FSM !!
         if shift_r = SHIFT_IDLE then
            state_x <= ST_IDLE;
            sprite_start <= sprite_en_r;
            tile_active <= '0';
         else
            state_x <= ST_SETUP;
         end if;

      end case;
   end process;

   process (clk) begin if rising_edge(clk) then
      if rst_n = '0' then
         state_r <= ST_IDLE;
      else
         state_r        <= state_x;
         vpo_r          <= vpo_x;         -- Y-Flip affects the y-pixel-offset per-tile.
         name_r         <= name_x;
         attr_r         <= attr_x;
         tile_pri_r     <= tile_pri_x;
         flip_x_r       <= flip_x_x;
         trans_r        <= trans_x;
         pal_sel_r      <= pal_sel_x;
         ptrn1_r        <= ptrn1_x;
         ptrn2_r        <= ptrn2_x;
         ptrn3_r        <= ptrn3_x;
         colr_fg_r      <= colr_fg_x;
         colr_bg_r      <= colr_bg_x;
         mcm_fg_r       <= mcm_fg_x;
         mcm_bg_r       <= mcm_bg_x;
      end if;
   end if;
   end process;


   -- Pattern shift registers.
   -- This FSM expands the tile and BML pixels into the line buffer.
   -- !! Expansion must be fewer states than the addressing FSM !!
   process (shift_r, state_r, done_r, x_linebuf_r, pixcnt_r, hto_r, hpo_r, hto_s, trig_start_r,
   ptrn1_r, ptrn2_r, ptrn3_r, p1_r, p2_r, p3_r, ntba_s, hscroll_s, hsize_s,
   x_expand_max_r, x_pixel_max, textstart_r, textpos_r, text_ntba_s, textattr_r, ctba_s,
   t_ntba_pos_r, t_horz_off_s, t_ctba_pos_r, texttile_r, text_cmax_s, textmode_r, text_hpo_s)
   begin

      shift_x        <= shift_r;
      done_x         <= done_r;
      textpos_x      <= textpos_r;
      textattr_x     <= textattr_r;
      texttile_x     <= texttile_r;
      x_linebuf_x    <= x_linebuf_r;
      pixcnt_x       <= pixcnt_r;
      hto_x          <= hto_r;
      hpo_x          <= hpo_r;
      p1_x           <= p1_r;
      p2_x           <= p2_r;
      p3_x           <= p3_r;

      -- Combinatorial defaults
      we_s <= '0';
      hto_s <= hto_r + 1;

      case shift_r is
      when SHIFT_IDLE =>

         done_x <= '0';

         -- Always scan the same number of pixels.
         x_linebuf_x <= (others => '0');

         -- Add the horizontal scroll to the calculated start position which
         -- already incorporates the vertical offset.
         --textpos_x <= std_logic_vector(textstart_r) + (text_ntba_s & "00000" & hscroll_s(0 to 4));
         --textattr_x <= std_logic_vector(textstart_r) + (ctba_s & "00000" & hscroll_s(0 to 4));
         textpos_x  <= t_ntba_pos_r + ("0000000" & t_horz_off_s);
         textattr_x <= t_ctba_pos_r + ("0000000" & t_horz_off_s);
         texttile_x <= t_horz_off_s;

         -- Start at the scroll pixel offset.
         hto_x <= ntba_s(3) & hscroll_s(0 to 4);
         hpo_x <= unsigned(hscroll_s(5 to 7));
         if textmode_r = '1' then
            hpo_x <= unsigned(text_hpo_s);
         end if;

         if trig_start_r = '1' then
            shift_x <= SHIFT_LOAD;
         end if;

      when SHIFT_LOAD =>

         -- Wait for the addressing FSM to trigger a load.
         -- !! Expansion must be fewer states than the addressing FSM !!
         pixcnt_x <= 0;
         if state_r = ST_LOAD_SHIFT then
            shift_x <= SHIFT_EXPAND;
            p1_x <= ptrn1_r;
            p2_x <= ptrn2_r;
            p3_x <= ptrn3_r;

            -- Text modes do not support the page size bits.
            if texttile_r = text_cmax_s then
               textpos_x  <= t_ntba_pos_r;
               textattr_x <= t_ctba_pos_r;
               texttile_x <= "0000000";
            else
               textpos_x  <= textpos_r + 1;
               textattr_x <= textattr_r + 1;
               texttile_x <= texttile_r + 1;
            end if;

            -- Tile count is based on page size.
            if hsize_s = '0' then
               hto_x <= ntba_s(3) & hto_s(1 to 5);
            else
               hto_x <= hto_s;
            end if;
         end if;

      when SHIFT_EXPAND =>

         p1_x <= p1_r(1 to 7) & '1';
         p2_x <= p2_r(1 to 7) & '1';
         p3_x <= p3_r(1 to 7) & '1';

         -- Signal when done with the whole tile row.
         if x_linebuf_r = x_pixel_max then
            done_x <= '1';
         end if;

         if done_r = '1' then
            shift_x <= SHIFT_IDLE;
         else
            -- It the tile is done, wait for the next load signal.
            if pixcnt_r = x_expand_max_r then
               shift_x <= SHIFT_LOAD;
            end if;

            pixcnt_x <= pixcnt_r + 1;

            -- The first tile may be partial due to scrolling, so shift
            -- without writing to the line buffer until the pixel offset
            -- is normalized to a tile offset.
            if hpo_r = 0 then
               we_s <= '1';
               x_linebuf_x <= x_linebuf_r + 1;
            else
               hpo_x <= hpo_r - 1;
            end if;
         end if;

      end case;
   end process;

   process (clk) begin if rising_edge(clk) then
      if rst_n = '0' then
         shift_r <= SHIFT_IDLE;
      else
         shift_r        <= shift_x;
         done_r         <= done_x;
         textpos_r      <= textpos_x;
         textattr_r     <= textattr_x;
         texttile_r     <= texttile_x;
         x_linebuf_r    <= x_linebuf_x;
         pixcnt_r       <= pixcnt_x;
         hto_r          <= hto_x;
         hpo_r          <= hpo_x;
         p1_r           <= p1_x;
         p2_r           <= p2_x;
         p3_r           <= p3_x;
      end if;
   end if;
   end process;


   -- Bitmap Layer shift register.
   process (bml_state_r, state_r, shift_r, shift_x, bml_shift_r, bml_xloc_r, bml_xcnt_r, bml_cnt_en_r, fifo_re_r,
   fifo_dout_s, bml_in_area_s, mode256_r, bml_x, we_s, bml_fat_r)
   begin

      bml_state_x    <= bml_state_r;
      bml_shift_x    <= bml_shift_r;      -- 2-bpp shift register
      bml_fat_x      <= bml_fat_r;        -- 4-bpp fat pixel shift register
      bml_xloc_x     <= bml_xloc_r;       -- X pixels drawn
      bml_xcnt_x     <= bml_xcnt_r;       -- Count down X coordinate
      bml_cnt_en_x   <= bml_cnt_en_r;
      fifo_re_x      <= '0';              -- Single tick FIFO read enable


      case bml_state_r is
      when SHIFT_IDLE =>

         bml_xloc_x <= x"00";             -- Number of X pixels drawn.
         bml_xcnt_x <= ('0' & bml_x);     -- Count down the X coordinate to begin expansion.
         bml_cnt_en_x <= mode256_r;       -- Keep the BML on a fat-pixel grid no matter the mode.

         -- Wait for the FIFO to receive at least one byte of data.
         -- The addressing FSM has been triggered and the expansion FSM
         -- is waiting for a load signal.
         if state_r = ST_ADDR_BML2 and shift_x /= SHIFT_IDLE then
            bml_state_x <= SHIFT_LOAD;
         end if;

      when SHIFT_LOAD =>

         bml_state_x <= SHIFT_EXPAND;
         bml_shift_x <= fifo_dout_s;
         bml_fat_x <= fifo_dout_s;
         fifo_re_x <= '1';
         bml_xcnt_x <= bml_xcnt_r - 1;

      when SHIFT_EXPAND =>

         -- Done when the shift FSM goes idle.
         if shift_x = SHIFT_IDLE then
            bml_state_x <= SHIFT_IDLE;

         -- Only expand the bitmap layer when the tile pixels are expanding.
         elsif shift_r = SHIFT_EXPAND and we_s = '1' then
            -- Double the bitmap when in text2 mode to keep it 0-255 over the whole screen
            -- instead of repeating.  This will toggle bml_cnt_en if mode256_r is '0', which
            -- is only true for modes >= 9.
            bml_cnt_en_x <= mode256_r or not bml_cnt_en_r;

            -- Counting down keeps the MSbit a '0' until bml_x number of counts, then it
            -- will wrap around and the MSbit will become '1' and enable bml_in_area_s
            -- if the y-location is also in range.
            if bml_cnt_en_r = '1' then
               bml_xcnt_x <= bml_xcnt_r - 1;
            end if;

            if bml_in_area_s = '1' and bml_cnt_en_r = '1' then
               -- When the pixel location is "00" load the data, otherwise shift
               -- the next pixel pair.  bml_xloc counts the width.
               bml_xloc_x <= bml_xloc_r + 1;
               bml_shift_x <= bml_shift_r(2 to 7) & "11";

               -- Fat pixels shift every other BML pixel.
               if bml_xloc_r(6 to 7) = "01" then
                  bml_fat_x <= bml_fat_r(4 to 7) & "1111";
               end if;

               if bml_xloc_r(6 to 7) = "11" then
                  bml_shift_x <= fifo_dout_s;
                  bml_fat_x <= fifo_dout_s;
                  fifo_re_x <= '1';
               end if;
            end if;
         end if;

      end case;
   end process;

   process (clk) begin if rising_edge(clk) then
      if rst_n = '0' then
         bml_state_r <= SHIFT_IDLE;
      else
         bml_state_r    <= bml_state_x;
         fifo_re_r      <= fifo_re_x;
         bml_shift_r    <= bml_shift_x;
         bml_fat_r      <= bml_fat_x;
         bml_xloc_r     <= bml_xloc_x;
         bml_xcnt_r     <= bml_xcnt_x;
         bml_cnt_en_r   <= bml_cnt_en_x;
      end if;
   end if;
   end process;

end rtl;
