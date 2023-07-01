--
--  vdp_register.vhd
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
------------------------------------------------------------------------------
--  23rd,March,2008
--      JP: VDP.VHD から分離 by t.hara
--
--  28th,March,2008
--      added "S#0 bit6 5th sprite (9th sprite) flag support" by t.hara
--
--  29th,March,2008
--      added V9958 registers (R25,R26,R27) by t.hara
--
--  26th,January,2017
--      patch yuukun status R0 S#5 timing
--
--  5th,September,2019 modified by Oduvaldo Pavan Junior
--      Fixed the lack of page flipping (R13) capability
--
--      Added the undocumented feature where R1 bit #2 change the blink counter
--      clock source from VSYNC to HSYNC
--
--  30th,May,2021 by t.hara
--      In the register writing by address auto-increment mode,
--      the bug that the address is incremented even if it exceeds R#47 is corrected.
--
--  2nd,June,2021 by t.hara
--      Fixed behavior of address auto-increment.
--      Fixed the write operation to the invalid register.
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_REGISTER IS
    PORT(
        RESET                       : IN    STD_LOGIC;
        CLK21M                      : IN    STD_LOGIC;

        REQ                         : IN    STD_LOGIC;
        ACK                         : OUT   STD_LOGIC;
        WRT                         : IN    STD_LOGIC;
        ADR                         : IN    STD_LOGIC_VECTOR( 15 DOWNTO 0 );
        DBI                         : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        DBO                         : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );

        DOTSTATE                    : IN    STD_LOGIC_VECTOR(  1 DOWNTO 0 );

        VDPCMDTRCLRACK              : IN    STD_LOGIC;
        VDPCMDREGWRACK              : IN    STD_LOGIC;
        HSYNC                       : IN    STD_LOGIC;

        VDPS0SPCOLLISIONINCIDENCE   : IN    STD_LOGIC;
        VDPS0SPOVERMAPPED           : IN    STD_LOGIC;
        VDPS0SPOVERMAPPEDNUM        : IN    STD_LOGIC_VECTOR(  4 DOWNTO 0 );
        SPVDPS0RESETREQ             : OUT   STD_LOGIC;
        SPVDPS0RESETACK             : IN    STD_LOGIC;
        SPVDPS5RESETREQ             : OUT   STD_LOGIC;
        SPVDPS5RESETACK             : IN    STD_LOGIC;

        VDPCMDTR                    : IN    STD_LOGIC;                          -- S#2
        VD                          : IN    STD_LOGIC;                          -- S#2
        HD                          : IN    STD_LOGIC;                          -- S#2
        VDPCMDBD                    : IN    STD_LOGIC;                          -- S#2
        FIELD                       : IN    STD_LOGIC;                          -- S#2
        VDPCMDCE                    : IN    STD_LOGIC;                          -- S#2
        VDPS3S4SPCOLLISIONX         : IN    STD_LOGIC_VECTOR(  8 DOWNTO 0 );    -- S#3,S#4
        VDPS5S6SPCOLLISIONY         : IN    STD_LOGIC_VECTOR(  8 DOWNTO 0 );    -- S#5,S#6
        VDPCMDCLR                   : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );    -- R44,S#7
        VDPCMDSXTMP                 : IN    STD_LOGIC_VECTOR( 10 DOWNTO 0 );    -- S#8,S#9

        VDPVRAMACCESSDATA           : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        VDPVRAMACCESSADDRTMP        : OUT   STD_LOGIC_VECTOR( 16 DOWNTO 0 );
        VDPVRAMADDRSETREQ           : OUT   STD_LOGIC;
        VDPVRAMADDRSETACK           : IN    STD_LOGIC;
        VDPVRAMWRREQ                : OUT   STD_LOGIC;
        VDPVRAMWRACK                : IN    STD_LOGIC;
        VDPVRAMRDDATA               : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        VDPVRAMRDREQ                : OUT   STD_LOGIC;
        VDPVRAMRDACK                : IN    STD_LOGIC;

        VDPCMDREGNUM                : OUT   STD_LOGIC_VECTOR(  3 DOWNTO 0 );
        VDPCMDREGDATA               : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        VDPCMDREGWRREQ              : OUT   STD_LOGIC;
        VDPCMDTRCLRREQ              : OUT   STD_LOGIC;

        PALETTEADDR_OUT             : IN    STD_LOGIC_VECTOR(  3 DOWNTO 0 );
        PALETTEDATARB_OUT           : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        PALETTEDATAG_OUT            : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );

        -- INTERRUPT
        CLR_VSYNC_INT               : OUT   STD_LOGIC;
        CLR_HSYNC_INT               : OUT   STD_LOGIC;
        REQ_VSYNC_INT_N             : IN    STD_LOGIC;
        REQ_HSYNC_INT_N             : IN    STD_LOGIC;

        -- REGISTER VALUE
        REG_R0_HSYNC_INT_EN         : OUT   STD_LOGIC;
        REG_R1_SP_SIZE              : OUT   STD_LOGIC;
        REG_R1_SP_ZOOM              : OUT   STD_LOGIC;
        REG_R1_BL_CLKS              : OUT   STD_LOGIC;
        REG_R1_VSYNC_INT_EN         : OUT   STD_LOGIC;
        REG_R1_DISP_ON              : OUT   STD_LOGIC;
        REG_R2_PT_NAM_ADDR          : OUT   STD_LOGIC_VECTOR(  6 DOWNTO 0 );
        REG_R4_PT_GEN_ADDR          : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        REG_R10R3_COL_ADDR          : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );
        REG_R11R5_SP_ATR_ADDR       : OUT   STD_LOGIC_VECTOR(  9 DOWNTO 0 );
        REG_R6_SP_GEN_ADDR          : OUT   STD_LOGIC_VECTOR(  5 DOWNTO 0 );
        REG_R7_FRAME_COL            : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R8_SP_OFF               : OUT   STD_LOGIC;
        REG_R8_COL0_ON              : OUT   STD_LOGIC;
        REG_R9_PAL_MODE             : OUT   STD_LOGIC;
        REG_R9_INTERLACE_MODE       : OUT   STD_LOGIC;
        REG_R9_Y_DOTS               : OUT   STD_LOGIC;
        REG_R12_BLINK_MODE          : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R13_BLINK_PERIOD        : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R18_ADJ                 : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R19_HSYNC_INT_LINE      : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R23_VSTART_LINE         : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REG_R25_CMD                 : OUT   STD_LOGIC;
        REG_R25_YAE                 : OUT   STD_LOGIC;
        REG_R25_YJK                 : OUT   STD_LOGIC;
        REG_R25_MSK                 : OUT   STD_LOGIC;
        REG_R25_SP2                 : OUT   STD_LOGIC;
        REG_R26_H_SCROLL            : OUT   STD_LOGIC_VECTOR(  8 DOWNTO 3 );
        REG_R27_H_SCROLL            : OUT   STD_LOGIC_VECTOR(  2 DOWNTO 0 );

        --  MODE
        VDPMODETEXT1                : OUT   STD_LOGIC;
        VDPMODETEXT1Q               : OUT   STD_LOGIC;
        VDPMODETEXT2                : OUT   STD_LOGIC;
        VDPMODEMULTI                : OUT   STD_LOGIC;
        VDPMODEMULTIQ               : OUT   STD_LOGIC;
        VDPMODEGRAPHIC1             : OUT   STD_LOGIC;
        VDPMODEGRAPHIC2             : OUT   STD_LOGIC;
        VDPMODEGRAPHIC3             : OUT   STD_LOGIC;
        VDPMODEGRAPHIC4             : OUT   STD_LOGIC;
        VDPMODEGRAPHIC5             : OUT   STD_LOGIC;
        VDPMODEGRAPHIC6             : OUT   STD_LOGIC;
        VDPMODEGRAPHIC7             : OUT   STD_LOGIC;
        VDPMODEISHIGHRES            : OUT   STD_LOGIC;
        SPMODE2                     : OUT   STD_LOGIC;
        VDPMODEISVRAMINTERLEAVE     : OUT   STD_LOGIC;

        -- SWITCHED I/O SIGNALS
        FORCED_V_MODE               : IN    STD_LOGIC;
        VDP_ID                      : IN    STD_LOGIC_VECTOR(  4 DOWNTO 0 )
    );
