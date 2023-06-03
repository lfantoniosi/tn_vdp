--
--  vdp_interrupt.vhd
--   Interrupt controller of ESE-VDP.
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

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE IEEE.STD_LOGIC_ARITH.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_INTERRUPT IS
    PORT(
        RESET                   : IN    STD_LOGIC;
        CLK21M                  : IN    STD_LOGIC;

        H_CNT                   : IN    STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        Y_CNT                   : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        ACTIVE_LINE             : IN    STD_LOGIC;
        V_BLANKING_START        : IN    STD_LOGIC;
        CLR_VSYNC_INT           : IN    STD_LOGIC;
        CLR_HSYNC_INT           : IN    STD_LOGIC;
        REQ_VSYNC_INT_N         : OUT   STD_LOGIC;
        REQ_HSYNC_INT_N         : OUT   STD_LOGIC;
        REG_R19_HSYNC_INT_LINE  : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 )
    );
END VDP_INTERRUPT;

ARCHITECTURE RTL OF VDP_INTERRUPT IS

    SIGNAL FF_VSYNC_INT_N           : STD_LOGIC;
    SIGNAL FF_HSYNC_INT_N           : STD_LOGIC;
    SIGNAL W_VSYNC_INTR_TIMING      : STD_LOGIC;
BEGIN

    REQ_VSYNC_INT_N <= FF_VSYNC_INT_N;
    REQ_HSYNC_INT_N <= FF_HSYNC_INT_N;

    -----------------------------------------------------------------------------
    -- VSYNC INTERRUPT REQUEST
    -----------------------------------------------------------------------------
    W_VSYNC_INTR_TIMING <=  '1' WHEN( H_CNT = LEFT_BORDER )ELSE
                            '0';

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_VSYNC_INT_N <= '1';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( CLR_VSYNC_INT = '1' )THEN
                -- V-BLANKING INTERRUPT CLEAR
                FF_VSYNC_INT_N <= '1';
            ELSIF( W_VSYNC_INTR_TIMING = '1' AND V_BLANKING_START = '1' )THEN
                -- V-BLANKING INTERRUPT REQUEST
                FF_VSYNC_INT_N <= '0';
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    --  W_HSYNC INTERRUPT REQUEST
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF (RESET = '1') THEN
            FF_HSYNC_INT_N <= '1';
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( CLR_HSYNC_INT = '1' OR (W_VSYNC_INTR_TIMING = '1' AND V_BLANKING_START = '1') )THEN
                -- H-BLANKING INTERRUPT CLEAR
                FF_HSYNC_INT_N <= '1';
            ELSIF( ACTIVE_LINE = '1' AND Y_CNT = REG_R19_HSYNC_INT_LINE )THEN
                -- H-BLANKING INTERRUPT REQUEST
                FF_HSYNC_INT_N <= '0';
            END IF;
        END IF;
    END PROCESS;

END RTL;
