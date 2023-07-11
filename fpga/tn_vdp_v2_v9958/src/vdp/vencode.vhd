--
-- vencode.vhd
--   RGB to NTSC video encoder
--   Revision 1.00
--
-- Copyright (c) 2006 Kazuhiro Tsujikawa (ESE Artists' factory)
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

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY VENCODE IS
    PORT(
        -- VDP CLOCK ... 21.477MHZ
        CLK21M          : IN    STD_LOGIC;
        RESET           : IN    STD_LOGIC;

        -- VIDEO INPUT
        VIDEOR          : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOG          : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOB          : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOHS_N       : IN    STD_LOGIC;
        VIDEOVS_N       : IN    STD_LOGIC;

        -- VIDEO OUTPUT
        VIDEOY          : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOC          : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOV          : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 )
    );
END VENCODE;

ARCHITECTURE RTL OF VENCODE IS

    SIGNAL FF_VIDEOY        : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL FF_VIDEOC        : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL FF_VIDEOV        : STD_LOGIC_VECTOR(  5 DOWNTO 0 );

    SIGNAL FF_SEQ           : STD_LOGIC_VECTOR(  2 DOWNTO 0 );

    SIGNAL FF_BURPHASE      : STD_LOGIC;
    SIGNAL FF_VCOUNTER      : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_HCOUNTER      : STD_LOGIC_VECTOR( 11 DOWNTO 0 );
    SIGNAL FF_WINDOW_V      : STD_LOGIC;
    SIGNAL FF_WINDOW_H      : STD_LOGIC;
    SIGNAL FF_WINDOW_C      : STD_LOGIC;
    SIGNAL FF_TABLEADR      : STD_LOGIC_VECTOR(  4 DOWNTO 0 );
    SIGNAL FF_TABLEDAT      : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL FF_PAL_DET_CNT   : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_PAL_MODE      : STD_LOGIC;

    SIGNAL FF_IVIDEOR       : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL FF_IVIDEOG       : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL FF_IVIDEOB       : STD_LOGIC_VECTOR(  5 DOWNTO 0 );

    SIGNAL Y                : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL C                : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL V                : STD_LOGIC_VECTOR(  7 DOWNTO 0 );

    SIGNAL C0               : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL Y1               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL Y2               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL Y3               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL U1               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL U2               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL U3               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL V1               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL V2               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL V3               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL W1               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL W2               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );
    SIGNAL W3               : STD_LOGIC_VECTOR( 13 DOWNTO 0 );

    SIGNAL FF_IVIDEOVS_N    : STD_LOGIC;
    SIGNAL FF_IVIDEOHS_N    : STD_LOGIC;

    CONSTANT VREF           : STD_LOGIC_VECTOR(  7 DOWNTO 0 ) := X"3B";
    CONSTANT CENT           : STD_LOGIC_VECTOR(  7 DOWNTO 0 ) := X"80";

    TYPE TYPTABLE IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    CONSTANT TABLE : TYPTABLE :=(
        X"00", X"FA", X"0C", X"EE", X"18", X"E7", X"18", X"E7",
        X"18", X"E7", X"18", X"E7", X"18", X"E7", X"18", X"E7",
        X"18", X"E7", X"18", X"EE", X"0C", X"FA", X"00", X"00",
        X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00"
    );