END VDP_REGISTER;

ARCHITECTURE RTL OF VDP_REGISTER IS
    COMPONENT RAM
        PORT(
            ADR     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
            CLK     : IN    STD_LOGIC;
            WE      : IN    STD_LOGIC;
            DBO     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
            DBI     : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 )
        );
    END COMPONENT;
    COMPONENT PALETTE_RB
        PORT(
            ADR     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
            CLK     : IN    STD_LOGIC;
            WE      : IN    STD_LOGIC;
            DBO     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
            DBI     : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 )
        );
    END COMPONENT;
    COMPONENT PALETTE_G
        PORT(
            ADR     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
            CLK     : IN    STD_LOGIC;
            WE      : IN    STD_LOGIC;
            DBO     : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
            DBI     : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 )
        );
    END COMPONENT;


    SIGNAL FF_ACK                   : STD_LOGIC;

    SIGNAL VDPP1IS1STBYTE           : STD_LOGIC;
    SIGNAL VDPP2IS1STBYTE           : STD_LOGIC;
    SIGNAL VDPP0DATA                : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL VDPP1DATA                : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL VDPREGPTR                : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL VDPREGWRPULSE            : STD_LOGIC;
    SIGNAL VDPR15STATUSREGNUM       : STD_LOGIC_VECTOR(  3 DOWNTO 0 );

    SIGNAL VSYNCINTACK              : STD_LOGIC;
    SIGNAL HSYNCINTACK              : STD_LOGIC;

    SIGNAL VDPR16PALNUM             : STD_LOGIC_VECTOR(  3 DOWNTO 0 );
    SIGNAL VDPR17REGNUM             : STD_LOGIC_VECTOR(  5 DOWNTO 0 );
    SIGNAL VDPR17INCREGNUM          : STD_LOGIC;

    SIGNAL PALETTEADDR              : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL PALETTEWE                : STD_LOGIC;
    SIGNAL PALETTEDATARB_IN         : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL PALETTEDATAG_IN          : STD_LOGIC_VECTOR(  7 DOWNTO 0 );
    SIGNAL PALETTEWRNUM             : STD_LOGIC_VECTOR(  3 DOWNTO 0 );
    SIGNAL FF_PALETTE_WR_REQ        : STD_LOGIC;
    SIGNAL FF_PALETTE_WR_ACK        : STD_LOGIC;
    SIGNAL FF_PALETTE_IN            : STD_LOGIC;
    SIGNAL FF_R2_PT_NAM_ADDR        : STD_LOGIC_VECTOR(  6 DOWNTO 0 );
    SIGNAL FF_R9_2PAGE_MODE         : STD_LOGIC;
    SIGNAL REG_R1_DISP_MODE         : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL FF_R1_DISP_ON            : STD_LOGIC;
    SIGNAL FF_R1_DISP_MODE          : STD_LOGIC_VECTOR(  1 DOWNTO 0 );
    SIGNAL FF_R25_SP2               : STD_LOGIC;
    SIGNAL FF_R26_H_SCROLL          : STD_LOGIC_VECTOR(  8 DOWNTO 3 );
    SIGNAL REG_R18_VERT             : STD_LOGIC_VECTOR(  3 DOWNTO 0 );
    SIGNAL REG_R18_HORZ             : STD_LOGIC_VECTOR(  3 DOWNTO 0 );
    SIGNAL REG_R0_DISP_MODE         : STD_LOGIC_VECTOR(  3 DOWNTO 1 );
    SIGNAL FF_R0_DISP_MODE          : STD_LOGIC_VECTOR(  3 DOWNTO 1 );
    SIGNAL FF_SPVDPS0RESETREQ       : STD_LOGIC;

    SIGNAL W_EVEN_DOTSTATE          : STD_LOGIC;
    SIGNAL W_IS_BITMAP_MODE         : STD_LOGIC;
