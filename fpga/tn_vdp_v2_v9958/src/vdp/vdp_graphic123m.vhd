--
--  vdp_graphic123M.vhd
--    Imprementation of Graphic Mode 1,2,3 and Multicolor Mode.
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
-- 12nd,August,2006 created by Kunihiko Ohnaka
-- JP: VDPのコアの実装とスクリーンモードの実装を分離した
--
-- 29th,October,2006 modified by Kunihiko Ohnaka
--   - Insert the license text.
--   - Add the document part below.
--
-- 16th, March, 2008 Refactoring by t.hara
-- JP: リファクタリング, VDP_PACKAGE の参照を削除
--
-------------------------------------------------------------------------------
-- Document
--
-- JP: GRAPHICモード1,2,3および MULTICOLORモードのメイン処理回路です。
--

LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY VDP_GRAPHIC123M IS
	PORT(
		CLK21M						: IN	STD_LOGIC;		--	21.477MHZ
		RESET						: IN	STD_LOGIC;

		-- CONTROL SIGNALS
		DOTSTATE					: IN	STD_LOGIC_VECTOR(  1 DOWNTO 0 );
		EIGHTDOTSTATE				: IN	STD_LOGIC_VECTOR(  2 DOWNTO 0 );
		DOTCOUNTERX					: IN	STD_LOGIC_VECTOR(  8 DOWNTO 0 );
		DOTCOUNTERY					: IN	STD_LOGIC_VECTOR(  8 DOWNTO 0 );

		VDPMODEMULTI				: IN	STD_LOGIC;
		VDPMODEMULTIQ				: IN	STD_LOGIC;
		VDPMODEGRAPHIC1				: IN	STD_LOGIC;
		VDPMODEGRAPHIC2				: IN	STD_LOGIC;
		VDPMODEGRAPHIC3				: IN	STD_LOGIC;

		-- REGISTERS
		REG_R2_PT_NAM_ADDR			: IN	STD_LOGIC_VECTOR(  6 DOWNTO 0 );
		REG_R4_PT_GEN_ADDR			: IN	STD_LOGIC_VECTOR(  5 DOWNTO 0 );
		REG_R10R3_COL_ADDR			: IN	STD_LOGIC_VECTOR( 10 DOWNTO 0 );
		REG_R26_H_SCROLL			: IN	STD_LOGIC_VECTOR(  8 DOWNTO 3 );
		REG_R27_H_SCROLL			: IN	STD_LOGIC_VECTOR(  2 DOWNTO 0 );
		--
		PRAMDAT						: IN	STD_LOGIC_VECTOR(  7 DOWNTO 0 );
		PRAMADR						: OUT	STD_LOGIC_VECTOR( 16 DOWNTO 0 );

		PCOLORCODE					: OUT	STD_LOGIC_VECTOR(  3 DOWNTO 0 )
	);
END VDP_GRAPHIC123M;

ARCHITECTURE RTL OF VDP_GRAPHIC123M IS
	SIGNAL FF_REQ_ADDR				: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL FF_COL_CODE				: STD_LOGIC_VECTOR(	 3 DOWNTO 0 );
	SIGNAL FF_PAT_NUM				: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL FF_PRE_PAT_GEN			: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL FF_PRE_PAT_COL			: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL FF_PAT_GEN				: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL FF_PAT_COL				: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );

	SIGNAL REQ_PAT_NAME_TBL_ADDR	: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL REQ_PAT_GEN_TBL_ADDR		: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL REQ_PAT_COL_TBL_ADDR		: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL REQ_ADDR					: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL COL_HL_SEL				: STD_LOGIC;
	SIGNAL COL_CODE					: STD_LOGIC_VECTOR(	 3 DOWNTO 0 );
	SIGNAL EIGHTDOTSTATE_DEC		: STD_LOGIC_VECTOR(	 3 DOWNTO 0 );
	SIGNAL W_DOTCOUNTERX			: STD_LOGIC_VECTOR(	 7 DOWNTO 3 );
