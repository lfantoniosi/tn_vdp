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

-- 100MHz TMS9900-compatible CPU (called the "GPU" in the F18A)
--
-- Notable differences between this implementation and the original 9900:
--
--   Does not implement all instructions.
--
--   Certain instructions are modified for alternate use.
--
--   Does not attempt to maintain original instruction timing.
--
--   The 16 general purpose registers (R0..R15) are a real register-file and
--   not implemented in RAM.
--
--   Uses a hard-coded instruction decode and control vs. a microcoded control
--   model of the original 9900.
--
--   Does not use the ALU for PC and other registers calculations.  Dedicated
--   adders are used instead.
--
-- The GPU has a not-so-great interface with the F18A host-CPU interface and
-- will be blocked at certain points to prevent VRAM contention.  This really
-- needs to be reworked, if only to make the implementation simpler (and
-- probably use less FPGA resources).
--
-- Most instructions take around 60ns to 150ns depending on memory access, and
-- have a 1-clock execute cycle.
--
-- The MUL, DIV, and Shift instructions are much faster than the original 9900
-- CPU.  The execute cycle for MUL is 1-clock (10ns) like other instructions.
-- The DIV and Shift instructions take a maximum of 16-clock cycles for the
-- execution cycle.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_gpu is
   port (
      clk            : in  std_logic;
      rst_n          : in  std_logic;     -- reset and load PC, active low
      trigger        : in  std_logic;     -- trigger the GPU
      running        : out std_logic;     -- '1' if the GPU is running, '0' when idle
      pause          : in  std_logic;     -- pause the GPU, active high
      pause_ack      : out std_logic;     -- acknowledge pause
      load_pc        : in  std_logic_vector(0 to 15);
   -- VRAM Interface
      vdin           : in  std_logic_vector(0 to 7);
      vwe            : out std_logic;
      vaddr          : out std_logic_vector(0 to 13);
      vdout          : out std_logic_vector(0 to 7);
   -- Palette Interface
      pdin           : in  std_logic_vector(0 to 11);
      pwe            : out std_logic;
      paddr          : out std_logic_vector(0 to 5);
      pdout          : out std_logic_vector(0 to 11);
   -- Register Interface
      rdin           : in  std_logic_vector(0 to 7);
      raddr          : out std_logic_vector(0 to 13);
      rwe            : out std_logic;     -- write enable for VDP registers
   -- Data inputs
      scanline       : in std_logic_vector(0 to 7);
      blank          : in std_logic;                  -- '1' when blanking (horz and vert)
      bmlba          : in std_logic_vector(0 to 7);   -- bitmap layer base address
      bml_w          : in std_logic_vector(0 to 7);   -- bitmap layer width
      pgba           : in std_logic;                  -- pattern generator base address
   -- Data output, 7-bits of user defined status
      gstatus        : out std_logic_vector(0 to 6);
   -- SPI Interface
      spi_clk        : out std_logic;
      spi_cs         : out std_logic;
      spi_mosi       : out std_logic;
      spi_miso       : in  std_logic
   );
end f18a_gpu;

