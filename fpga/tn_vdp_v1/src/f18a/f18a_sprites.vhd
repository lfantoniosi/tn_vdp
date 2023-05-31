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

-- Implements sprites.  This module really needs to be rewritten for clarity
-- and better organization (similar to the tile module).  It could also use
-- the same line-buffer as the tile module since their FSMs run sequentially,
-- and that would save a 2K block-RAM.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_sprites is
   port (
      clk            : in  std_logic;
      rst_n          : in  std_logic;
      x_sprt_pos     : in  unsigned(0 to 7);
      y_sprt_pos     : in  unsigned(0 to 7);
      y_next_in      : in  unsigned(0 to 8);
      y_margin_n     : in  std_logic;
      prescan_start  : in  std_logic;
      sprite_start   : in  std_logic;
      sprite_max     : in  unsigned(0 to 4);
      stop_sprt      : in  unsigned(0 to 5);          -- stop sprite to limit sprite processing
   -- Table base addresses
      size_bit       : in  std_logic;
      mag_bit        : in  std_logic;
      satba          : in  std_logic_vector(0 to 6);
      spgba          : in  std_logic_vector(0 to 2);
      gmode          : in  unsigned(0 to 3);
   -- F18A specific
      unlocked       : in  std_logic;                 -- '1' when enhanced registers are unlocked
      row30          : in  std_logic;                 -- 1 when 30 rows
      spgsize_i      : in  std_logic_vector(0 to 1);  -- Sprite pattern generator size offset
      sprt_ps        : in  std_logic_vector(0 to 1);  -- sprite palette select for normal mode
      ecm            : in  unsigned(0 to 1);          -- enhanced color mode
   -- VRAM Interface
      vdin           : in  std_logic_vector(0 to 7);
      vaddr          : out std_logic_vector(0 to 13);
   -- Outputs
      sprt_color     : out std_logic_vector(0 to 7);
      sprt_cf        : out std_logic;
      sprt_5s        : out std_logic;
      sprt_5th       : out std_logic_vector(0 to 4);
      reportmax_i    : in  std_logic
   );
end f18a_sprites;

