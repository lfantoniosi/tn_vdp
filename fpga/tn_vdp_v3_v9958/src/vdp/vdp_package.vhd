--
--  vdp_package.vhd
--   Package file of ESE-VDP.
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
-- Memo
--   Japanese comment lines are starts with "JP:".
--   JP: 日本語のコメント行は JP:を頭に付ける事にする
--
-------------------------------------------------------------------------------
-- Revision History
--
-- 29th,October,2006 modified by Kunihiko Ohnaka
--   - Insert the license text.
--   - Add the document part below.
--
-------------------------------------------------------------------------------
-- Document
--
-- JP: ESE-VDPのパッケージファイルです。
-- JP: ESE-VDPに含まれるモジュールのコンポーネント宣言や、定数宣言、
-- JP: 型変換用の関数などが定義されています。
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

PACKAGE VDP_PACKAGE IS

    -- VDP ID
--  CONSTANT VDP_ID : STD_LOGIC_VECTOR(  4 DOWNTO 0 ) := "00000";  -- V9938
--  CONSTANT VDP_ID : STD_LOGIC_VECTOR(  4 DOWNTO 0 ) := "00010";  -- V9958
--  SHARED VARIABLE VDP_ID : STD_LOGIC_VECTOR(  4 DOWNTO 0 );      -- managed by Switched I/O ports

    -- display start position ( when adjust=(0,0) )
    -- [from V9938 Technical Data Book]
    -- Horizontal Display Parameters
    --  [non TEXT]
    --   * Total Display      1368 clks  - a
    --   * Right Border         59 clks  - b
    --   * Right Blanking       27 clks  - c
    --   * H-Sync Pulse Width  100 clks  - d
    --   * Left Blanking       102 clks  - e
    --   * Left Border          56 clks  - f
    -- OFFSET_X is the position when preDotCounter_x is -8. So,
    --    => (d+e+f-8*4-8*4)/4 => (100+102+56)/4 - 16 => 48 + 1 = 49
    --
    -- Vertical Display Parameters (NTSC)
    --                            [192 Lines]  [212 Lines]
    --                            [Even][Odd]  [Even][Odd]
    --   * V-Sync Pulse Width          3    3       3    3 lines - g
    --   * Top Blanking               13 13.5      13 13.5 lines - h
    --   * Top Border                 26   26      16   16 lines - i
    --   * Display Time              192  192     212  212 lines - j
    --   * Bottom Border            25.5   25    15.5   15 lines - k
    --   * Bottom Blanking             3    3       3    3 lines - l
    -- OFFSET_Y is the start line of Top Border (192 Lines Mode)
    --    => l+g+h => 3 + 3 + 13 = 19
    --

    -- NUMBER OF CLOCKS PER LINE, MUST BE A MULTIPLE OF 4
    SHARED VARIABLE CLOCKS_PER_LINE                    : INTEGER RANGE 0 TO 2047 := 1716;
    SHARED VARIABLE CLOCKS_PER_HALF_LINE               : INTEGER RANGE 0 TO 2047 := 858;
--    SHARED VARIABLE CLOCKS_PER_LINE                    : INTEGER RANGE 0 TO 2047 := 1372;
--    SHARED VARIABLE CLOCKS_PER_HALF_LINE               : INTEGER RANGE 0 TO 2047 := 686;

    -- LEFT-TOP POSITION OF VISIBLE AREA
    CONSTANT OFFSET_X                           : STD_LOGIC_VECTOR(  6 DOWNTO 0 ) := "0110101"; -- 49
--  CONSTANT OFFSET_Y                           : STD_LOGIC_VECTOR(  6 DOWNTO 0 ) := "0010011"; -- 19
--  SHARED VARIABLE OFFSET_Y                    : STD_LOGIC_VECTOR(  6 DOWNTO 0 );              -- managed by Switched I/O ports

    CONSTANT LED_TV_X_NTSC                      : INTEGER := -20;
    CONSTANT LED_TV_Y_NTSC                      : INTEGER := 0; -- -1;
    CONSTANT LED_TV_X_PAL                       : INTEGER := -20;
    CONSTANT LED_TV_Y_PAL                       : INTEGER := 0; -- 3;

