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

-- Host system interface (i.e. the interface to the host CPU, hence the poorly
-- chosen module name).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_cpu is
   port (
      clk         : in  std_logic;
      rst_n       : in  std_logic;
      mode        : in  std_logic;
      csw_n       : in  std_logic;
      csr_n       : in  std_logic;
      cd_i        : in  std_logic_vector(0 to 7);
      cd_o        : out std_logic_vector(0 to 7);
      sp_cf       : in  std_logic;
      sp_5s       : in  std_logic;
      sp_5th      : in  std_logic_vector(0 to 4);
      intr_en     : in  std_logic;                    -- interrupt tick
      sp_cf_en    : in  std_logic;
      scanline    : in  unsigned(0 to 7);
      vscanln_en  : out std_logic;                    -- virtual scan line enable
      blank       : in  std_logic;                    -- '1' when blanking (horz and vert) for GPU
   -- VRAM Interface
      vdin        : in  std_logic_vector(0 to 7);
      vwe         : out std_logic;
      vaddr       : out std_logic_vector(0 to 13);
      vdout       : out std_logic_vector(0 to 7);
   -- PRAM Interface
      pwe         : out std_logic;
      paddr       : out std_logic_vector(0 to 5);
      pdout       : out std_logic_vector(0 to 11);
      pdin        : in  std_logic_vector(0 to 11);    -- color in for the GPU
   -- Outputs
      intr_n      : out std_logic;                    -- interrupt output to physical pin, active low
      gmode       : out unsigned(0 to 3);
      soft_blank  : out std_logic;
      size_bit    : out std_logic;
      mag_bit     : out std_logic;
      pgba        : out std_logic_vector(0 to 2);
      satba       : out std_logic_vector(0 to 6);
      spgba       : out std_logic_vector(0 to 2);
      textfg      : out std_logic_vector(0 to 3);
      textbg      : out std_logic_vector(0 to 3);
   -- F18A specific registers
      unlocked    : out std_logic;                    -- '1' when enhanced registers are unlocked
      row30       : out std_logic;
      tl1_off_o   : out std_logic;                    -- '1' when tile layer 1 is disabled
      pos_attr_o  : out std_logic;                    -- '1' to use position-based tile attributes
      tpgsize_o   : out std_logic_vector(0 to 1);     -- tile pattern table offset size
      spgsize_o   : out std_logic_vector(0 to 1);     -- sprite pattern table offset size
      tile_ecm    : out unsigned(0 to 1);
      sprt_ecm    : out unsigned(0 to 1);
      tile_ps     : out std_logic_vector(0 to 3);     -- T2PS[0..1] T1PS[2..3]
      sprt_ps     : out std_logic_vector(0 to 1);
      sprt_yreal  : out std_logic;
   -- Sprite max
      usr_sprite_max : in  std_logic_vector(0 to 4);  -- Jumper setting, used at reset
      sprite_max     : out unsigned(0 to 4);          -- Register setting overrides jumper
      stop_sprt      : out unsigned(0 to 5);          -- Stop Sprite to limit sprite processing
      reportmax_o    : out std_logic;
   -- Scroll support
      t1ntba      : out std_logic_vector(0 to 3);     -- tile1 name table base address
      t1ctba      : out std_logic_vector(0 to 7);     -- tile1 color table base address
      t1hsize     : out std_logic;                    -- tile1 horz page size (1 page or 2 pages)
      t1vsize     : out std_logic;                    -- tile1 vert page size (1 page or 2 pages)
      t1horz      : out std_logic_vector(0 to 7);     -- tile1 horz scroll
      t1vert      : out std_logic_vector(0 to 7);     -- tile1 vert scroll
      t2_en       : out std_logic;                    -- tile2 enable
      t2_pri_en   : out std_logic;                    -- tile2 priority enable (0 = TL2 always on top)
      t2ntba      : out std_logic_vector(0 to 3);     -- tile2 name table base address
      t2ctba      : out std_logic_vector(0 to 7);     -- tile2 color table base address
      t2hsize     : out std_logic;                    -- tile2 horz page size (1 page or 2 pages)
      t2vsize     : out std_logic;                    -- tile2 vert page size (1 page or 2 pages)
      t2horz      : out std_logic_vector(0 to 7);     -- tile2 horz scroll
      t2vert      : out std_logic_vector(0 to 7);     -- tile2 vert scroll

   -- Bitmap layer
      bmlba       : out std_logic_vector(0 to 7);     -- bitmap layer base address
      bml_x       : out std_logic_vector(0 to 7);
      bml_y       : out std_logic_vector(0 to 7);
      bml_w       : out std_logic_vector(0 to 7);
      bml_h       : out std_logic_vector(0 to 7);
      bml_ps      : out std_logic_vector(0 to 3);     -- bitmap layer palette select
      bml_en      : out std_logic;                    -- '1' to enable the bitmap layer
      bml_pri     : out std_logic;                    -- '1' when bitmap has priority over tiles
      bml_trans   : out std_logic;                    -- '1' to set "00" pixels transparent
      bml_fat_o   : out std_logic;                    -- '1' to set BML fat-pixel mode
   -- SPI Interface
      spi_clk     : out std_logic;
      spi_cs      : out std_logic;
      spi_mosi    : out std_logic;
      spi_miso    : in  std_logic
   );
end f18a_cpu;

