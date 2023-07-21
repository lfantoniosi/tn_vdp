--
--  vdp_hvcounter.vhd
--   horizontal and vertical counter of ESE-VDP.
--
--  Copyright (C) 2000-2006 Kunihiko Ohnaka
--  All rights reserved.
--                                     http://www.ohnaka.jp/ese-vdp/
--
--  本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
--  満たす場合に限り、再頒布および使用が許可されます。
--
--  1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
--    免責条項をそのままの形で保持すること。
--  2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
--    著作権表示、本条件一覧、および下記免責条項を含めること。
--  3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
--    に使用しないこと。
--
--  本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
--  特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
--  的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
--  発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
--  その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
--  されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
--  ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
--  れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
--  たは結果損害について、一切責任を負わないものとします。
--
--  Note that above Japanese version license is the formal document.
--  The following translation is only for reference.
--
--  Redistribution and use of this software or any derivative works,
--  are permitted provided that the following conditions are met:
--
--  1. Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer.
--  2. Redistributions in binary form must reproduce the above
--     copyright notice, this list of conditions and the following
--     disclaimer in the documentation and/or other materials
--     provided with the distribution.
--  3. Redistributions may not be sold, nor may they be used in a
--     commercial product or activity without specific prior written
--     permission.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
--  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
--  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
--  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
--  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
--  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
--  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--  POSSIBILITY OF SUCH DAMAGE.
--
-------------------------------------------------------------------------------
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE IEEE.STD_LOGIC_ARITH.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_HVCOUNTER IS
    PORT(
        RESET                   : IN    STD_LOGIC;
        CLK21M                  : IN    STD_LOGIC;

        H_CNT                   : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        H_CNT_IN_FIELD          : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        V_CNT_IN_FIELD          : OUT   STD_LOGIC_VECTOR(  9 DOWNTO 0 );
        V_CNT_IN_FRAME          : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        FIELD                   : OUT   STD_LOGIC;
        H_BLANK                 : OUT   STD_LOGIC;
        V_BLANK                 : OUT   STD_LOGIC;

        PAL_MODE                : IN    STD_LOGIC;
        INTERLACE_MODE          : IN    STD_LOGIC;
        Y212_MODE               : IN    STD_LOGIC;
        OFFSET_Y                : IN    STD_LOGIC_VECTOR(  6 DOWNTO 0 );
        HDMI_RESET              : OUT   STD_LOGIC
    );
END VDP_HVCOUNTER;

ARCHITECTURE RTL OF VDP_HVCOUNTER IS

    -- FLIP FLOP
    SIGNAL FF_H_CNT                 : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL FF_H_CNT_IN_FIELD        : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL FF_V_CNT_IN_FIELD        : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL FF_FIELD                 : STD_LOGIC;
    SIGNAL FF_V_CNT_IN_FRAME        : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL FF_H_BLANK               : STD_LOGIC;
    SIGNAL FF_V_BLANK               : STD_LOGIC;
    SIGNAL FF_PAL_MODE              : STD_LOGIC;
    SIGNAL FF_INTERLACE_MODE        : STD_LOGIC;
    SIGNAL FF_FIELD_END_CNT         : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL FF_FIELD_END             : STD_LOGIC;
    SIGNAL FF_HDMI_RESET            : STD_LOGIC;

    -- WIRE
    SIGNAL W_FIELD                  : STD_LOGIC;
    SIGNAL W_H_CNT_HALF             : STD_LOGIC;
    SIGNAL W_H_CNT_END              : STD_LOGIC;
    SIGNAL W_FIELD_END_CNT          : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL W_FIELD_END              : STD_LOGIC;
    SIGNAL W_DISPLAY_MODE           : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL W_LINE_MODE              : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL W_H_BLANK_START          : STD_LOGIC;
    SIGNAL W_H_BLANK_END            : STD_LOGIC;
    SIGNAL W_V_BLANKING_START       : STD_LOGIC;
    SIGNAL W_V_BLANKING_END         : STD_LOGIC;
    SIGNAL W_V_SYNC_INTR_START_LINE : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        
