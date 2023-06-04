--
--  vdp_vga.vhd
--   VGA up-scan converter.
--
--  Copyright (C) 2006 Kunihiko Ohnaka
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
-- Memo
--   Japanese comment lines are starts with "JP:".
--   JP: 日本語のコメント行は JP:を頭に付ける事にする
--
-------------------------------------------------------------------------------
-- Revision History
--
-- 3rd,June,2018 modified by KdL
--  - Added a trick to help set a pixel ratio 1:1
--    on an LED display at 60Hz (not guaranteed on all displays)
--
-- 29th,October,2006 modified by Kunihiko Ohnaka
--  - Inserted the license text
--  - Added the document part below
--
-- ??th,August,2006 modified by Kunihiko Ohnaka
--  - Moved the equalization pulse generator from vdp.vhd
--
-- 20th,August,2006 modified by Kunihiko Ohnaka
--  - Changed field mapping algorithm when interlace mode is enabled
--        even field  -> even line (odd  line is black)
--        odd  field  -> odd line  (even line is black)
--
-- 13rd,October,2003 created by Kunihiko Ohnaka
-- JP: VDPのコアの実装と表示デバイスへの出力を別ソースにした．
--
-------------------------------------------------------------------------------
-- Document
--
-- JP: ESE-VDPコア(vdp.vhd)が生成したビデオ信号を、VGAタイミングに
-- JP: 変換するアップスキャンコンバータです。
-- JP: NTSCは水平同期周波数が15.7kHz、垂直同期周波数が60Hzですが、
-- JP: VGAの水平同期周波数は31.5kHz、垂直同期周波数は60Hzであり、
-- JP: ライン数だけがほぼ倍になったようなタイミングになります。
-- JP: そこで、vdpを ntscモードで動かし、各ラインを倍の速度で
-- JP: 二度描画することでスキャンコンバートを実現しています。
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_VGA IS
    PORT(
        -- VDP CLOCK ... 21.477MHZ
        CLK21M          : IN    STD_LOGIC;
        RESET           : IN    STD_LOGIC;
        -- VIDEO INPUT
        VIDEORIN        : IN    STD_LOGIC_VECTOR( 5 DOWNTO 0);
        VIDEOGIN        : IN    STD_LOGIC_VECTOR( 5 DOWNTO 0);
        VIDEOBIN        : IN    STD_LOGIC_VECTOR( 5 DOWNTO 0);
        VIDEOVSIN_N     : IN    STD_LOGIC;
        HCOUNTERIN      : IN    STD_LOGIC_VECTOR(10 DOWNTO 0);
        VCOUNTERIN      : IN    STD_LOGIC_VECTOR(10 DOWNTO 0);
        -- MODE
        PALMODE         : IN    STD_LOGIC; -- Added by caro
        INTERLACEMODE   : IN    STD_LOGIC;
        LEGACY_VGA      : IN    STD_LOGIC;
        -- VIDEO OUTPUT
        VIDEOROUT       : OUT   STD_LOGIC_VECTOR( 5 DOWNTO 0);
        VIDEOGOUT       : OUT   STD_LOGIC_VECTOR( 5 DOWNTO 0);
        VIDEOBOUT       : OUT   STD_LOGIC_VECTOR( 5 DOWNTO 0);
        VIDEOHSOUT_N    : OUT   STD_LOGIC;
        VIDEOVSOUT_N    : OUT   STD_LOGIC;
        -- HDMI SUPPORT
        BLANK_O         : OUT   STD_LOGIC;
        -- SWITCHED I/O SIGNALS
        RATIOMODE       : IN    STD_LOGIC_VECTOR( 2 DOWNTO 0)
    );
END VDP_VGA;