architecture rtl of f18a_gpu is

   -- **NOTE**
   -- These are also defined in the CPU module to avoid using actual paths
   -- and resources to transfer a constant to the GPU module.
   constant VMAJOR   : std_logic_vector(0 to 3) := X"1";
   constant VMINOR   : std_logic_vector(0 to 3) := X"9";

   -- 2K private dedicated RAM for the GPU
   type gpuram_type is array (0 to 2047) of std_logic_vector(0 to 7);
   signal gpuram : gpuram_type := (
   x"02",x"0F",x"47",x"FE",x"10",x"0D",x"40",x"36",x"40",x"5A",x"40",x"94",x"40",x"B4",x"40",x"FA",
   x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",
   x"0C",x"A0",x"41",x"1C",x"03",x"40",x"04",x"C1",x"D0",x"60",x"3F",x"00",x"09",x"71",x"C0",x"21",
   x"40",x"06",x"06",x"90",x"10",x"F7",x"C0",x"20",x"3F",x"02",x"C0",x"60",x"3F",x"04",x"C0",x"A0",
   x"3F",x"06",x"D0",x"E0",x"3F",x"01",x"13",x"05",x"D0",x"10",x"DC",x"40",x"06",x"02",x"16",x"FD",
   x"10",x"03",x"DC",x"70",x"06",x"02",x"16",x"FD",x"04",x"5B",x"0D",x"0B",x"06",x"A0",x"40",x"B4",
   x"0F",x"0B",x"C1",x"C7",x"13",x"16",x"04",x"C0",x"D0",x"20",x"60",x"04",x"0A",x"30",x"C0",x"C0",
   x"04",x"C1",x"02",x"02",x"04",x"00",x"CC",x"01",x"06",x"02",x"16",x"FD",x"04",x"C0",x"D0",x"20",
   x"41",x"4F",x"06",x"C0",x"0A",x"30",x"A0",x"03",x"0C",x"A0",x"41",x"AC",x"D8",x"20",x"41",x"4F",
   x"B0",x"00",x"04",x"5B",x"D8",x"20",x"41",x"1A",x"3F",x"00",x"02",x"00",x"41",x"D4",x"C8",x"00",
   x"3F",x"02",x"02",x"00",x"40",x"06",x"C8",x"00",x"3F",x"04",x"02",x"00",x"40",x"10",x"C8",x"00",
   x"3F",x"06",x"04",x"5B",x"04",x"C7",x"D0",x"20",x"3F",x"01",x"13",x"13",x"C0",x"20",x"41",x"18",
   x"06",x"00",x"0C",x"A0",x"41",x"50",x"02",x"04",x"00",x"05",x"02",x"05",x"3F",x"02",x"02",x"06",
   x"41",x"40",x"8D",x"B5",x"16",x"03",x"06",x"04",x"16",x"FC",x"10",x"09",x"06",x"00",x"16",x"F1",
   x"10",x"09",x"C0",x"20",x"3F",x"02",x"0C",x"A0",x"41",x"50",x"80",x"40",x"14",x"03",x"0C",x"A0",
   x"41",x"98",x"05",x"47",x"D8",x"07",x"B0",x"00",x"04",x"5B",x"0D",x"0B",x"06",x"A0",x"40",x"B4",
   x"0F",x"0B",x"C1",x"C7",x"13",x"04",x"C0",x"20",x"3F",x"0C",x"0C",x"A0",x"41",x"AC",x"04",x"5B",
   x"05",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"02",x"00",x"41",x"10",
   x"02",x"01",x"41",x"14",x"02",x"02",x"0B",x"00",x"03",x"A0",x"32",x"02",x"32",x"30",x"32",x"30",
   x"32",x"30",x"02",x"02",x"00",x"07",x"36",x"31",x"06",x"02",x"16",x"FD",x"03",x"C0",x"0C",x"00",
   x"20",x"20",x"20",x"20",x"20",x"20",x"20",x"20",x"20",x"20",x"00",x"00",x"00",x"00",x"00",x"00",
   x"88",x"00",x"41",x"18",x"1A",x"03",x"C0",x"60",x"41",x"18",x"0C",x"00",x"0D",x"00",x"0A",x"40",
   x"02",x"01",x"0B",x"00",x"A0",x"20",x"41",x"16",x"17",x"01",x"05",x"81",x"A0",x"60",x"41",x"14",
   x"02",x"03",x"41",x"40",x"02",x"02",x"00",x"10",x"03",x"A0",x"32",x"01",x"06",x"C1",x"32",x"01",
   x"32",x"00",x"06",x"C0",x"32",x"00",x"36",x"00",x"36",x"33",x"06",x"02",x"16",x"FD",x"03",x"C0",
   x"0F",x"00",x"C0",x"60",x"41",x"18",x"0C",x"00",x"02",x"00",x"3F",x"00",x"02",x"01",x"41",x"40",
   x"02",x"02",x"00",x"08",x"CC",x"31",x"06",x"02",x"16",x"FD",x"0C",x"00",x"02",x"01",x"41",x"4A",
   x"D0",x"A0",x"41",x"4E",x"06",x"C2",x"D0",x"A0",x"41",x"4D",x"02",x"03",x"0B",x"00",x"03",x"A0",
   x"32",x"03",x"32",x"31",x"32",x"31",x"32",x"31",x"36",x"01",x"36",x"30",x"06",x"02",x"16",x"FD",
   x"03",x"C0",x"0C",x"00",x"03",x"40",
   -- 470 bytes
   others => (others => '0'));

   -- The workspace registers are *real* in this implementation. :)
   type regfile_type is array (0 to 15) of std_logic_vector(0 to 15);
   signal regfile : regfile_type := (
      x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
      x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000");

   -- Main FSM state control.
   type cpu_state_type is (
      st_cpu_idle, st_cpu_fetch, st_cpu_fetch_msb, st_cpu_fetch_lsb, st_cpu_latch_ir, st_cpu_decode,
      st_cpu_resolve_src, st_cpu_save_src, st_cpu_resolve_dst, st_cpu_save_dst,
      st_cpu_alu_op, st_cpu_alu_to_ws, st_cpu_alu_to_mem, st_cpu_alu_to_mem_lsb,
      st_cpu_status, st_cpu_b_op,

      st_cpu_x_op,
      st_cpu_mpy_op, st_cpu_mpy_dst, st_cpu_mpy_wait, st_cpu_mpy_msb, st_cpu_mpy_done,
      st_cpu_div_op, st_cpu_div_msb, st_cpu_div_wait, st_cpu_div_done,
      st_cpu_shift_op, st_cpu_shift_count, st_cpu_shift_done,
      st_cpu_spi_op, st_cpu_spi_wait,
      st_cpu_pix_op, st_cpu_pix_set, st_cpu_pix_read, st_cpu_pix_write, st_cpu_pix_done,

      st_cpu_load_immd, st_cpu_load_immd_msb, st_cpu_load_immd_lsb,

      st_cpu_mem_wr, st_cpu_mem_wri, st_cpu_mem_wri_msb, st_cpu_mem_wri_lsb, st_cpu_mem_wri_done,

      st_cpu_mem_sym, st_cpu_mem_sym_msb1, st_cpu_mem_sym_lsb1,
      st_cpu_mem_sym_msb2, st_cpu_mem_sym_lsb2, st_cpu_mem_sym_done,

      st_cpu_mem_idx, st_cpu_mem_idx_msb1, st_cpu_mem_idx_lsb1, st_cpu_mem_idx_ea,
      st_cpu_mem_idx_msb2, st_cpu_mem_idx_lsb2, st_cpu_mem_idx_done
   );

   signal cpu_state           : cpu_state_type;
   signal cpu_state_hold      : cpu_state_type;
   signal cpu_state_return    : cpu_state_type;
   signal src_state_sel       : cpu_state_type;
   signal dst_state_sel       : cpu_state_type;
   signal cpu_state_alu_store : cpu_state_type;
   signal cpu_state_t0        : cpu_state_type;    -- after decode
   signal cpu_state_t1        : cpu_state_type;    -- after src
   signal cpu_state_t2        : cpu_state_type;    -- after dst
   signal cpu_state_t3        : cpu_state_type;    -- after alu
   signal cpu_state_t4        : cpu_state_type;    -- after store
   signal hold                : std_logic;
   signal pause_req           : std_logic;
   signal pause_ack_reg       : std_logic;
   signal running_reg         : std_logic;
   signal bl_op_en            : std_logic;      -- '1' for branch and link operation
   signal rtwp_en             : std_logic;      -- '1' for the RTWP instruction
   signal jump_op_en          : std_logic;      -- '1' for a jump operation
   signal immd_to_src         : std_logic;      -- '1' to assign an immediate value as the src vs dst

   -- Decoder priority encoder.
   type format_type is (format1, format2, format3, format4, format5, format6, format7);
   signal format : format_type;
   signal format_next : format_type;

   -- ALU control.
   type alu_ctrl_type is (
      alu_mov, alu_add, alu_sub, alu_cmp, alu_coc, alu_inc, alu_inct,
      alu_dec, alu_dect, alu_andi, alu_czc, alu_andn, alu_or, alu_xor,
      alu_clr, alu_seto, alu_inv, alu_neg, alu_swpb, alu_abs, alu_div,
      alu_shift
   );
   signal alu_ctrl : alu_ctrl_type;
   signal alu_next : alu_ctrl_type;

   -- Jump control.
   type jump_ctrl_type is (
      jump_jmp, jump_jlt, jump_jle, jump_jeq, jump_jhe, jump_jgt, jump_jne,
      jump_jnc, jump_joc, jump_jno, jump_jl, jump_jh, jump_jop
   );
   signal jump_ctrl : jump_ctrl_type;
   signal take_jump : std_logic;

   -- Memory address register mux control.
   type mar_ctrl_type is (ctrl_mar_pc, ctrl_mar_t1);
   signal mar_ctrl : mar_ctrl_type;

   -- GPU dedicated RAM
   signal gaddr      : std_logic_vector(0 to 10);
   signal gdout      : std_logic_vector(0 to 7);
   signal gdin       : std_logic_vector(0 to 7);
   signal gwe_reg    : std_logic;
   signal gwe_next   : std_logic;

   -- Workspace register file
   signal ws_addr    : std_logic_vector(0 to 3) := "0000";  -- Default to keep simulation quiet
   signal ws_dst     : std_logic_vector(0 to 3);   -- destination ws reg
   signal ws_dout    : std_logic_vector(0 to 15);
   signal ws_dout_inc: std_logic_vector(0 to 15);
   signal ws_din     : std_logic_vector(0 to 15);
   signal ws_din_mux : std_logic_vector(0 to 15);
   signal ws_dst_save: std_logic_vector(0 to 15);  -- original dst ws reg value for byte ops
   signal ws_we      : std_logic;

   -- Stack support
   signal ws_inc_flag      : std_logic;            -- '1' to inc ws reg, '0' to dec
   signal ws_pre_flag      : std_logic;            -- '1' to pre inc/dec ws reg
   signal stack_to_pc_en   : std_logic;            -- '1' to store the stack op to the PC (ret)
   signal pc_to_stack_en   : std_logic;            -- '1' to store the PC on the stack (call)

   -- Memory addressing
   signal mar        : std_logic_vector(0 to 15);  -- memory address register
   signal mar_sel    : std_logic_vector(0 to 3);
   signal mar_low4   : std_logic_vector(0 to 3);
   signal mem_din    : std_logic_vector(0 to 7);   -- memory data in
   signal mem_dout   : std_logic_vector(0 to 7);   -- memory data out

   signal rdin_reg   : std_logic_vector(0 to 7);   -- VDP register read data in

   signal gstatus_reg: std_logic_vector(0 to 6);   -- 7-bits of user defined status

   signal blank_reg  : std_logic;                  -- register the blank input

   -- Write enable registers for external memory
   signal vwe_reg    : std_logic;                  -- VRAM write enable register
   signal rwe_reg    : std_logic;                  -- VDP-register write enable register
   signal pwe_reg    : std_logic;                  -- palette write enable, word ops only
   signal swe_reg    : std_logic;                  -- gpu status write enable

   signal vwe_next   : std_logic;
   signal rwe_next   : std_logic;
   signal pwe_next   : std_logic;
   signal swe_next   : std_logic;

   signal pc         : std_logic_vector(0 to 15);  -- program counter
   signal pc_inc     : std_logic_vector(0 to 15);  -- program counter + 1
   signal pc_jump    : std_logic_vector(0 to 15);  -- program counter + jump displacement

   signal ir         : std_logic_vector(0 to 15);  -- instruction register
   signal t1         : std_logic_vector(0 to 15);  -- temp 1
   signal t2         : std_logic_vector(0 to 15);  -- temp 2
   signal ea_t1t2    : std_logic_vector(0 to 15);  -- t1 + t2
   signal ea_src     : std_logic_vector(0 to 15);  -- effective address of the source
   signal ea_dst     : std_logic_vector(0 to 15);  -- effective address of the destination

   -- Opcode Decoding
   signal byte_next  : std_logic;
   signal force_byte : std_logic;                  -- force a byte selector
   signal byte       : std_logic;                  -- byte selector
   signal Td         : std_logic_vector(0 to 1);   -- destination mode: Td
   signal D          : std_logic_vector(0 to 3);   -- destination: D or C
   signal Ts         : std_logic_vector(0 to 1);   -- source mode: Ts
   signal S          : std_logic_vector(0 to 3);   -- source: S or W
   signal C          : std_logic_vector(0 to 3);   -- count: C
   signal disp       : std_logic_vector(0 to 7);   -- signed jump displacement

   signal Ts_next    : std_logic_vector(0 to 1);   -- provide a Ts override
   signal S_next     : std_logic_vector(0 to 3);   -- provide a S override
   signal Td_next    : std_logic_vector(0 to 1);   -- provide a Td override
   signal D_next     : std_logic_vector(0 to 3);   -- provide a D override

   -- Shifter
   type shift_ctrl_type is (shift_sla, shift_slc, shift_srl, shift_sra, shift_src);
   signal shift_ctrl : shift_ctrl_type;
   signal shift_next : shift_ctrl_type;

   signal shift_cnt        : integer range 0 to 16;
   signal shift_cnt_init   : integer range 0 to 16;

   signal shift_reg        : std_logic_vector(0 to 15);
   signal shift_carry      : std_logic;
   signal shift_dir        : std_logic;
   signal shift_bit        : std_logic;
   signal shift_load       : std_logic;
   signal shift_done       : std_logic;
   signal shift_msb        : std_logic;
   signal shift_overflow   : std_logic;

   -- ALU
   signal alu_out    : std_logic_vector(0 to 16);  -- ALU result, 17-bit to include the carry bit
   signal alu_reg    : std_logic_vector(0 to 15);  -- ALU result register
   signal src_oper   : std_logic_vector(0 to 15);  -- source operand
   signal alu_sa     : std_logic_vector(0 to 15);  -- source value to ALU
   signal alu_sa_n   : std_logic_vector(0 to 15);  -- inverted source value to ALU
   signal dst_oper   : std_logic_vector(0 to 15);  -- destination operand
   signal alu_da     : std_logic_vector(0 to 15);  -- destination value to ALU
   signal alu_to_ws  : std_logic;                  -- write the ALU result to ws reg vs memory
   signal alu_carry  : std_logic;                  -- ALU carry bit

   -- Multiply
   signal mpy_out    : std_logic_vector(0 to 31);  -- 32-bit multiply result
-- signal mac_r, mac_x : std_logic_vector(0 to 31);-- 32-bit multiply-accumulate
-- signal mac_clr_r, mac_clr_x : std_logic;        -- MAC clear

   -- Divide
   signal div_overflow  : std_logic;
   signal div_reset     : std_logic;
   signal div_start     : std_logic;
   signal div_done      : std_logic;
   signal div_rmd       : std_logic_vector(0 to 15);
   signal div_quo       : std_logic_vector(0 to 15);

   -- Source and destination flags
   signal auto_inc   : std_logic;                  -- auto increment destination
   signal src_is_ws  : std_logic;                  -- write src to ws reg vs memory
   signal src_autoinc: std_logic;                  -- auto increment source
   signal dst_is_ws  : std_logic;                  -- write dst to ws reg vs memory
   signal dst_autoinc: std_logic;                  -- auto increment destination

   -- Equality tests for status flags
   signal sa_eq_da      : std_logic;
   signal sa_msb_eq_da  : std_logic;
   signal sa_eq_8000    : std_logic;
   signal sa_eq_zero    : std_logic;
   signal da_eq_zero    : std_logic;
   signal alu_eq_zero   : std_logic;
   signal alu_msb_eq_da : std_logic;

   -- Status flags
   signal LGT           : std_logic := '0';        -- defaults to keep simulation quite
   signal AGT           : std_logic := '0';
   signal EQUAL         : std_logic := '0';
   signal CARRY         : std_logic := '0';
   signal OVFLW         : std_logic := '0';
   signal PARITY        : std_logic := '0';
   signal LGT_next      : std_logic := '0';
   signal AGT_next      : std_logic := '0';
   signal EQUAL_next    : std_logic := '0';
   signal CARRY_next    : std_logic := '0';
   signal OVFLW_next    : std_logic := '0';
   signal PARITY_next   : std_logic := '0';

   signal status_sel    : std_logic;
   signal status_bits   : std_logic_vector(0 to 5);

   -- DMA data
   signal dwe_r, dwe_x                    : std_logic;
   signal dma_src_r, dma_src_x, dma_src_s : std_logic_vector(0 to 15);
   signal dma_src_msb_r, dma_src_msb_x    : std_logic_vector(0 to 7);
   signal dma_src_lsb_r, dma_src_lsb_x    : std_logic_vector(0 to 7);
   signal dma_dst_r, dma_dst_x, dma_dst_s : std_logic_vector(0 to 15);
   signal dma_dst_msb_r, dma_dst_msb_x    : std_logic_vector(0 to 7);
   signal dma_dst_lsb_r, dma_dst_lsb_x    : std_logic_vector(0 to 7);
   signal dma_w_r, dma_w_x                : std_logic_vector(0 to 7);
   signal dma_h_r, dma_h_x                : std_logic_vector(0 to 7);
   signal dma_stride_r, dma_stride_x      : std_logic_vector(0 to 7);
   signal dma_copy_r, dma_copy_x          : std_logic;   -- '0' for src -> dst copy, otherwise '1' for dst fill.
   signal dma_inc_r, dma_inc_x            : std_logic;   -- '0' for address increment, otherwise '0' for decrement.

   signal dma_step_s                      : std_logic_vector(0 to 15);
   signal dma_w_minus_1_s                 : std_logic_vector(0 to 7);
   signal dma_diff_r, dma_diff_x, dma_diff_s : std_logic_vector(0 to 7);
   signal dma_diff_sign_s                 : std_logic_vector(0 to 7);
   signal dma_w_cnt_r, dma_w_cnt_x        : std_logic_vector(0 to 7);
   signal dma_w_rst_r, dma_w_rst_x        : std_logic_vector(0 to 7);
   signal dma_h_cnt_r, dma_h_cnt_x        : std_logic_vector(0 to 7);

   signal dma_data_r, dma_data_x, dma_data_s : std_logic_vector(0 to 7);

   -- DMA control
   type dma_type is (DMA_IDLE, DMA_WAIT, DMA_SRC, DMA_DST);
   signal dma_r, dma_x     : dma_type;
   signal dma_pause_ack_s  : std_logic;   -- '1' when the DMA acknowledges a CPU pause request
   signal dma_active_s     : std_logic;   -- '1' when the DMA is active
   signal dma_mar_s        : std_logic;   -- '1' when the VRAM MAR will use the DMA address
   signal dma_we_s         : std_logic;
   signal dma_addr_s       : std_logic_vector(0 to 15);
   signal dma_pause_r, dma_pause_s : std_logic;
   signal dma_trig_r, dma_trig_x : std_logic;


   -- SPI
   type spi_state_type is (st_spi_idle, st_spi_clk1, st_spi_clk0, st_spi_done);
   signal spi_state : spi_state_type;

   signal spi_cs_reg    : std_logic;
   signal spi_cs_next   : std_logic;

   signal spi_clk_reg   : std_logic;
   signal spi_counter   : integer range 0 to 7;

   signal spi_en        : std_logic;
   signal spi_done      : std_logic;

   signal spi_din       : std_logic_vector(0 to 7);
   signal spi_dout      : std_logic_vector(0 to 7);

   -- Bitmap layer calculations
   signal wmul_zadj_s   : std_logic;
   signal wmul9bit      : std_logic_vector(0 to 8);
   signal wmul_x, wmul_r: std_logic_vector(0 to 7);
   signal bml_yoff      : std_logic_vector(0 to 15);
   signal bml_addr      : std_logic_vector(0 to 15);
   signal gm2_addr      : std_logic_vector(0 to 15);

   signal pix_eq        : std_logic;
   signal pix_in        : std_logic_vector(0 to 1);
   signal pix_out       : std_logic_vector(0 to 7);

begin

   -- Bitmap layer pixel address calculation
   -- src_oper contains the x,y location, t2 is same as src_oper
   -- ws_dout contains the options and new pixel

   -- x
   -- y
   -- w = width of bitmap in pixels
   -- wmul = y multiplier

   -- wmul = (w + 3) >> 2   The '3' is because w + 3 == w - 1 + 4
   -- byte = (y * wmul) + (x >> 2)
   -- pixel index in byte = x & 0x03
   wmul_zadj_s <= '1' when bml_w = 0 else '0';
   wmul9bit <= (wmul_zadj_s & bml_w) + 3;       -- w + 3
   wmul_x <= '0' & wmul9bit(0 to 6);            -- divide by 4 and reduce to 8-bit
   process (clk) begin if rising_edge(clk) then
      wmul_r <= wmul_x;
      -- using t2 to break a link between the multiplier and mem_din via src_oper.
      bml_yoff <= t2(8 to 15) * wmul_r;      -- y_offset from base address, 8x8x16 multiplier
   end if; end process;
   -- Keep the address in the VRAM.
   bml_addr <= "00" & ((bmlba & "000000") + bml_yoff(2 to 15) + ("00000000" & src_oper(0 to 5)));

   --      ws_dout
   -- 01234567 89012345
   -- MAxxRWCE xxOOxxPP

   -- Mix the new pixel with the existing data.  There are two reasons
   -- vdin is used over the mem_din mux.  The first, and most important,
   -- is to prevent a long setup constraint caused when mem_din was used.
   -- There are too many unrelated signals coming in to the mem_din mux.
   -- However, using vdin for pix_in/pix_out (and pix_eq) consumes about
   -- 2% more slices than using mem_din...  The other reason is, the PIX
   -- instruction really only works with VRAM, which does *NOT* include
   -- the GPU RAM.
   process (src_oper, vdin, ws_dout) begin
   case src_oper(6 to 7) is
   when "00"   => pix_in   <= vdin(0 to 1);
                  pix_out  <= ws_dout(14 to 15) & vdin(2 to 7);
                  if ws_dout(10 to 11) = vdin(0 to 1) then
                     pix_eq <= ws_dout(6) and ws_dout(7); else
                     pix_eq <= ws_dout(6) and (not ws_dout(7)); end if;
   when "01"   => pix_in   <= vdin(2 to 3);
                  pix_out  <= vdin(0 to 1) & ws_dout(14 to 15) & vdin(4 to 7);
                  if ws_dout(10 to 11) = vdin(2 to 3) then
                     pix_eq <= ws_dout(6) and ws_dout(7); else
                     pix_eq <= ws_dout(6) and (not ws_dout(7)); end if;
   when "10"   => pix_in   <= vdin(4 to 5);
                  pix_out  <= vdin(0 to 3) & ws_dout(14 to 15) & vdin(6 to 7);
                  if ws_dout(10 to 11) = vdin(4 to 5) then
                     pix_eq <= ws_dout(6) and ws_dout(7); else
                     pix_eq <= ws_dout(6) and (not ws_dout(7)); end if;
   when "11"   => pix_in   <= vdin(6 to 7);
                  pix_out  <= vdin(0 to 5) & ws_dout(14 to 15);
                  if ws_dout(10 to 11) = vdin(6 to 7) then
                     pix_eq <= ws_dout(6) and ws_dout(7); else
                     pix_eq <= ws_dout(6) and (not ws_dout(7)); end if;
   when others => null;
   end case; end process;

   -- Calculate the original GM2 byte based on x,y coords.  Only the MSb of the
   -- pattern base from VR4 is used, so the table starts at 0K or 8K.
   -- src_oper contains the x,y values
   --
   --  0  1  2  3  4  5  6  7| 8  9 10 11 12 13 14 15
   -- X0 X1 X2 X3 X4 X5 X6 X7|Y0 Y1 Y2 Y3 Y4 Y5 Y6 Y7
   --
   gm2_addr <= "00" & (
      (pgba & src_oper(8 to 12) & "00000" & src_oper(13 to 15)) +    -- y / 8 * 256 + (y % 8)
      ("0000" & src_oper(0 to 4) & "000"));                          -- + (x AND >F8) (mask out the pixel index bits)


   -- SPI
   -- Always 8-bits
   -- 50MHz (clk/2)
   -- CKON, CKOF instructions control the CS line
   -- LDCR write 1 byte to the SPI
   -- STCR reads 1 byte from the SPI
   -- Holds the GPU until SPI is done (160ns due to 50MHz clk)
   -- Not affected by CPU pause request
   spi_cs <= spi_cs_reg;
   spi_clk <= spi_clk_reg;

   -- The output data is always the MSb of the data.
   spi_mosi <= 'Z' when spi_state = st_spi_idle else spi_dout(0);

   process (clk) begin if rising_edge(clk) then
      if rst_n = '0' then
         spi_state <= st_spi_idle;
         spi_clk_reg <= '0';
         spi_done <= '0';
      else
      case spi_state is

      when st_spi_idle =>
         spi_state <= st_spi_idle;
         spi_done <= '0';
         spi_clk_reg <= '0';
         spi_counter <= 0;
         spi_dout <= src_oper(0 to 7);

         if spi_en = '1' then
            spi_state <= st_spi_clk1;
         end if;

      when st_spi_clk1 =>
         spi_state <= st_spi_clk0;
         spi_clk_reg <= '1';
         -- Read data in on the rising edge.
         spi_din <= spi_din(1 to 7) & spi_miso;

         -- Count and test for done.
         spi_counter <= spi_counter + 1;
         if spi_counter = 7 then
            spi_state <= st_spi_done;
            spi_done <= '1';
         end if;

      when st_spi_clk0 =>
         spi_state <= st_spi_clk1;
         spi_clk_reg <= '0';
         -- Change the data out on the falling edge.
         spi_dout <= spi_dout(1 to 7) & '0';

      when st_spi_done =>
         -- Wait for the GPU to take down the spi_en flag.
         spi_state <= st_spi_done;
         spi_clk_reg <= '0';
         if spi_en = '0' then
            spi_state <= st_spi_idle;
         end if;

      end case;
      end if;
   end if; end process;


   -- DMA
   -- 8xx0 - MSB src
   -- 8xx1 - LSB src
   -- 8xx2 - MSB dst
   -- 8xx3 - LSB dst
   -- 8xx4 - width
   -- 8xx5 - height
   -- 8xx6 - stride
   -- 8xx7 - 0..5 | !INC/DEC | !COPY/FILL
   -- 8xx8 - trigger
   --
   -- src, dst, width, height, stride are copied to dedicated counters when
   -- the DMA is triggered, thus the original values remain unchanged.

   -- Write access to the DMA registers.
   process (mar, mem_dout, dwe_r, dma_r, dma_trig_r,
   dma_src_msb_r, dma_src_lsb_r, dma_dst_msb_r, dma_dst_lsb_r, dma_w_r, dma_h_r,
   dma_stride_r, dma_copy_r, dma_inc_r)
   begin

      dma_src_msb_x  <= dma_src_msb_r;
      dma_src_lsb_x  <= dma_src_lsb_r;
      dma_dst_msb_x  <= dma_dst_msb_r;
      dma_dst_lsb_x  <= dma_dst_lsb_r;
      dma_w_x        <= dma_w_r;
      dma_h_x        <= dma_h_r;
      dma_stride_x   <= dma_stride_r;
      dma_copy_x     <= dma_copy_r;
      dma_inc_x      <= dma_inc_r;

      dma_trig_x <= '0';

      if dwe_r = '1' then
         case mar(12 to 15) is
         when x"0" => dma_src_msb_x    <= mem_dout;
         when x"1" => dma_src_lsb_x    <= mem_dout;
         when x"2" => dma_dst_msb_x    <= mem_dout;
         when x"3" => dma_dst_lsb_x    <= mem_dout;
         when x"4" => dma_w_x          <= mem_dout;
         when x"5" => dma_h_x          <= mem_dout;
         when x"6" => dma_stride_x     <= mem_dout;
         when x"7" => dma_inc_x        <= mem_dout(6);
                      dma_copy_x       <= mem_dout(7);
         when x"8" => dma_trig_x       <= '1';
         when others => null;
         end case;
      end if;
   end process;

   process (clk) begin if rising_edge(clk) then
      dma_src_msb_r  <= dma_src_msb_x;
      dma_src_lsb_r  <= dma_src_lsb_x;
      dma_dst_msb_r  <= dma_dst_msb_x;
      dma_dst_lsb_r  <= dma_dst_lsb_x;
      dma_w_r        <= dma_w_x;
      dma_h_r        <= dma_h_x;
      dma_stride_r   <= dma_stride_x;
      dma_copy_r     <= dma_copy_x;
      dma_inc_r      <= dma_inc_x;
      dma_trig_r     <= dma_trig_x;
   end if; end process;

   -- +1 or -1 depending on the !INC/DEC flag.
   dma_step_s <= x"0001" when dma_inc_r = '0' else x"FFFF";

   -- Calculate stride-(w-1) for positive direction or (w-1)-stride for negative.
   dma_w_minus_1_s <= dma_w_r - 1;

   with dma_inc_r select
   dma_diff_s <=
      (dma_stride_r - dma_w_minus_1_s) when '0',
      (dma_w_minus_1_s - dma_stride_r) when others;

   -- Sign extend the step value.
   dma_diff_sign_s <=
      dma_diff_r(0) & dma_diff_r(0) & dma_diff_r(0) & dma_diff_r(0) &
      dma_diff_r(0) & dma_diff_r(0) & dma_diff_r(0) & dma_diff_r(0);

   process ( dma_w_cnt_r, dma_step_s, dma_src_r, dma_dst_r, dma_diff_sign_s, dma_diff_r )
   begin
      dma_src_s <= dma_src_r + dma_step_s;
      dma_dst_s <= dma_dst_r + dma_step_s;

      -- When the width counter is 1, add the stride difference.
      if dma_w_cnt_r = 1 then
         dma_src_s <= dma_src_r + (dma_diff_sign_s & dma_diff_r);
         dma_dst_s <= dma_dst_r + (dma_diff_sign_s & dma_diff_r);
      end if;
   end process;

   -- DMA address select.
   dma_addr_s <= dma_dst_r when dma_r = DMA_DST else dma_src_r;

   -- When copying source to destination, tie the VRAM input
   -- directly back out to the output to allow the fastest
   -- two-cycle read/write.
   dma_data_s <= vdin when dma_copy_r = '0' else dma_data_r;

   dma_we_s <= '1' when dma_r = DMA_DST else '0';

   -- DMA FSM
   -- DMA is limited to 16K VRAM to avoid mem_din mux.
   process (vdin, dma_data_r, pause_ack_reg,
   dma_r, dma_trig_r, dma_pause_s, dma_copy_r, dma_src_r, dma_dst_r,
   dma_src_msb_r, dma_src_lsb_r, dma_dst_msb_r, dma_dst_lsb_r,
   dma_w_r, dma_h_r, dma_w_cnt_r, dma_w_rst_r, dma_h_cnt_r,
   dma_diff_r, dma_diff_s, dma_src_s, dma_dst_s)
   begin

      dma_x          <= dma_r;
      dma_src_x      <= dma_src_r;
      dma_dst_x      <= dma_dst_r;
      dma_w_cnt_x    <= dma_w_cnt_r;
      dma_w_rst_x    <= dma_w_rst_r;
      dma_h_cnt_x    <= dma_h_cnt_r;
      dma_diff_x     <= dma_diff_r;
      dma_data_x     <= dma_data_r;

      dma_active_s <= '1';
      dma_mar_s <= '1';
      dma_pause_ack_s <= '0';

      case dma_r is

      when DMA_IDLE =>

         -- Load when the DMA is idle.
         dma_src_x   <= dma_src_msb_r & dma_src_lsb_r;
         dma_dst_x   <= dma_dst_msb_r & dma_dst_lsb_r;
         dma_w_cnt_x <= dma_w_r;
         dma_w_rst_x <= dma_w_r;
         dma_h_cnt_x <= dma_h_r;
         dma_diff_x  <= dma_diff_s;

         dma_mar_s <= '0';       -- '0' until the GPU acknowledges it has paused

         if dma_trig_r = '1' then
            dma_x <= DMA_WAIT;
         else
            dma_active_s <= '0';
            dma_pause_ack_s <= '1';
         end if;

      when DMA_WAIT =>

         if pause_ack_reg = '1' then
            dma_x <= DMA_SRC;
         else
            dma_mar_s <= '0';    -- '0' until the GPU acknowledges it has paused
         end if;

      when DMA_SRC =>

         -- Pausing must happen during the source state.
         if dma_pause_s = '1' then
            dma_pause_ack_s <= '1';
         else
            dma_src_x <= dma_src_s;
            dma_x <= DMA_DST;
            dma_data_x <= vdin;     -- Save the source byte for fill only operations.
         end if;

      when DMA_DST =>

         dma_dst_x <= dma_dst_s;

         if dma_w_cnt_r = 1 then
            dma_w_cnt_x <= dma_w_rst_r;
            dma_h_cnt_x <= dma_h_cnt_r - 1;
         else
            dma_w_cnt_x <= dma_w_cnt_r - 1;
         end if;

         if dma_h_cnt_r = 1 and dma_w_cnt_r = 1 then
            dma_x <= DMA_IDLE;
         else
            if dma_copy_r = '0' then
               dma_x <= DMA_SRC;
            else
               dma_x <= DMA_DST;

               -- Pausing is fine during the destination state if the source
               -- is a fixed value, otherwise the pause acknowledge will be
               -- delayed until the source state.
               if dma_pause_s = '1' then
                  dma_pause_ack_s <= '1';
               end if;
            end if;
         end if;

      end case;
   end process;

   -- Delay the release of the pause signal for one extra clock cycle
   -- to allow the DMA to reassert any addressing it was doing when
   -- it was paused.
   dma_pause_s <= pause or dma_pause_r;

   process (clk) begin if rising_edge(clk) then
      -- Pause is always transferred.
      dma_pause_r <= pause;

      if dma_pause_ack_s = '0' then
         dma_r          <= dma_x;
         dma_src_r      <= dma_src_x;
         dma_dst_r      <= dma_dst_x;
         dma_w_cnt_r    <= dma_w_cnt_x;
         dma_w_rst_r    <= dma_w_rst_x;
         dma_h_cnt_r    <= dma_h_cnt_x;
         dma_diff_r     <= dma_diff_x;
         dma_data_r     <= dma_data_x;
      end if;
   end if;
   end process;


   -- GPU RAM
   process (clk) begin if rising_edge(clk) then
      gdout <= gpuram(to_integer(unsigned(gaddr)));
      if gwe_reg = '1' then
         gpuram(to_integer(unsigned(gaddr))) <= gdin;
      end if;
   end if;
   end process;


   -- Workspace Register File as distributed RAM
   process (clk) begin
   if rising_edge(clk) then
      if ws_we = '1' then
         regfile(to_integer(unsigned(ws_addr))) <= ws_din;
      end if;
   end if;
   end process;

   -- Infer distributed RAM by reading asynchronously.
   ws_dout <= regfile(to_integer(unsigned(ws_addr)));
   ws_dout_inc <=
      ws_dout + 1 when byte = '1' else
      ws_dout + 2 when ws_inc_flag = '1' else
      ws_dout - 2;
   ws_din <= t1;

   -- Workspace register file data input mux.
   ws_din_mux <= alu_reg when byte = '0' else (alu_reg(0 to 7) & ws_dst_save(8 to 15));


   -- MAR (Memory Address Register) MUX
   process (mar_ctrl, dma_mar_s, dma_addr_s, pc, t1) begin
      if dma_mar_s = '1' then
         mar <= dma_addr_s;
      else
         case mar_ctrl is
         when ctrl_mar_pc => mar <= pc;
         when ctrl_mar_t1 => mar <= t1;
         end case;
      end if;
   end process;

   -- Address building
   -- VRAM 14-bit, 16K @ >0000 to >3FFF (0011 1111 1111 1111)
   -- GRAM 11-bit, 2K  @ >4000 to >47FF (0100 x111 1111 1111)
   -- PRAM  7-bit, 128 @ >5000 to >5x7F (0101 xxxx x111 1111)
   -- VREG  6-bit, 64  @ >6000 to >6x3F (0110 xxxx xx11 1111)
   -- current scanline @ >7000 to >7xx0 (0111 xxxx xxxx xxx0)
   -- blanking         @ >7001 to >7xx1 (0111 xxxx xxxx xxx1)
   -- DMA              @ >8000 to >8xx7 (1000 xxxx xxxx 0111)
   -- MAC              @ >9000 to >9003 (1001 xxxx xxxx xx11)
   -- F18A version     @ >A000 to >Axxx (1010 xxxx xxxx xxxx)
   -- GPU status data  @ >B000 to >Bxxx (1011 xxxx xxxx xxxx)
   vaddr <= mar(2 to 15);              -- Instruction addressing is only from VRAM and GRAM
   gaddr <= mar(5 to 15);              -- Instruction addressing is only from VRAM and GRAM
   paddr <= ea_dst(9 to 14);           -- Palette access is always the real address, word aligned
   raddr <= t1(10 to 15) & mem_dout;   -- Register addressing will always be T1 and never the PC

   vdout <= mem_dout when dma_mar_s = '0' else dma_data_s;
   gdin <= mem_dout;
   pdout <= alu_reg(4 to 15);       -- Palette RAM is 12-bit ----rrrrggggbbbb

   gstatus <= gstatus_reg;          -- 7-bits of user defined status
   process (clk) begin if rising_edge(clk) then
      if swe_reg = '1' then gstatus_reg <= mem_dout(1 to 7); end if;
   end if; end process;

   -- Registered write enables to prevent glitches from
   -- causing sporadic writes.
   vwe <= vwe_reg when dma_mar_s = '0' else dma_we_s;    -- VRAM
   pwe <= pwe_reg;   -- Palette RAM
   rwe <= rwe_reg;   -- VDP Registers

   -- Memory write enable selection based on the stored
   -- destination effective address.
   process (ea_dst)
   begin

      vwe_next <= '0';
      gwe_next <= '0';
      pwe_next <= '0';
      rwe_next <= '0';
      dwe_x <= '0';
      swe_next <= '0';
--    mac_clr_x <= '0';

      case ea_dst(0 to 3) is
      when x"0" |
           x"1" |
           x"2" |
           x"3" => vwe_next <= '1';    -- VRAM
      when x"4" => gwe_next <= '1';    -- GRAM (local, private)
      when x"5" => pwe_next <= '1';    -- Palette RAM
      when x"6" => rwe_next <= '1';    -- VDP Registers
      --   x"7" is the current scan line and is read-only
      when x"8" => dwe_x <= '1';       -- DMA registers
--    when x"9" => mac_clr_x <= '1';   -- MAC clear
      --   x"A" F18A version and is read-only
      when x"B" => swe_next <= '1';    -- 7-bits of user defined status
      when others => null;
      end case;
   end process;

   -- Data In and write enable selector
   -- Selection is 1-cycle behind the current address since the data
   -- visible in the current state was addressed in the previous state.
   process (clk) begin if rising_edge(clk) then
      mar_sel <= mar(0 to 3);
      mar_low4 <= mar(12 to 15);
      rdin_reg <= rdin;
      blank_reg <= blank;        -- register to break long path delay
   end if; end process;

   process (mar_sel, mar_low4, vdin, gdout, pdin, rdin_reg, blank_reg, scanline, --version, --mac_r,
   dma_src_msb_r, dma_src_lsb_r, dma_dst_msb_r, dma_dst_lsb_r, dma_w_r, dma_h_r, dma_stride_r,
   dma_inc_r, dma_copy_r)
   begin
      mem_din <= (others => '0');
      case mar_sel is
      when x"0" |
           x"1" |
           x"2" |
           x"3" =>   mem_din <= vdin;           -- VRAM
      when x"4" =>   mem_din <= gdout;          -- GRAM (local, private)
      when x"5" =>                              -- Palette RAM
         -- Return the MSB or LSB of the palette register depending
         -- on which byte is being addressed.  Palette access only
         -- works correctly with word instructions.
         if mar_low4(3) = '0' then
                     mem_din <= "0000" & pdin(0 to 3); else
                     mem_din <= pdin(4 to 11); end if;
      when x"6" =>   mem_din <= rdin_reg;       -- register read! :-)
      when x"7" =>
         if mar_low4(3) = '0' then
                     mem_din <= scanline; else  -- current scan line (y raster)
                     mem_din <= "0000000" & blank_reg; end if;
      when x"8" =>                              -- DMA
         case mar_low4 is
         when x"0" => mem_din <= dma_src_msb_r;
         when x"1" => mem_din <= dma_src_lsb_r;
         when x"2" => mem_din <= dma_dst_msb_r;
         when x"3" => mem_din <= dma_dst_lsb_r;
         when x"4" => mem_din <= dma_w_r;
         when x"5" => mem_din <= dma_h_r;
         when x"6" => mem_din <= dma_stride_r;
         when x"7" => mem_din <= ("000000" & dma_inc_r & dma_copy_r);
         when others => null;
         end case;
