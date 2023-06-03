--
--  vdp_text12.vhd
--    Imprementation of Text Mode 1,2.
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
-- Contributors
--
--   Alex Wulms
--     - Improvement of the TEXT2 mode such as 'blink function'.
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
-- 12nd,August,2006 created by Kunihiko Ohnaka
-- JP: VDPのコアの実装とスクリーンモードの実装を分離した
--
-- 13rd,March,2008
-- Fixed Blink by caro
--
-- 22nd,March,2008
-- JP: タイミング緩和と、リファクタリング by t.hara
--
-- 11st, September,2019 modified by Oduvaldo Pavan Junior
-- Fixed the lack of page flipping (R13) capability
--
-- Added the undocumented feature where R1 bit #2 change the blink counter
-- clock source from VSYNC to HSYNC
--
-------------------------------------------------------------------------------
-- Document
--
-- JP: TEXTモード1,2のメイン処理回路です。
--
-------------------------------------------------------------------------------
--

LIBRARY IEEE;
	USE IEEE.STD_LOGIC_1164.ALL;
	USE IEEE.STD_LOGIC_UNSIGNED.ALL;
	USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_TEXT12 IS
	PORT(
		-- VDP CLOCK ... 21.477MHZ
		CLK21M						: IN	STD_LOGIC;
		RESET						: IN	STD_LOGIC;

		DOTSTATE					: IN	STD_LOGIC_VECTOR(  1 DOWNTO 0 );
		DOTCOUNTERX					: IN	STD_LOGIC_VECTOR(  8 DOWNTO 0 );
		DOTCOUNTERY					: IN	STD_LOGIC_VECTOR(  8 DOWNTO 0 );
		DOTCOUNTERYP				: IN	STD_LOGIC_VECTOR(  8 DOWNTO 0 );

		VDPMODETEXT1				: IN	STD_LOGIC;
		VDPMODETEXT1Q				: IN	STD_LOGIC;
		VDPMODETEXT2				: IN	STD_LOGIC;

		-- REGISTERS
		REG_R1_BL_CLKS				: IN	STD_LOGIC;
		REG_R7_FRAME_COL			: IN	STD_LOGIC_VECTOR(  7 DOWNTO 0 );
		REG_R12_BLINK_MODE			: IN	STD_LOGIC_VECTOR(  7 DOWNTO 0 );
		REG_R13_BLINK_PERIOD		: IN	STD_LOGIC_VECTOR(  7 DOWNTO 0 );

		REG_R2_PT_NAM_ADDR			: IN	STD_LOGIC_VECTOR(  6 DOWNTO 0 );
		REG_R4_PT_GEN_ADDR			: IN	STD_LOGIC_VECTOR(  5 DOWNTO 0 );
		REG_R10R3_COL_ADDR			: IN	STD_LOGIC_VECTOR( 10 DOWNTO 0 );
		--
		PRAMDAT						: IN	STD_LOGIC_VECTOR(  7 DOWNTO 0 );
		PRAMADR						: OUT	STD_LOGIC_VECTOR( 16 DOWNTO 0 );
		TXVRAMREADEN				: OUT	STD_LOGIC;

		PCOLORCODE					: OUT	STD_LOGIC_VECTOR(  3 DOWNTO 0 )
	);
END VDP_TEXT12;

ARCHITECTURE RTL OF VDP_TEXT12 IS
	SIGNAL ITXVRAMREADEN			: STD_LOGIC;
	SIGNAL ITXVRAMREADEN2			: STD_LOGIC;
	SIGNAL DOTCOUNTER24				: STD_LOGIC_VECTOR(	 4 DOWNTO 0 );
	SIGNAL TXWINDOWX				: STD_LOGIC;
	SIGNAL TXPREWINDOWX				: STD_LOGIC;

	SIGNAL LOGICALVRAMADDRNAM		: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL LOGICALVRAMADDRGEN		: STD_LOGIC_VECTOR( 16 DOWNTO 0 );
	SIGNAL LOGICALVRAMADDRCOL		: STD_LOGIC_VECTOR( 16 DOWNTO 0 );

	SIGNAL TXCHARCOUNTER			: STD_LOGIC_VECTOR( 11 DOWNTO 0 );
	SIGNAL TXCHARCOUNTERX			: STD_LOGIC_VECTOR(	 6 DOWNTO 0 );
	SIGNAL TXCHARCOUNTERSTARTOFLINE : STD_LOGIC_VECTOR( 11 DOWNTO 0 );

	SIGNAL PATTERNNUM				: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL PREPATTERN				: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL PREBLINK					: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL PATTERN					: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL BLINK					: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );
	SIGNAL TXCOLORCODE				: STD_LOGIC;			 -- ONLY 2 COLORS
	SIGNAL TXCOLOR					: STD_LOGIC_VECTOR(	 7 DOWNTO 0 );

	SIGNAL FF_BLINK_CLK_CNT			: STD_LOGIC_VECTOR(	 3 DOWNTO 0 );
	SIGNAL FF_BLINK_STATE			: STD_LOGIC;
	SIGNAL FF_BLINK_PERIOD_CNT		: STD_LOGIC_VECTOR(	 3 DOWNTO 0 );
	SIGNAL W_BLINK_CNT_MAX			: STD_LOGIC_VECTOR(	 3 DOWNTO 0 );
	SIGNAL W_BLINK_SYNC				: STD_LOGIC;

