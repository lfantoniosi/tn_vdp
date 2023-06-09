--
--  vdp_sprite.vhd
--    Sprite module.
--
--  Copyright (C) 2004-2006 Kunihiko Ohnaka
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
-----------------------------------------------------------------------------
-- Memo
--   Japanese comment lines are starts with "JP:".
--   JP: 日本語のコメント行は JP:を頭に付ける事にする
--
-----------------------------------------------------------------------------
-- Revision History
--
-- 29th,October,2006 modified by Kunihiko Ohnaka
--   - Insert the license text.
--   - Add the document part below.
--
-- 26th,August,2006 modified by Kunihiko Ohnaka
--   - latch the base addresses every eight dot cycle
--     (DRAM RAS/CAS access emulation)
--
-- 20th,August,2006 modified by Kunihiko Ohnaka
--   - Change the drawing algorithm.
--   - Add sprite collision checking function.
--   - Add sprite over-mapped checking function.
--   - Many bugs are fixed, and it works fine.
--   - (first release virsion)
--
-- 17th,August,2004 created by Kunihiko Ohnaka
--   - Start new sprite module implementing.
--     * This module uses Block RAMs so that shrink the
--       circuit size.
--     * Separate sprite module from vdp.vhd.
--
-----------------------------------------------------------------------------
-- Document
--
-- JP: この実装ではBLOCKRAMを使い、消費するSLICEを節約するのが狙い。
-- JP: この実装を使わない状態での vdp.vhdをコンパイルした時の
-- JP: SLICE使用数は1900前後。
-- JP: 2006/8/16。このスプライトを使わない最新版(Cyclone)では、
-- JP:            2726LCだった.
-- JP: 2006/8/19。このスプライトを使ったところ、2278LCまで減少。
-- JP:
-- JP: [用語]
-- JP: ・ローカルプレーン番号
-- JP:   あるライン上に並んでいるスプライト(プレーン)だけを抜き出して
-- JP:   スプライトプレーン番号順に並べた時の順位。
-- JP:   例えばあるラインにスプライトプレーン#1,#4,#5が存在する場合、
-- JP:   それぞれのスプライトのローカルプレーン番号は#0,#1,#2となる。
-- JP:   スプライトモード2でも横一列に最大8枚しか並ばないので、
-- JP:   ローカルプレーン番号は最大で#7となる。
-- JP:
-- JP: ・画面描画帯域
-- JP:    VDPの実機は8ドット(32クロック)で連続アドレス上のデータ4バイト
-- JP:    (GRAPHIC6,7ではRAMのインターリーブアクセスによりバイト)
-- JP:    のリードに加え、ランダムアドレスへの2サイクル(2バイト)の
-- JP:    アクセスが加納
-- JP:    それらのDRAMアクセスサイクルに以下のように名前を付ける。
-- JP:     * 画面描画リードサイクル
-- JP:     * スプライトY座標検査サイクル
-- JP:     * ランダムアクセスサイクル
-- JP:
-- JP: ○似非VDPでのVRAMアクセスサイクル
-- JP:    似非VDPでは旧式のDRAMではなくより高速なメモリを使用している。
-- JP:    そのため、４クロックに1回確実にランダムアクセスを実行できる
-- JP:    メモリを持っている事を前提としてコーディングします。
-- JP:    また、Cyclone版似非MSXでは、16ビット幅のSDRAMを用いている
-- JP:    ため、一回のアクセスで連続する16ビットのデータを読む事も可能
-- JP:    です。
-- JP:    似非VDPでは、D0～D7の下位8ビットをVRAMの前半64Kバイト、
-- JP:    D8～D15の上位8ビットを後半64Kバイトにマッピングしています。
-- JP:    このような変則的な割り当てをするのは、実機のVDPのメモリ
-- JP:    マップをまねるためです。実際、4クロックで2バイトのメモリを
-- JP:    読み出す帯域が必要になるのはGRAPHIC6,7のモードだけです。
-- JP:    実機のVDPは、GRAPHIC6,7ではメモリのインターリーブを用い、
-- JP:    (GRAPHIC7における)偶数ドットをVRAMの前半64Kバイトに
-- JP:    わりあて、奇数ドットを後半64Kバイトに割り当てています。
-- JP:    そのため、似非VDPでも前半64Kと後半64Kの同一アドレス上の
-- JP:    データを１サイクル(4クロック)で読み出せる必要があるので
-- JP:    このようなマッピングになっています。
-- JP:    単純に言えば、SDRAMの16ビットアクセスを、実機のDRAMの
-- JP:    インターリーブアクセスに見立てているということです。
-- JP:
-- JP:    いろいろな現象から、VDPの内部は8ドットサイクルで動いていると
-- JP:    推測されています。8ドット、つまり32クロックのどうさをメモリ
-- JP:    の帯域から推測すると、以下のようになります。
-- JP:
-- JP:   　　ドット　：<=0=><=1=><=2=><=3=><=4=><=5=><=6=><=7=>
-- JP:   通常アクセス： A0   A1   A2   A3   A4  (A5)  A6  (A7)
-- JP: インターリーブ： B0   B1   B2   B3
-- JP:
-- JP:    - 描画中
-- JP:   　　・A0～A3 (B0～B3)
-- JP:        画面描画のために使用。B0～B3はインターリーブで同時に
-- JP:        読み出せるデータで、GRAPHIC6,7でしか使わない。
-- JP:   　　・A4     スプライトY座標検査
-- JP:   　　・A6     VRAM R/W or VDPコマンド (2回に一回ずつ、交互に割り当てる)
-- JP:
-- JP:     - 非描画中(スプライト準備中)
-- JP:    　　・A0     スプライトX座標リード
-- JP:    　　・A1     スプライトパターン番号リード
-- JP:    　　・A2     スプライトパターン左リード
-- JP:    　　・A3     スプライトパターン右リード
-- JP:    　　・A4     スプライトカラーリード
-- JP:    　　・A6     VRAM R/W or VDPコマンド (2回に一回ずつ、交互に割り当てる)
-- JP:
-- JP:   A5とA7のスロットは実際には使用することもできるのですが、
-- JP:   これを使ってしまうと実機よりも帯域が増えてしまうので、
-- JP:   あえて使わずに残しています。
-- JP:   また、非描画中のサイクルは、実機とは異なります。実機では
-- JP:   64クロックで 2つのスプライトをまとめて処理する事で、DRAMの
-- JP:   ページモードサイクルを有効利用できるようにしています。
-- JP:   また、その64クロックの中にはVRAMやVDPコマンドに割くための
-- JP:   スロットが無いので、64クロックサイクルの隙間にVRAMアク
-- JP:   セスのための隙間を空けているのかもしれません。（未確認）
-- JP:   似非VDPでもその動作を完全に真似する事は可能ですが、
-- JP:   ソースが必要以上に複雑に見えてしまうのと、2のn乗サイクル
-- JP:   からずれてしまうのがちょっぴり嫌だったので、上記のような
-- JP:   きれいなサイクルにしています。
-- JP:   どうしても実機と同じタイミングにしたいという方は
-- JP:   チャレンジしてみてください。
-- JP:
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_SPRITE IS
    PORT(
        -- VDP CLOCK ... 21.477MHZ
        CLK21M                      : IN    STD_LOGIC;
        RESET                       : IN    STD_LOGIC;

        DOTSTATE                    : IN    STD_LOGIC_VECTOR(  1 DOWNTO 0 );
        EIGHTDOTSTATE               : IN    STD_LOGIC_VECTOR(  2 DOWNTO 0 );

        DOTCOUNTERX                 : IN    STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        DOTCOUNTERYP                : IN    STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        BWINDOW_Y                   : IN    STD_LOGIC;

        -- VDP STATUS REGISTERS OF SPRITE
        PVDPS0SPCOLLISIONINCIDENCE  : OUT   STD_LOGIC;
        PVDPS0SPOVERMAPPED          : OUT   STD_LOGIC;
        PVDPS0SPOVERMAPPEDNUM       : OUT   STD_LOGIC_VECTOR(  4 DOWNTO 0 );
        PVDPS3S4SPCOLLISIONX        : OUT   STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        PVDPS5S6SPCOLLISIONY        : OUT   STD_LOGIC_VECTOR(  8 DOWNTO 0 );
        PVDPS0RESETREQ              : IN    STD_LOGIC;
        PVDPS0RESETACK              : OUT   STD_LOGIC;
        PVDPS5RESETREQ              : IN    STD_LOGIC;
        PVDPS5RESETACK              : OUT   STD_LOGIC;
        -- VDP REGISTERS
        REG_R1_SP_SIZE              : IN    STD_LOGIC;
        REG_R1_SP_ZOOM              : IN    STD_LOGIC;
        REG_R11R5_SP_ATR_ADDR       : IN    STD_LOGIC_VECTOR(  9 DOWNTO 0 );
        REG_R6_SP_GEN_ADDR          : IN    STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        REG_R8_COL0_ON              : IN    STD_LOGIC;
        REG_R8_SP_OFF               : IN    STD_LOGIC;
        REG_R23_VSTART_LINE         : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R27_H_SCROLL            : IN    STD_LOGIC_VECTOR(  2 DOWNTO 0 );
        SPMODE2                     : IN    STD_LOGIC;
        VRAMINTERLEAVEMODE          : IN    STD_LOGIC;

        SPVRAMACCESSING             : OUT   STD_LOGIC;

        PRAMDAT                     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        PRAMADR                     : OUT   STD_LOGIC_VECTOR( 16 DOWNTO 0 );

        -- JP: スプライトを描画した時に'1'になる。カラーコード0で
        -- JP: 描画する事もできるので、このビットが必要
        SPCOLOROUT                  : OUT   STD_LOGIC;
        -- OUTPUT COLOR
        SPCOLORCODE                 : OUT   STD_LOGIC_VECTOR(  3 DOWNTO 0 );
        REG_R9_Y_DOTS               : IN    STD_LOGIC;
        SPMAXSPR                    : IN    STD_LOGIC
    );