ARCHITECTURE RTL OF VDP_VGA IS
    COMPONENT VDP_DOUBLEBUF
        PORT (
            CLK         : IN    STD_LOGIC;
            XPOSITIONW  : IN    STD_LOGIC_VECTOR(  9 DOWNTO 0 );
            XPOSITIONR  : IN    STD_LOGIC_VECTOR(  9 DOWNTO 0 );
            EVENODD     : IN    STD_LOGIC;
            WE          : IN    STD_LOGIC;
            DATARIN     : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
            DATAGIN     : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
            DATABIN     : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
            DATAROUT    : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
            DATAGOUT    : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
            DATABOUT    : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 )
        );
    END COMPONENT;

    SIGNAL FF_HSYNC_N   : STD_LOGIC;
    SIGNAL FF_VSYNC_N   : STD_LOGIC;

    -- VIDEO OUTPUT ENABLE
    SIGNAL VIDEOOUTX    : STD_LOGIC;

    -- DOUBLE BUFFER SIGNAL
    SIGNAL XPOSITIONW   : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL XPOSITIONR   : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL EVENODD      : STD_LOGIC;
    SIGNAL WE_BUF       : STD_LOGIC;
    SIGNAL DATAROUT     : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL DATAGOUT     : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL DATABOUT     : STD_LOGIC_VECTOR(  5 DOWNTO 0 );

    -- DISP_START_X + DISP_WIDTH < CLOCKS_PER_LINE/2 = 684
    CONSTANT DISP_WIDTH             : INTEGER := 792; --576;
    SHARED VARIABLE DISP_START_X    : INTEGER := (CLOCKS_PER_LINE/2) - DISP_WIDTH - 32;          -- 106

BEGIN

    VIDEOROUT <= DATAROUT WHEN( VIDEOOUTX = '1' )ELSE (OTHERS => '0');
    VIDEOGOUT <= DATAGOUT WHEN( VIDEOOUTX = '1' )ELSE (OTHERS => '0');
    VIDEOBOUT <= DATABOUT WHEN( VIDEOOUTX = '1' )ELSE (OTHERS => '0');

    DBUF : VDP_DOUBLEBUF
    PORT MAP(
        CLK         => CLK21M,
        XPOSITIONW  => XPOSITIONW,
        XPOSITIONR  => XPOSITIONR,
        EVENODD     => EVENODD,
        WE          => WE_BUF,
        DATARIN     => VIDEORIN,
        DATAGIN     => VIDEOGIN,
        DATABIN     => VIDEOBIN,
        DATAROUT    => DATAROUT,
        DATAGOUT    => DATAGOUT,
        DATABOUT    => DATABOUT
    );

    XPOSITIONW  <=  HCOUNTERIN(10 DOWNTO 1) - (CLOCKS_PER_LINE/2 - DISP_WIDTH - 10);
    EVENODD     <=  VCOUNTERIN(1);
    WE_BUF      <=  '1';

    -- PIXEL RATIO 1:1 FOR LED DISPLAY
    PROCESS( CLK21M )
        CONSTANT DISP_START_Y   : INTEGER := 3;
        CONSTANT PRB_HEIGHT     : INTEGER := 25;
        CONSTANT RIGHT_X        : INTEGER := 858 - DISP_WIDTH - 2;              -- 106
        CONSTANT PAL_RIGHT_X    : INTEGER := 87;                                -- 87
        CONSTANT CENTER_X       : INTEGER := RIGHT_X - 32 - 2;                  -- 72
        CONSTANT BASE_LEFT_X    : INTEGER := CENTER_X - 32 - 2 - 3;             -- 35
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
--             IF( (RATIOMODE = "000" OR INTERLACEMODE = '1' OR PALMODE = '1') AND LEGACY_VGA = '1' )THEN
-- --                -- LEGACY OUTPUT
--                 DISP_START_X := RIGHT_X;                                        -- 106
--             ELSIF( PALMODE = '1' )THEN
-- --                -- 50HZ
--                 DISP_START_X := PAL_RIGHT_X;                                    -- 87
--             ELSIF( RATIOMODE = "000" OR INTERLACEMODE = '1' )THEN
-- --                -- 60HZ
--                 DISP_START_X := CENTER_X;                                       -- 72
--             ELSIF( (VCOUNTERIN < 38 + DISP_START_Y + PRB_HEIGHT) OR
--                    (VCOUNTERIN > 526 - PRB_HEIGHT AND VCOUNTERIN < 526 ) OR
--                    (VCOUNTERIN > 524 + 38 + DISP_START_Y AND VCOUNTERIN < 524 + 38 + DISP_START_Y + PRB_HEIGHT) OR
--                    (VCOUNTERIN > 524 + 526 - PRB_HEIGHT) )THEN
-- --                -- PIXEL RATIO 1:1 (VGA MODE, 60HZ, NOT INTERLACED)
-- --              --IF( EVENODD = '0' )THEN                                         -- PLOT FROM TOP-RIGHT
--                 IF( EVENODD = '1' )THEN                                         -- PLOT FROM TOP-LEFT
--                     DISP_START_X := BASE_LEFT_X + CONV_INTEGER(NOT RATIOMODE);  -- 35 TO 41
--                 ELSE
--                     DISP_START_X := RIGHT_X;                                    -- 106
--                 END IF;
--             ELSE
                DISP_START_X := (CLOCKS_PER_LINE/2) - DISP_WIDTH - 32 - 32 - 2;                                       -- 72
