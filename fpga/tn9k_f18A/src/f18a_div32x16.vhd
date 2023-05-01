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

-- Unsigned 32-bit dividend by 16-bit divisor division for the
-- TMS9900 compatible GPU.  16-clocks for the div-op plus two
-- clocks state change overhead.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity f18a_div32x16 is
   port (
      clk            : in  std_logic;
      reset          : in  std_logic;                    -- active high, forces divider idle
      start          : in  std_logic;                    -- '1' to load and trigger the divide
      ready          : out std_logic;                    -- '1' when ready, '0' while dividing
      done           : out std_logic;                    -- single done tick
      dividend_msb   : in  std_logic_vector(0 to 15);    -- MS Word of dividend 0 to FFFE
      dividend_lsb   : in  std_logic_vector(0 to 15);    -- LS Word of dividend 0 to FFFF
      divisor        : in  std_logic_vector(0 to 15);    -- divisor 0 to FFFF
      q              : out std_logic_vector(0 to 15);
      r              : out std_logic_vector(0 to 15)
   );
end f18a_div32x16;

architecture rtl of f18a_div32x16 is

   type div_state_t is (st_idle, st_op, st_done);
   signal div_state : div_state_t;

   signal rl      : std_logic_vector(0 to 15);           -- dividend lo 16-bits
   signal rh      : unsigned(0 to 15);                   -- dividend hi 16-bits
   signal msb     : std_logic;                           -- shifted msb of dividend for 17-bit subtraction
   signal diff    : unsigned(0 to 15);                   -- quotient - divisor difference
   signal sub17   : unsigned(0 to 16);                   -- 17-bit subtraction
   signal q_bit   : std_logic;                           -- quotient bit
   signal d       : unsigned(0 to 15);                   -- divisor register
   signal count   : integer range 0 to 15;               -- 0 to 15 counter
   signal rdy     : std_logic;
   signal dne     : std_logic;

begin

   -- Quotient and remainder will never be more than 16-bit.
   q <= rl;
   r <= std_logic_vector(rh);
   ready <= rdy;
   done <= dne;

   -- Compare and subtract to derive each quotient bit.
   sub17 <= (msb & rh) - ('0' & d);

   process (sub17, rh)
   begin
      -- If the partial result is greater than or equal to
      -- the divisor, subtract the divisor and set a '1'
      -- quotient bit for this round.
      if sub17(0) = '0' then
         diff <= sub17(1 to 16);
         q_bit <= '1';

      -- The partial result is smaller than the divisor
      -- so set a '0' quotient bit for this round.
      else
         diff <= rh;
         q_bit <= '0';
      end if;
   end process;

   -- Divide
   process (clk) begin if rising_edge(clk) then
      if reset = '1' then
         div_state <= st_idle;
      else

         rdy <= '1';
         dne <= '0';

         case div_state is

         when st_idle =>

            d <= unsigned(divisor);
            count <= 15;
            msb <= '0';

            -- Only change rl and rh when triggered so the registers
            -- retain their values after the division operation.
            if start = '1' then
               div_state <= st_op;
               rl <= dividend_lsb;
               rh <= unsigned(dividend_msb);
               rdy <= '0';
            end if;

         when st_op =>

            -- rl shifts left and stores the quotient bits.
            rl <= rl(1 to 15) & q_bit;
            -- rh shifts left and stores the difference and next dividend bit.
            rh <= diff(1 to 15) & rl(0);
            -- msb stores the shifted-out bit of rh for the 17-bit subtract.
            msb <= diff(0);

            count <= count - 1;
            rdy <= '0';

            if count = 0 then
               div_state <= st_done;
            end if;

         when st_done =>

            -- Final iteration stores the quotient and remainder.
            rl <= rl(1 to 15) & q_bit;
            rh <= diff;
            dne <= '1';
            div_state <= st_idle;

         end case;
      end if;
   end if; end process;

end rtl;