--    when x"9" =>                              -- MAC
--       case mar_low4 is
--       when x"0" => mem_din <= mac_r(0 to 7); -- MSB
--       when x"1" => mem_din <= mac_r(8 to 15);
--       when x"2" => mem_din <= mac_r(16 to 23);
--       when x"3" => mem_din <= mac_r(24 to 31);
--       when others => mem_din <= x"00";
--       end case;
      when x"A" =>   mem_din <= VMAJOR & VMINOR; -- version;        -- F18A version
      when others => null;
      end case;
   end process;


   --          0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |11 |12 |13 |14 |15 |
   --         ---------------------------------------------------------------+
   -- 1 arith  1 |opcode | B |  Td   |       D       |  Ts   |       S       |
   -- 2 arith  0   1 |opc| B |  Td   |       D       |  Ts   |       S       |
   -- 3 math   0   0   1 | --opcode- |     D or C    |  Ts   |       S       |
   -- 4 jump   0   0   0   1 | ----opcode--- |     signed displacement       |
   -- 5 shift  0   0   0   0   1 | --opcode- |       C       |       W       |
   -- 5 stack* 0   0   0   0   1 | 1 ------opcode--- | Ts/Td |      S/D      |
   -- 6 pgm    0   0   0   0   0   1 | ----opcode--- |  Ts   |       S       |
   -- 7 ctrl   0   0   0   0   0   0   1 | ----opcode--- |     not used      |
   -- 7 ctrl   0   0   0   0   0   0   1 | opcode & immd | X |       W       |
   --
   -- The stack format is new for added opcodes.  The original four shift
   -- opcodes have a '0' in bit-5, but have 3-bits for the instruction
   -- selection.  So, using bit-5 as a '1' allows detection of the new
   -- instructions and modifies the remaining bits to specify the src or
   -- dst of the operation, since the stack always works with R15.

   -- The Win994a simulator extensions for memory paging and stack.  Most
   -- go overboard, like all the different PUSH and POP instructions, but
   -- where possible (and makes sense) the same opcodes are used.
   --
   -- 0780
   -- 0DC0
   -- 0C40
   -- stack:
   -- 07C0
   -- 0E80
   -- 0D00 push   00001 101 00000000
   -- 0D40 pushd
   -- 0D80 pushq
   -- 0C02 pushws
   -- 0F00 pop    00001 111 00000000
   -- 0F40 popd
   -- 0F80 popq
   -- 0C03 popws
   -- 0C80 call   00001 100 10000000
   -- 0C00 ret    00001 100 00000000
   -- 0CC0 callm
   -- 0C01 retm


   -- The byte operator only exists in 8 instructions and is always bit 3.
