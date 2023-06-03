--
--  VDP_NTSC.vhd
--   VDP_NTSC sync signal generator.
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
-- 13rd,October,2003 created by Kunihiko Ohnaka
-- JP: VDPのコアの実装と表示デバイスへの出力を別ソースにした．
--
-- ??th,August,2006 modified by Kunihiko Ohnaka
--   - Move the equalization pulse generator from
--     vdp.vhd.
--
-- 29th,October,2006 modified by Kunihiko Ohnaka
--   - Insert the license text.
--   - Add the document part below.
--
-- 23rd,March,2008 modified by t.hara
-- JP: リファクタリング, NTSC と PAL のタイミング生成回路を統合
--
-------------------------------------------------------------------------------
-- Document
--
-- JP: ESE-VDPコア(vdp.vhd)が生成したビデオ信号を、NTSC/PALの
-- JP: タイミングに合った同期信号および映像信号に変換します。
-- JP: ESE-VDPコアはNTSCモード時は NTSC/PALのタイミングで映像
-- JP: 信号や垂直同期信号を生成するため、本モジュールでは
-- JP: 水平同期信号に等価パルスを挿入する処理だけを行って
-- JP: います。
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_NTSC_PAL IS
    PORT(
        CLK21M              : IN    STD_LOGIC;
        RESET               : IN    STD_LOGIC;
        -- MODE
        PALMODE             : IN    STD_LOGIC;
        INTERLACEMODE       : IN    STD_LOGIC;
        -- VIDEO INPUT
        VIDEORIN            : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOGIN            : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOBIN            : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOVSIN_N         : IN    STD_LOGIC;
        HCOUNTERIN          : IN    STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        VCOUNTERIN          : IN    STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        -- VIDEO OUTPUT
        VIDEOROUT           : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOGOUT           : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOBOUT           : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        VIDEOHSOUT_N        : OUT   STD_LOGIC;
        VIDEOVSOUT_N        : OUT   STD_LOGIC
    );
END VDP_NTSC_PAL;

ARCHITECTURE RTL OF VDP_NTSC_PAL IS
    TYPE TYPSSTATE IS (SSTATE_A, SSTATE_B, SSTATE_C, SSTATE_D);
    SIGNAL FF_SSTATE        : TYPSSTATE;
    SIGNAL FF_HSYNC_N       : STD_LOGIC;

    SIGNAL W_MODE           : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL W_STATE_A1_FULL  : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL W_STATE_A2_FULL  : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL W_STATE_B_FULL   : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
    SIGNAL W_STATE_C_FULL   : STD_LOGIC_VECTOR( 10 DOWNTO 0 );
BEGIN

    -- MODE
    W_MODE  <= PALMODE & INTERLACEMODE;
    WITH( W_MODE )SELECT W_STATE_A1_FULL <=
        "01000001100"   WHEN "00",  -- 524
        "01000001101"   WHEN "01",  -- 525
        "01001110010"   WHEN "10",  -- 626
        "01001110001"   WHEN "11",  -- 625
        (OTHERS => 'X') WHEN OTHERS;

    WITH( W_MODE )SELECT W_STATE_A2_FULL <=
        "01000011000"   WHEN "00",  -- 524+12
        "01000011001"   WHEN "01",  -- 525+12
        "01001111110"   WHEN "10",  -- 626+12
        "01001111101"   WHEN "11",  -- 625+12
        (OTHERS => 'X') WHEN OTHERS;

    WITH( W_MODE )SELECT W_STATE_B_FULL <=
        "01000010010"   WHEN "00",  -- 524+6
        "01000010011"   WHEN "01",  -- 525+6
        "01001111000"   WHEN "10",  -- 626+6
        "01001110111"   WHEN "11",  -- 625+6
        (OTHERS => 'X') WHEN OTHERS;

    WITH( W_MODE )SELECT W_STATE_C_FULL <=
        "01000011110"   WHEN "00",  -- 524+18
        "01000011111"   WHEN "01",  -- 525+18
        "01010000100"   WHEN "10",  -- 626+18
        "01010000011"   WHEN "11",  -- 625+18
        (OTHERS => 'X') WHEN OTHERS;

    -- STATE
    PROCESS( RESET, CLK21M )
    BEGIN
        IF (RESET = '1') THEN
            FF_SSTATE <= SSTATE_A;
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF(     (VCOUNTERIN = 0) OR
                    (VCOUNTERIN = 12) OR
                    (VCOUNTERIN = W_STATE_A1_FULL) OR
                    (VCOUNTERIN = W_STATE_A2_FULL) )THEN
                FF_SSTATE <= SSTATE_A;
            ELSIF(  (VCOUNTERIN = 6) OR
                    (VCOUNTERIN = W_STATE_B_FULL) )THEN
                FF_SSTATE <= SSTATE_B;
            ELSIF(  (VCOUNTERIN = 18) OR
                    (VCOUNTERIN = W_STATE_C_FULL) )THEN
                FF_SSTATE <= SSTATE_C;
            END IF;
        END IF;
    END PROCESS;

    -- GENERATE H SYNC PULSE
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_HSYNC_N <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( FF_SSTATE = SSTATE_A )THEN
                IF( (HCOUNTERIN = 1) OR (HCOUNTERIN = CLOCKS_PER_LINE/2+1) ) THEN
                    FF_HSYNC_N <= '0';                       -- PULSE ON
                ELSIF( (HCOUNTERIN = 51) OR (HCOUNTERIN = CLOCKS_PER_LINE/2+51) ) THEN
                    FF_HSYNC_N <= '1';                       -- PULSE OFF
                END IF;
            ELSIF( FF_SSTATE = SSTATE_B )THEN
                IF( (HCOUNTERIN = CLOCKS_PER_LINE-100+1 ) OR (HCOUNTERIN = CLOCKS_PER_LINE/2-100+1) ) THEN
                    FF_HSYNC_N <= '0';                       -- PULSE ON
                ELSIF( (HCOUNTERIN = 1) OR (HCOUNTERIN = CLOCKS_PER_LINE/2+1) ) THEN
                    FF_HSYNC_N <= '1';                       -- PULSE OFF
                END IF;
            ELSIF( FF_SSTATE = SSTATE_C )THEN
                IF( HCOUNTERIN = 1 )THEN
                    FF_HSYNC_N <= '0';                       -- PULSE ON
                ELSIF( HCOUNTERIN = 101 )THEN
                    FF_HSYNC_N <= '1';                       -- PULSE OFF
                END IF;
            END IF;
        END IF;
    END PROCESS;

    VIDEOHSOUT_N    <= FF_HSYNC_N;
    VIDEOVSOUT_N    <= VIDEOVSIN_N;
    VIDEOROUT       <= VIDEORIN;
    VIDEOGOUT       <= VIDEOGIN;
    VIDEOBOUT       <= VIDEOBIN;
END RTL;