--            END IF;
        END IF;
    END PROCESS;

    -- GENERATE H-SYNC SIGNAL
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_HSYNC_N <= '1';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (HCOUNTERIN = 0) OR (HCOUNTERIN = (CLOCKS_PER_LINE/2)) )THEN
                FF_HSYNC_N <= '0';
            ELSIF( (HCOUNTERIN = 40) OR (HCOUNTERIN = (CLOCKS_PER_LINE/2) + 40) )THEN
                FF_HSYNC_N <= '1';
            END IF;
        END IF;
    END PROCESS;

    -- GENERATE V-SYNC SIGNAL
    -- THE VIDEOVSIN_N SIGNAL IS NOT USED
    PROCESS( RESET, CLK21M )
        CONSTANT CENTER_Y       : INTEGER := 12;                                -- based on HDMI AV output
    BEGIN
        IF( RESET = '1' )THEN
            FF_VSYNC_N <= '1';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( PALMODE = '0' )THEN
                IF( INTERLACEMODE = '0' )THEN
                    IF( (VCOUNTERIN = 3*2 + CENTER_Y) OR (VCOUNTERIN = 524 + 3*2 + CENTER_Y) )THEN
                        FF_VSYNC_N <= '0';
                    ELSIF( (VCOUNTERIN = 6*2 + CENTER_Y) OR (VCOUNTERIN = 524 + 6*2 + CENTER_Y) )THEN
                        FF_VSYNC_N <= '1';
                    END IF;
                ELSE
                    IF( (VCOUNTERIN = 3*2 + CENTER_Y) OR (VCOUNTERIN = 525 + 3*2 + CENTER_Y) )THEN
                        FF_VSYNC_N <= '0';
                    ELSIF( (VCOUNTERIN = 6*2 + CENTER_Y) OR (VCOUNTERIN = 525 + 6*2 + CENTER_Y) )THEN
                        FF_VSYNC_N <= '1';
                    END IF;
                END IF;
            ELSE
                IF( INTERLACEMODE = '0' )THEN
                    IF( (VCOUNTERIN = 3*2 + CENTER_Y + 6) OR (VCOUNTERIN = 626 + 3*2 + CENTER_Y + 6) )THEN
                        FF_VSYNC_N <= '0';
                    ELSIF( (VCOUNTERIN = 6*2 + CENTER_Y + 6) OR (VCOUNTERIN = 626 + 6*2 + CENTER_Y + 6) )THEN
                        FF_VSYNC_N <= '1';
                    END IF;
                ELSE
                    IF( (VCOUNTERIN = 3*2 + CENTER_Y + 6) OR (VCOUNTERIN = 625 + 3*2 + CENTER_Y + 6) )THEN
                        FF_VSYNC_N <= '0';
                    ELSIF( (VCOUNTERIN = 6*2 + CENTER_Y + 6) OR (VCOUNTERIN = 625 + 6*2 + CENTER_Y + 6) )THEN
                        FF_VSYNC_N <= '1';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- GENERATE DATA READ TIMING
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            XPOSITIONR <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (HCOUNTERIN = DISP_START_X) OR
                    (HCOUNTERIN = DISP_START_X + (CLOCKS_PER_LINE/2)) )THEN
                XPOSITIONR <= (OTHERS => '0');
            ELSE
                XPOSITIONR <= XPOSITIONR + 1;
            END IF;
        END IF;
    END PROCESS;

    -- GENERATE VIDEO OUTPUT TIMING
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            VIDEOOUTX <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (HCOUNTERIN = DISP_START_X) OR
                    ((HCOUNTERIN = DISP_START_X + (CLOCKS_PER_LINE/2)) AND INTERLACEMODE = '0') )THEN
                VIDEOOUTX <= '1';
            ELSIF( (HCOUNTERIN = DISP_START_X + DISP_WIDTH - 116) OR
                    (HCOUNTERIN = DISP_START_X + DISP_WIDTH + (CLOCKS_PER_LINE/2) - 116) )THEN
                VIDEOOUTX <= '0';
            END IF;
        END IF;
    END PROCESS;

    VIDEOHSOUT_N <= FF_HSYNC_N;
    VIDEOVSOUT_N <= FF_VSYNC_N;

    -- HDMI SUPPORT
    BLANK_O <= '1' WHEN( VIDEOOUTX = '0' OR FF_VSYNC_N = '0' )ELSE '0';

END RTL;
