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
    use IEEE.numeric_std.all;
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
        VIDEOV          : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );

        VIDEOY_B         : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOY_R         : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 )

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

    SIGNAL Y_B              : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL Y_R              : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL FF_VIDEOY_B      : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL FF_VIDEOY_R      : STD_LOGIC_VECTOR(  5 DOWNTO 0 );


    SIGNAL FF_IVIDEOVS_N    : STD_LOGIC;
    SIGNAL FF_IVIDEOHS_N    : STD_LOGIC;

    CONSTANT CENT           : STD_LOGIC_VECTOR(  7 DOWNTO 0 ) := X"80";

    CONSTANT VREF           : STD_LOGIC_VECTOR(  7 DOWNTO 0 ) := X"3B";

    SIGNAL YCRCB0           : STD_LOGIC_VECTOR(15 downto 0);
    SIGNAL CR0              : STD_LOGIC_VECTOR(15 downto 0);
    SIGNAL CB0              : STD_LOGIC_VECTOR(15 downto 0);


    TYPE TYPTABLE IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    CONSTANT TABLE : TYPTABLE :=(
        X"00", X"FA", X"0C", X"EE", X"18", X"E7", X"18", X"E7",
        X"18", X"E7", X"18", X"E7", X"18", X"E7", X"18", X"E7",
        X"18", X"E7", X"18", X"EE", X"0C", X"FA", X"00", X"00",
        X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00"
    );
    -- de-gamma: level^1/2.22 
    TYPE GAMMA_TBL IS ARRAY (0 TO 255) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    CONSTANT GAMMA : GAMMA_TBL :=(
    x"00", x"15", x"1C", x"22", x"27", x"2B", x"2E", x"32", x"35", x"38", x"3B", x"3D", x"40", x"42", x"44", x"46", 
    x"48", x"4A", x"4C", x"4E", x"50", x"52", x"54", x"55", x"57", x"59", x"5A", x"5C", x"5D", x"5F", x"60", x"62", 
    x"63", x"65", x"66", x"67", x"69", x"6A", x"6B", x"6D", x"6E", x"6F", x"70", x"72", x"73", x"74", x"75", x"76", 
    x"77", x"78", x"7A", x"7B", x"7C", x"7D", x"7E", x"7F", x"80", x"81", x"82", x"83", x"84", x"85", x"86", x"87", 
    x"88", x"89", x"8A", x"8B", x"8C", x"8D", x"8E", x"8F", x"90", x"90", x"91", x"92", x"93", x"94", x"95", x"96", 
    x"97", x"97", x"98", x"99", x"9A", x"9B", x"9C", x"9C", x"9D", x"9E", x"9F", x"A0", x"A0", x"A1", x"A2", x"A3", 
    x"A4", x"A4", x"A5", x"A6", x"A7", x"A7", x"A8", x"A9", x"AA", x"AA", x"AB", x"AC", x"AD", x"AD", x"AE", x"AF", 
    x"AF", x"B0", x"B1", x"B2", x"B2", x"B3", x"B4", x"B4", x"B5", x"B6", x"B6", x"B7", x"B8", x"B8", x"B9", x"BA", 
    x"BA", x"BB", x"BC", x"BC", x"BD", x"BE", x"BE", x"BF", x"C0", x"C0", x"C1", x"C2", x"C2", x"C3", x"C3", x"C4", 
    x"C5", x"C5", x"C6", x"C7", x"C7", x"C8", x"C8", x"C9", x"CA", x"CA", x"CB", x"CB", x"CC", x"CD", x"CD", x"CE", 
    x"CE", x"CF", x"CF", x"D0", x"D1", x"D1", x"D2", x"D2", x"D3", x"D4", x"D4", x"D5", x"D5", x"D6", x"D6", x"D7", 
    x"D7", x"D8", x"D9", x"D9", x"DA", x"DA", x"DB", x"DB", x"DC", x"DC", x"DD", x"DD", x"DE", x"DF", x"DF", x"E0", 
    x"E0", x"E1", x"E1", x"E2", x"E2", x"E3", x"E3", x"E4", x"E4", x"E5", x"E5", x"E6", x"E6", x"E7", x"E7", x"E8", 
    x"E8", x"E9", x"E9", x"EA", x"EA", x"EB", x"EB", x"EC", x"EC", x"ED", x"ED", x"EE", x"EE", x"EF", x"EF", x"F0", 
    x"F0", x"F1", x"F1", x"F2", x"F2", x"F3", x"F3", x"F4", x"F4", x"F5", x"F5", x"F6", x"F6", x"F7", x"F7", x"F8", 
    x"F8", x"F9", x"F9", x"F9", x"FA", x"FA", x"FB", x"FB", x"FC", x"FC", x"FD", x"FD", x"FE", x"FE", x"FF", x"FF"
 );