-- see decoder
-- byte     <= ir(3) or force_byte;    -- byte selector
-- see decoder.  moved to support stack ops
-- Td       <= ir(4 to 5);             -- destination mode: Td
-- D        <= ir(6 to 9);             -- destination: D or C
-- Ts       <= ir(10 to 11);           -- source mode: Ts
-- S        <= ir(12 to 15);           -- source: S or W
   C        <= ir(8 to 11);            -- count: C
   disp     <= ir(8 to 15);            -- jump displacement


   -- Source addressing selector
   process (Ts, S) begin
      case Ts is
      when "00" =>            src_state_sel <= st_cpu_mem_wr;
      when "01" |
           "11" =>            src_state_sel <= st_cpu_mem_wri;
      when "10" =>
         if S = "0000" then   src_state_sel <= st_cpu_mem_sym;
         else                 src_state_sel <= st_cpu_mem_idx; end if;
      when others => null;
      end case;
   end process;

   src_is_ws <= '1' when Ts = "00" else '0';
   src_autoinc <= '1' when Ts = "11" else '0';


   -- Destination addressing selector
   process (Td, D) begin
      case Td is
      when "00" =>            dst_state_sel <= st_cpu_mem_wr;
      when "01" |
           "11" =>            dst_state_sel <= st_cpu_mem_wri;
      when "10" =>
         if D = "0000" then   dst_state_sel <= st_cpu_mem_sym;
         else                 dst_state_sel <= st_cpu_mem_idx; end if;
      when others => null;
      end case;
   end process;

   dst_is_ws <= '1' when Td = "00" else '0';
   dst_autoinc <= '1' when Td = "11" else '0';


   -- Decoder
   --
   -- The T states are used by the FSM to determine the instruction
   -- execution path.  The T states are used as follows:
   --
   -- fetch:         -> decode
   -- decode:        -> loads cpu_state_t0 (where to go after fetch/decode)
   -- src:           -> loads cpu_state_t1 (where to go after resolving and reading src data)
   -- dst:           -> loads cpu_state_t2 (where to go after resolving and reading dst data)
   -- alu_op:        -> loads cpu_state_t3 (where to go after ALU operation)
   -- alu_store:     -> loads cpu_state_t4 (where to go after ALU store)
   -- status flags:  -> fetch
   -- branch:        -> fetch
   -- branch link:   -> fetch
   -- jump:          -> fetch
   -- immediate:     -> alu_op
   -- mpy:           -> mpy_op -> fetch
   -- shift:         -> alu_op
   -- SPI:           -> alu_op
   -- X:             -> decode
   --

   -- These formats are *not* the same as described in various texts.
   format_next <=
      format1 when ir(0) = '1' else    -- "1XXXXXX"
      format2 when ir(1) = '1' else    -- "01XXXXX"
      format3 when ir(2) = '1' else    -- "001XXXX"
      format4 when ir(3) = '1' else    -- "0001XXX"
      format5 when ir(4) = '1' else    -- "00001XX"
      format6 when ir(5) = '1' else    -- "000001X"
      format7;                         -- "0000001"

   -- registered to prevent long setup and hold times
   process (clk) begin if rising_edge(clk) then
      format <= format_next;
      alu_ctrl <= alu_next;
      shift_ctrl <= shift_next;
      byte <= byte_next or force_byte;
   end if; end process;

   decoder : process (ir, format, spi_cs_reg)
   begin

      cpu_state_t0 <= st_cpu_resolve_src;    -- after decode
      cpu_state_t1 <= st_cpu_resolve_dst;    -- after src
      cpu_state_t2 <= st_cpu_alu_op;         -- after dst
      cpu_state_t3 <= st_cpu_alu_to_ws;      -- after alu
      cpu_state_t4 <= st_cpu_status;         -- after store
      alu_next <= alu_mov;

      byte_next <= '0';                      -- byte ops valid for format1 and format2 only
      force_byte <= '0';                     -- force a byte op for SPI
      Td_next <= ir(4 to 5);                 -- destination mode: Td
      D_next <= ir(6 to 9);                  -- destination: D or C
      Ts_next <= ir(10 to 11);               -- source mode: Ts
      S_next <= ir(12 to 15);                -- source: S or W

      status_sel <= '0';                     -- select status bits or zero for STST vs CLR op
      shift_next <= shift_sla;
      jump_ctrl <= jump_jeq;
      jump_op_en <= '0';
      bl_op_en <= '0';
      rtwp_en <= '0';
      spi_cs_next <= spi_cs_reg;
      ws_inc_flag <= '1';                    -- normally inc, dec for push and call
      ws_pre_flag <= '0';                    -- pre or post inc/dec for push, pop, call, ret
      stack_to_pc_en <= '0';                 -- '1' to store the stack op to the PC (ret)
      pc_to_stack_en <= '0';                 -- '1' to store the PC on the stack (call)
      immd_to_src <= '0';                    -- '1' to assign an immediate value as the src vs dst

      case format is

   -- Type 1: byte and word, dual operand, multiple addressing (8 opcodes)
      when format1 =>

         -- byte ops for format1 and format2 only
         byte_next <= ir(3);

         case ir(1 to 2) is

         when "00" => alu_next <= alu_cmp;                           -- C CB
            -- compare does not store
            cpu_state_t3 <= st_cpu_status;

         when "01" => alu_next <= alu_add;                           -- A AB
         when "10" => alu_next <= alu_mov;                           -- MOV MOVB
         when "11" => alu_next <= alu_or;                            -- SOC SOCB
         when others => null;
         end case;

   -- Type 2: byte and word, dual operand, multiple addressing (4 opcodes)
      when format2 =>

         -- byte ops for format1 and format2 only
         byte_next <= ir(3);

         if ir(2) = '0' then                                         -- SZC SZCB
            alu_next <= alu_andn;
         else                                                        -- S SB
            alu_next <= alu_sub;
         end if;

   -- Type 3: dual operand, multiple addressing for src, ws reg for dst (8 opcodes)
      when format3 =>

         -- Destination is always ws reg.
         Td_next <= "00";

         case ir(3 to 5) is

         when "000" => alu_next <= alu_coc;                          -- COC
            -- compare does not store
            cpu_state_t3 <= st_cpu_status;

         when "001" => alu_next <= alu_czc;                          -- CZC
            -- compare does not store
            cpu_state_t3 <= st_cpu_status;

         when "010" => alu_next <= alu_xor;                          -- XOR

         when "011" =>                                               -- XOP - re-purposed as PIX (pixel set/get)
            cpu_state_t1 <= st_cpu_pix_op;

         when "100" =>                                               -- LDCR
            -- write to SPI, always a byte operation
            force_byte <= '1';
            cpu_state_t1 <= st_cpu_spi_op;
            -- writing to SPI does not store
            cpu_state_t3 <= st_cpu_status;

         when "101" =>                                               -- STCR
            -- read from SPI, always a byte operation
            force_byte <= '1';
            cpu_state_t1 <= st_cpu_spi_op;

         when "110" =>                                               -- MPY
            -- MPY dst is always a ws reg
            cpu_state_t1 <= st_cpu_mpy_op;

         when "111" => alu_next <= alu_div;                          -- DIV
            -- DIV dst is always a ws reg
            cpu_state_t1 <= st_cpu_div_op;
            -- DIV can set the overflow flag, so it has an unused ALU control
            -- just to get access to the flag logic.

         when others => null;
         end case;

   -- Type 4: jump (16 opcodes)
      when format4 =>

         cpu_state_t0 <= st_cpu_b_op;
         jump_op_en <= '1';

         case ir(4 to 7) is

         when "0000" => jump_ctrl <= jump_jmp;                       -- JMP Jump unconditionally
         when "0001" => jump_ctrl <= jump_jlt;                       -- JLT Jump Less Than
         when "0010" => jump_ctrl <= jump_jle;                       -- JLE Jump Low or Equal
         when "0011" => jump_ctrl <= jump_jeq;                       -- JEQ Jump Equal
         when "0100" => jump_ctrl <= jump_jhe;                       -- JHE Jump High or Equal
         when "0101" => jump_ctrl <= jump_jgt;                       -- JGT Jump Greater Than
         when "0110" => jump_ctrl <= jump_jne;                       -- JNE Jump Not Equal
         when "0111" => jump_ctrl <= jump_jnc;                       -- JNC Jump No Carry
         when "1000" => jump_ctrl <= jump_joc;                       -- JOC Jump On Carry
         when "1001" => jump_ctrl <= jump_jno;                       -- JNO Jump No Overflow
         when "1010" => jump_ctrl <= jump_jl;                        -- JL  Jump Low
         when "1011" => jump_ctrl <= jump_jh;                        -- JH  Jump High
         when "1100" => jump_ctrl <= jump_jop;                       -- JOP Jump Odd Parity

         -- 1101                                                     -- unused opcode

         -- 1110
         --    ir(8) = 0                                             -- unused opcode
         --    ir(8) = 1                                             -- SBO (not implemented)

         -- 1111
         --    ir(8) = 0                                             -- SBZ (not implemented)
         --    ir(8) = 1                                             -- TB (not implemented)

         when others =>                                              -- NOP
            cpu_state_t0 <= st_cpu_fetch;
         end case;

   -- Type 5: shift (4 opcodes)
      when format5 =>

         case ir(5 to 7) is

         when "000" => shift_next <= shift_sra;                      -- SRA
            cpu_state_t0 <= st_cpu_shift_op;
            alu_next <= alu_shift;

         when "001" => shift_next <= shift_srl;                      -- SRL
            cpu_state_t0 <= st_cpu_shift_op;
            alu_next <= alu_shift;

         when "010" => shift_next <= shift_sla;                      -- SLA
            cpu_state_t0 <= st_cpu_shift_op;
            alu_next <= alu_shift;

         when "011" => shift_next <= shift_src;                      -- SRC
            cpu_state_t0 <= st_cpu_shift_op;
            alu_next <= alu_shift;

         -- New opcodes.  The real 9900 would execute these as NOP.
         -- push, pop, ret, call are opcode compatible (but not
         -- execution compatible) with the Asm994a assembler.
         -- All stack instructions use R15 as the stack pointer.
         --
         -- 0C00 ret    00001 100 0x xx xxxx
         -- 0C80 call   00001 100 1x Ts SSSS
         -- 0D00 push   00001 101 0x Ts SSSS
         -- 0E00 slc    00001 110 0x Ts SSSS
         -- 0F00 pop    00001 111 0x Td DDDD
         --
         -- CALL <gas> = (R15) <= PC , R15 <= R15 - 2 , PC <= gas
         -- PUSH <gas> = (R15) <= (gas) , R15 <= R15 - 2
         -- POP  <gad> = R15 <= R15 + 2 , (gad) <= (R15)
         -- RET        = R15 <= R15 + 2 , PC <= (R15)

         when "100" =>  -- "1000"                                    -- RET
            if ir(8) = '0' then
               cpu_state_t1 <= st_cpu_alu_op;   -- the dst is the PC
               cpu_state_t3 <= st_cpu_b_op;     -- nothing to store in memory, stack to PC
               alu_next <= alu_mov;             -- use ALU to move src to dst
               ws_pre_flag <= '1';              -- force a pre-increment
               Ts_next <= "11";                 -- indirect autoinc
               S_next <= x"F";                  -- the stack is always R15
               stack_to_pc_en <= '1';           -- ret places the src in the PC

      -- when "1001"                                                 -- CALL <gas>
            else
               cpu_state_t4 <= st_cpu_b_op;     -- src to PC
               alu_next <= alu_mov;             -- use ALU to move src to dst
               ws_inc_flag <= '0';              -- force a post-decrement
               Td_next <= "11";                 -- indirect autodec
               D_next <= x"F";                  -- the stack is always R15
               pc_to_stack_en <= '1';           -- call places the PC in the dst and ea_src in the PC

            end if;

         when "101" =>                                               -- PUSH <gas>
            alu_next <= alu_mov;                -- use ALU to move src to dst
            ws_inc_flag <= '0';                 -- force a post-decrement
            Td_next <= "11";                    -- indirect autodec
            D_next <= x"F";                     -- the stack is always R15

         when "110" => shift_next <= shift_slc;                      -- SLC
            cpu_state_t0 <= st_cpu_shift_op;
            alu_next <= alu_shift;

         when "111" =>                                               -- POP <gad>
            alu_next <= alu_mov;                -- use ALU to move src to dst
            ws_pre_flag <= '1';                 -- force a pre-increment
            Ts_next <= "11";                    -- indirect autoinc
            S_next <= x"F";                     -- the stack is always R15
            Td_next <= ir(10 to 11);            -- pop uses Ts/S for dst
            D_next <= ir(12 to 15);             -- pop uses Ts/S for dst

         when others => null;
         end case;

   -- Type 6: program, single src operand, multiple addressing (14 opcodes)
      when format6 =>

         cpu_state_t1 <= st_cpu_alu_op;   -- after src

         case ir(6 to 9) is

      -- when "0000" =>                                              -- BLWP
      -- Not implemented

         when "0001" =>                                              -- B
            cpu_state_t1 <= st_cpu_b_op;

         when "0010" =>                                              -- X
            -- replace ir with source data, jump to decode state.
            cpu_state_t1 <= st_cpu_x_op;

         when "0011" =>                                              -- CLR
            -- does not affect status
            cpu_state_t4 <= st_cpu_fetch;
            alu_next <= alu_clr;

         when "0100" => alu_next <= alu_neg;                         -- NEG
         when "0101" => alu_next <= alu_inv;                         -- INV
         when "0110" => alu_next <= alu_inc;                         -- INC
         when "0111" => alu_next <= alu_inct;                        -- INCT
         when "1000" => alu_next <= alu_dec;                         -- DEC
         when "1001" => alu_next <= alu_dect;                        -- DECT

         when "1010" =>                                              -- BL
            cpu_state_t1 <= st_cpu_b_op;
            bl_op_en <= '1';

         when "1011" => alu_next <= alu_swpb;                        -- SWPB
            -- does not affect status
            cpu_state_t4 <= st_cpu_fetch;

         when "1100" => alu_next <= alu_seto;                        -- SETO
            -- does not affect status
            cpu_state_t4 <= st_cpu_fetch;

         when "1101" => alu_next <= alu_abs;                         -- ABS
            -- TODO
            -- ABS does not store the result if it did not change, but
            -- that functionality is not implemented here.  Could cause
            -- a bug if this core is expanded to a full 9900 and used
            -- in a SoC.

         -- Unused opcodes.  The real 9900 would execute these as NOP.
         --when "1110" =>                                            -- unused
         --when "1111" =>                                            -- unused

         when others =>                                              -- NOP
            cpu_state_t0 <= st_cpu_fetch;
         end case;

   -- Type 7: single operand, ws reg dst with optional immediate value (15 opcodes)
      when format7 =>

         -- The immediate operation knows the source follows the instruction and
         -- the destination is specified in the S/W bits of the opcode, so
         -- normal source determination is not used.
         cpu_state_t0 <= st_cpu_load_immd;

         case ir(7 to 10) is

         when "0000" => alu_next <= alu_mov;                         -- LI
            immd_to_src <= '1';
         when "0001" => alu_next <= alu_add;                         -- AI
         when "0010" => alu_next <= alu_andi;                        -- ANDI
         when "0011" => alu_next <= alu_or;                          -- ORI

         when "0100" => alu_next <= alu_cmp;                         -- CI
            -- compare does not store
            cpu_state_t3 <= st_cpu_status;

      -- 1001 unused

      -- when "0101" =>                                              -- STWP
      -- Not implemented

         when "0110" =>                                              -- STST
            -- skip src, force dst to ws from S/W bits,
            -- do not affect status
            cpu_state_t0 <= st_cpu_resolve_dst;
            cpu_state_t4 <= st_cpu_fetch;
            alu_next <= alu_clr;
            status_sel <= '1';
            Td_next <= "00";
            D_next <= ir(12 to 15);

      -- when "0111" =>                                              -- LWPI
      -- Not implemented

      -- when "1000" =>                                              -- LIMI
      -- Not implemented

         when "1010" =>                                              -- IDLE
            cpu_state_t0 <= st_cpu_idle;

      -- when "1011" =>                                              -- RSET
      -- Not implemented

         when "1100" =>                                              -- RTWP
            cpu_state_t0 <= st_cpu_resolve_src;
            cpu_state_t1 <= st_cpu_b_op;
            Ts_next <= "01";  -- works like B and BL
            S_next <= x"E";
            rtwp_en <= '1';

         when "1101" =>                                              -- CKON
         -- SPI CS on
         cpu_state_t0 <= st_cpu_status;
         spi_cs_next <= '0';

         when "1110" =>                                              -- CKOF
         -- SPI CS off
         cpu_state_t0 <= st_cpu_status;
         spi_cs_next <= '1';

      -- when "1111" =>                                              -- LREX
      -- Not implemented

         when others =>                                              -- NOP
            cpu_state_t0 <= st_cpu_fetch;
         end case;
      end case;
   end process;


   -- Select the ALU store state, ws reg or memory, when storing the ALU result.
   process (cpu_state_t3, alu_to_ws)
   begin
      if cpu_state_t3 = st_cpu_alu_to_ws then
         if alu_to_ws = '1' then
            cpu_state_alu_store <= st_cpu_alu_to_ws;
         else
            cpu_state_alu_store <= st_cpu_alu_to_mem;
         end if;
      else
         cpu_state_alu_store <= cpu_state_t3;
      end if;
   end process;


   -- Shift Register
   process (shift_ctrl, shift_reg)
   begin
      case shift_ctrl is
      when shift_sla => shift_dir <= '0'; shift_bit <= '0';
      when shift_slc => shift_dir <= '0'; shift_bit <= shift_reg(0);
      when shift_srl => shift_dir <= '1'; shift_bit <= '0';
      when shift_sra => shift_dir <= '1'; shift_bit <= shift_reg(0);
      when shift_src => shift_dir <= '1'; shift_bit <= shift_reg(15);
      end case;
   end process;

   process (clk) begin if rising_edge(clk) then

      shift_done <= '0';
      if shift_reg(0) /= shift_msb then shift_overflow <= '1'; end if;

      if shift_load = '1' then
         shift_reg <= ws_dout;
         shift_msb <= ws_dout(0);
         shift_cnt <= shift_cnt_init;
         shift_overflow <= '0';  -- overflow happens if the MSb changes during a shift

      elsif shift_cnt /= 0 then

         if shift_cnt = 1 then shift_done <= '1'; end if;
         shift_cnt <= shift_cnt - 1;

         -- dir 0 = left, 1 = right
         if shift_dir = '0' then
            shift_reg <= shift_reg(1 to 15) & shift_bit;
            shift_carry <= shift_reg(0);
         else
            shift_reg <= shift_bit & shift_reg(0 to 14);
            shift_carry <= shift_reg(15);
         end if;
      end if;
   end if; end process;


   -- 16x16x32 Multiplier with Multiply-Accumulate (MAC) operation