architecture rtl of f18a_cpu is

   -- **NOTE**
   -- These are also defined in the GPU module to avoid using actual paths
   -- and resources to transfer a constant to the GPU module.
   constant VMAJOR   : std_logic_vector(0 to 3) := X"1";
   constant VMINOR   : std_logic_vector(0 to 3) := X"9";
   constant IDENT    : std_logic_vector(0 to 2) := "111"; -- >Ex

   -- Synchronization for csw and csr.
   signal csw_sync : std_logic_vector(0 to 1);
   signal csr_sync : std_logic_vector(0 to 1);
   signal csw_next : std_logic;
   signal csr_next : std_logic;
   signal csw  : std_logic;
   signal csr  : std_logic;

   -- States
   type state_io_type is (
      st_reset, st_idle, st_gpu_pause,
      st_data_write, st_data_read, st_read_done,
      st_pram_write, st_pram_1st, st_pram_2nd,
      st_read_status, st_setup_addr,
      st_reg_write, st_prefetch, st_save_prefetch,
      st_wait_eoc);

   signal io_state   : state_io_type;
   signal io_next    : state_io_type;
   signal io_subop   : state_io_type;

   -- Address counter
   signal addr_ff       : std_logic;                  -- hi/lo addr load flipflop
   signal regaddr       : std_logic_vector(0 to 13);  -- register select addr (mux GPU and CPU access)
   signal ramaddr       : std_logic_vector(0 to 13);  -- auto increment addr
   signal loadaddr      : std_logic_vector(0 to 13);  -- load address
   signal inc_en        : std_logic;                  -- increment enable
   signal regread       : std_logic_vector(0 to 7);   -- register read
   signal reg_val       : std_logic_vector(0 to 7);   -- register value, set when VRAM address is set
   signal reg_we        : std_logic;                  -- CPU register write enable
   signal is_vr0to7_s   : std_logic;                  -- '1' when writing VR0..7
   signal is_vr57_s     : std_logic;                  -- '1' when writing to VR57
   signal cpu_vr_mask_s : std_logic_vector(0 to 2);   -- Used to mask upper 3 bits of VR access

   -- GPU interface
   signal power_on_trig : std_logic := '0';           -- trigger the GPU once after power-on reset
   signal gpu_load      : std_logic;                  -- '0' resets and loads the GPU PC
   signal gpu_trigger   : std_logic;                  -- '1' start the GPU running
   signal gpu_trig_delay: std_logic;                  -- trigger delay for load and trigger event
   signal gpu_go        : std_logic;                  -- final trigger signal = trigger or trig_delay
   signal gpu_rst_n     : std_logic;                  -- '0' to reset the GPU and load the PC
   signal gpu_running   : std_logic;                  -- '1' when the GPU is running, '0' when idle
   signal gpu_pause     : std_logic;                  -- GPU paused
   signal gpu_pause_req : std_logic;                  -- GPU pause request
   signal gpu_pause_ack : std_logic;                  -- GPU pause acknowledge
   signal gpu_load_pc   : std_logic_vector(0 to 15);

   -- GPU VRAM interface
   signal gpu_addr      : std_logic_vector(0 to 13);
   signal gpu_dout      : std_logic_vector(0 to 7);
   signal gpu_we        : std_logic;
   -- Palette Interface
   signal gpu_pwe       : std_logic;
   signal gpu_paddr     : std_logic_vector(0 to 5);
   signal gpu_pdout     : std_logic_vector(0 to 11);
   -- Register Interface
   signal gpu_raddr     : std_logic_vector(0 to 13);
   signal gpu_rwe       : std_logic;                  -- write enable for VDP registers
   -- GPU status output, 7-bits of user defined status
   signal gpu_status    : std_logic_vector(0 to 6);

   -- VRAM interface
   signal we            : std_logic;
   signal pdata         : std_logic_vector(0 to 7);   -- prefetch data

   -- PRAM interface
   signal data_port_mode: std_logic := '0';
   signal pram_ff       : std_logic;
   signal pram_addr     : std_logic_vector(0 to 5);
   signal pram_data     : std_logic_vector(0 to 11);
   signal pram_we       : std_logic;
   signal pram_load     : std_logic;
   signal pram_inc_en   : std_logic;

   -- Data in and out registers
   signal cd_out        : std_logic_vector(0 to 7);
   signal cd_in, cd_r   : std_logic_vector(0 to 7);
   signal mode_r        : std_logic;

   -- Status register output, depends on status register pointer R15
   signal status_reg    : std_logic_vector(0 to 7);

   signal clear_sr0     : std_logic;                  -- clear SR0
   signal clear_sr1     : std_logic;                  -- clear SR1

   -- Status bits
   signal sp_c_ff       : std_logic;
   signal sp_5s_ff      : std_logic;
   signal sp_5th_reg    : std_logic_vector(0 to 4);

   -- Extra status
   signal horz_en       : std_logic;
   signal horz_ff       : std_logic;
   signal horz_last     : std_logic;
   signal horz_intr     : std_logic;

   -- Blanking edge detect and GPU horz/vert trigger
   signal blank_edge_r  : std_logic;
   signal gpu_hv_trig_r : std_logic;

   -- End of frame interrupt detection
   signal intr_n_reg    : std_logic;
   signal intr_ff       : std_logic;

   -- Segment counter
   signal cnt_nano_r, cnt_nano_sr, cnt_nano_x    : std_logic_vector(0 to 9);
   signal cnt_micro_r, cnt_micro_sr, cnt_micro_x : std_logic_vector(0 to 9);

   signal cnt_milli_r, cnt_milli_sr, cnt_milli_x : std_logic_vector(0 to 9);
   signal cnt_sec_r, cnt_sec_sr, cnt_sec_x       : std_logic_vector(0 to 15);
   signal cnt_nano_max_s  : std_logic;
   signal cnt_micro_max_s : std_logic;
   signal cnt_milli_max_s : std_logic;

   -- Internal registers.  No 4/16K selection or external video support.
   signal reg_sel       : std_logic_vector(0 to 5);
   signal reg0ie1       : std_logic;
   signal reg0m3        : std_logic;
   signal reg0m4        : std_logic;                  -- 9938 text2 mode support
   signal reg1b         : std_logic;
   signal reg1ie        : std_logic;
   signal reg1m1        : std_logic;
   signal reg1m2        : std_logic;
   signal reg1size      : std_logic;
   signal reg1mag       : std_logic;
   signal reg2          : std_logic_vector(0 to 3);
   signal reg3          : std_logic_vector(0 to 7);
   signal reg4          : std_logic_vector(0 to 2);
   signal reg5          : std_logic_vector(0 to 6);
   signal reg6          : std_logic_vector(0 to 2);
   signal reg7h         : std_logic_vector(0 to 3);
   signal reg7l         : std_logic_vector(0 to 3);

   -- F18A enhanced registers
   signal reg10t2ntba   : std_logic_vector(0 to 3);   -- Tile 2 name table base address
   signal reg11t2ctba   : std_logic_vector(0 to 7);   -- Tile 2 color table base address

   signal reg15cnt_rst  : std_logic;                  -- 32-bit counter reset
   signal reg15cnt_snap : std_logic;                  -- 32-bit counter snapshot
   signal reg15cnt_en   : std_logic;                  -- 32-bit counter enable
   signal reg15sreg_num : std_logic_vector(0 to 3);   -- Determines which status register to return
   signal reg19horz     : std_logic_vector(0 to 7);   -- Scan line interrupt line number

   signal reg24sprt_ps  : std_logic_vector(0 to 1);   -- sprite palette select
   signal reg24tile_ps  : std_logic_vector(0 to 3);   -- tile palette select, T2PS[0..1] T1PS[2..3]

   signal reg25horz     : std_logic_vector(0 to 7);   -- Tile 2 Horz scroll reg
   signal reg26vert     : std_logic_vector(0 to 7);   -- Tile 2 Vert scroll reg
   signal reg27horz     : std_logic_vector(0 to 7);   -- Tile 1 Horz scroll reg
   signal reg28vert     : std_logic_vector(0 to 7);   -- Tile 1 Vert scroll reg
   signal reg29hpsize1  : std_logic;                  -- Tile 1 horizontal page size
   signal reg29vpsize1  : std_logic;                  -- Tile 1 vertical page size
   signal reg29hpsize2  : std_logic;                  -- Tile 2 horizontal page size
   signal reg29vpsize2  : std_logic;                  -- Tile 2 vertical page size
   signal reg29tpgs     : std_logic_vector(0 to 1);   -- tile pattern table offset size
   signal reg29spgs     : std_logic_vector(0 to 1);   -- sprite pattern table offset size

   signal reg30sprtmax  : std_logic_vector(0 to 4);   -- Maximum displayable sprite

   signal reg31bml_ps   : std_logic_vector(0 to 3);   -- bitmap layer palette select
   signal reg31bml_en   : std_logic;                  -- '1' to enable the bitmap layer
   signal reg31bml_pri  : std_logic;                  -- '1' when bitmap has priority over tiles
   signal reg31bml_trns : std_logic;                  -- '1' to set "00" pixels as transparent
   signal reg31bml_fat  : std_logic;                  -- '1' to set BML fat-pixel mode

   signal reg32bmlba    : std_logic_vector(0 to 7);   -- bitmap layer base address
   signal reg33bml_x    : std_logic_vector(0 to 7);   -- bitmap layer x location
   signal reg34bml_y    : std_logic_vector(0 to 7);   -- bitmap layer y location
   signal reg35bml_w    : std_logic_vector(0 to 7);   -- bitmap layer width
   signal reg36bml_h    : std_logic_vector(0 to 7);   -- bitmap layer height

   signal reg47dpm      : std_logic;                  -- data-port write mode
   signal reg47auto     : std_logic;                  -- palette reg auto inc
   signal reg47paddr    : std_logic_vector(0 to 5);   -- palette reg address

   signal reg48inc      : std_logic_vector(0 to 7) := x"01";      -- VRAM address increment, signed
   signal reg48sign     : std_logic_vector(0 to 5) := "000000";   -- VRAM address sign extension

   signal reg49tile2_en : std_logic;                  -- Tile layer 2 enable
   signal reg49row30    : std_logic;                  -- 24/30 rows
   signal reg49ecmt     : std_logic_vector(0 to 1);   -- enhanced color mode tiles
   signal reg49yreal    : std_logic;                  -- Real Y coordinate for sprites
   signal reg49ecms     : std_logic_vector(0 to 1);   -- enhanced color mode sprites

   signal reg50t2_pri   : std_logic;                  -- tile2 priority enable (0 = TL2 always on top)
   signal reg50tl1_off  : std_logic;                  -- disable tile layer 1, GM1, GM2, MCM, T40, T80
   signal reg50pos_attr : std_logic;                  -- position based tile attributes
   signal reg50scanline : std_logic;                  -- virtual scan line enable

   signal reg50rptmax   : std_logic;                  -- report max sprite or 5th sprite
   signal reg50reboot   : std_logic;                  -- reboot the F18A
   signal reg50hgpu     : std_logic;                  -- GPU hsync trigger
   signal reg50vgpu     : std_logic;                  -- GPU vsync trigger

   signal reg51stopsprt : std_logic_vector(0 to 5);   -- Stop Sprite to limit sprite processing

   signal reg54gpu_msb  : std_logic_vector(0 to 7);   -- GPU PC MSB
   signal reg55gpu_lsb  : std_logic_vector(0 to 7);   -- GPU PC LSB

   signal reg57unlock   : std_logic;                  -- '1' when enhanced registers are unlocked
   signal reg57cnt      : std_logic;                  -- counter for unlock sequence
   signal reg57cnt_next : std_logic;

