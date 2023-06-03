--
--  vdp_linebuf.vhd
--    Line buffer for VGA upscan converter.
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
-- 29th,October,2006 modified by Kunihiko Ohnaka
--   - Insert the license text.
--   - Add the document part below.
--
-- 21st,March,2008 modified by t.hara
--   JP: リファクタリング, 桁揃えなど些細な修正。
--
-------------------------------------------------------------------------------
-- Document
--
-- JP: NTSCタイミングの 15kHzで出力されるビデオ信号をVGAタイミングに
-- JP: 合わせた31kHzの倍レートで出力するためのラインバッファモジュール
-- JP: です。
-- JP: ESE-VDPのメインクロックである21.477MHzで動作させるため、
-- JP: ドットクロックは一般的な 640x480ドットVGAモードの25.175MHz
-- JP: とは異なります。そのため、液晶モニタ等で表示させるとドットの形が
-- JP: いびつな形になる事があります。
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY VDP_LINEBUF IS
     PORT (
        ADDRESS     : IN    STD_LOGIC_VECTOR(  9 DOWNTO 0 );
        INCLOCK     : IN    STD_LOGIC;
        WE          : IN    STD_LOGIC;
        DATA        : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        Q           : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 )
    );
END VDP_LINEBUF;

ARCHITECTURE RTL OF VDP_LINEBUF IS
    TYPE MEM IS ARRAY ( 639 DOWNTO 0 ) OF STD_LOGIC_VECTOR( 4 DOWNTO 0 );
    SIGNAL IMEM     : MEM;
    SIGNAL IADDRESS : STD_LOGIC_VECTOR( 9 DOWNTO 0 );
BEGIN

    PROCESS( INCLOCK )
    BEGIN
        IF( INCLOCK'EVENT AND INCLOCK ='1' )THEN
            IF( WE = '1' )THEN
                IMEM( CONV_INTEGER(ADDRESS) ) <= DATA( 5 DOWNTO 1 );    -- data range required by YJK mode
            END IF;
            IADDRESS <= ADDRESS;
        END IF;
    END PROCESS;

    Q <= IMEM( CONV_INTEGER(IADDRESS) ) & "0";
END RTL;