-- mac_x <= mac_r + mpy_out;
   process (clk) begin if rising_edge(clk) then
      mpy_out <= alu_sa * alu_da;
--
--    if mac_clr_r = '1' then
--       mac_r <= (others => '0');
--    elsif cpu_state = st_cpu_mpy_done then
--       mac_r <= mac_x;
--    end if;
   end if; end process;


   -- 32 udiv 16 Divider
   inst_divide : entity work.f18a_div32x16
   port map (
      clk            => clk,
      reset          => div_reset,     -- active high, forces divider idle
      start          => div_start,     -- '1' to load and trigger the divide
      ready          => open,          -- '1' when ready, '0' while dividing
      done           => div_done,      -- single done tick
      dividend_msb   => dst_oper,      -- number being divided (dividend) 0 to 4,294,967,296
      dividend_lsb   => ws_dout,
      divisor        => src_oper,      -- divisor 0 to 65,535
      q              => div_quo,
      r              => div_rmd
   );


   -- Status bits vs clr selection
   status_bits <= "000000" when status_sel = '0' else LGT & AGT & EQUAL & CARRY & OVFLW & PARITY;

   -- Source and destination operands for word and byte operations.
   alu_sa <= src_oper when byte = '0' else (src_oper(0 to 7) & x"00");
   alu_sa_n <= not alu_sa;
   alu_da <= dst_oper when byte = '0' else (dst_oper(0 to 7) & x"00");


   -- ALU
   alu : process (alu_ctrl, alu_da, alu_sa, alu_sa_n, shift_carry, shift_reg, status_bits)
   begin
      case alu_ctrl is
      when alu_mov |                                                       -- MOV MOVB LI
           alu_div   => alu_out <= '0' & alu_sa;                           -- DIV (ALU unused)
      when alu_add   => alu_out <= ('0' & alu_da) + ('0' & alu_sa);        -- A AB AI
      when alu_sub |                                                       -- S SB
           alu_cmp   => alu_out <= ('0' & alu_da) + ('0' & alu_sa_n) + 1;  -- C CB CI
      when alu_coc   => alu_out <= '0' & ((not alu_da) and alu_sa);        -- COC
      when alu_inc   => alu_out <= ('0' & alu_sa) + 1;                     -- INC
      when alu_inct  => alu_out <= ('0' & alu_sa) + 2;                     -- INCT
      when alu_dec   => alu_out <= ('0' & alu_sa) + ('0' & x"FFFF");       -- DEC
      when alu_dect  => alu_out <= ('0' & alu_sa) + ('0' & x"FFFE");       -- DECT
      when alu_andi |                                                      -- ANDI
           alu_czc   => alu_out <= '0' & (alu_da and alu_sa);              -- CZC
      when alu_andn  => alu_out <= '0' & (alu_da and alu_sa_n);            -- SZC SZCB
      when alu_or    => alu_out <= '0' & (alu_da or alu_sa);               -- SOC SOCB ORI
      when alu_xor   => alu_out <= '0' & (alu_da xor alu_sa);              -- XOR
      when alu_clr   => alu_out <= '0' & status_bits & "0000000000";       -- CLR
      when alu_seto  => alu_out <= (others => '1');                        -- SETO
      when alu_inv   => alu_out <= '0' & alu_sa_n;                         -- INV
      when alu_neg   => alu_out <= ('0' & alu_sa_n) + 1;                   -- NEG (2's complement)
      when alu_swpb  => alu_out <= '0' & alu_sa(8 to 15) & alu_sa(0 to 7); -- SWPB
      when alu_abs   =>             if alu_sa(0) = '0' then                -- ABS
                        alu_out <= '0' & alu_sa; else                      -- same as MOV
                        alu_out <= ('0' & alu_sa_n) + 1; end if;           -- same as NEG
      when alu_shift => alu_out <= shift_carry & shift_reg;                -- SLA, SLC, SRL, SRA, SRC
      end case;
   end process;


   -- Equality checks for status flag logic.
   sa_eq_da       <= '1' when alu_sa = alu_da else '0';
   sa_msb_eq_da   <= '1' when alu_sa(0) = alu_da(0) else '0';
   sa_eq_8000     <= '1' when alu_sa = x"8000" else '0';
   sa_eq_zero     <= '1' when alu_sa = x"0000" else '0';
   da_eq_zero     <= '1' when alu_da = x"0000" else '0';
   alu_eq_zero    <= '1' when alu_reg = x"0000" else '0';
   alu_msb_eq_da  <= '1' when alu_reg(0) = alu_da(0) else '0';


   -- Status Flags
   status_flags : process (
   alu_ctrl, alu_reg, alu_carry, alu_da, alu_sa, byte, div_overflow, shift_ctrl, shift_overflow,
   sa_eq_da, sa_msb_eq_da, sa_eq_8000, sa_eq_zero, alu_eq_zero, alu_msb_eq_da,
   LGT, AGT, EQUAL, CARRY, OVFLW, PARITY)
   begin

      -- Logical Greater Than
      case alu_ctrl is
      when alu_cmp   => LGT_next <= (alu_sa(0) and (not alu_da(0))) or
                                    (sa_msb_eq_da and alu_reg(0));
      when alu_abs   => LGT_next <= not sa_eq_zero;
      when alu_coc |
           alu_czc |
           alu_div   => LGT_next <= LGT;              -- These do not affect LGT
      when others    => LGT_next <= not alu_eq_zero;
      end case;

      -- Arithmetic Greater Than
      case alu_ctrl is
      when alu_cmp   => AGT_next <= ((not alu_sa(0)) and alu_da(0)) or
                                    (sa_msb_eq_da and alu_reg(0));
      when alu_abs   => AGT_next <= ((not alu_sa(0)) and (not sa_eq_zero));
      when alu_coc |
           alu_czc |
           alu_div   => AGT_next <= AGT;              -- These do not affect AGT
      when others    => AGT_next <= ((not alu_reg(0)) and (not alu_eq_zero));
      end case;

      -- Equal
      case alu_ctrl is
      when alu_cmp   => EQUAL_next <= sa_eq_da;
      when alu_abs   => EQUAL_next <= sa_eq_zero;
      when alu_div   => EQUAL_next <= EQUAL;          -- These do not affect EQUAL
      when others    => EQUAL_next <= alu_eq_zero;    -- All others.
      end case;

      -- Carry
      case alu_ctrl is
      when  alu_add |
            alu_sub |
            alu_inc |
            alu_inct |
            alu_dec |
            alu_dect |
            alu_neg |
            alu_abs |
            alu_shift   => CARRY_next <= alu_carry;
      when others       => CARRY_next <= CARRY;
      end case;

      -- Overflow
      case alu_ctrl is
      when alu_add   => OVFLW_next <= (sa_msb_eq_da and (not alu_msb_eq_da));
      when alu_sub   => OVFLW_next <= ((not sa_msb_eq_da) and (not alu_msb_eq_da));
      when alu_inc |
           alu_inct  => OVFLW_next <= ((not alu_sa(0)) and alu_reg(0));
      when alu_dec |
           alu_dect  => OVFLW_next <= (alu_sa(0) and (not alu_reg(0)));
      when alu_abs |
           alu_neg   => OVFLW_next <= sa_eq_8000;
      when alu_shift => if shift_ctrl = shift_sla then
                        OVFLW_next <= shift_overflow; else
                        OVFLW_next <= OVFLW; end if;
      when alu_div   => OVFLW_next <= div_overflow;
      when others    => OVFLW_next <= OVFLW;
      end case;

      -- Parity
      if byte = '0' then
         PARITY_next <= PARITY;
      else
         case alu_ctrl is
         when alu_cmp |
              alu_mov => PARITY_next <=   (alu_sa(0) xor alu_sa(1)) xor
                                          (alu_sa(2) xor alu_sa(3)) xor
                                          (alu_sa(4) xor alu_sa(5)) xor
                                          (alu_sa(6) xor alu_sa(7));
         when alu_add |
              alu_sub |
              alu_or  |
              alu_andn => PARITY_next <=  (alu_reg(0) xor alu_reg(1)) xor
                                          (alu_reg(2) xor alu_reg(3)) xor
                                          (alu_reg(4) xor alu_reg(5)) xor
                                          (alu_reg(6) xor alu_reg(7));
         when others => PARITY_next <= PARITY;
         end case;
      end if;

   end process;


   -- Jump control
   process (jump_ctrl, LGT, AGT, EQUAL, CARRY, OVFLW, PARITY)
   begin
      case jump_ctrl is
      when jump_jgt  => take_jump <= AGT;                            -- JGT jump greater than (arithmetic)
      when jump_jlt  => take_jump <= ((not AGT) and (not EQUAL));    -- JLT jump less than (arithmetic)
      when jump_jmp  => take_jump <= '1';                            -- JMP unconditional jump
      when jump_jeq  => take_jump <= EQUAL;                          -- JEQ jump equal
      when jump_jne  => take_jump <= not EQUAL;                      -- JNE jump not equal
      when jump_jh   => take_jump <= (LGT and (not EQUAL));          -- JH  jump high
      when jump_jhe  => take_jump <= (LGT or EQUAL);                 -- JHE jump high or equal
      when jump_jl   => take_jump <= ((not LGT) and (not EQUAL));    -- JL  jump low
      when jump_jle  => take_jump <= ((not LGT) or EQUAL);           -- JLE jump low or equal
      when jump_joc  => take_jump <= CARRY;                          -- JOC jump on carry
      when jump_jnc  => take_jump <= not CARRY;                      -- JNC jump no carry
      when jump_jno  => take_jump <= not OVFLW;                      -- JNO jump no overflow
      when jump_jop  => take_jump <= PARITY;                         -- JOP jump odd parity
      end case;
   end process;


   -- PC
   pc_inc <= pc + 1;
   pc_jump <=
      pc +
         (disp(0) & disp(0) & disp(0) & disp(0) & disp(0) & disp(0) & disp(0) &
         disp &  '0') when take_jump = '1' else
      pc;

   -- The effective address of t1 + t2
   ea_t1t2 <= t1 + t2;

   -- Delay the pause for one extra clock cycle to allow the GPU to
   -- reassert any addressing it was doing when it was paused.
   process (clk) begin
   if rising_edge(clk) then
      hold <= pause or dma_active_s;
   end if;
   end process;

   pause_req <= pause or hold or dma_active_s;
   pause_ack <= pause_ack_reg and dma_pause_ack_s;
   running <= running_reg;

-- flags <= LGT & AGT & EQUAL & CARRY & OVFLW & PARITY;

   -- GPU FSM
   process (clk) begin
   if rising_edge(clk) then
   if rst_n = '0' then
      pc <= load_pc;
      cpu_state <= st_cpu_idle;
      spi_cs_reg <= '1';
      spi_en <= '0';
   else

      cpu_state_hold <= cpu_state;
      mar_ctrl <= ctrl_mar_pc;
      pause_ack_reg <= '0';
      running_reg <= '1';
      spi_en <= '0';
      div_reset <= '0';
      div_start <= '0';
      shift_load <= '0';

      -- Register the write enables to prevent glitches
      ws_we <= '0';
      vwe_reg <= '0';   -- VRAM
      gwe_reg <= '0';   -- GRAM
      rwe_reg <= '0';   -- VDP Registers
      pwe_reg <= '0';   -- Palette Registers
      dwe_r <= '0';     -- DMA (DMA)
      swe_reg <= '0';   -- GPU status output
--    mac_clr_r <= '0'; -- MAC clear

      case cpu_state is

      when st_cpu_idle =>

         -- Idle when reset or the IDLE instruction.  Only a trigger
         -- from the VDP can start the GPU again.
         if trigger = '1' then
            cpu_state <= st_cpu_fetch;
         else
            cpu_state <= st_cpu_idle;
            pause_ack_reg <= '1';
            running_reg <= '0';
         end if;

   -- Fetch
      when st_cpu_fetch =>

         if pause_req = '1' then
            pause_ack_reg <= '1';
            cpu_state <= st_cpu_fetch;
         else
            cpu_state <= st_cpu_fetch_msb;
         end if;

      when st_cpu_fetch_msb =>

         -- Addressing opcode MSB
         cpu_state <= st_cpu_fetch_lsb;
         pc <= pc_inc;

      when st_cpu_fetch_lsb =>

         -- Addressing opcode LSB
         cpu_state <= st_cpu_latch_ir;
         ir(0 to 7) <= mem_din;
         pc <= pc_inc;

      when st_cpu_latch_ir =>

         cpu_state <= st_cpu_decode;
         ir(8 to 15) <= mem_din;

   -- Decode cycle
      when st_cpu_decode =>

         cpu_state <= cpu_state_t0;
         Ts <= Ts_next;
         S <= S_next;
         Td <= Td_next;
         D <= D_next;

   -- Source
      when st_cpu_resolve_src =>

         if pause_req = '1' then
            pause_ack_reg <= '1';
            cpu_state <= st_cpu_resolve_src;
         else
            cpu_state <= src_state_sel;
         end if;

         cpu_state_return <= st_cpu_save_src;
         ws_addr <= S;                       -- Address the source ws reg
         auto_inc <= src_autoinc;            -- Set the src auto-increment flag

      when st_cpu_save_src =>

         cpu_state <= cpu_state_t1;
         src_oper <= t2;
         ea_src <= ea_dst;                   -- Save the src effective address for stack ops

         -- Save a flag for the destination type.  For single op instructions
         -- this flag is set once here, for dual op instructions, the *real*
         -- destination will set the real value in the a later state.
         alu_to_ws <= src_is_ws;

   -- Destination
      when st_cpu_resolve_dst =>

         if pause_req = '1' then
            pause_ack_reg <= '1';
            cpu_state <= st_cpu_resolve_dst;
         else
            cpu_state <= dst_state_sel;
         end if;

         cpu_state_return <= st_cpu_save_dst;
         ws_addr <= D_next;                  -- Address the destination ws reg
         auto_inc <= dst_autoinc;            -- Set the dst auto-increment flag

      when st_cpu_save_dst =>

         cpu_state <= cpu_state_t2;
         dst_oper <= t2;

         -- For dual op instructions, this overrides the flag as set in the
         -- source data selection.
         alu_to_ws <= dst_is_ws;


   -- ALU Operation
      when st_cpu_alu_op =>

         if pause_req = '1' then
            pause_ack_reg <= '1';
            cpu_state <= st_cpu_alu_op;
         else
            cpu_state <= cpu_state_alu_store;
         end if;

         alu_reg <= alu_out(1 to 16);
         alu_carry <= alu_out(0);
         -- Address the saved register even if not needed.  For a register
         -- destination, the register file write will be enabled in the
         -- next ALU Store state.
         ws_addr <= ws_dst;

   -- ALU Store to ws register
      when st_cpu_alu_to_ws =>

         cpu_state <= cpu_state_t4;
         t1 <= ws_din_mux;
         ws_we <= '1';

   -- ALU Store to memory
      when st_cpu_alu_to_mem =>

         -- Byte operations only perform a single write to the original
         -- address, whether odd or even, and always write the MSB of
         -- the ALU result since the source data ensured byte ops were
         -- placed in the MSB before entering the ALU.
         if byte = '0' then
            cpu_state <= st_cpu_alu_to_mem_lsb;
            t1 <= ea_dst(0 to 14) & '0';
         else
            cpu_state <= st_cpu_status;
            t1 <= ea_dst;
         end if;

         mar_ctrl <= ctrl_mar_t1;
         if pc_to_stack_en = '0' then           -- support CALL
            mem_dout <= alu_reg(0 to 7); else
            mem_dout <= PC(0 to 7); end if;

         vwe_reg <= vwe_next;    -- VRAM
         gwe_reg <= gwe_next;    -- GRAM
         rwe_reg <= rwe_next;    -- VDP Registers
         dwe_r <= dwe_x;         -- DMA (DMA)
         swe_reg <= swe_next;    -- GPU status
--       mac_clr_r <= mac_clr_x; -- MAC clear

      when st_cpu_alu_to_mem_lsb =>

         cpu_state <= cpu_state_t4;
         mar_ctrl <= ctrl_mar_t1;
         t1 <= ea_dst(0 to 14) & '1';
         if pc_to_stack_en = '0' then           -- support CALL
            mem_dout <= alu_reg(8 to 15); else
            mem_dout <= PC(8 to 15); end if;

         vwe_reg <= vwe_next;    -- VRAM
         gwe_reg <= gwe_next;    -- GRAM
         rwe_reg <= rwe_next;    -- VDP Registers
         dwe_r <= dwe_x;         -- DMA (DMA)
         swe_reg <= swe_next;    -- GPU status

         -- Only write the palette on the LSB of a word op write so a byte
         -- op will not cause an erroneous write.
         pwe_reg <= pwe_next;


   -- Status Update
      when st_cpu_status =>

         cpu_state <= st_cpu_fetch;

         if rtwp_en = '0' then
            LGT      <= LGT_next;
            AGT      <= AGT_next;
            EQUAL    <= EQUAL_next;
            CARRY    <= CARRY_next;
            OVFLW    <= OVFLW_next;
            PARITY   <= PARITY_next;
         else
            -- relies on the async response of the reg memory
            LGT      <= ws_dout(0);
            AGT      <= ws_dout(1);
            EQUAL    <= ws_dout(2);
            CARRY    <= ws_dout(3);
            OVFLW    <= ws_dout(4);
            PARITY   <= ws_dout(5);
         end if;

         spi_cs_reg <= spi_cs_next;

   -- Load PC for branch, branch and link, call, ret, or jump
      when st_cpu_b_op =>

         -- BL stores the PC in R11
         -- RTWP stores R15 in the status flags
         if rtwp_en = '0' then
            cpu_state <= st_cpu_fetch;
            ws_addr <= x"B";  -- R11
         else
            cpu_state <= st_cpu_status;
            ws_addr <= x"F";  -- R15
         end if;

         if jump_op_en = '1' then
            pc <= pc_jump;
         elsif pc_to_stack_en = '1' then  -- CALL
            pc <= ea_src;
         elsif stack_to_pc_en = '1' then  -- RET
            pc <= alu_reg;
         else                             -- B, BL
            pc <= ea_dst;
         end if;

         -- BL stores the PC in R11
         t1 <= pc;
         ws_we <= bl_op_en;

   -- X
      when st_cpu_x_op =>

         cpu_state <= st_cpu_decode;
         ir <= src_oper;

   -- Multiply
      when st_cpu_mpy_op =>

         cpu_state <= st_cpu_mpy_dst;
         -- address the destination (mpy src*dst -> dst,dst+1)
         ws_addr <= D;

      when st_cpu_mpy_dst =>

         cpu_state <= st_cpu_mpy_wait;
         -- relies on the async response of the reg memory
         dst_oper <= ws_dout;

      when st_cpu_mpy_wait =>

         cpu_state <= st_cpu_mpy_msb;

      when st_cpu_mpy_msb =>

         cpu_state <= st_cpu_mpy_done;
         t1 <= mpy_out(0 to 15);
         ws_we <= '1';

      when st_cpu_mpy_done =>

         cpu_state <= st_cpu_fetch;
         t1 <= mpy_out(16 to 31);
         ws_addr <= D + 1;
         ws_we <= '1';

   -- Divide
      when st_cpu_div_op =>

         cpu_state <= st_cpu_div_msb;
         -- address the dividend MSB at D
         ws_addr <= D;
         div_overflow <= '0';
         div_reset <= '1';

      when st_cpu_div_msb =>

         cpu_state <= st_cpu_div_wait;
         -- relies on the async response of the reg memory
         dst_oper <= ws_dout;

         -- The divisor (src_oper) must be > the MSB of the dividend
         if ws_dout >= src_oper then
            cpu_state <= st_cpu_status;
            div_overflow <= '1';
         end if;

         -- address the dividend LSB at D+1
         ws_addr <= D + 1;

         -- trigger the divide
         div_start <= '1';

      when st_cpu_div_wait =>

         cpu_state <= st_cpu_div_wait;

         -- if a pause request comes in, acknowledge it
         pause_ack_reg <= pause_req;

         if div_done = '1' then
            cpu_state <= st_cpu_div_done;
            -- Store the remainder since ws_addr is still D+1
            t1 <= div_rmd;
            ws_we <= '1';
         end if;

      when st_cpu_div_done =>

         -- Maintain any pause request since the fetch state tests for and
         -- properly waits on the signal to clear.
         pause_ack_reg <= pause_req;

         -- Store the quotient
         cpu_state <= st_cpu_fetch;
         ws_addr <= D;
         t1 <= div_quo;
         ws_we <= '1';

   -- Shift uses count, ws reg 0, and ws reg dst
      when st_cpu_shift_op =>

         -- Address ws reg 0 in case the count is zero.
         cpu_state <= st_cpu_shift_count;
         ws_addr <= x"0";

      when st_cpu_shift_count =>

         cpu_state <= st_cpu_shift_done;

         -- Address the source, which is also the destination.
         ws_addr <= S;

         -- Check the count.  If C = 0 then the count comes from the
         -- ws reg 0(12 to 15).  If that value is 0, the count is 16.
         if C = x"0" then
            if ws_dout(12 to 15) = x"0" then
               shift_cnt_init <= 16;
            else
               shift_cnt_init <= CONV_INTEGER(ws_dout(12 to 15));
            end if;
         else
            shift_cnt_init <= CONV_INTEGER(C);
         end if;

         -- Trigger the shift register to load and run.
         shift_load <= '1';

         -- Set dst to W (same as S)
         ws_dst <= S;
         alu_to_ws <= '1';

      when st_cpu_shift_done =>

         if shift_done = '1' then
            cpu_state <= st_cpu_alu_op;
         else
            cpu_state <= st_cpu_shift_done;
         end if;

         -- if a pause request comes in, acknowledge it
         pause_ack_reg <= pause_req;

         src_oper <= ws_dout;

   -- SPI via LDCR and STCR
      when st_cpu_spi_op =>

         cpu_state <= st_cpu_spi_wait;
         spi_en <= '1';

      when st_cpu_spi_wait =>

         spi_en <= '1';    -- hold until the spi_done flag is set

         if pause_req = '1' then
            pause_ack_reg <= '1';
            cpu_state <= st_cpu_spi_wait;
         elsif spi_done = '0' then
            cpu_state <= st_cpu_spi_wait;
         else
            cpu_state <= st_cpu_alu_op;
            src_oper <= spi_din & x"00";
         end if;

   -- Pixel set and read
      when st_cpu_pix_op =>

         cpu_state <= st_cpu_pix_set;

         -- Get the dst reg to determine if the pixel will be set
         ws_addr <= D;

      when st_cpu_pix_set =>

         -- MAxxRWCE xxOOxxPP
         -- M  - 1 = calculate the effective address for GM2 instead of the new bitmap layer
         --      0 = use the remainder of the bits for the new bitmap layer pixels
         -- A  - 1 = retrieve the pixel's effective address instead of setting a pixel
         --      0 = read or set a pixel according to the other bits
         -- R  - 1 = read current pixel into PP, only after possibly writing PP
         --      0 = do not read current pixel into PP
         -- W  - 1 = do not write PP
         --      0 = write PP to current pixel
         -- C  - 1 = compare OO with PP according to E, and write PP only if true
         --      0 = always write
         -- E  - 1 = only write PP if current pixel is equal to OO
         --      0 = only write PP if current pixel is not equal to OO
         -- OO   pixel to compare to existing pixel
         -- PP   new pixel to write, and previous pixel when reading

         -- ws_dout relies on the async response of the reg memory

         if ws_dout(0) = '1' then
            t1 <= gm2_addr;
         else
            t1 <= bml_addr;
         end if;

         -- if only calculating the effective address, then the operation
         -- is done.
         if ws_dout(0 to 1) /= "00" then
            cpu_state <= st_cpu_fetch;
            ws_we <= '1';
         else
            cpu_state <= st_cpu_pix_read;
            mar_ctrl <= ctrl_mar_t1;
         end if;

      when st_cpu_pix_read =>

         -- addressing the pixel data
         cpu_state <= st_cpu_pix_write;

      when st_cpu_pix_write =>

         -- if reading the current pixel, update the src reg with the pixel
         if ws_dout(4) = '1' then
            t1 <= ws_dout(0 to 13) & pix_in;
            ws_we <= '1';
         end if;

         if ws_dout(5) = '0' and (ws_dout(6) = '0' or (ws_dout(6) = '1' and pix_eq = '1')) then
            cpu_state <= st_cpu_pix_done;
         else
            cpu_state <= st_cpu_fetch;
         end if;

         -- Save the pixel address since this whole design was stupid and uses
         -- t1 for both the reg data in AND the RAM address.  In this case,
         -- it is possible that both a ws reg AND memory need to be updated,
         -- and since T1 is used for both actions, an extra state is needed
         -- to separate the updates.
         t2 <= t1;
         mem_dout <= pix_out;

      when st_cpu_pix_done =>

         cpu_state <= st_cpu_fetch;

         -- write the pixel data back to memory
         t1 <= t2;
         mar_ctrl <= ctrl_mar_t1;
         vwe_reg <= '1';

   -- Load Immediate
      when st_cpu_load_immd =>

         cpu_state <= st_cpu_load_immd_msb;

         -- PC is selected to memory by default, so the MSB would have
         -- been addressed already.
         t1(0 to 7) <= mem_din;
         pc <= pc_inc;

         -- Address the ws reg as the ALU src value.
         ws_addr <= S;

      when st_cpu_load_immd_msb =>

         -- Addressing LSB and src ws reg.
         cpu_state <= st_cpu_load_immd_lsb;
         pc <= pc_inc;

      when st_cpu_load_immd_lsb =>

         -- Save the LSB and set the destination ws reg.
         cpu_state <= st_cpu_alu_op;

         if immd_to_src = '0' then
            src_oper <= ws_dout; else
            src_oper <= t1(0 to 7) & mem_din; end if;

         dst_oper <= t1(0 to 7) & mem_din;

         -- Set dst to W (same as S)
         ws_dst <= S;
         alu_to_ws <= '1';


   -- Workspace Reg: Rx -> Operand
      when st_cpu_mem_wr =>

         cpu_state <= cpu_state_return;
         t2 <= ws_dout;

         -- The effective address of a register is WP+2*reg, and since the WP is
         -- always zero in this case, the address is 2*reg.
         ea_dst <= "00000000000" & ws_addr & '0';

         -- Save the workspace value to combine with the MSB for byte ops.
         ws_dst_save <= ws_dout;
         -- Save the destination register index.
         ws_dst <= ws_addr;


   -- Workspace Reg Indirect: Rx(value) -> Operand
   -- Workspace Reg Indirect Auto-Inc: Rx(value) -> Operand, Rx+[1|2]
   -- CALL <gas> = (R15) <= PC , R15 <= R15 - 2 , PC <= gas
   -- PUSH <gas> = (R15) <= gas , R15 <= R15 - 2
   -- POP  <gad> = R15 <= R15 + 2 , gad <= (R15)
   -- RET        = R15 <= R15 + 2 , PC <= (R15)
      when st_cpu_mem_wri =>

         cpu_state <= st_cpu_mem_wri_msb;

         -- The reg address was set in the previous state
         if ws_pre_flag = '1' then
            t1 <= ws_dout_inc(0 to 14) & '0';
         elsif byte = '0' then
            t1 <= ws_dout(0 to 14) & '0';    -- Word ops are always on even boundaries
         else
            t1 <= ws_dout;
         end if;

         -- Save effective address
         if ws_pre_flag = '1' then
            ea_dst <= ws_dout_inc;
         else
            ea_dst <= ws_dout;
         end if;

         mar_ctrl <= ctrl_mar_t1;

      when st_cpu_mem_wri_msb =>

         -- Addressing MSB or exact address of byte op
         cpu_state <= st_cpu_mem_wri_lsb;
         t1 <= t1 + 1;
         mar_ctrl <= ctrl_mar_t1;

      when st_cpu_mem_wri_lsb =>

         -- Addressing LSB of word op

         -- If a byte operation, the access is complete.
         if byte = '0' then
            cpu_state <= st_cpu_mem_wri_done;
         else
            cpu_state <= cpu_state_return;
         end if;

         -- Latch the new register value
         t1 <= ws_dout_inc;
         -- If this is an auto-increment operation, write the
         -- incremented value back to the workspace register.
         ws_we <= auto_inc;

         -- Byte operators will always be in the MSB.
         t2(0 to 7) <= mem_din;

      when st_cpu_mem_wri_done =>

         cpu_state <= cpu_state_return;
         t2(8 to 15) <= mem_din;


   -- Symbolic: (immediate) -> Operand
      when st_cpu_mem_sym =>

         cpu_state <= st_cpu_mem_sym_msb1;

         -- PC is selected to memory by default, so the MSB would have
         -- been addressed already.
         t1(0 to 7) <= mem_din;
         pc <= pc_inc;

      when st_cpu_mem_sym_msb1 =>

         -- Addressing LSB
         cpu_state <= st_cpu_mem_sym_lsb1;
         pc <= pc_inc;

      when st_cpu_mem_sym_lsb1 =>

         -- Save the LSB and address operand.
         cpu_state <= st_cpu_mem_sym_msb2;
         if byte = '0' then
            t1(8 to 15) <= mem_din(0 to 6) & '0';  -- Word ops are always on even boundaries
         else
            t1(8 to 15) <= mem_din;
         end if;

         ea_dst <= t1(0 to 7) & mem_din;           -- Save effective address
         mar_ctrl <= ctrl_mar_t1;

      when st_cpu_mem_sym_msb2 =>

         -- Addressing MSB or exact address of byte op
         cpu_state <= st_cpu_mem_sym_lsb2;
         t1 <= t1 + 1;
         mar_ctrl <= ctrl_mar_t1;

      when st_cpu_mem_sym_lsb2 =>

         -- Addressing LSB of word op

         -- If a byte operation, the access is complete.
         if byte = '0' then
            cpu_state <= st_cpu_mem_sym_done;
         else
            cpu_state <= cpu_state_return;
         end if;

         -- Byte operators will always be in the MSB.
         t2(0 to 7) <= mem_din;

      when st_cpu_mem_sym_done =>

         -- Save the LSB and return.
         cpu_state <= cpu_state_return;
         t2(8 to 15) <= mem_din;


   -- Indexed: Rx(value) + immediate -> Operand
      when st_cpu_mem_idx =>

         cpu_state <= st_cpu_mem_idx_msb1;

         -- PC is selected to memory by default, so the MSB would have
         -- been addressed already.
         t1(0 to 7) <= mem_din;
         pc <= pc_inc;

      when st_cpu_mem_idx_msb1 =>

         -- Addressing LSB
         cpu_state <= st_cpu_mem_idx_lsb1;
         pc <= pc_inc;
         t2 <= ws_dout;                      -- Latch the ws reg value into t2

      when st_cpu_mem_idx_lsb1 =>

         -- Save the LSB and address operand.
         cpu_state <= st_cpu_mem_idx_ea;
         t1(8 to 15) <= mem_din;

      when st_cpu_mem_idx_ea =>

         cpu_state <= st_cpu_mem_idx_msb2;
         if byte = '0' then
            t1 <= ea_t1t2(0 to 14) & '0';    -- Word ops are always on even boundaries
         else
            t1 <= ea_t1t2;
         end if;

         ea_dst <= ea_t1t2;                  -- Save effective address
         mar_ctrl <= ctrl_mar_t1;

      when st_cpu_mem_idx_msb2 =>

         -- Addressing MSB or exact address of byte op
         cpu_state <= st_cpu_mem_idx_lsb2;
         t1 <= t1 + 1;
         mar_ctrl <= ctrl_mar_t1;

      when st_cpu_mem_idx_lsb2 =>

         -- Addressing LSB of word op

         -- If a byte operation, the access is complete.
         if byte = '0' then
            cpu_state <= st_cpu_mem_idx_done;
         else
            cpu_state <= cpu_state_return;
         end if;

         -- Byte operators will always be in the MSB.
         t2(0 to 7) <= mem_din;

      when st_cpu_mem_idx_done =>

         -- Save the LSB and return.
         cpu_state <= cpu_state_return;
         t2(8 to 15) <= mem_din;

      end case;
   end if;
   end if;
   end process;

end rtl;