begin

   -- Synchronize #CSR and #CSW by sampling them over
   -- a period of 2 clock cycles or 20ns.
   process (clk)
   begin
      if rising_edge(clk) then
      if rst_n = '0' then
         csw_sync <= (others => '1');
         csr_sync <= (others => '1');
      else
         csw_sync <= csw_sync(1) & csw_n;
         csr_sync <= csr_sync(1) & csr_n;
         csw <= csw_next;
         csr <= csr_next;

         -- mode and data-in are not synchronized because once #CSR or #CSW
         -- are stable, the mode and input data will be as well.  So just
         -- register these inputs.
         mode_r <= mode;
         cd_r   <= cd_i;
      end if;
      end if;
   end process;

   csw_next <=
      '0' when csw_sync = "00" else
      '1' when csw_sync = "11" else
      csw;

   csr_next <=
      '0' when csr_sync = "00" else
      '1' when csr_sync = "11" else
      csr;


   -- The status register number determines which status is returned.
   process (reg15sreg_num, intr_ff, sp_5s_ff, sp_c_ff, sp_5th_reg, horz_ff,
   gpu_status, gpu_running, scanline, reg_val, blank,
   cnt_nano_sr, cnt_micro_sr, cnt_milli_sr, cnt_sec_sr)
   begin

      clear_sr0 <= '0';
      clear_sr1 <= '0';

      case reg15sreg_num is

      when X"0" =>   -- Original 9918A status
         status_reg <= intr_ff & sp_5s_ff & sp_c_ff & sp_5th_reg;
         clear_sr0 <= '1';

      when X"1" =>   -- Identification, blanking, and horizontal interrupt flag
         status_reg <= IDENT & "000" & blank & horz_ff;
         clear_sr1 <= '1';

      when X"2" =>   -- GPU status
         status_reg <= gpu_running & gpu_status;

      when X"3" =>   -- raster scan line
         status_reg <= std_logic_vector(scanline);

      when X"4" =>
         status_reg <= cnt_nano_sr(2 to 9);
      when X"5" =>
         status_reg <= "000000" & cnt_nano_sr(0 to 1);

      when X"6" =>
         status_reg <= cnt_micro_sr(2 to 9);
      when X"7" =>
         status_reg <= "000000" & cnt_micro_sr(0 to 1);

      when X"8" =>
         status_reg <= cnt_milli_sr(2 to 9);
      when X"9" =>
         status_reg <= "000000" & cnt_milli_sr(0 to 1);

      when X"A" =>
         status_reg <= cnt_sec_sr(8 to 15);
      when X"B" =>
         status_reg <= cnt_sec_sr(0 to 7);