BEGIN

	W_DOTCOUNTERX <= REG_R26_H_SCROLL( 7 DOWNTO 3 ) + DOTCOUNTERX(7 DOWNTO 3);

	-- ADDRESS DECODE
	REQ_PAT_NAME_TBL_ADDR<= (REG_R2_PT_NAM_ADDR & DOTCOUNTERY(7 DOWNTO 3) & W_DOTCOUNTERX );

	REQ_PAT_GEN_TBL_ADDR <= (REG_R4_PT_GEN_ADDR & FF_PAT_NUM & DOTCOUNTERY(2 DOWNTO 0)) WHEN( VDPMODEGRAPHIC1 = '1' )ELSE
							(REG_R4_PT_GEN_ADDR(5 DOWNTO 2) & DOTCOUNTERY(7 DOWNTO 6) & FF_PAT_NUM & DOTCOUNTERY(2 DOWNTO 0) ) AND
							("1111" & REG_R4_PT_GEN_ADDR(1 DOWNTO 0) & "11111111" & "111");

	REQ_PAT_COL_TBL_ADDR <= (REG_R4_PT_GEN_ADDR & FF_PAT_NUM & DOTCOUNTERY(4 DOWNTO 2)) WHEN( VDPMODEMULTI = '1' OR VDPMODEMULTIQ = '1' )ELSE
							(REG_R10R3_COL_ADDR & '0' & FF_PAT_NUM( 7 DOWNTO 3 ))			WHEN( VDPMODEGRAPHIC1 = '1' )ELSE
							(REG_R10R3_COL_ADDR(10 DOWNTO 7) & DOTCOUNTERY(7 DOWNTO 6) & FF_PAT_NUM & DOTCOUNTERY(2 DOWNTO 0)) AND
							("1111" & REG_R10R3_COL_ADDR(6 DOWNTO 0) & "111111" );

	-- DRAM READ REQUEST
	WITH( EIGHTDOTSTATE ) SELECT EIGHTDOTSTATE_DEC <=
		"0001"	WHEN "000",
		"0010"	WHEN "001",
		"0100"	WHEN "010",
		"1000"	WHEN "011",
		"0000"	WHEN OTHERS;

	WITH( EIGHTDOTSTATE ) SELECT REQ_ADDR <=
		REQ_PAT_NAME_TBL_ADDR	WHEN "000",
		REQ_PAT_GEN_TBL_ADDR	WHEN "001",
		REQ_PAT_COL_TBL_ADDR	WHEN "010",
		FF_REQ_ADDR				WHEN OTHERS;

	-- GENERATE PIXEL COLOR NUMBER
	COL_HL_SEL	<=	NOT EIGHTDOTSTATE(2)		WHEN( VDPMODEMULTI = '1' OR VDPMODEMULTIQ = '1' )ELSE
					FF_PAT_GEN(7);
	COL_CODE	<=	FF_PAT_COL( 7 DOWNTO 4 )	WHEN( COL_HL_SEL = '1' )ELSE
					FF_PAT_COL( 3 DOWNTO 0 );

	-- OUT ASSIGNMENT
	PRAMADR		<= FF_REQ_ADDR;
	PCOLORCODE	<= FF_COL_CODE;

	-- FF
	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_PAT_COL <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "00" AND EIGHTDOTSTATE_DEC(0) = '1' )THEN
				FF_PAT_COL <= FF_PRE_PAT_COL;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_PAT_GEN <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "00" AND EIGHTDOTSTATE_DEC(0) = '1' )THEN
				FF_PAT_GEN <= FF_PRE_PAT_GEN;
			ELSIF( DOTSTATE = "01" )THEN
				FF_PAT_GEN <= FF_PAT_GEN( 6 DOWNTO 0 ) & '0';
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_PAT_NUM <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "01" AND EIGHTDOTSTATE_DEC(1) = '1' )THEN
				FF_PAT_NUM <= PRAMDAT;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_PRE_PAT_GEN <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "01" AND EIGHTDOTSTATE_DEC(2) = '1' )THEN
				FF_PRE_PAT_GEN <= PRAMDAT;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_PRE_PAT_COL <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "01" AND EIGHTDOTSTATE_DEC(3) = '1' )THEN
				FF_PRE_PAT_COL <= PRAMDAT;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_COL_CODE <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "01" )THEN
				FF_COL_CODE <= COL_CODE;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_REQ_ADDR <= ( OTHERS => '0' );
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "11" )THEN
				FF_REQ_ADDR <= REQ_ADDR;
			END IF;
		END IF;
	END PROCESS;

END RTL;