BEGIN
    ACK                     <= FF_ACK;
    SPVDPS0RESETREQ         <= FF_SPVDPS0RESETREQ;

    VDPMODEGRAPHIC1         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "00000" )ELSE '0';
    VDPMODETEXT1            <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "00001" )ELSE '0';
    VDPMODEMULTI            <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "00010" )ELSE '0';
    VDPMODEGRAPHIC2         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "00100" )ELSE '0';
    VDPMODETEXT1Q           <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "00101" )ELSE '0';
    VDPMODEMULTIQ           <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "00110" )ELSE '0';
    VDPMODEGRAPHIC3         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "01000" )ELSE '0';
    VDPMODETEXT2            <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "01001" )ELSE '0';
    VDPMODEGRAPHIC4         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "01100" )ELSE '0';
    VDPMODEGRAPHIC5         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "10000" )ELSE '0';
    VDPMODEGRAPHIC6         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "10100" )ELSE '0';
    VDPMODEGRAPHIC7         <=  '1' WHEN( ( REG_R0_DISP_MODE & REG_R1_DISP_MODE(0) & REG_R1_DISP_MODE(1) ) = "11100" )ELSE '0';

    VDPMODEISHIGHRES        <=  '1' WHEN( REG_R0_DISP_MODE(3 DOWNTO 2) = "10" AND REG_R1_DISP_MODE = "00" )ELSE
                            '0';
    SPMODE2                 <=  '1' WHEN( REG_R1_DISP_MODE = "00" AND (REG_R0_DISP_MODE(3) OR REG_R0_DISP_MODE(2)) = '1' )ELSE
                            '0';

    VDPMODEISVRAMINTERLEAVE <=  '1' WHEN( (REG_R0_DISP_MODE(3) AND REG_R0_DISP_MODE(1)) = '1' )ELSE
                                '0';

    ----------------------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_ACK <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            FF_ACK <= REQ;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            REG_R1_DISP_ON      <= '0';
            REG_R0_DISP_MODE    <= "000";
            REG_R1_DISP_MODE    <= "00";
            REG_R25_SP2         <= '0';
            REG_R26_H_SCROLL    <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( HSYNC = '1' )THEN
                REG_R1_DISP_ON      <= FF_R1_DISP_ON;
                REG_R0_DISP_MODE    <= FF_R0_DISP_MODE;
                REG_R1_DISP_MODE    <= FF_R1_DISP_MODE;
                IF( VDP_ID /= "00000" )THEN
                    REG_R25_SP2         <= FF_R25_SP2;
                    REG_R26_H_SCROLL    <= FF_R26_H_SCROLL;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------------------
    W_IS_BITMAP_MODE    <=  '1' WHEN( REG_R0_DISP_MODE(3) = '1' OR REG_R0_DISP_MODE = "011" )ELSE
                            '0';

    PROCESS( CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_IS_BITMAP_MODE = '1' AND FF_R9_2PAGE_MODE = '1' )THEN
                REG_R2_PT_NAM_ADDR <= (FF_R2_PT_NAM_ADDR AND "1011111") OR ("0" & FIELD & "00000");
            ELSE
                REG_R2_PT_NAM_ADDR <= FF_R2_PT_NAM_ADDR;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- PALETTE REGISTER
    --------------------------------------------------------------------------
    PALETTEADDR <=  ( "0000" & PALETTEWRNUM )   WHEN( FF_PALETTE_IN = '1' )ELSE
                    ( "0000" & PALETTEADDR_OUT );
    PALETTEWE   <=  '1' WHEN( FF_PALETTE_IN = '1' )ELSE
                    '0';
    W_EVEN_DOTSTATE     <= '1' WHEN( DOTSTATE = "00" OR DOTSTATE = "11" )ELSE
                           '0';

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_PALETTE_IN <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_EVEN_DOTSTATE = '1' )THEN
                FF_PALETTE_IN <= '0';
            ELSE
                IF( FF_PALETTE_WR_REQ /= FF_PALETTE_WR_ACK )THEN
                    FF_PALETTE_IN <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            FF_PALETTE_WR_ACK <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( W_EVEN_DOTSTATE = '0' )THEN
                IF( FF_PALETTE_WR_REQ /= FF_PALETTE_WR_ACK ) THEN
                    FF_PALETTE_WR_ACK <= NOT FF_PALETTE_WR_ACK;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    U_PALETTEMEMRB: PALETTE_RB
    PORT MAP(
        ADR         => PALETTEADDR,
        CLK         => CLK21M,
        WE          => PALETTEWE,
        DBO         => PALETTEDATARB_IN,
        DBI         => PALETTEDATARB_OUT
    );

    U_PALETTEMEMG: PALETTE_G
    PORT MAP(
        ADR         => PALETTEADDR,
        CLK         => CLK21M,
        WE          => PALETTEWE,
        DBO         => PALETTEDATAG_IN,
        DBI         => PALETTEDATAG_OUT
    );

    --------------------------------------------------------------------------
    -- PROCESS OF CPU READ REQUEST
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            DBI <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( REQ = '1' AND WRT = '0' )THEN
                -- READ REQUEST
                CASE( ADR(1 DOWNTO 0) )IS
                WHEN "00"       => -- PORT#0 (0x98): READ VRAM
                    DBI <= VDPVRAMRDDATA;
                WHEN "01"       => -- PORT#1 (0x99): READ STATUS REGISTER
                    CASE( VDPR15STATUSREGNUM )IS
                    WHEN "0000" => -- READ S#0
                        DBI <= (NOT REQ_VSYNC_INT_N) & VDPS0SPOVERMAPPED & VDPS0SPCOLLISIONINCIDENCE & VDPS0SPOVERMAPPEDNUM;
                    WHEN "0001" => -- READ S#1
                        DBI <= "00" & VDP_ID & (NOT REQ_HSYNC_INT_N);
                    WHEN "0010" => -- READ S#2
                        DBI <= VDPCMDTR & VD & HD & VDPCMDBD & "11" & FIELD & VDPCMDCE;
                    WHEN "0011" => -- READ S#3
                        DBI <= VDPS3S4SPCOLLISIONX(7 DOWNTO 0);
                    WHEN "0100" => -- READ S#4
                        DBI <= "0000000" & VDPS3S4SPCOLLISIONX(8);
                    WHEN "0101" => -- READ S#5
                        DBI <= VDPS5S6SPCOLLISIONY(7 DOWNTO 0);
                    WHEN "0110" => -- READ S#6
                        DBI <= "0000000" & VDPS5S6SPCOLLISIONY(8);
                    WHEN "0111" => -- READ S#7: THE COLOR REGISTER
                        DBI <= VDPCMDCLR;
                    WHEN "1000" => -- READ S#8: SXTMP LSB
                        DBI <= VDPCMDSXTMP(7 DOWNTO 0);
                    WHEN "1001" => -- READ S#9: SXTMP MSB
                        DBI <= "1111111" & VDPCMDSXTMP(8);
                    WHEN OTHERS =>
                        DBI <= (OTHERS => '0');
                    END CASE;
                WHEN OTHERS => -- PORT#2, #3: NOT SUPPORTED IN READ MODE
                    DBI <= (OTHERS => '1');
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- HSYNC INTERRUPT RESET CONTROL
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            CLR_HSYNC_INT <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( REQ = '1' AND WRT = '0' )THEN
                -- CASE OF READ REQUEST
                IF( ADR(1 DOWNTO 0) = "01" AND VDPR15STATUSREGNUM = "0001" )THEN
                    -- CLEAR HSYNC INTERRUPT BY READ S#1
                    CLR_HSYNC_INT <= '1';
                ELSE
                    CLR_HSYNC_INT <= '0';
                END IF;
            ELSIF( VDPREGWRPULSE = '1' )THEN
                IF( VDPREGPTR = "010011" OR (VDPREGPTR = "000000" AND VDPP1DATA(4) = '1') )THEN
                    -- CLEAR HSYNC INTERRUPT BY WRITE R19, R0
                    CLR_HSYNC_INT <= '1';
                ELSE
                    CLR_HSYNC_INT <= '0';
                END IF;
            ELSE
                CLR_HSYNC_INT <= '0';
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- VSYNC INTERRUPT RESET CONTROL
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M )
    BEGIN
        IF( RESET = '1' )THEN
            CLR_VSYNC_INT <= '0';
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( REQ = '1' AND WRT = '0' )THEN
                -- CASE OF READ REQUEST
                IF( ADR(1 DOWNTO 0) = "01" AND VDPR15STATUSREGNUM = "0000" )THEN
                    -- CLEAR VSYNC INTERRUPT BY READ S#0
                    CLR_VSYNC_INT <= '1';
                ELSE
                    CLR_VSYNC_INT <= '0';
                END IF;
            ELSE
                CLR_VSYNC_INT <= '0';
            END IF;
        END IF;
    END PROCESS;

    REG_R18_ADJ <= REG_R18_VERT & REG_R18_HORZ;

    --------------------------------------------------------------------------
    -- PROCESS OF CPU WRITE REQUEST
    --------------------------------------------------------------------------
    PROCESS( RESET, CLK21M, FORCED_V_MODE )
    BEGIN
        IF( RESET = '1' )THEN
            VDPP1DATA               <= (OTHERS => '0');
            VDPP1IS1STBYTE          <= '1';
            VDPP2IS1STBYTE          <= '1';
            VDPREGWRPULSE           <= '0';
            VDPREGPTR               <= (OTHERS => '0');
            VDPVRAMWRREQ            <= '0';
            VDPVRAMRDREQ            <= '0';
            VDPVRAMADDRSETREQ       <= '0';
            VDPVRAMACCESSADDRTMP    <= (OTHERS => '0');
            VDPVRAMACCESSDATA       <= (OTHERS => '0');
            FF_R0_DISP_MODE         <= (OTHERS => '0');

            REG_R0_HSYNC_INT_EN     <= '0';
            FF_R1_DISP_MODE         <= (OTHERS => '0');
            REG_R1_SP_SIZE          <= '0';
            REG_R1_SP_ZOOM          <= '0';
            REG_R1_BL_CLKS          <= '0';
            REG_R1_VSYNC_INT_EN     <= '0';
            FF_R1_DISP_ON           <= '0';
            FF_R2_PT_NAM_ADDR       <= (OTHERS => '0');
            REG_R12_BLINK_MODE      <= (OTHERS => '0');
            REG_R13_BLINK_PERIOD    <= (OTHERS => '0');
            REG_R7_FRAME_COL        <= (OTHERS => '0');
            REG_R8_SP_OFF           <= '0';
            REG_R8_COL0_ON          <= '0';
            REG_R9_PAL_MODE         <= FORCED_V_MODE;
            FF_R9_2PAGE_MODE        <= '0';
            REG_R9_INTERLACE_MODE   <= '0';
            REG_R9_Y_DOTS           <= '0';
            VDPR15STATUSREGNUM      <= (OTHERS => '0');
            VDPR16PALNUM            <= (OTHERS => '0');
            VDPR17REGNUM            <= (OTHERS => '0');
            VDPR17INCREGNUM         <= '0';
            REG_R18_VERT            <= (OTHERS => '0');
            REG_R18_HORZ            <= (OTHERS => '0');
            REG_R19_HSYNC_INT_LINE  <= (OTHERS => '0');
            REG_R23_VSTART_LINE     <= (OTHERS => '0');
            REG_R25_CMD             <= '0';
            REG_R25_YAE             <= '0';
            REG_R25_YJK             <= '0';
            REG_R25_MSK             <= '0';
            FF_R25_SP2              <= '0';
            FF_R26_H_SCROLL         <= (OTHERS => '0');
            REG_R27_H_SCROLL        <= (OTHERS => '0');
            VDPCMDREGNUM            <= (OTHERS => '0');
            VDPCMDREGDATA           <= (OTHERS => '0');
            VDPCMDREGWRREQ          <= '0';
            VDPCMDTRCLRREQ          <= '0';

            -- PALETTE
            PALETTEDATARB_IN        <= (OTHERS => '0');
            PALETTEDATAG_IN         <= (OTHERS => '0');
            FF_PALETTE_WR_REQ       <= '0';
            PALETTEWRNUM            <= (OTHERS => '0');
        ELSIF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF (REQ = '1' AND WRT = '0') THEN
                -- READ REQUEST
                CASE ADR(1 DOWNTO 0) IS
                WHEN "00"       => -- PORT#0 (0x98): READ VRAM
                    VDPVRAMRDREQ <= NOT VDPVRAMRDACK;
                WHEN "01"       => -- PORT#1 (0x99): READ STATUS REGISTER
                    VDPP1IS1STBYTE <= '1';
                    CASE VDPR15STATUSREGNUM IS
                    WHEN "0000" => -- READ S#0
                        FF_SPVDPS0RESETREQ <= NOT SPVDPS0RESETACK;
                    WHEN "0001" => -- READ S#1
                        NULL;
                    WHEN "0101" => -- READ S#5
                        SPVDPS5RESETREQ <= NOT SPVDPS5RESETACK;
                    WHEN "0111" => -- READ S#7: THE COLOR REGISTER
                        VDPCMDTRCLRREQ <= NOT VDPCMDTRCLRACK;
                    WHEN OTHERS =>
                        NULL;
                    END CASE;
                WHEN OTHERS => -- PORT#3: NOT SUPPORTED IN READ MODE
                    NULL;
                END CASE;

            ELSIF (REQ = '1' AND WRT = '1') THEN
                -- WRITE REQUEST
                CASE ADR(1 DOWNTO 0) IS
                    WHEN "00"       => -- PORT#0 (0x98): WRITE VRAM
                        VDPVRAMACCESSDATA <= DBO;
                        VDPVRAMWRREQ <= NOT VDPVRAMWRACK;

                    WHEN "01"       => -- PORT#1 (0x99): REGISTER WRITE OR VRAM ADDR SETUP
                        IF(VDPP1IS1STBYTE = '1') THEN
                            -- IT IS THE FIRST BYTE; BUFFER IT
                            VDPP1IS1STBYTE <= '0';
                            VDPP1DATA      <= DBO;
                        ELSE
                            -- IT IS THE SECOND BYTE; PROCESS BOTH BYTES
                            VDPP1IS1STBYTE <= '1';
                            CASE DBO( 7 DOWNTO 6 ) IS
                                WHEN "01" =>    -- SET VRAM ACCESS ADDRESS(WRITE)
                                    VDPVRAMACCESSADDRTMP( 7 DOWNTO 0 ) <= VDPP1DATA( 7 DOWNTO 0);
                                    VDPVRAMACCESSADDRTMP(13 DOWNTO 8 ) <= DBO( 5 DOWNTO 0);
                                    VDPVRAMADDRSETREQ <= NOT VDPVRAMADDRSETACK;
                                WHEN "00" =>    -- SET VRAM ACCESS ADDRESS(READ)
                                    VDPVRAMACCESSADDRTMP( 7 DOWNTO 0 ) <= VDPP1DATA( 7 DOWNTO 0);
                                    VDPVRAMACCESSADDRTMP(13 DOWNTO 8 ) <= DBO( 5 DOWNTO 0);
                                    VDPVRAMADDRSETREQ <= NOT VDPVRAMADDRSETACK;
                                    VDPVRAMRDREQ <= NOT VDPVRAMRDACK;
                                WHEN "10" =>    -- DIRECT REGISTER SELECTION
                                    VDPREGPTR <= DBO( 5 DOWNTO 0);
                                    VDPREGWRPULSE <= '1';
                                WHEN "11" =>    -- DIRECT REGISTER SELECTION ??
                                    VDPREGPTR <= DBO( 5 DOWNTO 0);
                                    VDPREGWRPULSE <= '1';
                                WHEN OTHERS =>
                                    NULL;
                            END CASE;
                        END IF;

                    WHEN "10"       => -- PORT#2: PALETTE WRITE
                        IF(VDPP2IS1STBYTE = '1') THEN
                            PALETTEDATARB_IN <= DBO;
                            VDPP2IS1STBYTE <= '0';
                        ELSE
                            -- パレットはRGBのデータが揃った時に一度に書き換える。
                            -- (実機で動作を確認した)
                            PALETTEDATAG_IN <= DBO;
                            PALETTEWRNUM <= VDPR16PALNUM;
                            FF_PALETTE_WR_REQ <= NOT FF_PALETTE_WR_ACK;
                            VDPP2IS1STBYTE <= '1';
                            VDPR16PALNUM <= VDPR16PALNUM + 1;
                        END IF;

                    WHEN "11" => -- PORT#3: INDIRECT REGISTER WRITE
                        IF( VDPR17REGNUM /= "010001" ) THEN
                            -- REGISTER 17 CAN NOT BE MODIFIED. ALL OTHERS ARE OK
                            VDPREGWRPULSE <= '1';
                        END IF;
                        VDPP1DATA <= DBO;
                        VDPREGPTR <= VDPR17REGNUM;
                        IF( VDPR17INCREGNUM = '1' ) THEN
                            VDPR17REGNUM <= VDPR17REGNUM + 1;
                        END IF;

                    WHEN OTHERS =>
                        NULL;
                END CASE;

            ELSIF (VDPREGWRPULSE = '1') THEN
                -- WRITE TO REGISTER (IF PREVIOUSLY REQUESTED)
                VDPREGWRPULSE <= '0';
                IF ( VDPREGPTR(5) = '0') THEN
                    -- IT IS A NOT A COMMAND ENGINE REGISTER:
                    CASE VDPREGPTR(4 DOWNTO 0) IS
                        WHEN "00000" =>     -- #00
                            FF_R0_DISP_MODE <= VDPP1DATA( 3 DOWNTO 1);
                            REG_R0_HSYNC_INT_EN <= VDPP1DATA(4);
                        WHEN "00001" =>     -- #01
                            REG_R1_SP_ZOOM      <= VDPP1DATA(0);
                            REG_R1_SP_SIZE      <= VDPP1DATA(1);
                            REG_R1_BL_CLKS      <= VDPP1DATA(2);
                            FF_R1_DISP_MODE     <= VDPP1DATA(4 DOWNTO 3);
                            REG_R1_VSYNC_INT_EN <= VDPP1DATA(5);
                            FF_R1_DISP_ON       <= VDPP1DATA(6);
                        WHEN "00010" =>     -- #02
                            FF_R2_PT_NAM_ADDR   <= VDPP1DATA( 6 DOWNTO 0);
                        WHEN "00011" =>     -- #03
                            REG_R10R3_COL_ADDR(7 DOWNTO 0) <= VDPP1DATA( 7 DOWNTO 0);
                        WHEN "00100" =>     -- #04
                            REG_R4_PT_GEN_ADDR  <= VDPP1DATA( 5 DOWNTO 0);
                        WHEN "00101" =>     -- #05
                            REG_R11R5_SP_ATR_ADDR(7 DOWNTO 0) <= VDPP1DATA;
                        WHEN "00110" =>     -- #06
                            REG_R6_SP_GEN_ADDR  <= VDPP1DATA( 5 DOWNTO 0);
                        WHEN "00111" =>     -- #07
                            REG_R7_FRAME_COL    <= VDPP1DATA( 7 DOWNTO 0 );
                        WHEN "01000" =>     -- #08
                            REG_R8_SP_OFF       <= VDPP1DATA(1);
                            REG_R8_COL0_ON      <= VDPP1DATA(5);
                        WHEN "01001" =>     -- #09
                            REG_R9_PAL_MODE         <= VDPP1DATA(1);
                            FF_R9_2PAGE_MODE        <= VDPP1DATA(2);
                            REG_R9_INTERLACE_MODE   <= VDPP1DATA(3);
                            REG_R9_Y_DOTS           <= VDPP1DATA(7);
                        WHEN "01010" =>     -- #10
                            REG_R10R3_COL_ADDR(10 DOWNTO 8) <= VDPP1DATA( 2 DOWNTO 0);
                        WHEN "01011" =>     -- #11
                            REG_R11R5_SP_ATR_ADDR( 9 DOWNTO 8) <= VDPP1DATA( 1 DOWNTO 0);
                        WHEN "01100" =>     -- #12
                            REG_R12_BLINK_MODE  <= VDPP1DATA;
                        WHEN "01101" =>     -- #13
                            REG_R13_BLINK_PERIOD    <= VDPP1DATA;
                        WHEN "01110" =>     -- #14
                            VDPVRAMACCESSADDRTMP( 16 DOWNTO 14 ) <= VDPP1DATA( 2 DOWNTO 0);
                            VDPVRAMADDRSETREQ <= NOT VDPVRAMADDRSETACK;
                        WHEN "01111" =>     -- #15
                            VDPR15STATUSREGNUM <= VDPP1DATA( 3 DOWNTO 0);
                        WHEN "10000" =>     -- #16
                            VDPR16PALNUM <= VDPP1DATA( 3 DOWNTO 0 );
                            VDPP2IS1STBYTE <= '1';
                        WHEN "10001" =>     -- #17
                            VDPR17REGNUM <= VDPP1DATA( 5 DOWNTO 0 );
                            VDPR17INCREGNUM <= NOT VDPP1DATA(7);
                        WHEN "10010" =>     -- #18
                            REG_R18_VERT <= VDPP1DATA( 7 DOWNTO 4 );
                            REG_R18_HORZ <= VDPP1DATA( 3 DOWNTO 0 );
                        WHEN "10011" =>     -- #19
                            REG_R19_HSYNC_INT_LINE  <= VDPP1DATA;
                        WHEN "10111" =>     -- #23
                            REG_R23_VSTART_LINE     <= VDPP1DATA;
                        WHEN "11001" =>     -- #25
                            IF( VDP_ID /= "00000" )THEN
                                REG_R25_CMD <= VDPP1DATA(6);
                                REG_R25_YAE <= VDPP1DATA(4);
                                REG_R25_YJK <= VDPP1DATA(3);
                                REG_R25_MSK <= VDPP1DATA(1);
                                FF_R25_SP2 <= VDPP1DATA(0);
                            END IF;
                        WHEN "11010" =>     -- #26
                            IF( VDP_ID /= "00000" )THEN
                                FF_R26_H_SCROLL <= VDPP1DATA( 5 DOWNTO 0 );
                            END IF;
                        WHEN "11011" =>     -- #27
                            IF( VDP_ID /= "00000" )THEN
                                REG_R27_H_SCROLL <= VDPP1DATA( 2 DOWNTO 0 );
                            END IF;
                        WHEN OTHERS => NULL;
                    END CASE;
                ELSIF ( VDPREGPTR(4) = '0') THEN
                    -- REGISTERS FOR VDP COMMAND
                    VDPCMDREGNUM <= VDPREGPTR(3 DOWNTO 0);
                    VDPCMDREGDATA <= VDPP1DATA;
                    VDPCMDREGWRREQ <= NOT VDPCMDREGWRACK;
                END IF;
            END IF;

        END IF;
    END PROCESS;
END RTL;