architecture rtl of f18a_sprites is

   -- The sprite line buffers are 512 pixels by 9-bits per pixel.
   constant ADDR_WIDTH : integer := 9;
   constant DATA_WIDTH : integer := 9;

   type sprite_line_buffer is array (0 to 2**ADDR_WIDTH-1) of
      std_logic_vector (0 to DATA_WIDTH-1);
   signal linebuf1: sprite_line_buffer;
   signal linebuf2: sprite_line_buffer;

   -- Same data for both buffers since only 1 is written to at a time.
   signal din     : std_logic_vector(0 to DATA_WIDTH - 1);

   signal we1     : std_logic;
   signal addr1a  : std_logic_vector(0 to ADDR_WIDTH - 1);
   signal dout1a  : std_logic_vector(0 to DATA_WIDTH - 1);
   signal addr1b  : std_logic_vector(0 to ADDR_WIDTH - 1);
   signal dout1b  : std_logic_vector(0 to DATA_WIDTH - 1);

   signal we2     : std_logic;
   signal addr2a  : std_logic_vector(0 to ADDR_WIDTH - 1);
   signal dout2a  : std_logic_vector(0 to DATA_WIDTH - 1);
   signal addr2b  : std_logic_vector(0 to ADDR_WIDTH - 1);
   signal dout2b  : std_logic_vector(0 to DATA_WIDTH - 1);

   type state_sprite_type is (
      st_idle, st_clear, st_setup,
      st_sat_tag,
      st_sat_y, st_sat_name,
      st_sat_x, st_ptrn_setup,
      st_ptrn1a, st_ptrn1b,
      st_ptrn2a, st_ptrn2b,
      st_ptrn3a, st_ptrn3b,
      st_pre_expand, st_expand,
      st_next);
   signal sprt_state : state_sprite_type;

   -- Sprite addressing and selection
   signal sp_size       : std_logic_vector(0 to 7);   -- sprite size in pixels: 7, 15, or 31
   signal x_expand_max  : unsigned(0 to 3);           -- sprite pattern size: 7(8) or 15(16)
   signal x_expand      : unsigned(0 to 3);           -- current expand shift count
   signal y_range       : std_logic_vector(0 to 7);   -- difference of y_pos - sp_y
   signal vpo8          : std_logic_vector(0 to 2);   -- vert pixel offset 8x8, selected normal or flipped
   signal vpo8m         : std_logic_vector(0 to 2);   -- vert pixel offset 8x8 mag, selected normal or flipped
   signal vpo16         : std_logic_vector(0 to 3);   -- vert pixel offset 16x16, selected normal or flipped
   signal vpo16m        : std_logic_vector(0 to 3);   -- vert pixel offset 16x16 mag, selected normal or flipped

   -- Sprite x and y resolution.
   signal sp_x_9bit     : unsigned(0 to 8);
   signal sp_real_x     : unsigned(0 to 8);

   signal sp_y          : unsigned(0 to 7);
   signal y_next        : unsigned(0 to 8);           -- register y_next_in

   signal sp_x_valid    : std_logic;

   signal report5th_r, report5th_s : std_logic;
   signal in_range      : std_logic;                  -- the sprite is part of the current scan line
   signal hit_sprite_max: std_logic;                  -- the sprite max limit is reached
   signal stop_byte     : std_logic;                  -- a sprite list stop byte is found
   signal sprt_5s_flag  : std_logic;                  -- spnum contains the max sprite
   signal sp_tag_size   : std_logic;                  -- sprite specific size from tag byte
   signal sp_flip_x     : std_logic;
   signal sp_flip_y     : std_logic;

   signal vram_mux_sel  : std_logic;
   signal ptrn_byte_sel : std_logic;
   signal sp_att_byte   : std_logic_vector(0 to 1);
   signal ptrn_mux      : std_logic_vector(0 to 3);
   signal name_mux      : std_logic_vector(0 to 6);
   signal spgba_sel     : std_logic_vector(0 to 5);
   signal ptrn2ba       : std_logic_vector(0 to 5);
   signal ptrn3ba       : std_logic_vector(0 to 5);
   signal spgoffset_s   : std_logic_vector(0 to 3);   -- ECM2/3 pattern table offset size
   signal spnum         : unsigned(0 to 4);           -- sprite number counter
   signal active_cnt    : unsigned(0 to 4);           -- track sprites on a line: 0 to 31 counter

   -- Current sprite attributes
   signal sp_x          : unsigned(0 to 8);           -- sprite x / line expand buffer address
   signal sp_name       : std_logic_vector(0 to 7);   -- sprite name
   signal sp_color      : std_logic_vector(0 to 3);   -- sprite color
   signal sp_ecb        : std_logic;                  -- sprite early clock bit

   -- Pattern expansion
   signal ptrn          : std_logic_vector(0 to 15);  -- sprite pattern to expand
   signal ptrn2         : std_logic_vector(0 to 15);  -- sprite pattern to expand
   signal ptrn3         : std_logic_vector(0 to 15);  -- sprite pattern to expand
   signal mag_reg       : std_logic;                  -- copy of mag_bit from VDP register
   signal shift_en      : std_logic;                  -- shift enable for magnification

   signal ptrn_mux_sel  : std_logic_vector(0 to 1);
   signal size_sel_bit  : std_logic;

   signal x_read_addr   : unsigned(0 to 8);           -- read ahead address
   signal ra_ispix      : std_logic;                  -- read ahead sprite pixel valid color
   signal ra_cnbit      : std_logic;                  -- read ahead collision bit
   signal ra_data       : std_logic_vector(0 to 7);   -- read ahead data

   signal cnbit         : std_logic;                  -- sprite pixel collision detect
   signal ispix         : std_logic;                  -- if current sprite pixel is visible
   signal pixbit        : std_logic;                  -- if the current pattern makes a non-zero
   signal cf            : std_logic;                  -- collision flag

   -- Pixel expansion color selection
   signal pixidx  : unsigned(0 to 3);
   signal pix0    : std_logic;
   signal pix1    : std_logic;
   signal pix2    : std_logic;

   signal x_disp_addr : unsigned(0 to 8);             -- output buffer x displacement +32

   -- Buffer write and clear enable
   signal we            : std_logic;
   signal clear_en      : std_logic;
   signal allowed       : std_logic;                  -- if sprites are allowed