--    when X"C" =>
--    when X"D" =>

      when X"E" =>   -- F18A major and minor versions
         status_reg <= VMAJOR & VMINOR;

      when X"F" =>   -- Register read value, set when the VRAM address is set
         status_reg <= reg_val;

      when others =>
         status_reg <= X"00";

      end case;
   end process;


   -- Segmented counter, 10ns accuracy.
   cnt_nano_max_s <= '1' when cnt_nano_r = 990 else '0';
   cnt_micro_max_s <= '1' when cnt_micro_r = 999 else '0';
   cnt_milli_max_s <= '1' when cnt_milli_r = 999 else '0';

   process (cnt_nano_r, cnt_micro_r, cnt_milli_r, cnt_sec_r, reg15cnt_rst,
   cnt_nano_max_s, cnt_micro_max_s, cnt_milli_max_s)
   begin

      cnt_micro_x <= cnt_micro_r;
      cnt_milli_x <= cnt_milli_r;
      cnt_sec_x   <= cnt_sec_r;

      -- Nanosecond counter.
      if reg15cnt_rst = '1' or cnt_nano_max_s = '1' then
         cnt_nano_x <= (others => '0');
      else
         cnt_nano_x <= cnt_nano_r + 10;
      end if;

      -- Microsecond counter.
      if reg15cnt_rst = '1' or (cnt_nano_max_s = '1' and cnt_micro_max_s = '1') then
         cnt_micro_x <= (others => '0');
      elsif cnt_nano_max_s = '1' then
         cnt_micro_x <= cnt_micro_r + 1;
      end if;

      -- Millisecond counter.
      if reg15cnt_rst = '1' or (cnt_nano_max_s = '1' and cnt_micro_max_s = '1' and cnt_milli_max_s = '1') then
         cnt_milli_x <= (others => '0');
      elsif (cnt_nano_max_s = '1' and cnt_micro_max_s = '1') then
         cnt_milli_x <= cnt_milli_r + 1;
      end if;

      -- Second counter, rolls over.
      if reg15cnt_rst = '1' then
         cnt_sec_x <= (others => '0');
      elsif (cnt_nano_max_s = '1' and cnt_micro_max_s = '1' and cnt_milli_max_s = '1') then
         cnt_sec_x <= cnt_sec_r + 1;
      end if;
   end process;

   process (clk) begin if rising_edge(clk) then
      if reg15cnt_en = '1' then
         cnt_nano_r  <= cnt_nano_x;
         cnt_micro_r <= cnt_micro_x;
         cnt_milli_r <= cnt_milli_x;
         cnt_sec_r   <= cnt_sec_x;
      end if;

      if reg15cnt_snap = '1' then
         cnt_nano_sr  <= cnt_nano_r;
         cnt_micro_sr <= cnt_micro_r;
         cnt_milli_sr <= cnt_milli_r;
         cnt_sec_sr   <= cnt_sec_r;
      end if;
   end if; end process;


   -- Horizontal interrupt flag and edge detect, disable if reg19horz is 0.
   horz_intr <= '1' when scanline = unsigned(reg19horz) and unsigned(reg19horz) /= 0 else '0';
   process (clk) begin if rising_edge(clk) then
      horz_en <= '0';
      horz_last <= horz_intr;
      if horz_intr = '1' and horz_last = '0' then
         horz_en <= '1';
      end if;
   end if; end process;


   -- cd_io data path
   --   cd_io(0)
   --   cd_io(1)
   --   cd_io addr-lsb
   --   cd_io(2 to 7) addr-msb
   --   cd_io to vram
   --   cd_io from vram

   -- Decode the four main operations, plus the F18A data-port mode for palette access.
   -- For address read setup, address write setup, and register write the two-byte
   -- operation is the same for both VDP writes: csw=0 mode=1.  The only way the VDP
   -- knows the difference is to check the two MSbits of the second byte (see io_subop).
   io_next <=
      st_data_read   when (mode_r = '0' and csr = '0') else
      st_data_write  when (mode_r = '0' and csw = '0' and data_port_mode = '0') else
      st_pram_write  when (mode_r = '0' and csw = '0' and data_port_mode = '1') else
      st_read_status when (mode_r = '1' and csr = '0') else
      st_setup_addr  when (mode_r = '1' and csw = '0') else
      st_reset;

   -- Decode the four address setup sub-operations:
   --
   -- 1st byte written: address byte or register data (always latched to the address counter LSB)
   --
   -- 2nd byte written: always latched to the address counter MSB
   --
   -- 00aaaaaa - read address MSbits, causes a prefetch
   -- 01aaaaaa - write address MSbits, inhibits a prefetch
   -- 10rrrrrr - write register, inhibits a prefetch
   -- 11xxxxxx - undefined in the datasheet, inhibits a prefetch.  The 9918A has been
   --            characterized and performs a write to register for this condition.
   process ( addr_ff, cd_in )
   begin
      -- First byte stored in address counter LSB, just wait for end of cycle.
      io_subop <= st_wait_eoc;

      -- Second byte, depends on MSbits of input byte.
      if addr_ff = '1' then
         if cd_in(0) = '1' then           -- 10 or 11 register write
            io_subop <= st_reg_write;
         elsif cd_in(1) = '0' then        -- 00 read address setup, perform prefetch
            io_subop <= st_prefetch;
         end if;                          -- 01 write address setup, nothing else to do, default action
      end if;
   end process;


   -- 9938 Datasheet, pg. 121
   -- Absolute minimums (fastest possible CPU access)
   -- Minimum csw / csr = 168nS (700nS typical)
   -- Read:  csr (186nS) + data disable time (65nS) = 251nS minimum
   -- Write: addr setup (30nS) + csw (186nS) + data hold (30nS) = 246nS minimum

   -- Primary CPU IO state machine.
   process (clk)
   begin
      if rising_edge(clk) then
      if rst_n = '0' then

         -- During reset, hold controlling flags.
         io_state       <= st_reset;
         addr_ff        <= '0';
         pram_ff        <= '0';     -- palette ram ff
         data_port_mode <= '0';     -- data-port mode to VRAM
         inc_en         <= '0';
         we             <= '0';
         pram_we        <= '0';
         intr_n_reg     <= '1';
         intr_ff        <= '0';
         horz_ff        <= '0';

      else

         -- Enable signals are only active for 1 clock.
         we <= '0';           -- VRAM write enable
         inc_en <= '0';       -- VRAM address counter enable
         pram_we <= '0';      -- PRAM write enable
         pram_inc_en <= '0';  -- PRAM address counter enable

         -- Always ask the GPU to pause unless idle or waiting for the EOC.
         gpu_pause_req <= '1';

         -- See if the data port mode was updated.
         if pram_load = '1' then data_port_mode <= reg47dpm; end if;

         -- Sample and hold status bits until the status register is read.
         if sp_cf = '1' and sp_cf_en = '1' then sp_c_ff <= '1'; end if;

         -- Sample the interrupt ticks.  The flags can be set in the status byte
         -- independently from the interrupt enable bit.
         if intr_en = '1' then intr_ff <= '1'; end if;
         if horz_en = '1' then horz_ff <= '1'; end if;

         -- The interrupt output is active low and registered to prevent glitches.
         if (intr_ff = '1' and reg1ie = '1') or (horz_ff = '1' and reg0ie1 = '1') then
            intr_n_reg <= '0';
         else
            intr_n_reg <= '1';
         end if;

         -- See pg. 2-11, 2.3.3 of the 9918A datasheet.  The 5S flag is only set
         -- whenever there are five or more sprites on a scan line (0 to 192)
         -- *AND* the frame flag is equal to 0.
         -- 5TH number fix.  Only set the 5S flag if the frame flag is 0.
         -- The 5s flag is restricted to the active scan lines, 0..192 and 0..239,
         -- in the sprite module.
         if sp_5s = '1' and intr_ff = '0' then
            sp_5s_ff <= '1';
         end if;

         -- 5TH number fix.  As long as the 5S flag is zero, the 5TH number register
         -- follows the sprite scanning sequence.  Seems to be a transparent latch
         -- that follows the input (current sprite being scanned) until latched by
         -- the 5S flag.  If the status register is being polled and 5S is reset mid
         -- frame, then the 5TH number begins following the scanned sprites again.
         if sp_5s_ff = '0' then sp_5th_reg <= sp_5th; end if;

         -- Process the I/O state.
         case io_state is

         when st_reset =>

            io_state <= st_idle;
            addr_ff <= '0';         -- address ff
            pram_ff <= '0';         -- palette ram ff
            data_port_mode <= '0';  -- data-port mode to VRAM

         when st_idle =>

            io_state <= st_idle;
            gpu_pause <= '0';       -- GPU not paused until it acknowledges
            gpu_pause_req <= '0';   -- Do not request a pause when idle

            -- Wait for csw or csr to go low.
            if csw = '0' or csr = '0' then
               -- Don't pause the GPU for a status read.
               if io_next = st_read_status then
                  io_state <= io_next;
               else
                  io_state <= st_gpu_pause;
                  gpu_pause_req <= '1';
               end if;
            end if;

         when st_gpu_pause =>

            cd_in <= cd_r;             -- register the input data

            if gpu_pause_ack = '1' then
               io_state <= io_next;
               gpu_pause <= '1';       -- Set the GPU paused status
            else
               io_state <= st_gpu_pause;
            end if;

         when st_data_write =>

            io_state <= st_wait_eoc;
            pdata <= cd_in;            -- copy write data to prefetch buffer
            we <= '1';
            inc_en <= '1';
            addr_ff <= '0';

         when st_pram_write =>

            if pram_ff = '0' then
               io_state <= st_pram_1st;
            else
               io_state <= st_pram_2nd;
            end if;

         when st_pram_1st =>

            io_state <= st_wait_eoc;               -- 01234567 01234567 bytes in
            pram_ff <= '1';                        --     0123 45678901 palette reg
            pram_data(0 to 3) <= cd_in(4 to 7);    -- ----rrrr ggggbbbb color format

         when st_pram_2nd =>

            io_state <= st_wait_eoc;
            pram_ff <= '0';
            pram_data(4 to 11) <= cd_in;
            pram_we <= '1';
            pram_inc_en <= reg47auto;

            -- If auto increment of the palette address is not set, or
            -- the palette address will roll to zero, then auto exit
            -- data port mode.  This is also acts as a fail-safe to not
            -- get stuck continuously writing to the palette.
            if reg47auto = '0' or pram_addr = "111111" then
               data_port_mode <= '0';
            end if;

         when st_data_read =>

            -- Wait 1 clock for the prefetch data read due to the GPU handshake.
            io_state <= st_read_done;

         when st_read_done =>

            io_state <= st_wait_eoc;
            cd_out <= pdata;           -- prefetch data out
            pdata <= vdin;             -- new data to prefetch register
            inc_en <= '1';
            addr_ff <= '0';

         when st_read_status =>

            io_state <= st_wait_eoc;
            cd_out <= status_reg;
            gpu_pause_req <= '0';
            gpu_pause <= '0';

            -- Reading any of the status registers resets the access flags
            addr_ff <= '0';            -- address ff
            pram_ff <= '0';            -- palette ram ff
            data_port_mode <= '0';     -- data-port mode to VRAM

            if clear_sr0 = '1' then
               -- Reset the vert interrupt on status read.
               intr_ff <= '0';         -- Allows hazard of setting/clearing at the same time
               sp_5s_ff <= '0';        -- More than 5 sprites on a line
               sp_c_ff <= '0';         -- Sprite collision
            end if;

            if clear_sr1 = '1' then
               -- Reset the horz interrupt on status read.
               horz_ff <= '0';
            end if;

         when st_setup_addr =>

            io_state <= io_subop;
            addr_ff <= not addr_ff;

         when st_reg_write =>

            io_state <= st_wait_eoc;

         when st_prefetch =>

            -- Wait 1 clock for the data read.
            io_state <= st_save_prefetch;

         when st_save_prefetch =>

            io_state <= st_wait_eoc;
            reg_val <= regread;        -- Latch the register read data.
            pdata <= vdin;
            inc_en <= '1';

         when st_wait_eoc =>

            -- Wait for the end of the read or write cycle.
            if csw = '1' and csr = '1' then
               io_state <= st_idle;
            end if;

            gpu_pause_req <= '0';
            gpu_pause <= '0';

         end case;

      end if;
      end if;
   end process;


   -- Register select decoder based on address register.
   -- xx012345|67890123
   reg_sel <= regaddr(0 to 5);

   -- Make sure VR0 - VR7 and VR57 can be written to even when locked out, since
   -- writing to VR57 is the only way for the CPU to unlock, and VR0 - VR7 are
   -- the original registers.
   is_vr0to7_s <= '1' when reg_sel < "001000" else '0';
   is_vr57_s   <= '1' when ramaddr(0 to 5) = "111001" else '0';
   reg_we      <= is_vr0to7_s or is_vr57_s or reg57unlock;

   -- Track consecutive writes to VR57 with "000111xx" data.  When only
   -- considering the low 3-bits for a register, this would be the same
   -- as writing "000111xx" to VR1, which sets 4K, blank, no interrupt,
   -- and M1 and M2 to '1' at the same time, which is an illegal mode.
   -- Basically, setting VR1 to this value would be useless, and therefore
   -- should never happen even by sloppy programming.
   reg57cnt_next <= '1' when ramaddr(6 to 11) = "000111" else '0';


   process (clk)
   begin
      if rising_edge(clk) then
      if rst_n = '0' or reg50reboot = '1' then

         -- VDP reset clears R0 and R1 (pg 2-5, sec 2.1.7)
         reg0ie1     <= '0';
         reg0m3      <= '0';
         reg0m4      <= '0';
         reg1b       <= '1';
         reg1ie      <= '0';
         reg1m1      <= '0';
         reg1m2      <= '0';
         reg1size    <= '0';
         reg1mag     <= '0';
         reg2        <= x"0";       -- VR2 ntba  @ >0000 for 768 bytes
         reg3        <= x"10";      -- VR3 ctba  @ >0400 for 32 bytes for color sets
         reg4        <= "001";      -- VR4 pgtba @ >0800 for 2K bytes for patterns
         reg5        <= "0001010";  -- VR5 satba @ >0500 for 128 bytes + 32 bytes link table
         reg6        <= "010";      -- VR6 spgba @ >1000 for 2K bytes for patterns
         reg7h       <= x"1";       -- Foreground / text color for text mode, black
         reg7l       <= x"F";       -- Background / border color, white
         -- F18A specific registers
         reg10t2ntba    <= (others => '0');
         reg11t2ctba    <= (others => '0');
         reg15cnt_en    <= '0';
         reg15sreg_num  <= (others => '0');
         reg19horz      <= (others => '0');
         reg24sprt_ps   <= "00";
         reg24tile_ps   <= "0000";
         reg25horz      <= "00000000";
         reg26vert      <= "00000000";
         reg27horz      <= "00000000";
         reg28vert      <= "00000000";
         reg29hpsize1   <= '0';
         reg29vpsize1   <= '0';
         reg29hpsize2   <= '0';
         reg29vpsize2   <= '0';
         reg29tpgs      <= "00";
         reg29spgs      <= "00";
         reg30sprtmax   <= usr_sprite_max;
         reg31bml_en    <= '0';
         reg47dpm       <= '0';
         reg48inc       <= x"01";
         reg48sign      <= "000000";
         reg49tile2_en  <= '0';
         reg49row30     <= '0';
         reg49ecmt      <= "00";
         reg49yreal     <= '0';
         reg49ecms      <= "00";
         reg50t2_pri    <= '0';
         reg50tl1_off   <= '0';
         reg50pos_attr  <= '0';
         reg50scanline  <= '0';
         reg50rptmax    <= '0';
         reg50reboot    <= '0';
         reg50hgpu      <= '0';
         reg50vgpu      <= '0';
         reg51stopsprt  <= "100000";
         reg54gpu_msb   <= x"40";            -- default to GRAM address >4000
         reg55gpu_lsb   <= x"00";
         reg57unlock    <= '0';
         reg57cnt       <= '0';
         gpu_load       <= '0';
         gpu_trigger    <= '0';

      else
         -- Trigger a pram counter load only when the palette address
         -- register is updated.
         pram_load <= '0';

         gpu_load <= '0';
         gpu_trigger <= '0';

         reg15cnt_rst  <= '0';    -- single tick counter reset
         reg15cnt_snap <= '0';    -- single tick counter snapshot

         -- Make sure the sprite max is always set, even if resets are
         -- missed.  Also, this is a way to programmatically reset the
         -- sprite max to the jumper setting.
         if reg30sprtmax = "00000" then
            reg30sprtmax <= usr_sprite_max;
         end if;


         if (io_state = st_reg_write and reg_we = '1') or gpu_rwe = '1' then

            -- For every write other than reg57, the counter is reset.
            reg57cnt <= '0';

            case reg_sel is
               when "000000" =>  reg0ie1        <= regaddr(9);
                                 reg0m4         <= regaddr(11);
                                 reg0m3         <= regaddr(12);
               when "000001" =>  reg1b          <= regaddr(7);
                                 reg1ie         <= regaddr(8);
                                 reg1m1         <= regaddr(9);
                                 reg1m2         <= regaddr(10);
                                 reg1size       <= regaddr(12);
                                 reg1mag        <= regaddr(13);
               when "000010" =>  reg2           <= regaddr(10 to 13);
               when "000011" =>  reg3           <= regaddr(6 to 13);
               when "000100" =>  reg4           <= regaddr(11 to 13);
               when "000101" =>  reg5           <= regaddr(7 to 13);
               when "000110" =>  reg6           <= regaddr(11 to 13);
               when "000111" =>  reg7h          <= regaddr(6 to 9);
                                 reg7l          <= regaddr(10 to 13);
               -- F18A specific or compatible registers
               -- xx012345|67890123
               when "001010" =>  reg10t2ntba    <= regaddr(10 to 13);
               when "001011" =>  reg11t2ctba    <= regaddr(6 to 13);
               when "001111" =>  reg15cnt_rst   <= regaddr(7);
                                 reg15cnt_snap  <= regaddr(8);
                                 reg15cnt_en    <= regaddr(9);
                                 reg15sreg_num  <= regaddr(10 to 13);
               when "010011" =>  reg19horz      <= regaddr(6 to 13);
               when "011000" =>  reg24sprt_ps   <= regaddr(8 to 9);
                                 reg24tile_ps   <= regaddr(10 to 13);  -- T2PS[0..1] T1PS[2..3]
               when "011001" =>  reg25horz      <= regaddr(6 to 13);
               when "011010" =>  reg26vert      <= regaddr(6 to 13);
               when "011011" =>  reg27horz      <= regaddr(6 to 13);
               when "011100" =>  reg28vert      <= regaddr(6 to 13);
               when "011101" =>  reg29spgs      <= regaddr(6 to 7);
                                 reg29hpsize2   <= regaddr(8);
                                 reg29vpsize2   <= regaddr(9);
                                 reg29tpgs      <= regaddr(10 to 11);
                                 reg29hpsize1   <= regaddr(12);
                                 reg29vpsize1   <= regaddr(13);
               when "011110" =>  reg30sprtmax   <= regaddr(9 to 13);
               when "011111" =>  reg31bml_en    <= regaddr(6);
                                 reg31bml_pri   <= regaddr(7);
                                 reg31bml_trns  <= regaddr(8);
                                 reg31bml_fat   <= regaddr(9);
                                 reg31bml_ps    <= regaddr(10 to 13);
               when "100000" =>  reg32bmlba     <= regaddr(6 to 13);
               when "100001" =>  reg33bml_x     <= regaddr(6 to 13);
               when "100010" =>  reg34bml_y     <= regaddr(6 to 13);
               when "100011" =>  reg35bml_w     <= regaddr(6 to 13);
               when "100100" =>  reg36bml_h     <= regaddr(6 to 13);
               when "101111" =>  reg47dpm       <= regaddr(6);
                                 reg47auto      <= regaddr(7);
                                 reg47paddr     <= regaddr(8 to 13);
                                 pram_load      <= gpu_pause;        -- CPU interface only
               when "110000" =>  reg48inc       <= regaddr(6 to 13);
                                 reg48sign      <= regaddr(6) & regaddr(6) & regaddr(6) &
                                                   regaddr(6) & regaddr(6) & regaddr(6);
               when "110001" =>  reg49tile2_en  <= regaddr(6);
                                 reg49row30     <= regaddr(7);
                                 reg49ecmt      <= regaddr(8 to 9);
                                 reg49yreal     <= regaddr(10);
                                 reg49ecms      <= regaddr(12 to 13);
               when "110010" =>  reg50reboot    <= regaddr(6);
                                 reg50hgpu      <= regaddr(7);
                                 reg50vgpu      <= regaddr(8);
                                 reg50tl1_off   <= regaddr(9);
                                 reg50rptmax    <= regaddr(10);
                                 reg50scanline  <= regaddr(11);
                                 reg50pos_attr  <= regaddr(12);
                                 reg50t2_pri    <= regaddr(13);
               when "110011" =>  reg51stopsprt  <= regaddr(8 to 13);
               when "110110" =>  reg54gpu_msb   <= regaddr(6 to 13);
               when "110111" =>  reg55gpu_lsb   <= regaddr(6 to 13);
                                 gpu_load       <= gpu_pause;        -- CPU interface only
                                 gpu_trigger    <= gpu_pause;        -- CPU interface only
               when "111000" =>  gpu_load       <= gpu_pause and (not regaddr(13)); -- CPU interface only
                                 gpu_trigger    <= gpu_pause and regaddr(13);       -- CPU interface only
               when "111001" =>  reg57cnt       <= reg57cnt_next;
                                 reg57unlock    <= reg57cnt and reg57cnt_next;
               when others =>    null;    -- ignore any others
            end case;
         end if;
      end if;
      end if;
   end process;


   -- VDP register read
   process (reg_sel,
   reg0ie1, reg0m4, reg0m3, reg1b, reg1ie, reg1m1, reg1m2, reg1size, reg1mag,
   reg2, reg3, reg4, reg5, reg6, reg7h, reg7l, reg10t2ntba, reg11t2ctba, reg15sreg_num, reg15cnt_en,
   reg19horz, reg24sprt_ps, reg24tile_ps, reg25horz, reg26vert, reg27horz, reg28vert,
   reg29hpsize1, reg29vpsize1, reg29hpsize2, reg29tpgs, reg29spgs, reg29vpsize2, reg30sprtmax, reg31bml_ps,
   reg31bml_trns, reg31bml_fat, reg31bml_pri, reg31bml_en, reg32bmlba, reg33bml_x, reg34bml_y,
   reg35bml_w, reg36bml_h, reg47dpm, reg47auto, reg47paddr, reg48inc,
   reg49tile2_en, reg49row30, reg49ecmt, reg49yreal, reg49ecms,
   reg50t2_pri, reg50tl1_off, reg50pos_attr, reg50rptmax, reg50hgpu, reg50vgpu, reg50scanline,
   reg51stopsprt, reg54gpu_msb, reg55gpu_lsb)
   begin
      regread <= (others => '0');
      case reg_sel is
         when "000000" => regread <= "000" & reg0ie1 & '0' & reg0m4 & reg0m3 & '0';
         when "000001" => regread <= '0' & reg1b & reg1ie & reg1m1 & reg1m2 & '0' & reg1size & reg1mag;
         when "000010" => regread <= "0000" & reg2;
         when "000011" => regread <= reg3;
         when "000100" => regread <= "00000" & reg4;
         when "000101" => regread <= '0' & reg5;
         when "000110" => regread <= "00000" & reg6;
         when "000111" => regread <= reg7h & reg7l;
         -- F18A specific or compatible registers
         when "001010" => regread <= "0000" & reg10t2ntba;
         when "001011" => regread <= reg11t2ctba;
         when "001111" => regread <= "000" & reg15cnt_en & reg15sreg_num;
         when "010011" => regread <= reg19horz;
         when "011000" => regread <= "00" & reg24sprt_ps & reg24tile_ps;
         when "011001" => regread <= reg25horz;
         when "011010" => regread <= reg26vert;
         when "011011" => regread <= reg27horz;
         when "011100" => regread <= reg28vert;
         when "011101" => regread <= reg29spgs & reg29hpsize2 & reg29vpsize2 & reg29tpgs & reg29hpsize1 & reg29vpsize1;
         when "011110" => regread <= "000" & reg30sprtmax;
         when "011111" => regread <= reg31bml_en & reg31bml_pri & reg31bml_trns & reg31bml_fat & reg31bml_ps;
         when "100000" => regread <= reg32bmlba;
         when "100001" => regread <= reg33bml_x;
         when "100010" => regread <= reg34bml_y;
         when "100011" => regread <= reg35bml_w;
         when "100100" => regread <= reg36bml_h;
         when "101111" => regread <= reg47dpm & reg47auto & reg47paddr;
         when "110000" => regread <= reg48inc;
         when "110001" => regread <= reg49tile2_en & reg49row30 & reg49ecmt & reg49yreal & '0' & reg49ecms;
         when "110010" => regread <= "0" & reg50hgpu & reg50vgpu & reg50tl1_off & reg50rptmax & reg50scanline & reg50pos_attr & reg50t2_pri;
         when "110011" => regread <= "00" & reg51stopsprt;
         when "110110" => regread <= reg54gpu_msb;
         when "110111" => regread <= reg55gpu_lsb;
         when others   => null;    -- ignore any others
      end case;
   end process;


   -- GPU reset, load, and trigger:
   -- reset loads the GPU's PC and goes to idle state
   -- trigger starts the GPU running
   gpu_rst_n <= rst_n and (not gpu_load);

   -- Add a one cycle delay to the trigger so the writing of the
   -- GPU PC LSB (VR55) can set a reset/load and trigger event.
   process (clk) begin if rising_edge(clk) then
      if rst_n = '0' then
         gpu_trig_delay <= '0';
      else
         -- Trigger the GPU once at power on.  The bitstream ensures
         -- power_on_trig starts with a '0'.
         if power_on_trig = '0' then
            power_on_trig <= '1';
            gpu_trig_delay <= '1';
         else
            gpu_trig_delay <= gpu_trigger;
         end if;
      end if;
   end if; end process;

   -- GPU horz/vert edge detect and trigger.
   process (clk) begin if rising_edge(clk) then
      gpu_hv_trig_r <= '0';
      blank_edge_r <= blank;

      if (reg50hgpu = '1' and blank = '1' and blank_edge_r = '0') or
      (reg50vgpu = '1' and intr_en = '1') then
         gpu_hv_trig_r <= '1';
      end if;
   end if; end process;

   gpu_go <= gpu_trigger or gpu_trig_delay or gpu_hv_trig_r;
   gpu_load_pc <= reg54gpu_msb & reg55gpu_lsb;

   -- 9900 GPU
   inst_gpu : entity work.f18a_gpu
   port map (
      clk      => clk,
      rst_n    => gpu_rst_n,        -- reset and load GPU PC, active low
      trigger  => gpu_go,           -- trigger the GPU, active high
      running  => gpu_running,      -- '1' if the GPU is running, '0' when idle
      pause    => gpu_pause_req,    -- GPU pause request, active high
      pause_ack=> gpu_pause_ack,    -- GPU pause acknowledge, active high
      load_pc  => gpu_load_pc,      -- GPU start address
   -- VRAM Interface
      vdin     => vdin,             -- data into GPU from VRAM
      vwe      => gpu_we,
      vaddr    => gpu_addr,
      vdout    => gpu_dout,
   -- Register Interface
      rdin     => regread,          -- register read
      raddr    => gpu_raddr,        -- register address AND data
      rwe      => gpu_rwe,          -- write enable for VDP registers
   -- Palette Interface
      pdin     => pdin,             -- palette data in from color, in to CPU, in to GPU
      pwe      => gpu_pwe,
      paddr    => gpu_paddr,
      pdout    => gpu_pdout,        -- out from GPU
   -- Data inputs
      scanline => std_logic_vector(scanline),
      blank    => blank,            -- '1' when blanking (horz and vert) for GPU
      bmlba    => reg32bmlba,       -- bitmap layer base address
      bml_w    => reg35bml_w,       -- bitmap layer width
      pgba     => reg4(0),          -- pattern generator base address
   -- Data outputs
      gstatus  => gpu_status,       -- user status data
   -- SPI Interface
      spi_clk  => spi_clk,
      spi_cs   => spi_cs,
      spi_mosi => spi_mosi,
      spi_miso => spi_miso
   );

   -- Address counter and register select / register data.
   -- 9918A datasheet, pg 2-1:
   -- "NOTE - The CPU address is destroyed by writing to the VDP register."
   process (clk)
   begin
      if rising_edge(clk) then
      if rst_n = '0' then
         ramaddr <= (others => '0');
      else
         if io_state = st_setup_addr then
            ramaddr <= loadaddr;
         elsif inc_en = '1' then
            ramaddr <= ramaddr + (reg48sign & reg48inc);
         end if;
      end if;
      end if;
   end process;

   -- Hybrid mask or ignore VRs over VR7 based on the M4 mode bit (80-column mode)
   -- and the F18A lock-out.  When the F18A is locked, the M4 mode bit determines
   -- if VRs greater than VR7 are masked or ignored.  This allows the use of 80-column
   -- mode without unlocking the F18A, but still ignore writes to VRs over VR7 that
   -- 9938 software will do.  Otherwise, if the F18A is locked and M4 is not set, the
   -- three MSbits of the VR address are masked to 000 as the 9918A does.
   --
   -- NOTE: The address register is loaded with the actual value passed in, it is only
   -- the register select input that receives the modified VR address.
   --
   -- xx000RRR  9918A, locked F18A when M4 = 0
   -- xxRRRRRR  9938, locked F18A when M4 = 1, unlocked F18A

   cpu_vr_mask_s <=
      "000" when reg57unlock = '0' and reg0m4 = '0' and is_vr57_s = '0' else
      ramaddr(0 to 2);

   -- ramaddr: xx012345|67890123
   -- cd_in:   01234567|01234567
   loadaddr <=
      ramaddr(0 to 5) & cd_in when addr_ff = '0' else    -- latch LSB
      cd_in(2 to 7) & ramaddr(6 to 13);                  -- latch MSB

   -- Register access mux.  CPU or GPU
   regaddr <= cpu_vr_mask_s & ramaddr(3 to 13) when gpu_pause = '1' else gpu_raddr;


   -- VRAM interface.  ramaddr is fetched every clock cycle.
   vwe <= we when gpu_pause = '1' else gpu_we;
   vaddr <= ramaddr when gpu_pause = '1' else gpu_addr;
   vdout <= cd_in when gpu_pause = '1' else gpu_dout;

   -- PRAM interface.
   pwe <= pram_we when gpu_pause = '1' else gpu_pwe;
   paddr <= pram_addr when gpu_pause = '1' else gpu_paddr;
   pdout <= pram_data when gpu_pause = '1' else gpu_pdout;

   -- PRAM counter.
   process (clk)
   begin
      if rising_edge(clk) then
         if pram_load = '1' then
            pram_addr <= reg47paddr;
         elsif pram_inc_en = '1' then
            pram_addr <= pram_addr + 1;
         end if;
      end if;
   end process;


   -- Host system data output.
   cd_o <= cd_out;

   -- Interrupt output is active low and registered to prevent glitches.
   -- See Idle state.
   intr_n <= intr_n_reg;

   gmode       <= reg0m4 & reg0m3 & reg1m2 & reg1m1;
   soft_blank  <= reg1b;
   size_bit    <= reg1size;
   mag_bit     <= reg1mag;
   pgba        <= reg4;
   satba       <= reg5;
   spgba       <= reg6;
   textfg      <= reg7h;
   textbg      <= reg7l;

   -- F18A enhanced registers
   unlocked    <= reg57unlock;
   row30       <= reg49row30;
   tile_ecm    <= unsigned(reg49ecmt);
   tile_ps     <= reg24tile_ps;
   tl1_off_o   <= reg50tl1_off;
   pos_attr_o  <= reg50pos_attr;
   vscanln_en  <= reg50scanline;

   sprt_ps     <= reg24sprt_ps;
   sprt_ecm    <= unsigned(reg49ecms);
   sprt_yreal  <= reg49yreal;

   sprite_max  <= unsigned(reg30sprtmax);
   stop_sprt   <= unsigned(reg51stopsprt);
   reportmax_o <= reg50rptmax;

   tpgsize_o   <= reg29tpgs;     -- tile pattern table offset size
   spgsize_o   <= reg29spgs;     -- sprite pattern table offset size

   t1ntba      <= reg2;          -- tile1 name table base address
   t1ctba      <= reg3;          -- tile1 color table base address
   t1hsize     <= reg29hpsize1;  -- tile1 horz page size (1 page or 2 pages)
   t1vsize     <= reg29vpsize1;  -- tile1 vert page size (1 page or 2 pages)
   t1horz      <= reg27horz;     -- tile1 horz scroll
   t1vert      <= reg28vert;     -- tile1 vert scroll
   t2_en       <= reg49tile2_en; -- tile2 enable
   t2_pri_en   <= reg50t2_pri;   -- tile2 priority enable (0 = TL2 always on top)
   t2ntba      <= reg10t2ntba;   -- tile2 name table base address
   t2ctba      <= reg11t2ctba;   -- tile2 color table base address
   t2hsize     <= reg29hpsize2;  -- tile2 horz page size (1 page or 2 pages)
   t2vsize     <= reg29vpsize2;  -- tile2 vert page size (1 page or 2 pages)
   t2horz      <= reg25horz;     -- tile2 horz scroll
   t2vert      <= reg26vert;     -- tile2 vert scroll

   bmlba       <= reg32bmlba;    -- bitmap layer base address
   bml_x       <= reg33bml_x;
   bml_y       <= reg34bml_y;
   bml_w       <= reg35bml_w;
   bml_h       <= reg36bml_h;
   bml_ps      <= reg31bml_ps;   -- bitmap layer palette select
   bml_en      <= reg31bml_en;   -- '1' to enable the bitmap layer
   bml_pri     <= reg31bml_pri;  -- '1' when bitmap has priority over tiles
   bml_trans   <= reg31bml_trns; -- '1' to set "00" pixels transparent
   bml_fat_o   <= reg31bml_fat;  -- '1' to set BML fat-pixel mode
end rtl;