BEGIN

	-- JP: RAMは DOTSTATEが"10","00"の時にアドレスを出して"01"でアクセスする。
	-- JP: EIGHTDOTSTATEで見ると、
	-- JP:	0-1		READ PATTERN NUM.
	-- JP:	1-2		READ PATTERN
	-- JP: となる。
	--

	----------------------------------------------------------------
	--
	----------------------------------------------------------------
	TXCHARCOUNTER		<=	TXCHARCOUNTERSTARTOFLINE + TXCHARCOUNTERX;

	LOGICALVRAMADDRNAM	<=	(REG_R2_PT_NAM_ADDR & TXCHARCOUNTER(9 DOWNTO 0)) WHEN( VDPMODETEXT1 = '1' OR VDPMODETEXT1Q = '1' )ELSE
							(REG_R2_PT_NAM_ADDR(6 DOWNTO 2) & TXCHARCOUNTER);

	LOGICALVRAMADDRGEN	<=	REG_R4_PT_GEN_ADDR & PATTERNNUM & DOTCOUNTERY(2 DOWNTO 0);

	LOGICALVRAMADDRCOL	<=	REG_R10R3_COL_ADDR(10 DOWNTO 3) & TXCHARCOUNTER(11 DOWNTO 3);

	TXVRAMREADEN		<=	ITXVRAMREADEN					WHEN( VDPMODETEXT1 = '1' OR VDPMODETEXT1Q = '1' )ELSE
							ITXVRAMREADEN OR ITXVRAMREADEN2 WHEN( VDPMODETEXT2 = '1' )ELSE
							'0';

	TXCOLOR				<=	REG_R12_BLINK_MODE		WHEN( ( VDPMODETEXT2 = '1') AND (FF_BLINK_STATE = '1') AND (BLINK(7) = '1') )ELSE
							REG_R7_FRAME_COL;
	PCOLORCODE			<=	TXCOLOR(7 DOWNTO 4)		WHEN( (TXWINDOWX = '1') AND (TXCOLORCODE = '1') )ELSE
							TXCOLOR(3 DOWNTO 0)		WHEN( (TXWINDOWX = '1') AND (TXCOLORCODE = '0') )ELSE
							REG_R7_FRAME_COL(3 DOWNTO 0);

	---------------------------------------------------------------------------
	-- TIMING GENERATOR
	---------------------------------------------------------------------------
	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			DOTCOUNTER24	<= (OTHERS => '0');
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "10" )THEN
				IF( DOTCOUNTERX = 12 )THEN
					-- JP: DOTCOUNTERは"10"のタイミングでは既にカウントアップしているので注意
					DOTCOUNTER24 <= (OTHERS => '0');
				ELSE
					-- THE DOTCOUNTER24(2 DOWNTO 0) COUNTS UP 0 TO 5,
					-- AND THE DOTCOUNTER24(4 DOWNTO 3) COUNTS UP 0 TO 3.
					IF( DOTCOUNTER24(2 DOWNTO 0) = "101" ) THEN
						DOTCOUNTER24(4 DOWNTO 3) <= DOTCOUNTER24(4 DOWNTO 3) + 1;
						DOTCOUNTER24(2 DOWNTO 0) <= "000";
					ELSE
						DOTCOUNTER24(2 DOWNTO 0) <= DOTCOUNTER24(2 DOWNTO 0) + 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			TXPREWINDOWX	<= '0';
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "10" )THEN
				IF( DOTCOUNTERX = 12 )THEN
					TXPREWINDOWX <= '1';
				ELSIF( DOTCOUNTERX = 240+12 )THEN
					TXPREWINDOWX <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			TXWINDOWX		<= '0';
		ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
			IF( DOTSTATE = "01" )THEN
				IF( DOTCOUNTERX = 16 )THEN
					TXWINDOWX <= '1';
				ELSIF( DOTCOUNTERX = 240+16 )THEN
					TXWINDOWX <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;

	---------------------------------------------------------------------------
	--
	---------------------------------------------------------------------------
	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			PATTERNNUM					<= (OTHERS => '0');
			PRAMADR						<= (OTHERS => '0');
			ITXVRAMREADEN				<= '0';
			ITXVRAMREADEN2				<= '0';
			TXCHARCOUNTERX				<= (OTHERS => '0');
			PREBLINK					<= (OTHERS => '0');
			TXCHARCOUNTERSTARTOFLINE	<= (OTHERS => '0');
		ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
			CASE DOTSTATE IS
				WHEN "11" =>
					IF( TXPREWINDOWX = '1' ) THEN
						-- VRAM READ ADDRESS OUTPUT.
						CASE DOTCOUNTER24(2 DOWNTO 0) IS
							WHEN "000" =>
								IF( DOTCOUNTER24(4 DOWNTO 3) = "00" ) THEN
									-- READ COLOR TABLE(TEXT2 BLINK)
									-- IT IS USED ONLY ONE TIME PER 8 CHARACTERS.
									PRAMADR <= LOGICALVRAMADDRCOL;
									ITXVRAMREADEN2 <= '1';
								END IF;
							WHEN "001" =>
								-- READ PATTERN NAME TABLE
								PRAMADR <= LOGICALVRAMADDRNAM;
								ITXVRAMREADEN <= '1';
								TXCHARCOUNTERX <= TXCHARCOUNTERX + 1;
							WHEN "010" =>
								-- READ PATTERN GENERATOR TABLE
								PRAMADR <= LOGICALVRAMADDRGEN;
								ITXVRAMREADEN <= '1';
							WHEN "100" =>
								-- READ PATTERN NAME TABLE
								-- IT IS USED IF VDPMODE IS TEST2.
								PRAMADR <= LOGICALVRAMADDRNAM;
								ITXVRAMREADEN2 <= '1';
								IF( VDPMODETEXT2 = '1' ) THEN
									TXCHARCOUNTERX <= TXCHARCOUNTERX + 1;
								END IF;
							WHEN "101" =>
								-- READ PATTERN GENERATOR TABLE
								-- IT IS USED IF VDPMODE IS TEST2.
								PRAMADR <= LOGICALVRAMADDRGEN;
								ITXVRAMREADEN2 <= '1';
							WHEN OTHERS =>
								NULL;
						END CASE;
					END IF;
				WHEN "10" =>
					ITXVRAMREADEN <= '0';
					ITXVRAMREADEN2 <= '0';
				WHEN "00" =>
					IF( DOTCOUNTERX = 11) THEN
						TXCHARCOUNTERX <= (OTHERS => '0');
						IF( DOTCOUNTERYP = 0 )	THEN
							TXCHARCOUNTERSTARTOFLINE <= (OTHERS => '0');
						END IF;
					ELSIF( (DOTCOUNTERX = 240+11) AND (DOTCOUNTERYP(2 DOWNTO 0) = "111") ) THEN
							TXCHARCOUNTERSTARTOFLINE <= TXCHARCOUNTERSTARTOFLINE + TXCHARCOUNTERX;
					END IF;
				WHEN "01" =>
					CASE DOTCOUNTER24(2 DOWNTO 0) IS
						WHEN "001" =>
							-- READ COLOR TABLE(TEXT2 BLINK)
							-- IT IS USED ONLY ONE TIME PER 8 CHARACTERS.
							IF( DOTCOUNTER24(4 DOWNTO 3) = "00" ) THEN
								PREBLINK <= PRAMDAT;
							END IF;
						WHEN "010" =>
							-- READ PATTERN NAME TABLE
							PATTERNNUM <= PRAMDAT;
						WHEN "011" =>
							-- READ PATTERN GENERATOR TABLE
							PREPATTERN <= PRAMDAT;
						WHEN "101" =>
							-- READ PATTERN NAME TABLE
							-- IT IS USED IF VDPMODE IS TEST2.
							PATTERNNUM <= PRAMDAT;
						WHEN "000" =>
							-- READ PATTERN GENERATOR TABLE
							-- IT IS USED IF VDPMODE IS TEST2.
							IF( VDPMODETEXT2 = '1' ) THEN
								PREPATTERN <= PRAMDAT;
							END IF;
						WHEN OTHERS =>
							NULL;
					END CASE;
				WHEN OTHERS => NULL;
			END CASE;
		END IF;
	END PROCESS;

	----------------------------------------------------------------
	--
	----------------------------------------------------------------
	PROCESS( RESET, CLK21M )
	BEGIN
		IF(RESET = '1' ) THEN
			PATTERN			<= (OTHERS => '0');
			TXCOLORCODE		<= '0';
			BLINK			<= (OTHERS => '0');
		ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
			-- COLOR CODE DECISION
			-- JP: "01"と"10"のタイミングでかラーコードを出力してあげれば、
			-- JP: VDPエンティティの方でパレットをデコードして色を出力してくれる。
			-- JP: "01"と"10"で同じ色を出力すれば横256ドットになり、違う色を
			-- JP: 出力すれば横512ドット表示となる。
			CASE DOTSTATE IS
				WHEN "00" =>
					IF( DOTCOUNTER24(2 DOWNTO 0) = "100" ) THEN
						-- LOAD NEXT 8 DOT DATA
						-- JP: キャラクタの描画は DOTCOUNTER24が、
						-- JP:	 "0:4"から"1:3"の6ドット
						-- JP:	 "1:4"から"2:3"の6ドット
						-- JP:	 "2:4"から"3:3"の6ドット
						-- JP:	 "3:4"から"0:3"の6ドット
						-- JP: で行われるので"100"のタイミングでロードする
						PATTERN <= PREPATTERN;
					ELSIF( (DOTCOUNTER24(2 DOWNTO 0) = "001") AND (VDPMODETEXT2 = '1') ) THEN
						-- JP: TEXT2では"001"のタイミングでもロードする。
						PATTERN <= PREPATTERN;
					END IF;
					IF( (DOTCOUNTER24(2 DOWNTO 0) = "100") OR
							(DOTCOUNTER24(2 DOWNTO 0) = "001") ) THEN
						-- EVALUATE BLINK SIGNAL
						IF(DOTCOUNTER24(4 DOWNTO 0) = "00100") THEN
							BLINK <= PREBLINK;
						ELSE
							BLINK <= BLINK(6 DOWNTO 0) & "0";
						END IF;
					END IF;
				WHEN "01" =>
					-- パターンに応じてカラーコードを決定
					TXCOLORCODE <= PATTERN(7);
					-- パターンをシフト
					PATTERN <= PATTERN(6 DOWNTO 0) & '0';
				WHEN "11" =>
					NULL;
				WHEN "10" =>
					IF( VDPMODETEXT2 = '1' ) THEN
						TXCOLORCODE <= PATTERN(7);
						-- パターンをシフト
						PATTERN <= PATTERN(6 DOWNTO 0) & '0';
					END IF;

				WHEN OTHERS => NULL;
			END CASE;
		END IF;
	END PROCESS;

	--------------------------------------------------------------------------
	-- BLINK TIMING GENERATION FIXED BY CARO AND T.HARA
	--------------------------------------------------------------------------
	W_BLINK_CNT_MAX <=	REG_R13_BLINK_PERIOD( 3 DOWNTO 0 )	WHEN( FF_BLINK_STATE = '0' )ELSE
						REG_R13_BLINK_PERIOD( 7 DOWNTO 4 );
	W_BLINK_SYNC	<=	'1' WHEN( (DOTCOUNTERX = 0) AND (DOTCOUNTERYP = 0) AND (DOTSTATE = "00") AND (REG_R1_BL_CLKS = '0') )ELSE
						'1' WHEN( (DOTCOUNTERX = 0) AND (DOTSTATE = "00") AND (REG_R1_BL_CLKS = '1') )ELSE
						'0';

	PROCESS( RESET, CLK21M )
	BEGIN
		IF( RESET = '1' )THEN
			FF_BLINK_CLK_CNT <= (OTHERS => '0');
			FF_BLINK_STATE <= '0';
			FF_BLINK_PERIOD_CNT <= (OTHERS => '0');
		ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
			IF( W_BLINK_SYNC = '1' )THEN

				IF (FF_BLINK_CLK_CNT = "1001") THEN
					FF_BLINK_CLK_CNT <= (OTHERS => '0');
					FF_BLINK_PERIOD_CNT <= FF_BLINK_PERIOD_CNT + 1;
				ELSE
					FF_BLINK_CLK_CNT <= FF_BLINK_CLK_CNT + 1;
				END IF;

				IF( FF_BLINK_PERIOD_CNT >= W_BLINK_CNT_MAX )THEN
					FF_BLINK_PERIOD_CNT <= (OTHERS => '0');
					IF (REG_R13_BLINK_PERIOD( 7 DOWNTO 4 ) = "0000")THEN
						 -- WHEN ON PERIOD IS 0, THE PAGE SELECTED SHOULD BE ALWAYS ODD / R#2
						 FF_BLINK_STATE <= '0';
					ELSIF( REG_R13_BLINK_PERIOD( 3 DOWNTO 0 ) = "0000")THEN
						 -- WHEN OFF PERIOD IS 0 AND ON NOT, THE PAGE SELECT SHOULD BE ALWAYS THE R#2 EVEN PAIR
						 FF_BLINK_STATE <= '1';
					ELSE
						 -- NEITHER ARE 0, SO JUST KEEP SWITCHING WHEN PERIOD ENDS
						 FF_BLINK_STATE <= NOT FF_BLINK_STATE;
					END IF;
				END IF;

			END IF;

		END IF;
	END PROCESS;

END RTL;