BEGIN

    VIDEOY <= FF_VIDEOY;
    VIDEOC <= FF_VIDEOC;
    VIDEOV <= FF_VIDEOV;

    VIDEOY_B <= FF_VIDEOY_B;
    VIDEOY_R <= FF_VIDEOY_R;

    --  Y = +0.299R +0.587G +0.114B
    -- +U = +0.615R -0.518G -0.097B (  0)
    -- +V = +0.179R -0.510G +0.331B ( 60)
    -- +W = -0.435R +0.007G +0.428B (120)
    -- -U = -0.615R +0.518G +0.097B (180)
    -- -V = -0.179R +0.510G -0.331B (240)
    -- -W = +0.435R -0.007G -0.428B (300)

 --   Y <=    (('0' & Y1(11 DOWNTO 5)) + (('0' & Y2(11 DOWNTO 5)) + ('0' & Y3(11 DOWNTO 5))) + VREF);

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

--    Y_B <= (X"00" + ('0' & U1(11 DOWNTO 5)) + ('0' & U2(11 DOWNTO 5)) + ('0' & U3(11 DOWNTO 5))) ;
--    Y_R <= (X"00" + ('0' & V1(11 DOWNTO 5)) + ('0' & V2(11 DOWNTO 5)) + ('0' & V3(11 DOWNTO 5))) ;

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

    YCRCB0 <= (128 + (X"42" * FF_IVIDEOR & "00") + (X"81" * FF_IVIDEOG & "00") + (X"19" * FF_IVIDEOB & "00"));
    CB0    <= (128 - (X"26" * FF_IVIDEOR & "00") - (X"4A" * FF_IVIDEOG & "00") + (X"70" * FF_IVIDEOB & "00"));
    CR0    <= (128 + (X"70" * FF_IVIDEOR & "00") - (X"5E" * FF_IVIDEOG & "00") - (X"12" * FF_IVIDEOB & "00"));

    Y   <= (GAMMA(conv_integer(YCRCB0(15 downto 8) +  16)));
    Y_B <= (CB0(15 downto 8) + 128); 
    Y_R <= (CR0(15 downto 8) + 128); 

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
                FF_SEQ <= "111";
--            ELSIF( FF_SEQ(1 DOWNTO 0) = "00" )THEN
--                FF_SEQ <= FF_SEQ - 1;
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

                FF_VIDEOY_B <= (OTHERS => '0');
                FF_VIDEOY_R <= (OTHERS => '0');

            ELSIF( FF_WINDOW_V = '1' AND FF_WINDOW_H = '1' )THEN
                FF_VIDEOY <= Y(7 DOWNTO 2);
                FF_VIDEOC <= C(7 DOWNTO 2);
                FF_VIDEOV <= V(7 DOWNTO 2);

                FF_VIDEOY_B <= Y_B(7 DOWNTO 2);
                FF_VIDEOY_R <= Y_R(7 DOWNTO 2);
            ELSE
                FF_VIDEOY <= VREF(7 DOWNTO 2);

                FF_VIDEOY_B <= CENT(7 DOWNTO 2); 
                FF_VIDEOY_R <= CENT(7 DOWNTO 2); 

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
