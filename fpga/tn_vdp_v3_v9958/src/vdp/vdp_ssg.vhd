--
--  vdp_ssg.vhd
--   Synchronous Signal Generator of ESE-VDP.
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
--  30th,March,2008
--  JP: VDP.VHD から分離 by t.hara
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE IEEE.STD_LOGIC_ARITH.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_SSG IS
    PORT(
        RESET                   : IN    STD_LOGIC;
        CLK21M                  : IN    STD_LOGIC;

        H_CNT                   : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        H_CNT_IN_FIELD          : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        V_CNT                   : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        DOTSTATE                : OUT   STD_LOGIC_VECTOR(  1 DOWNTO 0 );
        EIGHTDOTSTATE           : OUT   STD_LOGIC_VECTOR(  2 DOWNTO 0 );
        PREDOTCOUNTER_X         : OUT   STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        PREDOTCOUNTER_Y         : OUT   STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        PREDOTCOUNTER_YP        : OUT   STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        PREWINDOW_Y             : OUT   STD_LOGIC;
        PREWINDOW_Y_SP          : OUT   STD_LOGIC;
        FIELD                   : OUT   STD_LOGIC;
        WINDOW_X                : OUT   STD_LOGIC;
        PVIDEODHCLK             : OUT   STD_LOGIC;
        PVIDEODLCLK             : OUT   STD_LOGIC;
        IVIDEOVS_N              : OUT   STD_LOGIC;

        HD                      : OUT   STD_LOGIC;
        VD                      : OUT   STD_LOGIC;
        HSYNC                   : OUT   STD_LOGIC;
        ENAHSYNC                : OUT   STD_LOGIC;
        V_BLANKING_START        : OUT   STD_LOGIC;

        VDPR9PALMODE            : IN    STD_LOGIC;
        REG_R9_INTERLACE_MODE   : IN    STD_LOGIC;
        REG_R9_Y_DOTS           : IN    STD_LOGIC;
        REG_R18_ADJ             : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
--        REG_R19_HSYNC_INT_LINE  : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R23_VSTART_LINE     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R25_MSK             : IN    STD_LOGIC;
        REG_R27_H_SCROLL        : IN    STD_LOGIC_VECTOR(  2 DOWNTO 0 );
        REG_R25_YJK             : IN    STD_LOGIC;
        CENTERYJK_R25_N         : IN    STD_LOGIC;
        OFFSET_Y                : IN    STD_LOGIC_VECTOR(  6 DOWNTO 0 );
        HDMI_RESET              : OUT   STD_LOGIC
    );
END VDP_SSG;

ARCHITECTURE RTL OF VDP_SSG IS

    COMPONENT VDP_HVCOUNTER
        PORT(
            RESET               : IN    STD_LOGIC;
            CLK21M              : IN    STD_LOGIC;

            H_CNT               : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
            H_CNT_IN_FIELD      : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
            V_CNT_IN_FIELD      : OUT   STD_LOGIC_VECTOR(  9 DOWNTO 0 );
            V_CNT_IN_FRAME      : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
            FIELD               : OUT   STD_LOGIC;
            H_BLANK             : OUT   STD_LOGIC;
            V_BLANK             : OUT   STD_LOGIC;

            PAL_MODE            : IN    STD_LOGIC;
            INTERLACE_MODE      : IN    STD_LOGIC;
            Y212_MODE           : IN    STD_LOGIC;
            OFFSET_Y            : IN    STD_LOGIC_VECTOR(  6 DOWNTO 0 );
            HDMI_RESET          : OUT   STD_LOGIC
        );
    END COMPONENT;

    -- FLIP FLOP
    SIGNAL FF_DOTSTATE          : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL FF_EIGHTDOTSTATE     : STD_LOGIC_VECTOR(  2 DOWNTO 0 );
    SIGNAL FF_PRE_X_CNT         : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_X_CNT             : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_PRE_Y_CNT         : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_MONITOR_LINE      : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_VIDEO_DH_CLK      : STD_LOGIC;
    SIGNAL FF_VIDEO_DL_CLK      : STD_LOGIC;
    SIGNAL FF_PRE_X_CNT_START1  : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL FF_RIGHT_MASK        : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_WINDOW_X          : STD_LOGIC;

    -- WIRE
    SIGNAL W_H_CNT                  : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL W_H_CNT_IN_FIELD         : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL W_V_CNT_IN_FRAME         : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL W_V_CNT_IN_FIELD         : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL W_FIELD                  : STD_LOGIC;
    SIGNAL W_H_BLANK                : STD_LOGIC;
    SIGNAL W_V_BLANK                : STD_LOGIC;
    SIGNAL W_PRE_X_CNT_START0       : STD_LOGIC_VECTOR(  4 DOWNTO 0 );
    SIGNAL W_PRE_X_CNT_START2       : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL W_HSYNC                  : STD_LOGIC;
    SIGNAL W_LEFT_MASK              : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL W_Y_ADJ                  : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL W_LINE_MODE              : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL W_V_BLANKING_START       : STD_LOGIC;
    SIGNAL W_V_BLANKING_END         : STD_LOGIC;

    SIGNAL W_V_SYNC_INTR_START_LINE : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    SIGNAL FF_TOP_BORDER_LINES      : STD_LOGIC_VECTOR(8 DOWNTO 0);