BEGIN

    VIDEOY <= FF_VIDEOY;
    VIDEOC <= FF_VIDEOC;
    VIDEOV <= FF_VIDEOV;

    --  Y = +0.299R +0.587G +0.114B
    -- +U = +0.615R -0.518G -0.097B (  0)
    -- +V = +0.179R -0.510G +0.331B ( 60)
    -- +W = -0.435R +0.007G +0.428B (120)
    -- -U = -0.615R +0.518G +0.097B (180)
    -- -V = -0.179R +0.510G -0.331B (240)
    -- -W = +0.435R -0.007G -0.428B (300)

    Y <=    (('0' & Y1(11 DOWNTO 5)) + (('0' & Y2(11 DOWNTO 5)) + ('0' & Y3(11 DOWNTO 5))) + VREF);

    V <=    Y(7 DOWNTO 0)   + C0(7 DOWNTO 0) WHEN FF_SEQ = "110" ELSE   --  +U
            Y(7 DOWNTO 0)   + C0(7 DOWNTO 0) WHEN FF_SEQ = "101" ELSE   --  +V
            Y(7 DOWNTO 0)   + C0(7 DOWNTO 0) WHEN FF_SEQ = "100" ELSE   --  +W
            Y(7 DOWNTO 0)   - C0(7 DOWNTO 0) WHEN FF_SEQ = "010" ELSE   --  -U
            Y(7 DOWNTO 0)   - C0(7 DOWNTO 0) WHEN FF_SEQ = "001" ELSE   --  -V
            Y(7 DOWNTO 0)   - C0(7 DOWNTO 0);                           --  -W

    C <=    CENT            + C0(7 DOWNTO 0) WHEN FF_SEQ = "110" ELSE   --  +U
            CENT            + C0(7 DOWNTO 0) WHEN FF_SEQ = "101" ELSE   --  +V
            CENT            + C0(7 DOWNTO 0) WHEN FF_SEQ = "100" ELSE   --  +W
            CENT            - C0(7 DOWNTO 0) WHEN FF_SEQ = "010" ELSE   --  -U
            CENT            - C0(7 DOWNTO 0) WHEN FF_SEQ = "001" ELSE   --  -V
            CENT            - C0(7 DOWNTO 0);                           --  -W


    C0 <=   (X"00" + ('0' & U1(11 DOWNTO 5)) - ('0' & U2(11 DOWNTO 5)) - ('0' & U3(11 DOWNTO 5))) WHEN FF_SEQ(1) = '1' ELSE
            (X"00" + ('0' & V1(11 DOWNTO 5)) - ('0' & V2(11 DOWNTO 5)) + ('0' & V3(11 DOWNTO 5))) WHEN FF_SEQ(0) = '1' ELSE
            (X"00" - ('0' & W1(11 DOWNTO 5)) + ('0' & W2(11 DOWNTO 5)) + ('0' & W3(11 DOWNTO 5)));

    Y1 <= (X"18" * FF_IVIDEOR); -- HEX(0.299*(2*0.714*256/3.3)*0.72*16) = $17.D
    Y2 <= (X"2F" * FF_IVIDEOG); -- HEX(0.587*(2*0.714*256/3.3)*0.72*16) = $2E.D
    Y3 <= (X"09" * FF_IVIDEOB); -- HEX(0.114*(2*0.714*256/3.3)*0.72*16) = $09.1

    U1 <= (X"32" * FF_IVIDEOR); -- HEX(0.615*(2*0.714*256/3.3)*0.72*16) = $31.0
    U2 <= (X"29" * FF_IVIDEOG); -- HEX(0.518*(2*0.714*256/3.3)*0.72*16) = $29.5
    U3 <= (X"08" * FF_IVIDEOB); -- HEX(0.097*(2*0.714*256/3.3)*0.72*16) = $07.B

    V1 <= (X"0F" * FF_IVIDEOR); -- HEX(0.179*(2*0.714*256/3.3)*0.72*16) = $0E.4
    V2 <= (X"28" * FF_IVIDEOG); -- HEX(0.510*(2*0.714*256/3.3)*0.72*16) = $28.A
    V3 <= (X"1A" * FF_IVIDEOB); -- HEX(0.331*(2*0.714*256/3.3)*0.72*16) = $1A.6

    W1 <= (X"24" * FF_IVIDEOR); -- HEX(0.435*(2*0.714*256/3.3)*0.72*16) = $22.B
    W2 <= (X"01" * FF_IVIDEOG); -- HEX(0.007*(2*0.714*256/3.3)*0.72*16) = $00.8
    W3 <= (X"22" * FF_IVIDEOB); -- HEX(0.428*(2*0.714*256/3.3)*0.72*16) = $22.2

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            FF_IVIDEOVS_N <= VIDEOVS_N;
            FF_IVIDEOHS_N <= VIDEOHS_N;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- CLOCK PHASE : 3.58MHZ(1FSC) = 21.48MHZ(6FSC) / 6
    -- FF_SEQ : (7) 654 (3) 210
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (VIDEOHS_N = '0' AND FF_IVIDEOHS_N = '1') )THEN
                FF_SEQ <= "110";
            ELSIF( FF_SEQ(1 DOWNTO 0) = "00" )THEN
                FF_SEQ <= FF_SEQ - 2;
            ELSE
                FF_SEQ <= FF_SEQ - 1;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- HORIZONTAL COUNTER : MSX_X=0[FF_HCOUNTER=100H], MSX_X=511[FF_HCOUNTER=4FF]
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( VIDEOHS_N = '0' AND FF_IVIDEOHS_N = '1' )THEN
                FF_HCOUNTER <= X"000";
            ELSE
                FF_HCOUNTER <= FF_HCOUNTER + 1;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- VERTICAL COUNTER : MSX_Y=0[FF_VCOUNTER=22H], MSX_Y=211[FF_VCOUNTER=F5H]
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( VIDEOVS_N = '1' AND FF_IVIDEOVS_N = '0' )THEN
                FF_VCOUNTER <= (OTHERS => '0');
                FF_BURPHASE <= '0';
            ELSIF( VIDEOHS_N = '0' AND FF_IVIDEOHS_N = '1' )THEN
                FF_VCOUNTER <= FF_VCOUNTER + 1;
                FF_BURPHASE <= FF_BURPHASE XOR (NOT FF_HCOUNTER(1)); -- FF_HCOUNTER:1364/1367
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- VERTICAL DISPLAY WINDOW
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( FF_VCOUNTER = (X"22" - X"10" - 1) )THEN
                FF_WINDOW_V <= '1';
            ELSIF(  ((FF_VCOUNTER = 262-7) AND (FF_PAL_MODE = '0')) OR
                    ((FF_VCOUNTER = 312-7) AND (FF_PAL_MODE = '1')) )THEN
                -- JP: -7という数字にあまり根拠は無い。オリジナルのソースが
                -- JP:  FF_VCOUNTER = X"FF"
                -- JP: という条件判定をしていたのでそれを 262-7と表現し直した。
                -- JP: 恐らく、オリジナルのソースはカウンタが8ビットだっため、
                -- JP: 255が最大値だったのだろう。
                -- JP: 大中的には 262-3= 259くらいで良いと思う(ボトムボーダ領域は
                -- JP: 3ラインだから)
                FF_WINDOW_V <= '0';
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- HORIZONTAL DISPLAY WINDOW
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( FF_HCOUNTER = (X"100" - X"030" - 1) )THEN
                FF_WINDOW_H <= '1';
            ELSIF( FF_HCOUNTER = (X"4FF" + X"030" - 1) )THEN
                FF_WINDOW_H <= '0';
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- COLOR BURST WINDOW
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (FF_WINDOW_V = '0') OR (FF_HCOUNTER = X"0CC") )THEN
                FF_WINDOW_C <= '0';
            ELSIF( FF_WINDOW_V = '1' AND (FF_HCOUNTER = X"06C") )THEN
                FF_WINDOW_C <= '1';
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- COLOR BURST TABLE POINTER
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( FF_WINDOW_C = '0' )THEN
                FF_TABLEADR <= (OTHERS => '0');
            ELSIF( FF_SEQ = "101" OR FF_SEQ = "001" )THEN
                FF_TABLEADR <= FF_TABLEADR + 1;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            FF_TABLEDAT <= TABLE(CONV_INTEGER(FF_TABLEADR));
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- VIDEO ENCODE
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (VIDEOVS_N XOR VIDEOHS_N) = '1' )THEN
                FF_VIDEOY <= (OTHERS => '0');
                FF_VIDEOC <= CENT(7 DOWNTO 2);
                FF_VIDEOV <= (OTHERS => '0');
            ELSIF( FF_WINDOW_V = '1' AND FF_WINDOW_H = '1' )THEN
                FF_VIDEOY <= Y(7 DOWNTO 2);
                FF_VIDEOC <= C(7 DOWNTO 2);
                FF_VIDEOV <= V(7 DOWNTO 2);
            ELSE
                FF_VIDEOY <= VREF(7 DOWNTO 2);
                IF( FF_SEQ(1 DOWNTO 0) = "10" )THEN
                    FF_VIDEOC <= CENT(7 DOWNTO 2);
                    FF_VIDEOV <= VREF(7 DOWNTO 2);
                ELSIF( FF_BURPHASE = '1' )THEN
                    FF_VIDEOC <= CENT(7 DOWNTO 2) + FF_TABLEDAT(7 DOWNTO 2);
                    FF_VIDEOV <= VREF(7 DOWNTO 2) + FF_TABLEDAT(7 DOWNTO 2);
                ELSE
                    FF_VIDEOC <= CENT(7 DOWNTO 2) - FF_TABLEDAT(7 DOWNTO 2);
                    FF_VIDEOV <= VREF(7 DOWNTO 2) - FF_TABLEDAT(7 DOWNTO 2);
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (VIDEOVS_N XOR VIDEOHS_N) = '1' )THEN
                -- HOLD
            ELSIF( FF_WINDOW_V = '1' AND FF_WINDOW_H = '1' )THEN
                IF( FF_HCOUNTER(0) = '0' )THEN
                    FF_IVIDEOR <= VIDEOR;
                    FF_IVIDEOG <= VIDEOG;
                    FF_IVIDEOB <= VIDEOB;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- PAL AUTO DETECTION
    --------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF(    VIDEOVS_N = '1' AND FF_IVIDEOVS_N = '0' )THEN
                FF_PAL_DET_CNT <= (OTHERS => '0');
            ELSIF( VIDEOHS_N = '0' AND FF_IVIDEOHS_N = '1' )THEN
                FF_PAL_DET_CNT <= FF_PAL_DET_CNT + 1;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( VIDEOVS_N = '1' AND FF_IVIDEOVS_N = '0' )THEN
                IF( FF_PAL_DET_CNT > 300 )THEN
                    FF_PAL_MODE <= '1';
                ELSE
                    FF_PAL_MODE <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;
END RTL;