--  CONSTANT DISPLAY_OFFSET_NTSC                : INTEGER := 0;
--  CONSTANT DISPLAY_OFFSET_PAL                 : INTEGER := 27;

--  CONSTANT SCAN_LINE_OFFSET_192               : INTEGER := 24;
--  CONSTANT SCAN_LINE_OFFSET_212               : INTEGER := 14;

--  CONSTANT LAST_LINE_NTSC                     : INTEGER := 262;                               -- 262 & 262.5 => 3 + 13 + 26 + 192 + 25 + 3
--  CONSTANT LAST_LINE_PAL                      : INTEGER := 313;                               -- 312.5 & 313 => 3 + 13 + 53 + 192 + 49 + 3

--  CONSTANT FIRST_LINE_192_NTSC                : INTEGER := DISPLAY_OFFSET_NTSC + SCAN_LINE_OFFSET_192;
--  CONSTANT FIRST_LINE_212_NTSC                : INTEGER := DISPLAY_OFFSET_NTSC + SCAN_LINE_OFFSET_212;
--  CONSTANT FIRST_LINE_192_PAL                 : INTEGER := DISPLAY_OFFSET_PAL + SCAN_LINE_OFFSET_192;
--  CONSTANT FIRST_LINE_212_PAL                 : INTEGER := DISPLAY_OFFSET_PAL + SCAN_LINE_OFFSET_212;

--  CONSTANT INTERNAL_X_INIT                    : INTEGER := 102;
--  CONSTANT PRE_DOTCOUNTER_X_START             : INTEGER := -30;
--  CONSTANT PRE_DOTCOUNTER_Y_START             : INTEGER := -2;
--  CONSTANT PRE_DOTCOUNTER_Y_START_192_NTSC    : INTEGER := PRE_DOTCOUNTER_Y_START - DISPLAY_OFFSET_NTSC - SCAN_LINE_OFFSET_192;
--  CONSTANT PRE_DOTCOUNTER_Y_START_212_NTSC    : INTEGER := PRE_DOTCOUNTER_Y_START - DISPLAY_OFFSET_NTSC - SCAN_LINE_OFFSET_212;
--  CONSTANT PRE_DOTCOUNTER_Y_START_192_PAL     : INTEGER := PRE_DOTCOUNTER_Y_START - DISPLAY_OFFSET_PAL - SCAN_LINE_OFFSET_192;
--  CONSTANT PRE_DOTCOUNTER_Y_START_212_PAL     : INTEGER := PRE_DOTCOUNTER_Y_START - DISPLAY_OFFSET_PAL - SCAN_LINE_OFFSET_212;

    CONSTANT LEFT_BORDER                        : INTEGER := 295; --235;
--    CONSTANT LEFT_BORDER                        : INTEGER := 235; 
--  CONSTANT DISPLAY_AREA                       : INTEGER := 1024;

--  CONSTANT VISIBLE_AREA_SX                    : INTEGER := LEFT_BORDER;
--  CONSTANT VISIBLE_AREA_EX                    : INTEGER := CLOCKS_PER_LINE;

--  CONSTANT H_BLANKING_START                   : INTEGER := CLOCKS_PER_LINE - 59 - 27 + 1;

--    CONSTANT V_BLANKING_START_192_NTSC          : INTEGER := 240;
--    CONSTANT V_BLANKING_START_212_NTSC          : INTEGER := 250;
--    CONSTANT V_BLANKING_START_192_PAL           : INTEGER := 263;
--    CONSTANT V_BLANKING_START_212_PAL           : INTEGER := 273;

END VDP_PACKAGE;
