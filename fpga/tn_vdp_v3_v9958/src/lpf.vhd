--
-- lpf.vhd
--   low pass filter
--   Revision 1.00
--
-- Copyright (c) 2007 Takayuki Hara.
-- All rights reserved.
--
-- Redistribution and use of this source code or any derivative works, are
-- permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Redistributions may not be sold, nor may they be used in a commercial
--    product or activity without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
-- OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
-- OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--


--  LPF [1:4:6:4:1]/16
LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY LPF1 IS
    GENERIC (
        MSBI    : INTEGER
    );
    PORT(
        CLK21M  : IN    STD_LOGIC;
        RESET   : IN    STD_LOGIC;
        CLKENA  : IN    STD_LOGIC;
        IDATA   : IN    STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
        ODATA   : OUT   STD_LOGIC_VECTOR( MSBI DOWNTO 0 )
    );
END LPF1;

ARCHITECTURE RTL OF LPF1 IS
    SIGNAL FF_D1    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D2    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D3    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D4    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D5    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_OUT   : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );

    SIGNAL W_0      : STD_LOGIC_VECTOR( MSBI + 3 DOWNTO 0 );
    SIGNAL W_1      : STD_LOGIC_VECTOR( MSBI + 3 DOWNTO 0 );
    SIGNAL W_2      : STD_LOGIC_VECTOR( MSBI + 1 DOWNTO 0 );
    SIGNAL W_OUT    : STD_LOGIC_VECTOR( MSBI + 4 DOWNTO 0 );