END VDP_SPRITE;

ARCHITECTURE RTL OF VDP_SPRITE IS
    COMPONENT VDP_SPINFORAM
        PORT(
            ADDRESS     : IN    STD_LOGIC_VECTOR(  4 DOWNTO 0 );
            INCLOCK     : IN    STD_LOGIC;
            WE          : IN    STD_LOGIC;
            DATA        : IN    STD_LOGIC_VECTOR( 31 DOWNTO 0 );
            Q           : OUT   STD_LOGIC_VECTOR( 31 DOWNTO 0 )
        );
    END COMPONENT;

    COMPONENT RAM10
        PORT(
            ADR     : IN    STD_LOGIC_VECTOR(    7 DOWNTO 0 );
            CLK     : IN    STD_LOGIC;
            WE      : IN    STD_LOGIC;
            DBO     : IN    STD_LOGIC_VECTOR(    9 DOWNTO 0 );
            DBI     : OUT   STD_LOGIC_VECTOR(    9 DOWNTO 0 )
        );
    END COMPONENT;

    SIGNAL FF_SP_EN                 : STD_LOGIC;
    SIGNAL FF_CUR_Y                 : STD_LOGIC_VECTOR(  8 DOWNTO 0 );

    SIGNAL FF_VDPS0RESETACK         : STD_LOGIC;
    SIGNAL FF_VDPS5RESETACK         : STD_LOGIC;

    -- FOR SPINFORAM
    SIGNAL SPINFORAMADDR            : STD_LOGIC_VECTOR(  4 DOWNTO 0);
    SIGNAL SPINFORAMWE              : STD_LOGIC;
    SIGNAL SPINFORAMDATA_IN         : STD_LOGIC_VECTOR( 31 DOWNTO 0);
    SIGNAL SPINFORAMDATA_OUT        : STD_LOGIC_VECTOR( 31 DOWNTO 0);

    SIGNAL SPINFORAMX_IN            : STD_LOGIC_VECTOR(  8 DOWNTO 0);
    SIGNAL SPINFORAMPATTERN_IN      : STD_LOGIC_VECTOR( 15 DOWNTO 0);
    SIGNAL SPINFORAMCOLOR_IN        : STD_LOGIC_VECTOR(  3 DOWNTO 0);
    SIGNAL SPINFORAMCC_IN           : STD_LOGIC;
    SIGNAL SPINFORAMIC_IN           : STD_LOGIC;
    SIGNAL SPINFORAMX_OUT           : STD_LOGIC_VECTOR( 8 DOWNTO 0);
    SIGNAL SPINFORAMPATTERN_OUT     : STD_LOGIC_VECTOR( 15 DOWNTO 0);
    SIGNAL SPINFORAMCOLOR_OUT       : STD_LOGIC_VECTOR(  3 DOWNTO 0);
    SIGNAL SPINFORAMCC_OUT          : STD_LOGIC;
    SIGNAL SPINFORAMIC_OUT          : STD_LOGIC;

    TYPE TYPESPSTATE IS ( SPSTATE_IDLE, SPSTATE_YTEST_DRAW, SPSTATE_PREPARE );
    SIGNAL SPSTATE                  : TYPESPSTATE;

    -- JP: スプライトプレーン番号×横方向表示枚数の配列
    TYPE SPRENDERPLANESTYPE IS ARRAY( 0 TO 31 ) OF STD_LOGIC_VECTOR( 4 DOWNTO 0 );
    SIGNAL SPRENDERPLANES           : SPRENDERPLANESTYPE;

    SIGNAL IRAMADR                  : STD_LOGIC_VECTOR( 16 DOWNTO 0 );
    SIGNAL FF_Y_TEST_VRAM_ADDR      : STD_LOGIC_VECTOR( 16 DOWNTO 0 );
    SIGNAL IRAMADRPREPARE           : STD_LOGIC_VECTOR( 16 DOWNTO 0 );

    SIGNAL SPATTRTBLBASEADDR        : STD_LOGIC_VECTOR( REG_R11R5_SP_ATR_ADDR'LENGTH -1 DOWNTO 0);
    SIGNAL SPPTNGENETBLBASEADDR     : STD_LOGIC_VECTOR( REG_R6_SP_GEN_ADDR'LENGTH -1 DOWNTO 0);
    SIGNAL SPATTRIB_ADDR            : STD_LOGIC_VECTOR( 16 DOWNTO 2 );
    SIGNAL READVRAMADDRCREAD        : STD_LOGIC_VECTOR( 16 DOWNTO 0 );
    SIGNAL READVRAMADDRPTREAD       : STD_LOGIC_VECTOR( 16 DOWNTO 0 );

    -- JP: Y座標検査中のプレーン番号
    SIGNAL FF_Y_TEST_SP_NUM         : STD_LOGIC_VECTOR(  4 DOWNTO 0 );
    SIGNAL FF_Y_TEST_LISTUP_ADDR    : STD_LOGIC_VECTOR(  4 DOWNTO 0 );   -- 0 - 8
    SIGNAL FF_Y_TEST_EN             : STD_LOGIC;
    -- JP: 下書きデータ準備中のローカルプレーン番号
    SIGNAL SPPREPARELOCALPLANENUM   : STD_LOGIC_VECTOR(  4 DOWNTO 0 );
    -- JP: 下書きデータ準備中のプレーン番号
    SIGNAL SPPREPAREPLANENUM        : STD_LOGIC_VECTOR(  4 DOWNTO 0 );
    -- JP: 下書きデータ準備中のスプライトのYライン番号(スプライトのどの部分を描画するか)
    SIGNAL SPPREPARELINENUM         : STD_LOGIC_VECTOR(  3 DOWNTO 0 );
    -- JP: 下書きデータ準備中のスプライトのX位置。0の時左8ドット。1の時右8ドット。(16X16モードのみで使用)
    SIGNAL SPPREPAREXPOS            : STD_LOGIC;
    SIGNAL SPPREPAREPATTERNNUM      : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    -- JP: 下書データの準備が終了した
    SIGNAL SPPREPAREEND             : STD_LOGIC;
    SIGNAL SPCCD                    : STD_LOGIC;

    -- JP: 下書きをしているスプライトのローカルプレーン番号
    SIGNAL SPPREDRAWLOCALPLANENUM   : STD_LOGIC_VECTOR(  4 DOWNTO 0 );   -- 0 - 7
    SIGNAL SPPREDRAWEND             : STD_LOGIC;

    -- JP: ラインバッファへの描画用
    SIGNAL SPDRAWX                  : STD_LOGIC_VECTOR(  8 DOWNTO 0 );  -- -32 - 287 (=256+31)
    SIGNAL SPDRAWPATTERN            : STD_LOGIC_VECTOR( 15 DOWNTO 0 );
    SIGNAL SPDRAWCOLOR              : STD_LOGIC_VECTOR(  3 DOWNTO 0 );

    -- JP: スプライト描画ラインバッファの制御信号
    SIGNAL SPLINEBUFADDR_E          : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL SPLINEBUFADDR_O          : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL SPLINEBUFWE_E            : STD_LOGIC;
    SIGNAL SPLINEBUFWE_O            : STD_LOGIC;
    SIGNAL SPLINEBUFDATA_IN_E       : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL SPLINEBUFDATA_IN_O       : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL SPLINEBUFDATA_OUT_E      : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL SPLINEBUFDATA_OUT_O      : STD_LOGIC_VECTOR(  9 DOWNTO 0 );

    SIGNAL SPLINEBUFDISPWE          : STD_LOGIC;
    SIGNAL SPLINEBUFDRAWWE          : STD_LOGIC;
    SIGNAL SPLINEBUFDISPX           : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL SPLINEBUFDRAWX           : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL SPLINEBUFDRAWCOLOR       : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL SPLINEBUFDISPDATA_OUT    : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL SPLINEBUFDRAWDATA_OUT    : STD_LOGIC_VECTOR(  9 DOWNTO 0 );

    SIGNAL SPWINDOWX                : STD_LOGIC;

    SIGNAL FF_SP_OVERMAP            : STD_LOGIC;
    SIGNAL FF_SP_OVERMAP_NUM        : STD_LOGIC_VECTOR(  4 DOWNTO 0 );

    SIGNAL W_SPLISTUPY              : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL W_TARGET_SP_EN           : STD_LOGIC;
    SIGNAL W_SP_OFF                 : STD_LOGIC;
    SIGNAL W_SP_OVERMAP             : STD_LOGIC;
    SIGNAL W_ACTIVE                 : STD_LOGIC;
    SIGNAL SPWINDOW_Y               : STD_LOGIC;

BEGIN

    PVDPS0RESETACK          <= FF_VDPS0RESETACK;
    PVDPS5RESETACK          <= FF_VDPS5RESETACK;
    PVDPS0SPOVERMAPPED      <= FF_SP_OVERMAP;
    PVDPS0SPOVERMAPPEDNUM   <= FF_SP_OVERMAP_NUM;

    -----------------------------------------------------------------------------
    -- スプライトを表示するか否かを示す信号
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_SP_EN <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "01" AND DOTCOUNTERX = 0 )THEN
                FF_SP_EN <= (NOT REG_R8_SP_OFF) AND W_ACTIVE;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- SPRITE INFORMATION ARRAY
    -- 実際に表示するスプライトの情報を集めて記録しておくRAM
    -----------------------------------------------------------------------------
    ISPINFORAM: VDP_SPINFORAM
    PORT MAP(
        ADDRESS     => SPINFORAMADDR,
        INCLOCK     => CLK21M,
        WE          => SPINFORAMWE,
        DATA        => SPINFORAMDATA_IN,
        Q           => SPINFORAMDATA_OUT
    );

    SPINFORAMDATA_IN    <=  '0' &
                            SPINFORAMX_IN & SPINFORAMPATTERN_IN &
                            SPINFORAMCOLOR_IN & SPINFORAMCC_IN & SPINFORAMIC_IN;
    SPINFORAMX_OUT      <=  SPINFORAMDATA_OUT( 30 DOWNTO 22 );
    SPINFORAMPATTERN_OUT<=  SPINFORAMDATA_OUT( 21 DOWNTO  6 );
    SPINFORAMCOLOR_OUT  <=  SPINFORAMDATA_OUT(  5 DOWNTO  2 );
    SPINFORAMCC_OUT     <=  SPINFORAMDATA_OUT( 1 );
    SPINFORAMIC_OUT     <=  SPINFORAMDATA_OUT( 0 );

    SPINFORAMADDR <=    SPPREPARELOCALPLANENUM  WHEN( SPSTATE = SPSTATE_PREPARE )ELSE
                        SPPREDRAWLOCALPLANENUM;

    -----------------------------------------------------------------------------
    -- SPRITE LINE BUFFER
    -----------------------------------------------------------------------------
    SPLINEBUFADDR_E         <= SPLINEBUFDISPX       WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDRAWX;
    SPLINEBUFDATA_IN_E      <= "0000000000"           WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDRAWCOLOR;
    SPLINEBUFWE_E           <= SPLINEBUFDISPWE      WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDRAWWE;
    SPLINEBUFDISPDATA_OUT   <= SPLINEBUFDATA_OUT_E  WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDATA_OUT_O;

    U_EVEN_LINE_BUF: RAM10
    PORT MAP(
        ADR     => SPLINEBUFADDR_E      ,
        CLK     => CLK21M               ,
        WE      => SPLINEBUFWE_E        ,
        DBO     => SPLINEBUFDATA_IN_E   ,
        DBI     => SPLINEBUFDATA_OUT_E
    );

    SPLINEBUFADDR_O         <= SPLINEBUFDRAWX       WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDISPX;
    SPLINEBUFDATA_IN_O      <= SPLINEBUFDRAWCOLOR   WHEN( DOTCOUNTERYP(0) = '0' )ELSE "0000000000";
    SPLINEBUFWE_O           <= SPLINEBUFDRAWWE      WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDISPWE;
    SPLINEBUFDRAWDATA_OUT   <= SPLINEBUFDATA_OUT_O  WHEN( DOTCOUNTERYP(0) = '0' )ELSE SPLINEBUFDATA_OUT_E;

    U_ODD_LINE_BUF: RAM10
    PORT MAP(
        ADR     => SPLINEBUFADDR_O      ,
        CLK     => CLK21M               ,
        WE      => SPLINEBUFWE_O        ,
        DBO     => SPLINEBUFDATA_IN_O   ,
        DBI     => SPLINEBUFDATA_OUT_O
    );

    -----------------------------------------------------------------------------
    SPPREPAREXPOS       <=  '1' WHEN( EIGHTDOTSTATE = "100" )ELSE
                            '0';

    -- JP: VRAMアクセスアドレスの出力
    IRAMADR <=  FF_Y_TEST_VRAM_ADDR     WHEN( SPSTATE = SPSTATE_YTEST_DRAW )ELSE
                IRAMADRPREPARE;
    PRAMADR <=  IRAMADR(16 DOWNTO 0)    WHEN( VRAMINTERLEAVEMODE = '0' )ELSE
                IRAMADR(0) & IRAMADR(16 DOWNTO 1);

    -----------------------------------------------------------------------------
    -- STATE MACHINE
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            SPSTATE <= SPSTATE_IDLE;
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "10" )THEN
                CASE SPSTATE IS
                WHEN SPSTATE_IDLE =>
                    IF( DOTCOUNTERX = 0 )THEN
                        SPSTATE <= SPSTATE_YTEST_DRAW;
                    END IF;
                WHEN SPSTATE_YTEST_DRAW =>
                    IF( DOTCOUNTERX = 256+8 )THEN
                        SPSTATE <= SPSTATE_PREPARE;
                    END IF;
                WHEN SPSTATE_PREPARE =>
                    IF( SPPREPAREEND = '1' )THEN
                        SPSTATE <= SPSTATE_IDLE;
                    END IF;
                WHEN OTHERS =>
                    SPSTATE <= SPSTATE_IDLE;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- 現ラインのライン番号
    -----------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( (DOTSTATE = "01") AND (DOTCOUNTERX = 0) )THEN
                --   +1 SHOULD BE NEEDED. BECAUSE IT WILL BE DRAWN IN THE NEXT LINE.
                FF_CUR_Y <= DOTCOUNTERYP + ('0' & REG_R23_VSTART_LINE) + 1;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- VRAM ADDRESS GENERATOR
    -----------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            -- LATCHING ADDRESS SIGNALS
            IF( (DOTSTATE = "01") AND (DOTCOUNTERX = 0) )THEN
                SPPTNGENETBLBASEADDR <= REG_R6_SP_GEN_ADDR;
                IF( SPMODE2 = '0' )THEN
                    SPATTRTBLBASEADDR <= REG_R11R5_SP_ATR_ADDR( 9 DOWNTO 0 );
                ELSE
                    SPATTRTBLBASEADDR <= REG_R11R5_SP_ATR_ADDR( 9 DOWNTO 2 ) & "00";
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- VRAM ACCESS MASK
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            SPVRAMACCESSING <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "10" )THEN
                CASE SPSTATE IS
                WHEN SPSTATE_IDLE =>
                    IF( DOTCOUNTERX = 0 )THEN
                        SPVRAMACCESSING <= (NOT REG_R8_SP_OFF) AND W_ACTIVE;
                    END IF;
                WHEN SPSTATE_YTEST_DRAW =>
                    IF( DOTCOUNTERX = 256+8 )THEN
                        SPVRAMACCESSING <= FF_SP_EN;
                    END IF;
                WHEN SPSTATE_PREPARE =>
                    IF( SPPREPAREEND = '1' )THEN
                        SPVRAMACCESSING <= '0';
                    END IF;
                WHEN OTHERS =>
                    NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- [Y_TEST]Yテスト用の信号
    -----------------------------------------------------------------------------
    W_SPLISTUPY     <= FF_CUR_Y(7 DOWNTO 0) - PRAMDAT;

    -- [Y_TEST]着目スプライトを現ラインに表示するかどうかの信号
    W_TARGET_SP_EN  <=  '1'     WHEN(   ((W_SPLISTUPY(7 DOWNTO 3) = "00000") AND (REG_R1_SP_SIZE = '0' ) AND (REG_R1_SP_ZOOM='0')) OR
                                        ((W_SPLISTUPY(7 DOWNTO 4) = "0000" ) AND (REG_R1_SP_SIZE = '1' ) AND (REG_R1_SP_ZOOM='0')) OR
                                        ((W_SPLISTUPY(7 DOWNTO 4) = "0000" ) AND (REG_R1_SP_SIZE = '0' ) AND (REG_R1_SP_ZOOM='1')) OR
                                        ((W_SPLISTUPY(7 DOWNTO 5) = "000"  ) AND (REG_R1_SP_SIZE = '1' ) AND (REG_R1_SP_ZOOM='1')) )ELSE
                        '0';

    -- [Y_TEST]これ以降のスプライトは表示禁止かどうかの信号
    W_SP_OFF        <=  '1' WHEN( PRAMDAT = ("1101" & SPMODE2 & "000") )ELSE
                        '0';

    -- [Y_TEST]４つ（８つ）のスプライトが並んでいるかどうかの信号
    W_SP_OVERMAP    <=  '1' WHEN(FF_Y_TEST_LISTUP_ADDR(4) = '1' OR (SPMAXSPR = '0' AND ((FF_Y_TEST_LISTUP_ADDR(2) = '1' AND SPMODE2 = '0') OR FF_Y_TEST_LISTUP_ADDR(3) = '1' ))) ELSE
                        '0';
    -- [Y_TEST]表示中のラインか否か
    W_ACTIVE        <=  BWINDOW_Y;

    -----------------------------------------------------------------------------
    -- [SPWINDOW_Y]
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            SPWINDOW_Y <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF (DOTCOUNTERYP = 0) THEN
                SPWINDOW_Y <= '1';
            ELSIF( (REG_R9_Y_DOTS = '0' AND DOTCOUNTERYP = 192) OR
                (REG_R9_Y_DOTS = '1' AND DOTCOUNTERYP = 212) )THEN
                SPWINDOW_Y <= '0';
            END IF;
        END IF;
    END PROCESS;


    -----------------------------------------------------------------------------
    -- [Y_TEST]Yテストステートでないことを示す信号
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_Y_TEST_EN <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "01" )THEN
                IF( DOTCOUNTERX = 0 ) THEN
                    FF_Y_TEST_EN <= FF_SP_EN;
                ELSIF( EIGHTDOTSTATE = "110" )THEN
                    IF( W_SP_OFF = '1' OR (W_SP_OVERMAP AND W_TARGET_SP_EN) = '1' OR FF_Y_TEST_SP_NUM = "11111" )THEN
                        FF_Y_TEST_EN <= '0';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- [Y_TEST]テスト対象のスプライト番号 (0～31)
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_Y_TEST_SP_NUM <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "01" )THEN
                IF( DOTCOUNTERX = 0 )THEN
                    FF_Y_TEST_SP_NUM <= (OTHERS => '0');
                ELSIF( EIGHTDOTSTATE = "110" )THEN
                    IF( FF_Y_TEST_EN = '1' AND FF_Y_TEST_SP_NUM /= "11111" )THEN
                        FF_Y_TEST_SP_NUM <= FF_Y_TEST_SP_NUM + 1;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- [Y_TEST]表示するスプライトをリストアップするためのリストアップメモリアドレス 0～8
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_Y_TEST_LISTUP_ADDR <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "01" )THEN
                IF( DOTCOUNTERX = 0 )THEN
                    -- INITIALIZE
                    FF_Y_TEST_LISTUP_ADDR <= (OTHERS => '0');
                ELSIF( EIGHTDOTSTATE = "110" )THEN
                    -- NEXT SPRITE [リストアップメモリが満杯になるまでインクリメント]
                    IF( FF_Y_TEST_EN = '1' AND W_TARGET_SP_EN = '1' AND W_SP_OVERMAP = '0' AND W_SP_OFF = '0' )THEN
                        FF_Y_TEST_LISTUP_ADDR <= FF_Y_TEST_LISTUP_ADDR + 1;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- [Y_TEST]表示するスプライトをリストアップするためのリストアップメモリへの書き込み
    -----------------------------------------------------------------------------
    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "01" )THEN
                IF( DOTCOUNTERX = 0 )THEN
                    -- INITIALIZE
                ELSIF( EIGHTDOTSTATE = "110" )THEN
                    -- NEXT SPRITE
                    IF( FF_Y_TEST_EN = '1' AND W_TARGET_SP_EN = '1' AND W_SP_OVERMAP = '0' AND W_SP_OFF = '0' )THEN
                        SPRENDERPLANES( CONV_INTEGER(FF_Y_TEST_LISTUP_ADDR) ) <= FF_Y_TEST_SP_NUM;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- [Y_TEST]４つ目（８つ目）のスプライトが並んだかどうかの信号
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_SP_OVERMAP       <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( PVDPS0RESETREQ = NOT FF_VDPS0RESETACK )THEN
                -- S#0が読み込まれるまでクリアしない
                FF_SP_OVERMAP       <= '0';
            ELSIF( DOTSTATE = "01" )THEN
                IF( DOTCOUNTERX = 0 )THEN
                    -- INITIALIZE
                ELSIF( EIGHTDOTSTATE = "110" )THEN
                    IF( SPWINDOW_Y = '1' AND FF_Y_TEST_EN = '1' AND W_TARGET_SP_EN = '1' AND W_SP_OVERMAP = '1' AND W_SP_OFF = '0' )THEN
                        FF_SP_OVERMAP <= '1';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- [Y_TEST]処理をあきらめたスプライト信号
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_SP_OVERMAP_NUM   <= (OTHERS => '1');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( PVDPS0RESETREQ = NOT FF_VDPS0RESETACK )THEN
                FF_SP_OVERMAP_NUM   <= (OTHERS => '1');
            ELSIF( DOTSTATE = "01" )THEN
                IF( DOTCOUNTERX = 0 )THEN
                    -- INITIALIZE
                ELSIF( EIGHTDOTSTATE = "110" )THEN
                    -- JP: 調査をあきらめたスプライト番号が格納される。OVERMAPとは限らない。
                    -- JP: しかし、すでに OVERMAP で値が確定している場合は更新しない。
                    IF( SPWINDOW_Y = '1' AND FF_Y_TEST_EN = '1' AND W_TARGET_SP_EN = '1' AND W_SP_OVERMAP = '1' AND W_SP_OFF = '0' AND FF_SP_OVERMAP = '0' )THEN
                        FF_SP_OVERMAP_NUM <= FF_Y_TEST_SP_NUM;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- Yテスト用の VRAM読み出しアドレス
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_Y_TEST_VRAM_ADDR <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "11" )THEN
                FF_Y_TEST_VRAM_ADDR <= SPATTRTBLBASEADDR & FF_Y_TEST_SP_NUM & "00";
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- PREPARE SPRITE
    --
    -- JP: 画面描画中           : 8ドット描画する間に1プレーン、スプライトのY座標を検査し、
    -- JP:                        表示すべきスプライトをリストアップする。
    -- JP: 画面非描画中         : リストアップしたスプライトの情報を集め、inforamに格納
    -- JP: 次の画面描画中       : inforamに格納された情報を元に、ラインバッファに描画
    -- JP: 次の次の画面描画中   : ラインバッファに描画された絵を出力し、画面描画に混ぜる
    -----------------------------------------------------------------------------

    -- READ TIMING OF SPRITE ATTRIBUTE TABLE
    SPATTRIB_ADDR       <=  SPATTRTBLBASEADDR & SPPREPAREPLANENUM;
    READVRAMADDRPTREAD  <=
        SPPTNGENETBLBASEADDR & SPPREPAREPATTERNNUM( 7 DOWNTO 0 ) & SPPREPARELINENUM( 2 DOWNTO 0 )       WHEN( REG_R1_SP_SIZE = '0' )ELSE    -- 8X8 MODE
        SPPTNGENETBLBASEADDR & SPPREPAREPATTERNNUM( 7 DOWNTO 2 ) & SPPREPAREXPOS & SPPREPARELINENUM( 3 DOWNTO 0 );                          -- 16X16 MODE
    READVRAMADDRCREAD   <=  SPATTRIB_ADDR & "11" WHEN( SPMODE2 = '0' )ELSE
                            SPATTRTBLBASEADDR(9 DOWNTO 3) & (NOT SPATTRTBLBASEADDR(2)) & SPPREPAREPLANENUM & SPPREPARELINENUM;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            IRAMADRPREPARE <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            -- PREPAREING
            IF( DOTSTATE = "11" )THEN
                CASE EIGHTDOTSTATE IS
                WHEN "000" =>                               -- Y READ
                    IRAMADRPREPARE <= SPATTRIB_ADDR & "00";
                WHEN "001" =>                               -- X READ
                    IRAMADRPREPARE <= SPATTRIB_ADDR & "01";
                WHEN "010" =>                               -- PATTERN NUM READ
                    IRAMADRPREPARE <= SPATTRIB_ADDR & "10";
                WHEN "011" | "100" =>                       -- PATTERN READ
                    IRAMADRPREPARE <= READVRAMADDRPTREAD;
                WHEN "101" =>                               -- COLOR READ
                    IRAMADRPREPARE <= READVRAMADDRCREAD;
                WHEN OTHERS =>
                    NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            CASE DOTSTATE IS
                WHEN "11" =>
                    SPINFORAMWE <= '0';
                WHEN "01" =>
                    IF( SPSTATE = SPSTATE_PREPARE )THEN
                        IF( EIGHTDOTSTATE = "110" )THEN
                            SPINFORAMWE <= '1';
                        END IF;
                    ELSE
                        SPINFORAMWE <= '0';
                    END IF;
                WHEN OTHERS =>
                    NULL;
            END CASE;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            SPPREPARELOCALPLANENUM  <= (OTHERS => '0');
            SPPREPAREEND            <= '0';

        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            -- PREPAREING
            CASE DOTSTATE IS
                WHEN "01" =>
                    IF( SPSTATE = SPSTATE_PREPARE ) THEN
                        CASE EIGHTDOTSTATE IS
                            WHEN "001" =>                               -- Y READ
                                -- JP: スプライトの何行目が該当したか覚えておく
                                IF( REG_R1_SP_ZOOM = '0' ) THEN
                                    SPPREPARELINENUM    <= W_SPLISTUPY(3 DOWNTO 0);
                                ELSE
                                    SPPREPARELINENUM    <= W_SPLISTUPY(4 DOWNTO 1);
                                END IF;
                            WHEN "010" =>                               -- X READ
                                SPINFORAMX_IN <= '0' & PRAMDAT;
                            WHEN "011" =>                               -- PATTERN NUM READ
                                SPPREPAREPATTERNNUM <= PRAMDAT;
                            WHEN "100" =>                               -- PATTERN READ LEFT
                                SPINFORAMPATTERN_IN(15 DOWNTO 8) <= PRAMDAT;
                            WHEN "101" =>                               -- PATTERN READ RIGHT
                                IF( REG_R1_SP_SIZE = '0' ) THEN
                                    -- 8X8 MODE
                                    SPINFORAMPATTERN_IN( 7 DOWNTO 0) <= (OTHERS => '0');
                                ELSE
                                    -- 16X16 MODE
                                    SPINFORAMPATTERN_IN( 7 DOWNTO 0) <= PRAMDAT;
                                END IF;
                            WHEN "110" =>                               -- COLOR READ
                                -- COLOR
                                SPINFORAMCOLOR_IN <= PRAMDAT(3 DOWNTO 0);
                                -- CC   優先順位ビット (1: 優先順位無し, 0: 優先順位あり)
                                IF(SPMODE2 = '1') THEN
                                    SPINFORAMCC_IN <= PRAMDAT(6);
                                ELSE
                                    SPINFORAMCC_IN <= '0';
                                END IF;
                                -- IC   衝突検知ビット (1: 検知しない, 0: 検知する)
                                SPINFORAMIC_IN <= PRAMDAT(5) AND SPMODE2;
                                -- EC   32ドット左シフト (1: する, 0: しない)
                                IF( PRAMDAT(7) = '1' ) THEN
                                    SPINFORAMX_IN <= SPINFORAMX_IN - 32;
                                END IF;

                                -- IF ALL OF THE SPRITES LIST-UPED ARE READED,
                                -- THE SPRITES LEFT SHOULD NOT BE DRAWN.
                                IF( SPPREPARELOCALPLANENUM >= FF_Y_TEST_LISTUP_ADDR )THEN
                                    SPINFORAMPATTERN_IN <= (OTHERS => '0');
                                END IF;

                            WHEN "111" =>
                                SPPREPARELOCALPLANENUM <= SPPREPARELOCALPLANENUM + 1;
                                IF( SPPREPARELOCALPLANENUM = 15 OR (SPMAXSPR = '0' AND ((SPPREPARELOCALPLANENUM = 7) OR (SPPREPARELOCALPLANENUM = 3 AND SPMODE2='0'))) ) THEN
                                    SPPREPAREEND <= '1';
                                END IF;
                            WHEN OTHERS =>
                                NULL;
                        END CASE;
                    ELSE
                        SPPREPARELOCALPLANENUM <= (OTHERS => '0');
                        SPPREPAREEND <= '0';
                    END IF;
                WHEN OTHERS =>
                    NULL;
            END CASE;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( DOTSTATE = "01" )THEN
                IF( SPSTATE = SPSTATE_PREPARE )THEN
                    IF( EIGHTDOTSTATE = "111" )THEN
                        SPPREPAREPLANENUM <= SPRENDERPLANES( CONV_INTEGER( SPPREPARELOCALPLANENUM + 1 ) );
                    END IF;
                ELSE
                    SPPREPAREPLANENUM <= SPRENDERPLANES(0);
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- DRAWING TO LINE BUFFER.
    --
    -- DOTCOUNTERX( 4 DOWNTO 0 )
    --   0... 31    DRAW LOCAL PLANE#0 TO LINE BUFFER
    --  32... 63    DRAW LOCAL PLANE#1 TO LINE BUFFER
    --     :                         :
    -- 224...255    DRAW LOCAL PLANE#7 TO LINE BUFFER
    -----------------------------------------------------------------------------
    PROCESS( CLK21M, RESET )
        VARIABLE SPCC0FOUNDV                        : STD_LOGIC;
        VARIABLE LASTCC0LOCALPLANENUMV              : STD_LOGIC_VECTOR(4 DOWNTO 0);
        VARIABLE SPDRAWXV                           : STD_LOGIC_VECTOR(8 DOWNTO 0);  -- -32 - 287 (=256+31)
        VARIABLE VDPS0SPCOLLISIONINCIDENCEV         : STD_LOGIC;
        VARIABLE VDPS3S4SPCOLLISIONXV               : STD_LOGIC_VECTOR(8 DOWNTO 0);
        VARIABLE VDPS5S6SPCOLLISIONYV               : STD_LOGIC_VECTOR(8 DOWNTO 0);
    BEGIN
        IF( RESET ='1' ) THEN
            SPLINEBUFDRAWWE             <= '0';                 -- JP: ラインバッファへの書き込みイネーブラ
            SPPREDRAWEND                <= '0';
            SPDRAWPATTERN               <= (OTHERS => '0');
            SPLINEBUFDRAWCOLOR          <= (OTHERS => '0');
            SPLINEBUFDRAWX              <= (OTHERS => '0');
            SPDRAWCOLOR                 <= (OTHERS => '0');

            VDPS0SPCOLLISIONINCIDENCEV  := '0';                 -- JP: スプライトが衝突したかどうかを示すフラグ
            VDPS3S4SPCOLLISIONXV        := (OTHERS => '0');
            VDPS5S6SPCOLLISIONYV        := (OTHERS => '0');
            SPCC0FOUNDV                 := '0';
            LASTCC0LOCALPLANENUMV       := (OTHERS => '0');

        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( SPSTATE = SPSTATE_YTEST_DRAW ) THEN
                CASE DOTSTATE IS
                    WHEN "10" =>
                        -- JP: 処理単位の始まり
                        SPLINEBUFDRAWWE <= '0';
                    WHEN "00" =>
                        -- JP:
                        IF( DOTCOUNTERX(3 DOWNTO 0) = 1 ) THEN
                            SPDRAWPATTERN   <= SPINFORAMPATTERN_OUT;
                            SPDRAWXV        := SPINFORAMX_OUT;
                        ELSE
                            IF( (REG_R1_SP_ZOOM = '0') OR (DOTCOUNTERX(0) = '1') ) THEN
                                SPDRAWPATTERN <= SPDRAWPATTERN(14 DOWNTO 0) & "0";
                            END IF;
                            SPDRAWXV := SPDRAWX + 1;
                        END IF;
                        SPDRAWX <= SPDRAWXV;
                        SPLINEBUFDRAWX <= SPDRAWXV(7 DOWNTO 0);
                    WHEN "01" =>
                        SPDRAWCOLOR <= SPINFORAMCOLOR_OUT;
                    WHEN "11" =>
                        IF( SPINFORAMCC_OUT = '0' ) THEN
                            LASTCC0LOCALPLANENUMV := SPPREDRAWLOCALPLANENUM;
                            SPCC0FOUNDV := '1';
                        END IF;
                        IF( (SPDRAWPATTERN(15) = '1') AND (SPDRAWX(8) = '0') AND (SPPREDRAWEND = '0') AND
                                ((REG_R8_COL0_ON = '1') OR (SPDRAWCOLOR /= 0)) ) THEN
                            -- JP: スプライトのドットを描画
                            -- JP: ラインバッファの7ビット目は、何らかの色を描画した時に'1'になる。
                            -- JP: ラインバッファの6-4ビット目はそこに描画されているドットのローカルプレーン番号
                            -- JP: (色合成されているときは親となるCC='0'のスプライトのローカルプレーン番号)が入る。
                            -- JP: つまり、LASTCC0LOCALPLANENUMVがこの番号と等しいときはOR合成してよい事になる。
                            IF( (SPLINEBUFDRAWDATA_OUT(9) = '0') AND (SPCC0FOUNDV = '1') ) THEN
                                -- JP: 何も描かれていない(ビット7が'0')とき、このドットに初めての
                                -- JP: スプライトが描画される。ただし、CC='0'のスプライトが同一ライン上にまだ
                                -- JP: 現れていない時は描画しない
                                SPLINEBUFDRAWCOLOR <= ("1" & LASTCC0LOCALPLANENUMV & SPDRAWCOLOR);
                                SPLINEBUFDRAWWE <= '1';
                            ELSIF( (SPLINEBUFDRAWDATA_OUT(9) = '1') AND (SPINFORAMCC_OUT = '1') AND
                                         (SPLINEBUFDRAWDATA_OUT(8 DOWNTO 4) = LASTCC0LOCALPLANENUMV) ) THEN
                                -- JP: 既に絵が描かれているが、CCが'1'でかつこのドットに描かれているスプライトの
                                -- JP: LOCALPLANENUMが LASTCC0LOCALPLANENUMVと等しい時は、ラインバッファから
                                -- JP: 下地データを読み、書きたい色と論理和を取リ、書き戻す。
                                SPLINEBUFDRAWCOLOR <= SPLINEBUFDRAWDATA_OUT OR ("000000" & SPDRAWCOLOR);
                                SPLINEBUFDRAWWE <= '1';
                            ELSIF( (SPLINEBUFDRAWDATA_OUT(9) = '1') AND (SPINFORAMIC_OUT = '0') ) THEN
                                SPLINEBUFDRAWCOLOR <= SPLINEBUFDRAWDATA_OUT;
                                -- JP: スプライトが衝突。
                                -- SPRITE COLISION OCCURED
                                VDPS0SPCOLLISIONINCIDENCEV := '1';
                                VDPS3S4SPCOLLISIONXV := SPDRAWX(8 DOWNTO 0) + 12;
                                -- NOTE: DRAWING LINE IS PREVIOUS LINE.
                                VDPS5S6SPCOLLISIONYV := FF_CUR_Y + 7;
                            END IF;
                        END IF;
                        --
                        IF( DOTCOUNTERX = 0 ) THEN
                            SPPREDRAWLOCALPLANENUM <= (OTHERS => '0');
                            SPPREDRAWEND <= '0';
                            LASTCC0LOCALPLANENUMV := (OTHERS => '0');
                            SPCC0FOUNDV := '0';
                        ELSIF( DOTCOUNTERX(3 DOWNTO 0) = 0 ) THEN
                            SPPREDRAWLOCALPLANENUM <= SPPREDRAWLOCALPLANENUM + 1;
                            IF( SPPREDRAWLOCALPLANENUM = 15 OR (SPMAXSPR = '0' AND ((SPPREDRAWLOCALPLANENUM = 7) OR (SPPREDRAWLOCALPLANENUM = 3 AND SPMODE2 = '0' ))) ) THEN
                                SPPREDRAWEND <= '1';
                            END IF;
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;
            END IF;

            -- STATUS REGISTER
            IF( PVDPS0RESETREQ /= FF_VDPS0RESETACK ) THEN
                FF_VDPS0RESETACK <= PVDPS0RESETREQ;
                VDPS0SPCOLLISIONINCIDENCEV := '0';
            END IF;
            IF( PVDPS5RESETREQ /= FF_VDPS5RESETACK ) THEN
                FF_VDPS5RESETACK <= PVDPS5RESETREQ;
                VDPS3S4SPCOLLISIONXV := (OTHERS => '0');
                VDPS5S6SPCOLLISIONYV := (OTHERS => '0');
            END IF;

            PVDPS0SPCOLLISIONINCIDENCE <= VDPS0SPCOLLISIONINCIDENCEV;
            PVDPS3S4SPCOLLISIONX    <= VDPS3S4SPCOLLISIONXV;
            PVDPS5S6SPCOLLISIONY    <= VDPS5S6SPCOLLISIONYV;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------
    -- JP: 画面へのレンダリング。VDPエンティティがDOTSTATE="11"の時に値を取得できるように、
    -- JP: "01"のタイミングで出力する。
    -----------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            SPLINEBUFDISPX  <= (OTHERS => '0');
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( DOTSTATE = "10" )THEN
                -- JP: DOTCOUNTERと実際の表示(カラーコードの出力)は8ドットずれている
                IF( DOTCOUNTERX = 8 )THEN
                    SPLINEBUFDISPX <= ("00000" & REG_R27_H_SCROLL);
                ELSE
                    SPLINEBUFDISPX <= SPLINEBUFDISPX + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' ) THEN
            SPWINDOWX <= '0';
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( DOTSTATE = "10" )THEN
                -- JP: DOTCOUNTERと実際の表示(カラーコードの出力)は8ドットずれている
                IF( DOTCOUNTERX = 8 )THEN
                    SPWINDOWX <= '1';
                ELSIF( SPLINEBUFDISPX = X"FF" ) THEN
                    SPWINDOWX <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' ) THEN
            SPLINEBUFDISPWE <= '0';
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( DOTSTATE = "10" )THEN
                SPLINEBUFDISPWE <= '0';
            ELSIF( DOTSTATE = "11" AND SPWINDOWX = '1' )THEN
                -- CLEAR DISPLAYED DOT
                SPLINEBUFDISPWE <= '1';
            END IF;
        END IF;
    END PROCESS;

    -- JP: ウィンドウで表示をカットする
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' ) THEN
            SPCOLOROUT  <= '0';                     -- JP:  0=透明, 1=スプライトドット
            SPCOLORCODE <= (OTHERS => '0');         -- JP:  SPCOLOROUT=1 の時のスプライトドット色番号
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( DOTSTATE = "01" )THEN
                IF( SPWINDOWX = '1' ) THEN
                    SPCOLOROUT  <= SPLINEBUFDISPDATA_OUT( 9 );
                    SPCOLORCODE <= SPLINEBUFDISPDATA_OUT( 3 DOWNTO 0 );
                ELSE
                    SPCOLOROUT  <= '0';
                    SPCOLORCODE <= (OTHERS => '0');
                END IF;
            END IF;
        END IF;
    END PROCESS;

END RTL;