BEGIN
    -----------------------------------------------------------------------------
    --  PORT ASSIGNMENT
    -----------------------------------------------------------------------------
    H_CNT               <= W_H_CNT;
    H_CNT_IN_FIELD      <= W_H_CNT_IN_FIELD;
    V_CNT               <= W_V_CNT_IN_FRAME;
    DOTSTATE            <= FF_DOTSTATE;
    EIGHTDOTSTATE       <= FF_EIGHTDOTSTATE;
    FIELD               <= W_FIELD;
    WINDOW_X            <= FF_WINDOW_X;
    PVIDEODHCLK         <= FF_VIDEO_DH_CLK;
    PVIDEODLCLK         <= FF_VIDEO_DL_CLK;
    PREDOTCOUNTER_X     <= FF_PRE_X_CNT;
    PREDOTCOUNTER_Y     <= FF_PRE_Y_CNT;
    PREDOTCOUNTER_YP    <= FF_MONITOR_LINE;
    HD                  <= W_H_BLANK;
    VD                  <= W_V_BLANK;
    HSYNC               <= '1' WHEN( W_H_CNT(1 DOWNTO 0) = "10" AND FF_PRE_X_CNT = "111111111" )ELSE '0';
    V_BLANKING_START    <= W_V_BLANKING_START;

    -----------------------------------------------------------------------------
    --  SUB COMPONENTS
    -----------------------------------------------------------------------------
    U_HVCOUNTER: VDP_HVCOUNTER
    PORT MAP (
        RESET               => RESET                ,
        CLK21M              => CLK21M               ,

        H_CNT               => W_H_CNT              ,
        H_CNT_IN_FIELD      => W_H_CNT_IN_FIELD     ,
        V_CNT_IN_FIELD      => W_V_CNT_IN_FIELD     ,
        V_CNT_IN_FRAME      => W_V_CNT_IN_FRAME     ,
        FIELD               => W_FIELD              ,
        H_BLANK             => W_H_BLANK            ,
        V_BLANK             => W_V_BLANK            ,

        PAL_MODE            => VDPR9PALMODE         ,
        INTERLACE_MODE      => REG_R9_INTERLACE_MODE,
        Y212_MODE           => REG_R9_Y_DOTS        ,
        OFFSET_Y            => OFFSET_Y             ,
        HDMI_RESET          => HDMI_RESET           
    );

    -----------------------------------------------------------------------------
    --  DOT STATE
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_DOTSTATE     <= "00";
            FF_VIDEO_DH_CLK <= '0';
            FF_VIDEO_DL_CLK <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_H_CNT = CLOCKS_PER_LINE-1 )THEN
                FF_DOTSTATE     <= "00";
                FF_VIDEO_DH_CLK <= '1';
                FF_VIDEO_DL_CLK <= '1';
            ELSE
                CASE FF_DOTSTATE IS
                WHEN "00" =>
                    FF_DOTSTATE     <= "01";
                    FF_VIDEO_DH_CLK <= '0';
                    FF_VIDEO_DL_CLK <= '1';
                WHEN "01" =>
                    FF_DOTSTATE     <= "11";
                    FF_VIDEO_DH_CLK <= '1';
                    FF_VIDEO_DL_CLK <= '0';
                WHEN "11" =>
                    FF_DOTSTATE     <= "10";
                    FF_VIDEO_DH_CLK <= '0';
                    FF_VIDEO_DL_CLK <= '0';
                WHEN "10" =>
                    FF_DOTSTATE     <= "00";
                    FF_VIDEO_DH_CLK <= '1';
                    FF_VIDEO_DL_CLK <= '1';
                WHEN OTHERS =>
                    NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    --  8DOT STATE
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_EIGHTDOTSTATE <= "000";
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_H_CNT(1 DOWNTO 0) = "11" )THEN
                IF( FF_PRE_X_CNT = 0 )THEN
                    FF_EIGHTDOTSTATE <= "000";
                ELSE
                    FF_EIGHTDOTSTATE <= FF_EIGHTDOTSTATE + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    --  GENERATE DOTCOUNTER
    -----------------------------------------------------------------------------

    W_PRE_X_CNT_START0  <=  REG_R18_ADJ(3) & REG_R18_ADJ(3 DOWNTO 0) + "11000";                 --  (-8...7) - 8 = (-16...-1)

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_PRE_X_CNT_START1 <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            FF_PRE_X_CNT_START1 <= (W_PRE_X_CNT_START0(4) & W_PRE_X_CNT_START0) - ("000" & REG_R27_H_SCROLL);   -- (-23...-1)
        END IF;
    END PROCESS;

    W_PRE_X_CNT_START2( 8 DOWNTO 6 ) <= (OTHERS => FF_PRE_X_CNT_START1(5));
    W_PRE_X_CNT_START2( 5 DOWNTO 0 ) <= FF_PRE_X_CNT_START1;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_PRE_X_CNT <= (OTHERS =>'0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_NTSC - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00") + 4) & "10") AND REG_R25_YJK = '1' AND CENTERYJK_R25_N = '1' AND VDPR9PALMODE = '0') OR
                (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_NTSC - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00")    ) & "10") AND (REG_R25_YJK = '0' OR CENTERYJK_R25_N = '0') AND VDPR9PALMODE = '0') OR
                (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_PAL - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00") + 4) & "10") AND REG_R25_YJK = '1' AND CENTERYJK_R25_N = '1' AND VDPR9PALMODE = '1') OR
                (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_PAL - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00")    ) & "10") AND (REG_R25_YJK = '0' OR CENTERYJK_R25_N = '0') AND VDPR9PALMODE = '1') )THEN
                FF_PRE_X_CNT <= W_PRE_X_CNT_START2;
            ELSIF( W_H_CNT(1 DOWNTO 0) = "10" )THEN
                FF_PRE_X_CNT <= FF_PRE_X_CNT + 1;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_X_CNT <= (OTHERS =>'0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_NTSC - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00") + 4) & "10") AND REG_R25_YJK = '1' AND CENTERYJK_R25_N = '1' AND VDPR9PALMODE = '0') OR
                (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_NTSC - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00")    ) & "10") AND (REG_R25_YJK = '0' OR CENTERYJK_R25_N = '0') AND VDPR9PALMODE = '0') OR
                (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_PAL - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00") + 4) & "10") AND REG_R25_YJK = '1' AND CENTERYJK_R25_N = '1' AND VDPR9PALMODE = '1') OR
                (W_H_CNT = ("00" & (OFFSET_X + LED_TV_X_PAL - ((REG_R25_MSK AND (NOT CENTERYJK_R25_N)) & "00")    ) & "10") AND (REG_R25_YJK = '0' OR CENTERYJK_R25_N = '0') AND VDPR9PALMODE = '1') )THEN
                -- HOLD
            ELSIF( W_H_CNT(1 DOWNTO 0) = "10") THEN
                IF( FF_PRE_X_CNT = "111111111" )THEN
                    -- JP: FF_PRE_X_CNT が -1から0にカウントアップする時にFF_X_CNTを-8にする
                    FF_X_CNT <= "111111000";        -- -8
                ELSE
                    FF_X_CNT <= FF_X_CNT + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- GENERATE V-SYNC PULSE
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            IVIDEOVS_N <= '1';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_V_CNT_IN_FIELD = 6 )THEN
                -- SSTATE = SSTATE_B
                IVIDEOVS_N <= '0';
            ELSIF( W_V_CNT_IN_FIELD = 12 )THEN
                -- SSTATE = SSTATE_A
                IVIDEOVS_N <= '1';
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    --  DISPLAY WINDOW
    -----------------------------------------------------------------------------

    -- LEFT MASK (R25 MSK)
    -- H_SCROLL = 0 --> 8
    -- H_SCROLL = 1 --> 7
    -- H_SCROLL = 2 --> 6
    -- H_SCROLL = 3 --> 5
    -- H_SCROLL = 4 --> 4
    -- H_SCROLL = 5 --> 3
    -- H_SCROLL = 6 --> 2
    -- H_SCROLL = 7 --> 1
    W_LEFT_MASK     <=  (OTHERS => '0') WHEN( REG_R25_MSK = '0' )ELSE
                        "00000" & ("0" & (NOT REG_R27_H_SCROLL) + 1);

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            -- MAIN WINDOW
            IF( W_H_CNT( 1 DOWNTO 0) = "01" AND FF_X_CNT = W_LEFT_MASK )THEN
                -- WHEN DOTCOUNTER_X = 0
                FF_RIGHT_MASK <= "100000000" - ("000000" & REG_R27_H_SCROLL);
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_WINDOW_X <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            -- MAIN WINDOW
            IF( W_H_CNT( 1 DOWNTO 0) = "01" AND FF_X_CNT = W_LEFT_MASK ) THEN
                -- WHEN DOTCOUNTER_X = 0
                FF_WINDOW_X <= '1';
            ELSIF( W_H_CNT( 1 DOWNTO 0) = "01" AND FF_X_CNT = FF_RIGHT_MASK ) THEN
                -- WHEN DOTCOUNTER_X = 256
                FF_WINDOW_X <= '0';
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- Y
    -----------------------------------------------------------------------------
    W_HSYNC <=  '1'     WHEN( W_H_CNT(1 DOWNTO 0) = "10" AND FF_PRE_X_CNT = "111111111" )ELSE
                '0';

    W_Y_ADJ <=  (REG_R18_ADJ(7) & REG_R18_ADJ(7) & REG_R18_ADJ(7) &
                 REG_R18_ADJ(7) & REG_R18_ADJ(7) & REG_R18_ADJ(7 DOWNTO 4));

    PROCESS( CLK21M, RESET )
        VARIABLE PREDOTCOUNTER_YP_V     : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        VARIABLE PREDOTCOUNTERYPSTART   : STD_LOGIC_VECTOR(  8 DOWNTO 0 );
    BEGIN
        IF (RESET = '1') THEN
            FF_PRE_Y_CNT        <= (OTHERS =>'0');
            FF_MONITOR_LINE     <= (OTHERS =>'0');
            PREWINDOW_Y         <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN

            IF( W_HSYNC = '1' )THEN
                -- JP: PREWINDOW_Xが 1になるタイミングと同じタイミングでY座標の計算
                IF(  W_V_BLANKING_END = '1' )THEN
                    IF(    REG_R9_Y_DOTS = '0' AND VDPR9PALMODE = '0' )THEN
                        PREDOTCOUNTERYPSTART := "111100110";                    -- TOP BORDER LINES = -26
                    ELSIF( REG_R9_Y_DOTS = '1' AND VDPR9PALMODE = '0' )THEN
                        PREDOTCOUNTERYPSTART := "111110000";                    -- TOP BORDER LINES = -16
                    ELSIF( REG_R9_Y_DOTS = '0' AND VDPR9PALMODE = '1' )THEN
                        PREDOTCOUNTERYPSTART := "111001011";                    -- TOP BORDER LINES = -53
                    ELSIF( REG_R9_Y_DOTS = '1' AND VDPR9PALMODE = '1' )THEN
                        PREDOTCOUNTERYPSTART := "111010101";                    -- TOP BORDER LINES = -43
                    END IF;
                    FF_MONITOR_LINE <= PREDOTCOUNTERYPSTART + W_Y_ADJ;
                    FF_TOP_BORDER_LINES <= "000000000" - PREDOTCOUNTERYPSTART - W_Y_ADJ;
                    PREWINDOW_Y_SP  <= '1';
                ELSE
                    IF( PREDOTCOUNTER_YP_V = 255 )THEN
                        PREDOTCOUNTER_YP_V := FF_MONITOR_LINE;
                    ELSE
                        PREDOTCOUNTER_YP_V := FF_MONITOR_LINE + 1;
                    END IF;
                    IF( PREDOTCOUNTER_YP_V = 0 ) THEN
                        ENAHSYNC        <= '1';
                        PREWINDOW_Y     <= '1';
                    ELSIF( (REG_R9_Y_DOTS = '0' AND PREDOTCOUNTER_YP_V = 192) OR
                           (REG_R9_Y_DOTS = '1' AND PREDOTCOUNTER_YP_V = 212) )THEN
                        PREWINDOW_Y     <= '0';
                        PREWINDOW_Y_SP  <= '0';
                    ELSIF( (REG_R9_Y_DOTS = '0' AND VDPR9PALMODE = '0' AND PREDOTCOUNTER_YP_V = 235) OR
                           (REG_R9_Y_DOTS = '1' AND VDPR9PALMODE = '0' AND PREDOTCOUNTER_YP_V = 245) OR
                           (REG_R9_Y_DOTS = '0' AND VDPR9PALMODE = '1' AND PREDOTCOUNTER_YP_V = 259) OR
                           (REG_R9_Y_DOTS = '1' AND VDPR9PALMODE = '1' AND PREDOTCOUNTER_YP_V = 269) )THEN
                        ENAHSYNC        <= '0';
                    END IF;
                    FF_MONITOR_LINE <= PREDOTCOUNTER_YP_V;
                END IF;
            END IF;

            FF_PRE_Y_CNT <= FF_MONITOR_LINE + ("0" & REG_R23_VSTART_LINE);
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- VSYNC INTERRUPT REQUEST
    -----------------------------------------------------------------------------
    W_LINE_MODE         <=  REG_R9_Y_DOTS & VDPR9PALMODE;

    WITH W_LINE_MODE SELECT W_V_SYNC_INTR_START_LINE <=
        CONV_STD_LOGIC_VECTOR( 192 + CONV_INTEGER(OFFSET_Y) + LED_TV_Y_NTSC, 9 )   WHEN "00",
        CONV_STD_LOGIC_VECTOR( 212 + CONV_INTEGER(OFFSET_Y) + LED_TV_Y_NTSC, 9 )   WHEN "10",
        CONV_STD_LOGIC_VECTOR( 192 + CONV_INTEGER(OFFSET_Y) + LED_TV_Y_PAL, 9 )    WHEN "01",
        CONV_STD_LOGIC_VECTOR( 212 + CONV_INTEGER(OFFSET_Y) + LED_TV_Y_PAL, 9 )    WHEN "11",
        (OTHERS => 'X')                                         WHEN OTHERS;

    W_V_BLANKING_END    <=  '1' WHEN( (W_V_CNT_IN_FIELD = ("00" & (OFFSET_Y + LED_TV_Y_NTSC) & (W_FIELD AND REG_R9_INTERLACE_MODE)) AND VDPR9PALMODE = '0') OR
                                      (W_V_CNT_IN_FIELD = ("00" & (OFFSET_Y + LED_TV_Y_PAL) & (W_FIELD AND REG_R9_INTERLACE_MODE)) AND VDPR9PALMODE = '1') )ELSE
                            '0';
    W_V_BLANKING_START  <=  '1' WHEN( (W_V_CNT_IN_FIELD = ((W_V_SYNC_INTR_START_LINE + FF_TOP_BORDER_LINES) & (W_FIELD AND REG_R9_INTERLACE_MODE)) AND VDPR9PALMODE = '0') OR
                                      (W_V_CNT_IN_FIELD = ((W_V_SYNC_INTR_START_LINE + FF_TOP_BORDER_LINES) & (W_FIELD AND REG_R9_INTERLACE_MODE)) AND VDPR9PALMODE = '1') )ELSE
                            '0';

END RTL;