BEGIN

    ODATA   <= FF_OUT;

    W_0     <= ('0' & FF_D3 & "00") + ("00" & FF_D3 & '0');     --  FF_D3 * 6
    W_1     <= (('0' & FF_D2) + ('0' & FF_D4)) & "00";          --  (FF_D2 + DD_D4) * 4
    W_2     <= ('0' & FF_D1) + ('0' & FF_D5);                   --  FF_D1 + FF_D5

    W_OUT   <= ('0' & W_0) + ('0' & W_1) + ("00" & W_2);

    -- DELAY LINE
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_D1   <= ( OTHERS => '0' );
            FF_D2   <= ( OTHERS => '0' );
            FF_D3   <= ( OTHERS => '0' );
            FF_D4   <= ( OTHERS => '0' );
            FF_D5   <= ( OTHERS => '0' );
            FF_OUT  <= ( OTHERS => '0' );
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( CLKENA = '1' )THEN
                FF_D1   <= IDATA;
                FF_D2   <= FF_D1;
                FF_D3   <= FF_D2;
                FF_D4   <= FF_D3;
                FF_D5   <= FF_D4;
                FF_OUT  <= W_OUT( W_OUT'HIGH DOWNTO 4 );
            END IF;
        END IF;
    END PROCESS;
END RTL;

--  LPF [1:1:1:1:1:1:1:1]/8
LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY LPF2 IS
    GENERIC (
        MSBI    : INTEGER
    );
    PORT(
        CLK21M  : IN    STD_LOGIC;
        RESET   : IN    STD_LOGIC;
        CLKENA  : IN    STD_LOGIC;
        IDATA   : IN    STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
        ODATA   : OUT   STD_LOGIC_VECTOR( MSBI DOWNTO 0 )
    );
END LPF2;

ARCHITECTURE RTL OF LPF2 IS
    SIGNAL FF_D1    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D2    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D3    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D4    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D5    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D6    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D7    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_D8    : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
    SIGNAL FF_OUT   : STD_LOGIC_VECTOR( MSBI DOWNTO 0 );

    SIGNAL W_1      : STD_LOGIC_VECTOR( MSBI + 1 DOWNTO 0 );
    SIGNAL W_3      : STD_LOGIC_VECTOR( MSBI + 1 DOWNTO 0 );
    SIGNAL W_5      : STD_LOGIC_VECTOR( MSBI + 1 DOWNTO 0 );
    SIGNAL W_7      : STD_LOGIC_VECTOR( MSBI + 1 DOWNTO 0 );

    SIGNAL W_11     : STD_LOGIC_VECTOR( MSBI + 2 DOWNTO 0 );
    SIGNAL W_13     : STD_LOGIC_VECTOR( MSBI + 2 DOWNTO 0 );

    SIGNAL W_OUT    : STD_LOGIC_VECTOR( MSBI + 3 DOWNTO 0 );
BEGIN

    ODATA   <= FF_OUT;

    W_1     <= ('0' & FF_D1) + ('0' & FF_D8);
    W_3     <= ('0' & FF_D2) + ('0' & FF_D7);
    W_5     <= ('0' & FF_D3) + ('0' & FF_D6);
    W_7     <= ('0' & FF_D4) + ('0' & FF_D5);

    W_11    <= ('0' & W_1) + ('0' & W_5);
    W_13    <= ('0' & W_3) + ('0' & W_7);

    W_OUT   <= ('0' & W_11) + ('0' & W_13);

    -- DELAY LINE
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_D1   <= ( OTHERS => '0' );
            FF_D2   <= ( OTHERS => '0' );
            FF_D3   <= ( OTHERS => '0' );
            FF_D4   <= ( OTHERS => '0' );
            FF_D5   <= ( OTHERS => '0' );
            FF_D6   <= ( OTHERS => '0' );
            FF_D7   <= ( OTHERS => '0' );
            FF_D8   <= ( OTHERS => '0' );
            FF_OUT  <= ( OTHERS => '0' );
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( CLKENA = '1' )THEN
                FF_D1   <= IDATA;
                FF_D2   <= FF_D1;
                FF_D3   <= FF_D2;
                FF_D4   <= FF_D3;
                FF_D5   <= FF_D4;
                FF_D6   <= FF_D5;
                FF_D7   <= FF_D6;
                FF_D8   <= FF_D7;
                FF_OUT  <= W_OUT( W_OUT'HIGH DOWNTO 3 );
            END IF;
        END IF;
    END PROCESS;
END RTL;

-- 線形補間フィルタ用符号付き乗算器 --
LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_SIGNED.ALL;

ENTITY INTERPO_MUL IS
    GENERIC (
        MSBI    : INTEGER
    );
    PORT (
        DIFF    : IN    STD_LOGIC_VECTOR( MSBI+1 DOWNTO 0 );    --  符号付き
        WEIGHT  : IN    STD_LOGIC_VECTOR( 2      DOWNTO 0 );    --  符号無し
        OFF     : OUT   STD_LOGIC_VECTOR( MSBI+4 DOWNTO 0 )     --  符号付き
    );
END INTERPO_MUL;

ARCHITECTURE RTL OF INTERPO_MUL IS
    SIGNAL W_OFF    : STD_LOGIC_VECTOR( MSBI+5 DOWNTO 0 );
BEGIN
    W_OFF   <= DIFF * ('0' & WEIGHT);
    OFF     <= W_OFF( MSBI+4 DOWNTO 0 );
END RTL;

--  線形補間フィルタ --
LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY INTERPO IS
    GENERIC (
        MSBI    : INTEGER
    );
    PORT (
        CLK21M  : IN    STD_LOGIC;
        RESET   : IN    STD_LOGIC;
        CLKENA  : IN    STD_LOGIC;
        IDATA   : IN    STD_LOGIC_VECTOR( MSBI DOWNTO 0 );
        ODATA   : OUT   STD_LOGIC_VECTOR( MSBI DOWNTO 0 )
    );
END INTERPO;

ARCHITECTURE RTL OF INTERPO IS
    COMPONENT INTERPO_MUL
        GENERIC (
            MSBI    : INTEGER
        );
        PORT (
            DIFF    : IN    STD_LOGIC_VECTOR( MSBI+1 DOWNTO 0 );    --  符号付き
            WEIGHT  : IN    STD_LOGIC_VECTOR( 2      DOWNTO 0 );    --  符号無し
            OFF     : OUT   STD_LOGIC_VECTOR( MSBI+4 DOWNTO 0 )     --  符号付き
        );
    END COMPONENT;

    SIGNAL FF_D1        : STD_LOGIC_VECTOR( MSBI   DOWNTO 0 );
    SIGNAL FF_D2        : STD_LOGIC_VECTOR( MSBI   DOWNTO 0 );
    SIGNAL FF_WEIGHT    : STD_LOGIC_VECTOR( 2      DOWNTO 0 );

    SIGNAL W_DIFF       : STD_LOGIC_VECTOR( MSBI+1 DOWNTO 0 );
    SIGNAL W_OFF        : STD_LOGIC_VECTOR( MSBI+4 DOWNTO 0 );
    SIGNAL W_MUL5       : STD_LOGIC_VECTOR( MSBI+6 DOWNTO 0 );
    SIGNAL W_OUT        : STD_LOGIC_VECTOR( MSBI+1 DOWNTO 0 );
BEGIN

    --  遅延ライン --
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_D2 <= (OTHERS => '0');
            FF_D1 <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( CLKENA = '1' )THEN
                FF_D2 <= IDATA;
                FF_D1 <= FF_D2;
            END IF;
        END IF;
    END PROCESS;

    --  補間係数 --
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_WEIGHT <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( CLKENA = '1' )THEN
                FF_WEIGHT <= (OTHERS => '0');
            ELSE
                FF_WEIGHT <= FF_WEIGHT + 1;
            END IF;
        END IF;
    END PROCESS;

    --  補間 --
    --  O = ((D1 * (6-W)) + D2 * W) / 6 = (D1 * 6 - D1 * W + D2 * W) / 6 = D1 + ((D2 - D1) * W) / 6;
    W_DIFF  <= ('0' & FF_D2) - ('0' & FF_D1);   --  符号付き    --

    U_INTERPO_MUL: INTERPO_MUL
    GENERIC MAP (
        MSBI    => MSBI
    )
    PORT MAP (
        DIFF    => W_DIFF,
        WEIGHT  => FF_WEIGHT,
        OFF     => W_OFF
    );

    W_MUL5  <= (W_OFF & "00") + (W_OFF(MSBI+4) & W_OFF(MSBI+4) & W_OFF);
    W_OUT   <= ('0' & FF_D1) + W_MUL5( W_MUL5'HIGH DOWNTO 5 );

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            ODATA <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_OUT( W_OUT'HIGH ) = '0' )THEN
                ODATA <= W_OUT( MSBI DOWNTO 0 );
            ELSE
                ODATA <= (OTHERS => '1');   --  飽和
            END IF;
        END IF;
    END PROCESS;
END RTL;
