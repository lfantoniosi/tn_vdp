--
--  vdp_doublebuf.vhd
--    Double Buffered Line Memory.
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
-- Document
--
-- JP: ダブルバッファリング機能付きラインバッファモジュール。
-- JP: vga.vhdによるアップスキャンコンバートに使用します。
--
-- JP: xPositionWに X座標を入れ，weを 1にすると書き込みバッファに
-- JP: 書き込まれる．また，xPositionRに X座標を入れると，読み込み
-- JP: バッファから読み出した色コードが qから出力される。
-- JP: evenOdd信号によって，読み込みバッファと書き込みバッファが
-- JP: 切り替わる。
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY VDP_DOUBLEBUF IS
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
END VDP_DOUBLEBUF;

ARCHITECTURE RTL OF VDP_DOUBLEBUF IS
    COMPONENT VDP_LINEBUF
         PORT (
            ADDRESS     : IN    STD_LOGIC_VECTOR(  9 DOWNTO 0 );
            INCLOCK     : IN    STD_LOGIC;
            WE          : IN    STD_LOGIC;
            DATA        : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
            Q           : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 )
        );
    END COMPONENT;

    SIGNAL WE_E     : STD_LOGIC;
    SIGNAL WE_O     : STD_LOGIC;
    SIGNAL ADDR_E   : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL ADDR_O   : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL OUTR_E   : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL OUTG_E   : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL OUTB_E   : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL OUTR_O   : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL OUTG_O   : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL OUTB_O   : STD_LOGIC_VECTOR(5 DOWNTO 0);
BEGIN
    -- EVEN LINE
    U_BUF_RE: VDP_LINEBUF
    PORT MAP(
        ADDRESS     => ADDR_E,
        INCLOCK     => CLK,
        WE          => WE_E,
        DATA        => DATARIN,
        Q           => OUTR_E
    );

    U_BUF_GE: VDP_LINEBUF
    PORT MAP(
        ADDRESS     => ADDR_E,
        INCLOCK     => CLK,
        WE          => WE_E,
        DATA        => DATAGIN,
        Q           => OUTG_E
    );

    U_BUF_BE: VDP_LINEBUF
    PORT MAP(
        ADDRESS     => ADDR_E,
        INCLOCK     => CLK,
        WE          => WE_E,
        DATA        => DATABIN,
        Q           => OUTB_E
    );
    -- ODD LINE
    U_BUF_RO: VDP_LINEBUF
    PORT MAP(
        ADDRESS     => ADDR_O,
        INCLOCK     => CLK,
        WE          => WE_O,
        DATA        => DATARIN,
        Q           => OUTR_O
    );

    U_BUF_GO: VDP_LINEBUF
    PORT MAP(
        ADDRESS     => ADDR_O,
        INCLOCK     => CLK,
        WE          => WE_O,
        DATA        => DATAGIN,
        Q           => OUTG_O
    );

    U_BUF_BO: VDP_LINEBUF
    PORT MAP(
        ADDRESS     => ADDR_O,
        INCLOCK     => CLK,
        WE          => WE_O,
        DATA        => DATABIN,
        Q           => OUTB_O
    );

    WE_E        <= WE WHEN( EVENODD = '0' )ELSE '0';
    WE_O        <= WE WHEN( EVENODD = '1' )ELSE '0';

    ADDR_E      <= XPOSITIONW WHEN( EVENODD = '0' )ELSE XPOSITIONR;
    ADDR_O      <= XPOSITIONW WHEN( EVENODD = '1' )ELSE XPOSITIONR;

    DATAROUT    <= OUTR_E WHEN( EVENODD = '1' )ELSE OUTR_O;
    DATAGOUT    <= OUTG_E WHEN( EVENODD = '1' )ELSE OUTG_O;
    DATABOUT    <= OUTB_E WHEN( EVENODD = '1' )ELSE OUTB_O;
END RTL;