BEGIN

    H_CNT               <= FF_H_CNT;
    H_CNT_IN_FIELD      <= FF_H_CNT_IN_FIELD;
    V_CNT_IN_FIELD      <= FF_V_CNT_IN_FIELD;
    FIELD               <= FF_FIELD;
    V_CNT_IN_FRAME      <= FF_V_CNT_IN_FRAME;
    H_BLANK             <= FF_H_BLANK;
    V_BLANK             <= FF_V_BLANK;
    HDMI_RESET          <= FF_HDMI_RESET;
    --------------------------------------------------------------------------
    --  V SYNCHRONIZE MODE CHANGE
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_PAL_MODE         <= '0';
            FF_INTERLACE_MODE   <= '0';
            FF_HDMI_RESET       <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( ((W_H_CNT_HALF OR W_H_CNT_END) AND W_FIELD_END AND FF_FIELD) = '1' )THEN
                FF_PAL_MODE         <= PAL_MODE;
                FF_INTERLACE_MODE   <= INTERLACE_MODE;
                IF (FF_PAL_MODE = PAL_MODE)THEN
                    FF_HDMI_RESET <= '0';
                ELSE 
                    FF_HDMI_RESET <= '1';
                END IF;
            ELSE
                FF_HDMI_RESET       <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            CLOCKS_PER_LINE         := 1716;
            CLOCKS_PER_HALF_LINE    := 858;
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( HDMI_RESET = '1' )THEN
                IF (PAL_MODE = '0') THEN
                    CLOCKS_PER_LINE         := 1716;
                    CLOCKS_PER_HALF_LINE    := 858;
                ELSE
                    CLOCKS_PER_LINE         := 1728;
                    CLOCKS_PER_HALF_LINE    := 864;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    --  HORIZONTAL COUNTER
    --------------------------------------------------------------------------
    W_H_CNT_HALF    <=  '1' WHEN( FF_H_CNT = (CLOCKS_PER_HALF_LINE)-1 )ELSE
                        '0';
    W_H_CNT_END     <=  '1' WHEN( FF_H_CNT = CLOCKS_PER_LINE-1 )ELSE
                        '0';

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_H_CNT <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_H_CNT_END = '1' OR (W_FIELD_END = '1' AND W_H_CNT_HALF ='1' AND FF_INTERLACE_MODE='0'))THEN
                FF_H_CNT <= (OTHERS => '0' );
            ELSE
                FF_H_CNT <= FF_H_CNT + 1;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_H_CNT_IN_FIELD <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_H_CNT_END = '1' OR W_H_CNT_HALF = '1' )THEN
                FF_H_CNT_IN_FIELD <= (OTHERS => '0' );
            ELSE
                FF_H_CNT_IN_FIELD <= FF_H_CNT_IN_FIELD + 1;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    --  VERTICAL COUNTER
    --------------------------------------------------------------------------
--    W_DISPLAY_MODE  <=  FF_INTERLACE_MODE & FF_PAL_MODE;
--    WITH( W_DISPLAY_MODE )SELECT W_FIELD_END_CNT <=
--        CONV_STD_LOGIC_VECTOR( 523, 10 )    WHEN "00",
--        CONV_STD_LOGIC_VECTOR( 524, 10 )    WHEN "10",

--        CONV_STD_LOGIC_VECTOR( 623, 10 )    WHEN "01",
--        CONV_STD_LOGIC_VECTOR( 624, 10 )    WHEN "11",

--        (OTHERS=>'X')                       WHEN OTHERS;