begin

   -- Line buffer 1
   process (clk)
   begin
      if rising_edge(clk) then
         dout1a <= linebuf1(to_integer(unsigned(addr1a)));
         dout1b <= linebuf1(to_integer(unsigned(addr1b)));
         if we1 = '1' then
            linebuf1(to_integer(unsigned(addr1a))) <= din;
         end if;
      end if;
   end process;


   -- Line buffer 2
   process (clk)
   begin
      if rising_edge(clk) then
         dout2a <= linebuf2(to_integer(unsigned(addr2a)));
         dout2b <= linebuf2(to_integer(unsigned(addr2b)));
         if we2 = '1' then
            linebuf2(to_integer(unsigned(addr2a))) <= din;
         end if;
      end if;
   end process;

   -- Sprites are not allowed in text modes when the F18A is locked.
   allowed <= '0' when ((gmode = 1 or gmode = 9) and unlocked = '0') else '1';


   -- Sprites can specify to use the VR1 "global" size bit, or specify
   -- the sprite will be 16x16.  A 0 in the sprite's SIZE bit of the tag
   -- field means "use the VR1 setting", which is 0 for 8x8, and 1 for 16x16.
   -- A 1 in the SIZE bit means the sprite is 16x16.
   size_sel_bit <= size_bit when unlocked = '0' or sp_tag_size = '0' else '1';


   -- size mag value
   --   0   0   8x8
   --   0   1   16x16 mag(8x8)
   --   1   0   16x16
   --   1   1   32x32 mag(16x16)
   sp_size <=
      x"07" when size_sel_bit = '0' and mag_bit = '0' else  -- 07
      x"1F" when size_sel_bit = '1' and mag_bit = '1' else  -- 31
      x"0F";                                                -- 15

   -- Expansion maximum size mux
   x_expand_max <= x"7" when size_sel_bit = '0' else x"F";


   -- Real X location for the sprite based on early clock.
   -- The sprite buffer is offset by 32 to make ECB adjustment easier.  So, an
   -- x value of 0 is really 32, hence the +32 to the x value when ECB is NOT active.
   sp_real_x <= sp_x_9bit when sp_ecb = '1' else sp_x_9bit + 32;

   -- Valid pixel range in the buffer is 32..287 (255 pixels)
   sp_x_valid <= '1' when sp_x > 31 and sp_x < 288 else '0';

   -- In range comparator, allow two clocks before using in
   -- read sprite x state
   in_range <= '1' when y_range <= sp_size else '0';

   -- Sprite maximum reached indicator
   hit_sprite_max <=
      in_range when active_cnt = sprite_max and sprite_max /= 31 else '0';

   -- Report the 5th sprite for legacy support when enabled (default).  This
   -- will not stop the processing of sprites.  Fixes problem with software
   -- that use the 5th sprite flag and sprite numbers in the status register
   -- for scan line detection.
   -- Testing against 5 instead of 4 since active_cnt is incremented before
   -- report5th_s is registered for it's single-tick notification.
   report5th_s <= (not reportmax_i) when active_cnt = 5 else '0';

   -- Stop processing if an end of sprite list byte is found.
   -- The stop byte is only active when the ROW30 flag is '0'.  To limit sprites
   -- when the ROW30 flag is enabled, VR51 (stop sprite) must be used.  VR51 is
   -- always active and can be used instead of the original >D0 stop byte in the
   -- sprite Y-location.  Only VR51 values 0..31 are considered, and values from
   -- 32..63 are treated as 32.
   stop_byte <= '1' when
      (vdin = x"D0" and row30 = '0') or (stop_sprt(0) = '0' and spnum = stop_sprt(1 to 5)) else
      '0';


   -- 8x8 sprite
   --  0 1 2 3 4 5 6 7 8 9 10 11 12 13
   -- |SPGT |
   --       |  SPRITE NAME   |
   --              x x x x x |  ROW   |
   --                x x x x |  ROW   | x

   -- 16x16 sprite, 1st byte
   --  0 1 2 3 4 5 6 7 8 9 10 11 12 13
   -- |SPGT |
   --       |SPRITE NAME|x x
   --                   |0|
   --              x x x x|    ROW    |
   --                x x x|    ROW    | x

   -- 16x16 sprite, 2nd byte
   --  0 1 2 3 4 5 6 7 8 9 10 11 12 13
   -- |SPGT |
   --       |SPRITE NAME|x x
   --                   |1|
   --              x x x x|    ROW    |
   --                x x x|    ROW    | x

   --  0 1 2 3 4 5 6 7 8 9 10 11 12 13
   -- |     SAT     | SP# 0-31  | byte|
   --

   -- Sprite Attribute Table
   --
   -- |                  VERTICAL              | 00 - Y
   -- |                 HORIZONTAL             | 01 - X
   -- |                   NAME                 | 10 - Name
   -- | ECB | FLIP X | FLIP Y | SIZE | COL3..0 | 11 - Tag
   -- | ECB | FLIP X | FLIP Y | SIZE | PAL3..0 | 11 ECM > 0

   --  0 1 2 3 4 5 6 7 8 9 10 11 12 13
   -- |   SAT + 1   |0 0| SP# 0 - 31  | Link table follows the SAT which is 128 bytes

   --    0    1    2    3    4    5    6    7
   -- |  X |  X |LINK|        PARENT          |


   -- VRAM Interface mux
   vaddr <=
      satba & std_logic_vector(spnum) & sp_att_byte when vram_mux_sel = '0' else
      spgba_sel & name_mux(3 to 6) & ptrn_mux;


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
   process (spgsize_i) begin
   case spgsize_i is
      when "00" => spgoffset_s <= "1000";
      when "01" => spgoffset_s <= "0100";
      when "10" => spgoffset_s <= "0010";
      when "11" => spgoffset_s <= "0001";
      when others => null;
   end case; end process;

   ptrn2ba <= (spgba & name_mux(0 to 2)) + ("00" & spgoffset_s);
   ptrn3ba <= (spgba & name_mux(0 to 2)) + ("0" & spgoffset_s & "0");

   -- The 8th name bit for 8x8 sprites is in the pattern mux below.
   name_mux <=
      sp_name(0 to 6) when size_sel_bit = '0' else
      sp_name(0 to 5) & ptrn_byte_sel;

   -- Vertical addressing based on ECM and sprite y flip bit
   vpo8     <= y_range(5 to 7) when unlocked = '0' or sp_flip_y = '0' else not y_range(5 to 7);
   vpo8m    <= y_range(4 to 6) when unlocked = '0' or sp_flip_y = '0' else not y_range(4 to 6);
   vpo16    <= y_range(4 to 7) when unlocked = '0' or sp_flip_y = '0' else not y_range(4 to 7);
   vpo16m   <= y_range(3 to 6) when unlocked = '0' or sp_flip_y = '0' else not y_range(3 to 6);

   -- Pattern address mux for the 4 possible sprite sizes: 8x8, 8x8 mag, 16x16, 16x16 mag
   ptrn_mux_sel <= size_sel_bit & mag_bit;
   process (ptrn_mux_sel, sp_name, vpo8, vpo8m, vpo16, vpo16m)
   begin
      case ptrn_mux_sel is
      when   "00" => ptrn_mux <= sp_name(7) & vpo8;  -- 8x8
      when   "01" => ptrn_mux <= sp_name(7) & vpo8m; -- 8x8 mag
      when   "10" => ptrn_mux <= vpo16;  -- 16x16
      when   "11" => ptrn_mux <= vpo16m; -- 16x16 mag
      when others => null;
      end case;
   end process;


   -- Sprites
   process (clk)
   begin
      if rising_edge(clk) then
      if rst_n = '0' then
         sprt_state <= st_idle;
      else

         -- Single cycle flags.
         we <= '0';              -- write enable, active high
         clear_en <= '0';        -- 1 when clearing the off-line line buffer

         -- tag attribute byte select by default.
         sp_att_byte <= "11";    -- tag (y, x, name, tag)

         vram_mux_sel <= '0';    -- default to reading the sprite attribute table
         ptrn_byte_sel <= '0';   -- 1st or 2nd byte for 16x16 sprites
         sprt_5s_flag <= '0';
         report5th_r <= '0';

         case sprt_state is

         when st_idle =>

            spnum <= (others => '0');
            active_cnt <= (others => '0');
            sprt_5s_flag <= '0';

            if prescan_start = '1' then
               sprt_state <= st_clear;
               sp_x <= (others => '0');
               clear_en <= '1';
               we <= '1';
            elsif sprite_start = '1' and allowed = '1' then
               sprt_state <= st_setup;
            end if;

         -- Clear the off-line buffer prior to use.  This happens while the
         -- tiles are being expanded since the sprites need access to VRAM
         -- which is currently being accessed by the tile FSM.
         when st_clear =>

            we <= '1';
            clear_en <= '1';

            if sp_x < 290 then
               sp_x <= sp_x + 1;
            else
               sprt_state <= st_idle;
            end if;

         -- Sprite processing loop

         -- tag (needed to set x final location, sprite size, and y in-range determination)
         -- y pos
         -- name (needed to read patterns, know here if in horz range)
         -- x pos
         -- pattern address setup
         -- p1a (normal and ecm 1)
         -- p1b
         -- p2a (ecm 4-color)
         -- p2b
         -- p3a (ecm 8-color)
         -- p3b
         -- pre-expansion
         -- expansion - 8 to 16 clocks
         -- next sprite

         when st_setup =>

            sprt_state <= st_sat_tag;

            -- spnum was changed in last state (idle or next loop)
            -- tag byte from SAT is being addressed
            -- no data ready

            -- y attribute byte select during next state
            sp_att_byte <= "00"; -- y (y, x, name, tag)

            -- tag byte from SAT is being addressed
            -- current data is link byte

            -- save the sprite parent number and link bit

            -- parent tag attribute addressing during next state

         when st_sat_tag =>

            sprt_state <= st_sat_y;

            -- y byte from SAT is being addressed
            -- current data is tag byte

            -- save the tag data
            sp_ecb      <= vdin(0);
            sp_flip_x   <= vdin(1);
            sp_flip_y   <= vdin(2);
            sp_tag_size <= vdin(3);
            sp_color    <= vdin(4 to 7);

            -- name attribute byte select during next state
            sp_att_byte <= "10"; -- name (y, x, name, tag)

            -- parent y attribute addressing during next state

         when st_sat_y =>

            sprt_state <= st_sat_name;

            -- name byte from SAT is being addressed
            -- current data is sprite's y byte

            sp_y <= unsigned(vdin);

            -- A >D0 byte or stop-sprite value will stop sprite processing
            if stop_byte = '1' then
               sprt_state <= st_idle;
            end if;

            -- x attribute byte select during next state
            sp_att_byte <= "01"; -- x (y, x, name, tag)

            --sp_y_parent <= unsigned(vdin);

         when st_sat_name =>

            sprt_state <= st_sat_x;

            -- x byte from SAT is being addressed
            -- current data is sprite's name byte

            sp_name <= vdin;
            y_range <= std_logic_vector(y_sprt_pos - sp_y);

            -- Cannot setup address for next state because the sprite
            -- name from this state is required, and that data is being
            -- registered in this state.

         when st_sat_x =>

            sprt_state <= st_ptrn_setup;

            -- nothing being addressed
            -- current data is sprite's x byte

            sp_x_9bit <= unsigned('0' & vdin);

            -- If the sprite is not in range or this sprite would
            -- be displayed but the sprite limit has been reached,
            -- skip the sprite.
            if in_range = '0' or hit_sprite_max = '1' then
               sprt_state <= st_next;
               sprt_5s_flag <= in_range;
            end if;

            -- ptrn1a addressing during next state
            vram_mux_sel <= '1';
            spgba_sel <= spgba & name_mux(0 to 2); -- ptrn1

         when st_ptrn_setup =>

            sprt_state <= st_ptrn1a;

            -- ptrn1a is being addressed
            -- current data is invalid


            -- ptrn1b addressing during next state
            vram_mux_sel <= '1';
            ptrn_byte_sel <= '1'; -- b

         when st_ptrn1a =>

            sprt_state <= st_ptrn1b;

            -- The sprite was in range, so count it.
            active_cnt <= active_cnt + 1;

            -- ptrn1b is being addressed
            -- current data is ptrn1a

            ptrn(0 to 7) <= vdin;

            -- ptrn2a addressing during next state
            vram_mux_sel <= '1';
            spgba_sel <= ptrn2ba; -- ptrn2

         when st_ptrn1b =>

            sprt_state <= st_ptrn2a;

            -- ptrn2a is being addressed
            -- current data is ptrn1b

            ptrn(8 to 15) <= vdin;

            -- set up the x counters
            sp_x        <= sp_real_x;
            x_read_addr <= sp_real_x;

            -- ptrn2b addressing during next state
            vram_mux_sel <= '1';
            ptrn_byte_sel <= '1'; -- b

         when st_ptrn2a =>

            sprt_state <= st_ptrn2b;

            -- ptrn2b is being addressed
            -- current data is ptrn2a

            ptrn2(0 to 7) <= vdin;

            -- ptrn3a addressing during next state
            vram_mux_sel <= '1';
            spgba_sel <= ptrn3ba; -- ptrn3

         when st_ptrn2b =>

            sprt_state <= st_ptrn3a;

            -- ptrn3a is being addressed
            -- current data is ptrn2b

            ptrn2(8 to 15) <= vdin;

            -- ptrn3b addressing during next state
            vram_mux_sel <= '1';
            ptrn_byte_sel <= '1'; -- b

         when st_ptrn3a =>

            sprt_state <= st_ptrn3b;

            -- ptrn3b is being addressed
            -- current data is ptrn3a

            ptrn3(0 to 7) <= vdin;

         when st_ptrn3b =>

            sprt_state <= st_pre_expand;

            -- current data is ptrn3a

            ptrn3(8 to 15) <= vdin;

         when st_pre_expand =>

            sprt_state <= st_expand;

            -- read ahead bits are current

            -- advance the read ahead 1 address in front of the x location.
            x_read_addr <= x_read_addr + 1;

            -- set the write enable based on a valid x location.
            we <= sp_x_valid;

            x_expand <= (others => '0');
            shift_en <= mag_bit;

            -- Keep changes in mag_bit (which comes from a VDP register
            -- and can change at *any* time) from dead-locking the
            -- sprite pixel expansion.
            mag_reg <= mag_bit;

         when st_expand =>

            sprt_state <= st_expand;

            -- Advance the address counters.
            sp_x <= sp_x + 1;
            x_read_addr <= x_read_addr + 1;

            -- Write a pixel only when visible.
            we <= sp_x_valid;

            -- Delay the pattern shift based on the magnification bit.
            if mag_reg = '1' then shift_en <= not shift_en; end if;

            -- Shift next pixel.  x_expand is an index into the pattern registers.
            if x_expand < x_expand_max and shift_en = '0' then
               x_expand <= x_expand + 1;
            end if;

            -- Make sure to expand the last pixel when magnification is on.
            -- shift_en = '0' for the first pixel, so this will force one
            -- more clock cycle in this state.  Also, stop expansion if the
            -- end of the buffer is reached.
            -- 255 + 32 == 287 which is the end of the visible buffer
            if (x_expand = x_expand_max and shift_en = '0') or sp_x = 287 then
               sprt_state <= st_next;
               we <= '0';
               -- If enabled, report that this is the 5th active sprite.
               report5th_r <= report5th_s;
            end if;

         when st_next =>

            -- Always increment the sprite number.
            spnum <= spnum + 1;

            if spnum < 31 and sprt_5s_flag = '0' then
               sprt_state <= st_setup;
            else
               sprt_state <= st_idle;
            end if;

         end case;
      end if;
      end if;
   end process;


   -- The sprite line buffers are 512 pixels by 9-bits per pixel.
   --
   --    0    1     2     3     4     5     6     7     8
   -- | CF | PIX | PCD |      6-bit color address           |
   --
   -- CF  = collision flag.  1 if two sprites collided at this x
   --       location.
   -- PIX = if there is a sprite pixel or not, used to facilitate
   --       transparent pixels.  If PIX = 0 then the sprite
   --       does not have a pixel for this location.  If PIX = 1
   --       then the 6-bit color address is valid.
   -- PCD = pixel collision detection.  1 if the pattern pixel
   --       was other than 0, 00, or 000.  Primarily used for
   --       collision detection in original color mode where the
   --       pattern indicated a pixel or no pixel and did not
   --       have anything to do with the color, which allowed for
   --       a '1' pixel with a transparent color, and could
   --       cause the collision flag to be set based on the pattern
   --       pixel.  In enhanced color modes, the pattern becomes
   --       the color index, so there is no way to have a pixel
   --       index that is a transparent color.  A color of >000
   --       in a palette register will be black, not transparent.
   --
   -- For sprites, an ECM color of "0", "00", or "000" will always
   -- be transparent no matter what the color value is at the
   -- zero-index.


   -- Select the active pixel based on the mode and X flip.
   pixidx <= x_expand when unlocked = '0' or sp_flip_x = '0' else not x_expand;

   -- Get pixel color bit references.
   pix0 <= ptrn(to_integer(pixidx));
   pix1 <= ptrn2(to_integer(pixidx));
   pix2 <= ptrn3(to_integer(pixidx));

   -- pixbit indicates if a pixel exists.  This is necessary in normal
   -- color mode because a transparent sprite can still collide based
   -- on the pattern bits, i.e. the sprite's color has nothing to do
   -- with the collision detection.
   --
   -- pixbit is different from ispix which does take color into consideration.
   pixbit <=
      pix0 or pix1 when ecm = 2 else
      pix0 or pix1 or pix2 when ecm = 3 else
      pix0;

   -- Determine if there is a pixel based on the pattern value and ECM.
   -- Normal mode, if the pattern is 1, but the color is 0 (transparent),
   -- keep the original color.
   -- Other enhanced color modes, a pattern pixel of 1 means a color,
   -- thus a pixel.  Only a 0 bit pattern is transparent in ECMs 1..3.
   ispix <= '0' when (sp_color = "0000" and ecm = 0) else pixbit;


   -- Record if the pixel had a *pattern* bit at the current x location.  This
   -- is independent from the pixel's color in Normal mode (ECM 0).  For the
   -- new ECMs, at least one pattern bit must be 1.  For ECMs > 0, this will be
   -- the same as ispix.
   -- If the collision indicator bit is already set for this x location, keep it.
   cnbit <= pixbit when ra_cnbit = '0' else '1';

   -- Record if two sprites collided at this x pixel.  In normal mode, collision
   -- is based strictly on the pattern pixels and color is not considered.  This
   -- means even a transparent colored sprite can collide if it has any 1 bits in
   -- its pattern.  In ECMs, the color *is* the pattern, so collision depends on
   -- a non zero (0, 00, or 000) color index.
   -- The collision flag is used during line buffer output to only trigger the
   -- status register's collision flag if the sprite was in the visible display
   -- area of the screen.
   cf <= pixbit and ra_cnbit;

   -- ps = palette select
   -- cs = color select
   -- In the ECMs > 0, the sprite's color becomes a palette select and the pattern
   -- bits become the final color selection.
   --
   -- original mode: ps0 ps1 cs0 cs1 cs2 cs3
   -- 1-bit mode   : ps0 cs0 cs1 cs2 cs3 px0
   -- 2-bit mode   : cs0 cs1 cs2 cs3 px1 px0
   -- 3-bit mode   : cs0 cs1 cs2 px2 px1 px0
   process (clear_en, ra_data, ra_ispix, ispix, cnbit, cf,
   ecm, sprt_ps, sp_color, pix0, pix1, pix2)
   begin
      if clear_en = '1' then
         din <= "000000000";
      elsif ra_ispix = '1' then
         din <= cf & ra_data;
      else
      case ecm is
      when "00" => din <= cf & ispix & cnbit & sprt_ps & sp_color;                     -- Original color mode
      when "01" => din <= cf & ispix & cnbit & sprt_ps(0) & sp_color & pix0;           -- 1-bit color
      when "10" => din <= cf & ispix & cnbit & sp_color & pix1 & pix0;                 -- 2-bit color
      when "11" => din <= cf & ispix & cnbit & sp_color(0 to 2) & pix2 & pix1 & pix0;  -- 3-bit color
      when others => null;
      end case;
      end if;
   end process;

   -- Register y_next
   process (clk) begin if rising_edge(clk) then
      y_next <= y_next_in;
   end if; end process;

   -- Read-ahead for sprite processing
   addr1b <= std_logic_vector(x_read_addr);
   addr2b <= std_logic_vector(x_read_addr);

   ra_ispix <= dout1b(1) when y_next(8) = '0' else dout2b(1);
   ra_cnbit <= dout1b(2) when y_next(8) = '0' else dout2b(2);
   ra_data  <= dout1b(1 to 8) when y_next(8) = '0' else dout2b(1 to 8);


   -- When y_next is even, data goes to linebuf1.
   we1 <= (not y_next(8)) and we;
   we2 <= y_next(8) and we;

   -- Line buffer address mux.  A y_next that is odd means the even buffer
   -- (linebuf1) has data to display since it was filled on the even
   -- y_next line.
   x_disp_addr <= unsigned('0' & x_sprt_pos) + 32;

   addr1a <= std_logic_vector(sp_x) when y_next(8) = '0' else
      std_logic_vector(x_disp_addr);
   addr2a <= std_logic_vector(sp_x) when y_next(8) = '1' else
      std_logic_vector(x_disp_addr);

   -- Color index output.
   sprt_color <= dout1a(1 to 8) when y_next(8) = '1' else dout2a(1 to 8);

   -- Coincidence detection is triggered by any sprites with an
   -- overlapping pixel, except those beyond the SAT terminator >D0.
   -- Pixel color does not matter, since a pixel can be set to '1'
   -- but have a transparent color, it will still trigger coincidence.
   -- Sprite coincidence flag

   -- Collision detection must be delayed until the actual output is
   -- being generated because sprites pre-buffer by 1 line.
   sprt_cf <= (dout1a(0) and y_margin_n) when y_next(8) = '1' else (dout2a(0) and y_margin_n);

   -- 5th sprite output
   -- Limit updating the 5s flag to the tile scan lines 0..191 or 0..239.  In the
   -- 9918A sprites are not processed outside of this range, and updating the 5s
   -- flag outside of this range will cause problems for programs using the 5s flag
   -- to watch for specific scan lines.
   sprt_5th <= std_logic_vector(spnum);
   sprt_5s <= ((sprt_5s_flag or report5th_r) and y_margin_n) when sprt_state = st_next else '0';

end rtl;