--    W_FIELD_END <=  '1' WHEN( FF_V_CNT_IN_FIELD = FF_FIELD_END_CNT )ELSE
--                    '0';

    W_FIELD_END <= FF_FIELD_END;
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_FIELD_END   <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
                IF (
                    (FF_FIELD = '0' AND FF_INTERLACE_MODE = '0' AND FF_PAL_MODE = '0' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 524, 10 )) OR
                    (FF_FIELD = '0' AND FF_INTERLACE_MODE = '0' AND FF_PAL_MODE = '1' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 624, 10 )) OR
                    (FF_FIELD = '1' AND FF_INTERLACE_MODE = '0' AND FF_PAL_MODE = '0' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 524, 10 )) OR
                    (FF_FIELD = '1' AND FF_INTERLACE_MODE = '0' AND FF_PAL_MODE = '1' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 624, 10 )) OR

                    (FF_FIELD = '0' AND FF_INTERLACE_MODE = '1' AND FF_PAL_MODE = '0' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 524, 10 )) OR
                    (FF_FIELD = '0' AND FF_INTERLACE_MODE = '1' AND FF_PAL_MODE = '1' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 624, 10 )) OR
                    (FF_FIELD = '1' AND FF_INTERLACE_MODE = '1' AND FF_PAL_MODE = '0' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 524, 10 )) OR
                    (FF_FIELD = '1' AND FF_INTERLACE_MODE = '1' AND FF_PAL_MODE = '1' AND FF_V_CNT_IN_FIELD = CONV_STD_LOGIC_VECTOR( 624, 10 )) ) THEN
                FF_FIELD_END <= '1';
            ELSE    
                FF_FIELD_END <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_V_CNT_IN_FIELD   <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (W_H_CNT_HALF OR W_H_CNT_END) = '1' )THEN
                IF( W_FIELD_END = '1' )THEN
                    FF_V_CNT_IN_FIELD <= (OTHERS => '0');
                ELSE
                    FF_V_CNT_IN_FIELD <= FF_V_CNT_IN_FIELD + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    --  FIELD ID
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_FIELD <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            -- GENERATE FF_FIELD SIGNAL
            IF( (W_H_CNT_HALF OR W_H_CNT_END) = '1' )THEN
                IF( W_FIELD_END = '1' )THEN
                    FF_FIELD <= NOT FF_FIELD;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    --  VERTICAL COUNTER IN FRAME
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_V_CNT_IN_FRAME   <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (W_H_CNT_HALF OR W_H_CNT_END) = '1' )THEN
                IF( W_FIELD_END = '1' AND (FF_FIELD = '1' OR FF_INTERLACE_MODE = '0')) THEN
                    FF_V_CNT_IN_FRAME   <= (OTHERS => '0');
                ELSE
                    FF_V_CNT_IN_FRAME   <= FF_V_CNT_IN_FRAME + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- H BLANKING
    -----------------------------------------------------------------------------
    W_H_BLANK_START     <=   W_H_CNT_END;
    W_H_BLANK_END       <=  '1' WHEN( FF_H_CNT = LEFT_BORDER )ELSE
                            '0';

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_H_BLANK <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_H_BLANK_START = '1' )THEN
                FF_H_BLANK <= '1';
            ELSIF( W_H_BLANK_END = '1' )THEN
                FF_H_BLANK <= '0';
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- V BLANKING
    -----------------------------------------------------------------------------
    W_LINE_MODE <= Y212_MODE & FF_PAL_MODE;

    WITH W_LINE_MODE SELECT W_V_SYNC_INTR_START_LINE <=
        CONV_STD_LOGIC_VECTOR( V_BLANKING_START_192_NTSC, 9 )   WHEN "00",
        CONV_STD_LOGIC_VECTOR( V_BLANKING_START_212_NTSC, 9 )   WHEN "10",
        CONV_STD_LOGIC_VECTOR( V_BLANKING_START_192_PAL, 9 )    WHEN "01",
        CONV_STD_LOGIC_VECTOR( V_BLANKING_START_212_PAL, 9 )    WHEN "11",
        (OTHERS => 'X')                                         WHEN OTHERS;

    W_V_BLANKING_END    <=  '1' WHEN( (FF_V_CNT_IN_FIELD = ("00" & (OFFSET_Y + LED_TV_Y_NTSC) & (FF_FIELD AND FF_INTERLACE_MODE)) AND FF_PAL_MODE = '0') OR
                                      (FF_V_CNT_IN_FIELD = ("00" & (OFFSET_Y + LED_TV_Y_PAL) & (FF_FIELD AND FF_INTERLACE_MODE)) AND FF_PAL_MODE = '1') )ELSE
                            '0';
    W_V_BLANKING_START  <=  '1' WHEN( (FF_V_CNT_IN_FIELD = ((W_V_SYNC_INTR_START_LINE + LED_TV_Y_NTSC) & (FF_FIELD AND FF_INTERLACE_MODE)) AND FF_PAL_MODE = '0') OR
                                      (FF_V_CNT_IN_FIELD = ((W_V_SYNC_INTR_START_LINE + LED_TV_Y_PAL) & (FF_FIELD AND FF_INTERLACE_MODE)) AND FF_PAL_MODE = '1') )ELSE
                            '0';

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_V_BLANK <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_H_BLANK_END = '1' )THEN
                IF( W_V_BLANKING_END = '1' )THEN
                    FF_V_BLANK <= '0';
                ELSIF( W_V_BLANKING_START = '1' )THEN
                    FF_V_BLANK <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS;

END RTL;
