--
--  vdp_command.vhd
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
--  20th,March,2008
--      JP: VDP.VHD から分離 by t.hara
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;
    USE IEEE.STD_LOGIC_ARITH.ALL;
    USE WORK.VDP_PACKAGE.ALL;

ENTITY VDP_COMMAND IS
    PORT(
        RESET               : IN    STD_LOGIC;
        CLK21M              : IN    STD_LOGIC;

        VDPMODEGRAPHIC4     : IN    STD_LOGIC;
        VDPMODEGRAPHIC5     : IN    STD_LOGIC;
        VDPMODEGRAPHIC6     : IN    STD_LOGIC;
        VDPMODEGRAPHIC7     : IN    STD_LOGIC;
        VDPMODEISHIGHRES    : IN    STD_LOGIC;

        VRAMWRACK           : IN    STD_LOGIC;
        VRAMRDACK           : IN    STD_LOGIC;
        VRAMREADINGR        : IN    STD_LOGIC;
        VRAMREADINGA        : IN    STD_LOGIC;
        VRAMRDDATA          : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        REGWRREQ            : IN    STD_LOGIC;
        TRCLRREQ            : IN    STD_LOGIC;
        REGNUM              : IN    STD_LOGIC_VECTOR(  3 DOWNTO 0 );
        REGDATA             : IN    STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        PREGWRACK           : OUT   STD_LOGIC;
        PTRCLRACK           : OUT   STD_LOGIC;
        PVRAMWRREQ          : OUT   STD_LOGIC;
        PVRAMRDREQ          : OUT   STD_LOGIC;
        PVRAMACCESSADDR     : OUT   STD_LOGIC_VECTOR( 16 DOWNTO 0 );
        PVRAMWRDATA         : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );
        PCLR                : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 0 );    -- R44, S#7
        PCE                 : OUT   STD_LOGIC;                          -- S#2 (BIT 0)
        PBD                 : OUT   STD_LOGIC;                          -- S#2 (BIT 4)
        PTR                 : OUT   STD_LOGIC;                          -- S#2 (BIT 7)
        PSXTMP              : OUT   STD_LOGIC_VECTOR( 10 DOWNTO 0 );    -- S#8, S#9

        CUR_VDP_COMMAND     : OUT   STD_LOGIC_VECTOR(  7 DOWNTO 4 );

        REG_R25_CMD         : IN    STD_LOGIC
    );
END VDP_COMMAND;

ARCHITECTURE RTL OF VDP_COMMAND IS
    -- VDP COMMAND SIGNALS - CAN BE SET BY CPU
    SIGNAL SX                   : STD_LOGIC_VECTOR(  8 DOWNTO 0 );      -- R33,32
    SIGNAL SY                   : STD_LOGIC_VECTOR(  9 DOWNTO 0 );      -- R35,34
    SIGNAL DX                   : STD_LOGIC_VECTOR(  8 DOWNTO 0 );      -- R37,36
    SIGNAL DY                   : STD_LOGIC_VECTOR(  9 DOWNTO 0 );      -- R39,38
    SIGNAL NX                   : STD_LOGIC_VECTOR(  9 DOWNTO 0 );      -- R41,40
    SIGNAL NY                   : STD_LOGIC_VECTOR(  9 DOWNTO 0 );      -- R43,42
    SIGNAL MM                   : STD_LOGIC;                            -- R45 BIT 0
    SIGNAL EQ                   : STD_LOGIC;                            -- R45 BIT 1
    SIGNAL DIX                  : STD_LOGIC;                            -- R45 BIT 2
    SIGNAL DIY                  : STD_LOGIC;                            -- R45 BIT 3
--  SIGNAL MXS                  : STD_LOGIC;                            -- R45 BIT 4
--  SIGNAL MXD                  : STD_LOGIC;                            -- R45 BIT 5
    SIGNAL CMR                  : STD_LOGIC_VECTOR(  7 DOWNTO 0 );      -- R46

    -- VDP COMMAND SIGNALS - INTERNAL REGISTERS
    SIGNAL DXTMP                : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL NXTMP                : STD_LOGIC_VECTOR(  9 DOWNTO 0 );
    SIGNAL REGWRACK             : STD_LOGIC;
    SIGNAL TRCLRACK             : STD_LOGIC;
    SIGNAL CMRWR                : STD_LOGIC;

    -- VDP COMMAND SIGNALS - COMMUNICATION BETWEEN COMMAND PROCESSOR
    -- AND MEMORY INTERFACE (WHICH IS IN THE COLOR GENERATOR)
    SIGNAL VRAMWRREQ            : STD_LOGIC;
    SIGNAL VRAMRDREQ            : STD_LOGIC;
    SIGNAL VRAMACCESSADDR       : STD_LOGIC_VECTOR( 16 DOWNTO 0 );
    SIGNAL VRAMWRDATA           : STD_LOGIC_VECTOR(  7 DOWNTO 0 );

    SIGNAL CLR                  : STD_LOGIC_VECTOR(  7 DOWNTO 0 );      -- R44, S#7
    -- VDP COMMAND SIGNALS - CAN BE READ BY CPU
    SIGNAL CE                   : STD_LOGIC;                            -- S#2 (BIT 0)
    SIGNAL BD                   : STD_LOGIC;                            -- S#2 (BIT 4)
    SIGNAL TR                   : STD_LOGIC;                            -- S#2 (BIT 7)
    SIGNAL SXTMP                : STD_LOGIC_VECTOR( 10 DOWNTO 0 );      -- S#8, S#9

    SIGNAL W_VDPCMD_EN          : STD_LOGIC;

    -- VDP COMMAND STATE REGISTER
    TYPE TYPSTATE IS (
        STIDLE, STCHKLOOP,
        STRDCPU, STWAITCPU,
        STRDVRAM, STWAITRDVRAM,
        STPOINTWAITRDVRAM,
        STSRCHWAITRDVRAM,
        STPRERDVRAM, STWAITPRERDVRAM,
        STWRVRAM, STWAITWRVRAM,
        STLINENEWPOS, STLINECHKLOOP,
        STSRCHCHKLOOP,
        STEXECEND
    );
    SIGNAL STATE : TYPSTATE;

    CONSTANT HMMC       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1111";
    CONSTANT YMMM       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1110";
    CONSTANT HMMM       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1101";
    CONSTANT HMMV       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1100";
    CONSTANT LMMC       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1011";
    CONSTANT LMCM       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1010";
    CONSTANT LMMM       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1001";
    CONSTANT LMMV       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "1000";
    CONSTANT LINE       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "0111";
    CONSTANT SRCH       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "0110";
    CONSTANT PSET       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "0101";
    CONSTANT POINT      : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "0100";
    CONSTANT STOP       : STD_LOGIC_VECTOR( 3 DOWNTO 0 ) := "0000";

    CONSTANT IMPB210    : STD_LOGIC_VECTOR( 2 DOWNTO 0 ) := "000";
    CONSTANT ANDB210    : STD_LOGIC_VECTOR( 2 DOWNTO 0 ) := "001";
    CONSTANT ORB210     : STD_LOGIC_VECTOR( 2 DOWNTO 0 ) := "010";
    CONSTANT EORB210    : STD_LOGIC_VECTOR( 2 DOWNTO 0 ) := "011";
    CONSTANT NOTB210    : STD_LOGIC_VECTOR( 2 DOWNTO 0 ) := "100";
BEGIN

    PREGWRACK       <=  REGWRACK;
    PTRCLRACK       <=  TRCLRACK;
    PVRAMWRREQ      <=  VRAMWRREQ WHEN( W_VDPCMD_EN = '1' )ELSE
                        VRAMWRACK;
    PVRAMRDREQ      <=  VRAMRDREQ;
    PVRAMACCESSADDR <=  VRAMACCESSADDR;
    PVRAMWRDATA     <=  VRAMWRDATA;
    PCLR            <=  CLR;
    PCE             <=  CE;
    PBD             <=  BD;
    PTR             <=  TR;
    PSXTMP          <=  SXTMP;

    CUR_VDP_COMMAND <=  CMR( 7 DOWNTO 4 );

    -- R25 CMD BIT
    -- 0 = NORMAL
    -- 1 = VDP COMMAND ON TEXT/GRAPHIC1/GRAPHIC2/GRAPHIC3/MOSAIC MODE
    W_VDPCMD_EN <=  (VDPMODEGRAPHIC7 OR REG_R25_CMD) WHEN( (VDPMODEGRAPHIC4 OR VDPMODEGRAPHIC5 OR VDPMODEGRAPHIC6) = '0' )ELSE
                    (VDPMODEGRAPHIC4 OR VDPMODEGRAPHIC5 OR VDPMODEGRAPHIC6);

    PROCESS( RESET, CLK21M )
        VARIABLE INITIALIZING: STD_LOGIC;
        VARIABLE NXCOUNT : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE XCOUNTDELTA : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE YCOUNTDELTA : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE NXLOOPEND : STD_LOGIC;
        VARIABLE DYEND : STD_LOGIC;
        VARIABLE SYEND : STD_LOGIC;
        VARIABLE NYLOOPEND : STD_LOGIC;
        VARIABLE NX_MINUS_ONE : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE RDXLOW : STD_LOGIC_VECTOR(1 DOWNTO 0);
        VARIABLE RDPOINT : STD_LOGIC_VECTOR(7 DOWNTO 0);
        VARIABLE COLMASK : STD_LOGIC_VECTOR(7 DOWNTO 0);
        VARIABLE MAXXMASK : STD_LOGIC_VECTOR(1 DOWNTO 0);
        VARIABLE LOGOPDESTCOL : STD_LOGIC_VECTOR(7 DOWNTO 0);
        VARIABLE GRAPHIC4_OR_6 : STD_LOGIC;
        VARIABLE SRCHEQRSLT : STD_LOGIC;
        VARIABLE VDPVRAMACCESSY : STD_LOGIC_VECTOR(9 DOWNTO 0);
        VARIABLE VDPVRAMACCESSX : STD_LOGIC_VECTOR(8 DOWNTO 0);
    BEGIN
        IF (RESET = '1') THEN
            STATE <= STIDLE;    -- VERY IMPORTANT FOR XILINX SYNTHESIS TOOL(XST)
            INITIALIZING := '0';
            NXCOUNT := (OTHERS => '0');
            NXLOOPEND := '0';
            XCOUNTDELTA := (OTHERS => '0');
            YCOUNTDELTA := (OTHERS => '0');
            COLMASK := (OTHERS => '1');
            RDXLOW := "00";
            SX <= (OTHERS => '0');  -- R32
            SY <= (OTHERS => '0');  -- R34
            DX <= (OTHERS => '0');  -- R36
            DY <= (OTHERS => '0');  -- R38
            NX <= (OTHERS => '0');  -- R40
            NY <= (OTHERS => '0');  -- R42
            CLR <= (OTHERS => '0'); -- R44
            MM  <= '0'; -- R45 BIT 0
            EQ  <= '0'; -- R45 BIT 1
            DIX <= '0'; -- R45 BIT 2
            DIY <= '0'; -- R45 BIT 3
--          MXS <= '0'; -- R45 BIT 4
--          MXD <= '0'; -- R45 BIT 5
            CMR <= (OTHERS => '0'); -- R46
            SXTMP <= (OTHERS => '0');
            DXTMP <= (OTHERS => '0');
            CMRWR <= '0';
            REGWRACK <= '0';
            VRAMWRREQ <= '0';
            VRAMRDREQ <= '0';
            VRAMWRDATA <= (OTHERS => '0');

            TR <= '1'; -- TRANSFER READY
            CE <= '0'; -- COMMAND EXECUTING
            BD <= '0'; -- BORDER COLOR FOUND
            TRCLRACK <= '0';
            VDPVRAMACCESSY := (OTHERS => '0');
            VDPVRAMACCESSX := (OTHERS => '0');
            VRAMACCESSADDR <= (OTHERS => '0');
        ELSIF (CLK21M'EVENT AND CLK21M = '1') THEN
            IF( (VDPMODEGRAPHIC4 = '1') OR (VDPMODEGRAPHIC6 = '1') ) THEN
                GRAPHIC4_OR_6 := '1';
            ELSE
                GRAPHIC4_OR_6 := '0';
            END IF;


            CASE CMR(7 DOWNTO 6) IS
                WHEN "11" =>
                    -- BYTE COMMAND
                    IF( GRAPHIC4_OR_6 = '1' ) THEN
                        -- GRAPHIC4,6 (SCREEN 5, 7)
                        NXCOUNT := "0" & NX(9 DOWNTO 1);
                        IF (DIX = '0') THEN
                            XCOUNTDELTA := "00000000010"; -- +2
                        ELSE
                            XCOUNTDELTA := "11111111110"; -- -2
                        END IF;
                    ELSIF( VDPMODEGRAPHIC5 = '1' ) THEN
                        -- GRAPHIC5 (SCREEN 6)
                        NXCOUNT := "00" & NX(9 DOWNTO 2);
                        IF (DIX = '0') THEN
                            XCOUNTDELTA := "00000000100"; -- +4
                        ELSE
                            XCOUNTDELTA := "11111111100"; -- -4;
                        END IF;
                    ELSE
                        -- GRAPHIC7 (SCREEN 8) AND OTHER
                        NXCOUNT := NX;
                        IF (DIX = '0') THEN
                            XCOUNTDELTA := "00000000001"; -- +1
                        ELSE
                            XCOUNTDELTA := "11111111111"; -- -1
                        END IF;
                    END IF;
                    COLMASK := (OTHERS => '1');
                WHEN OTHERS =>
                    -- DOT COMMAND
                    NXCOUNT := NX;
                    IF (DIX = '0') THEN
                        XCOUNTDELTA := "00000000001"; -- +1;
                    ELSE
                        XCOUNTDELTA := "11111111111"; -- -1;
                    END IF;
                    IF (GRAPHIC4_OR_6 = '1') THEN
                        COLMASK := "00001111";
                    ELSIF (VDPMODEGRAPHIC5 = '1') THEN
                        COLMASK := "00000011";
                    ELSE
                        COLMASK := (OTHERS => '1');
                    END IF;
            END CASE;

            IF (DIY = '0') THEN
                YCOUNTDELTA := "0000000001";
            ELSE
                YCOUNTDELTA := "1111111111";
            END IF;


            IF (VDPMODEISHIGHRES = '1') THEN
                -- GRAPHIC 5,6 (SCREEN 6, 7)
                MAXXMASK := "10";
            ELSE
                MAXXMASK := "01";
            END IF;

            -- DETERMINE IF X-LOOP IS FINISHED
            CASE CMR(7 DOWNTO 4) IS
                WHEN HMMV | HMMC | LMMV | LMMC =>
                    IF ((NXTMP = 0) OR
                            ((DXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK)) THEN
                        NXLOOPEND := '1';
                    ELSE
                        NXLOOPEND := '0';
                    END IF;
                WHEN YMMM =>
                    IF ((DXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK) THEN
                        NXLOOPEND := '1';
                    ELSE
                        NXLOOPEND := '0';
                    END IF;
                WHEN HMMM | LMMM =>
                    IF ((NXTMP = 0) OR
                            ((SXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK) OR
                            ((DXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK)) THEN
                        NXLOOPEND := '1';
                    ELSE
                        NXLOOPEND := '0';
                    END IF;
                WHEN LMCM =>
                    IF ((NXTMP = 0) OR
                            ((SXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK)) THEN
                        NXLOOPEND := '1';
                    ELSE
                        NXLOOPEND := '0';
                    END IF;
                WHEN SRCH =>
                    IF ((SXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK) THEN
                        NXLOOPEND := '1';
                    ELSE
                        NXLOOPEND := '0';
                    END IF;
                WHEN OTHERS =>
                    NXLOOPEND := '1';
            END CASE;

            -- RETRIEVE THE 'POINT' OUT OF THE BYTE THAT WAS MOST RECENTLY READ
            IF (GRAPHIC4_OR_6 = '1') THEN
                -- SCREEN 5, 7
                IF( RDXLOW(0) = '0' ) THEN
                    RDPOINT := "0000" & VRAMRDDATA(7 DOWNTO 4);
                ELSE
                    RDPOINT := "0000" & VRAMRDDATA(3 DOWNTO 0);
                END IF;
            ELSIF (VDPMODEGRAPHIC5 = '1') THEN
                -- SCREEN 6
                CASE RDXLOW IS
                    WHEN "00" =>
                        RDPOINT := "000000" & VRAMRDDATA(7 DOWNTO 6);
                    WHEN "01" =>
                        RDPOINT := "000000" & VRAMRDDATA(5 DOWNTO 4);
                    WHEN "10" =>
                        RDPOINT := "000000" & VRAMRDDATA(3 DOWNTO 2);
                    WHEN OTHERS =>
--                  WHEN "11" =>
                        RDPOINT := "000000" & VRAMRDDATA(1 DOWNTO 0);
--                  WHEN OTHERS =>
--                      NULL; -- SHOULD NEVER OCCUR
                END CASE;
            ELSE
                -- SCREEN 8 AND OTHER MODES
                RDPOINT := VRAMRDDATA;
            END IF;

            -- PERFORM LOGICAL OPERATION ON MOST RECENTLY READ POINT AND
            -- ON THE POINT TO BE WRITTEN.
            IF ((CMR(3) = '0') OR ((VRAMWRDATA AND COLMASK) /= "00000000")) THEN
                CASE CMR(2 DOWNTO 0) IS
                    WHEN IMPB210 =>
                        LOGOPDESTCOL := (VRAMWRDATA AND COLMASK);
                    WHEN ANDB210 =>
                        LOGOPDESTCOL := (VRAMWRDATA AND COLMASK) AND RDPOINT;
                    WHEN ORB210 =>
                        LOGOPDESTCOL := (VRAMWRDATA AND COLMASK) OR RDPOINT;
                    WHEN EORB210 =>
                        LOGOPDESTCOL := (VRAMWRDATA AND COLMASK) XOR RDPOINT;
                    WHEN NOTB210 =>
                        LOGOPDESTCOL := NOT (VRAMWRDATA AND COLMASK);
                    WHEN OTHERS =>
                        LOGOPDESTCOL := RDPOINT;
                END CASE;
            ELSE
                LOGOPDESTCOL := RDPOINT;
            END IF;

            -- PROCESS REGISTER UPDATE REQUEST, CLEAR 'TRANSFER READY' REQUEST
            -- OR PROCESS ANY ONGOING COMMAND.
            IF( REGWRREQ /= REGWRACK ) THEN
                REGWRACK <= NOT REGWRACK;
                CASE REGNUM IS
                    WHEN "0000" =>      -- #32
                        SX(7 DOWNTO 0) <= REGDATA;
                    WHEN "0001" =>      -- #33
                        SX(8) <= REGDATA(0);
                    WHEN "0010" =>      -- #34
                        SY(7 DOWNTO 0) <= REGDATA;
                    WHEN "0011" =>      -- #35
                        SY(9 DOWNTO 8) <= REGDATA(1 DOWNTO 0);
                    WHEN "0100" =>      -- #36
                        DX(7 DOWNTO 0) <= REGDATA;
                    WHEN "0101" =>      -- #37
                        DX(8) <= REGDATA(0);
                    WHEN "0110" =>      -- #38
                        DY(7 DOWNTO 0) <= REGDATA;
                    WHEN "0111" =>      -- #39
                        DY(9 DOWNTO 8) <= REGDATA(1 DOWNTO 0);
                    WHEN "1000" =>      -- #40
                        NX(7 DOWNTO 0) <= REGDATA;
                    WHEN "1001" =>      -- #41
                        NX(9 DOWNTO 8) <= REGDATA(1 DOWNTO 0);
                    WHEN "1010" =>      -- #42
                        NY(7 DOWNTO 0) <= REGDATA;
                    WHEN "1011" =>      -- #43
                        NY(9 DOWNTO 8) <= REGDATA(1 DOWNTO 0);
                    WHEN "1100" =>      -- #44
                        IF (CE = '1') THEN
                            CLR <= REGDATA AND COLMASK;
                        ELSE
                            CLR <= REGDATA;
                        END IF;
                        TR <= '0'; -- DATA IS TRANSFERRED FROM CPU TO VDP COLOR REGISTER
                    WHEN "1101" =>      -- #45
                        MM  <= REGDATA(0);
                        EQ  <= REGDATA(1);
                        DIX <= REGDATA(2);
                        DIY <= REGDATA(3);
--                      MXD <= REGDATA(5);
                    WHEN "1110" =>      -- #46
                        -- INITIALIZE THE NEW COMMAND
                        -- NOTE THAT THIS WILL ABORT ANY ONGOING COMMAND!
                        CMR <= REGDATA;
                        CMRWR <= W_VDPCMD_EN;
                        STATE <= STIDLE;
                    WHEN OTHERS =>
                        NULL;
                END CASE;
            ELSIF( TRCLRREQ /= TRCLRACK ) THEN
                -- RESET THE DATA TRANSFER REGISTER (CPU HAS JUST READ THE COLOR REGISTER)
                TRCLRACK <= NOT TRCLRACK;
                TR <= '0';
            ELSE
                -- PROCESS THE VDP COMMAND STATE
                CASE STATE IS
                    WHEN STIDLE =>
                        IF( CMRWR = '0' ) THEN
                            CE <= '0';
                            CE <= '0';
                        ELSE
                            -- EXEC NEW VDP COMMAND
                            CMRWR <= '0';
                            CE <= '1';
                            BD <= '0';
                            IF CMR(7 DOWNTO 4) = LINE THEN
                                -- LINE COMMAND REQUIRES SPECIAL SXTMP AND NXTMP SET-UP
                                NX_MINUS_ONE := NX - 1;
                                SXTMP <= "00" & NX_MINUS_ONE(9 DOWNTO 1);
                                NXTMP <= (OTHERS => '0');
                            ELSE
                                IF CMR(7 DOWNTO 4) = YMMM THEN
                                    -- FOR YMMM, SXTMP = DXTMP = DX
                                    SXTMP <= "00" & DX;
                                ELSE
                                    -- FOR ALL OTHERS, SXTMP IS BUSINES AS USUAL
                                    SXTMP <= "00" & SX;
                                END IF;
                                -- NXTMP IS BUSINESS AS USUAL FOR ALL BUT THE LINE COMMAND
                                NXTMP <= NXCOUNT;
                            END IF;
                            DXTMP <= '0' & DX;
                            INITIALIZING := '1';
                            STATE <= STCHKLOOP;
                        END IF;

                    WHEN STRDCPU =>
                        -- APPLICABLE TO HMMC, LMMC
                        IF (TR = '0') THEN
                            -- CPU HAS TRANSFERRED DATA TO (OR FROM) THE COLOR REGISTER
                            TR <= '1';  -- VDP IS READY TO RECEIVE THE NEXT TRANSFER.
                            VRAMWRDATA <= CLR;
                            IF (CMR(6) = '0') THEN
                                -- IT IS LMMC
                                STATE <= STPRERDVRAM;
                            ELSE
                                -- IT IS HMMC
                                STATE <= STWRVRAM;
                            END IF;
                        END IF;

                    WHEN STWAITCPU =>
                        -- APPLICABLE TO LMCM
                        IF( TR  = '0' ) THEN
                            -- CPU HAS TRANSFERRED DATA FROM (OR TO) THE COLOR REGISTER
                            -- VDP MAY READ THE NEXT VALUE INTO THE COLOR REGISTER
                            STATE <= STRDVRAM;
                        END IF;

                    WHEN STRDVRAM =>
                        -- APPLICABLE TO YMMM, HMMM, LMCM, LMMM, SRCH, POINT
                        VDPVRAMACCESSY := SY;
                        VDPVRAMACCESSX := SXTMP(8 DOWNTO 0);
                        RDXLOW := SXTMP(1 DOWNTO 0);
                        VRAMRDREQ <= NOT VRAMRDACK;
                        CASE CMR(7 DOWNTO 4) IS
                            WHEN POINT =>
                                STATE <= STPOINTWAITRDVRAM;
                            WHEN SRCH =>
                                STATE <= STSRCHWAITRDVRAM;
                            WHEN OTHERS =>
                                STATE <= STWAITRDVRAM;
                         END CASE;

                    WHEN STPOINTWAITRDVRAM =>
                        -- APPLICABLE TO POINT
                        IF ( VRAMRDREQ = VRAMRDACK ) THEN
                            CLR <= RDPOINT;
                            STATE <= STEXECEND;
                        END IF;

                    WHEN STSRCHWAITRDVRAM =>
                        -- APPLICABLE TO SRCH
                        IF ( VRAMRDREQ = VRAMRDACK ) THEN
                            IF (RDPOINT = CLR) THEN
                                 SRCHEQRSLT := '0';
                             ELSE
                                 SRCHEQRSLT := '1';
                             END IF;
                             IF (EQ = SRCHEQRSLT) THEN
                                 BD <= '1';
                                 STATE <= STEXECEND;
                             ELSE
                                 SXTMP <= SXTMP + XCOUNTDELTA;
                                 STATE <= STSRCHCHKLOOP;
                             END IF;
                         END IF;

                    WHEN STWAITRDVRAM =>
                        -- APPLICABLE TO YMMM, HMMM, LMCM, LMMM
                        IF ( VRAMRDREQ = VRAMRDACK ) THEN
                            SXTMP <= SXTMP + XCOUNTDELTA;
                            CASE CMR(7 DOWNTO 4) IS
                                WHEN LMMM =>
                                    VRAMWRDATA <= RDPOINT;
                                    STATE <= STPRERDVRAM;
                                WHEN LMCM =>
                                    CLR <= RDPOINT;
                                    TR <= '1';
                                    NXTMP <= NXTMP - 1;
                                    STATE <= STCHKLOOP;
                                WHEN OTHERS => -- REMAINING: YMMM, HMMM
                                    VRAMWRDATA <= VRAMRDDATA;
                                    STATE <= STWRVRAM;
                            END CASE;
                        END IF;

                    WHEN STPRERDVRAM =>
                        -- APPLICABLE TO LMMC, LMMM, LMMV, LINE, PSET
                        VDPVRAMACCESSY := DY;
                        VDPVRAMACCESSX := DXTMP(8 DOWNTO 0);
                        RDXLOW := DXTMP(1 DOWNTO 0);
                        VRAMRDREQ <= NOT VRAMRDACK;
                        STATE <= STWAITPRERDVRAM;

                    WHEN STWAITPRERDVRAM =>
                        -- APPLICABLE TO LMMC, LMMM, LMMV, LINE, PSET
                        IF ( VRAMRDREQ = VRAMRDACK ) THEN
                            IF (GRAPHIC4_OR_6 = '1') THEN
                                -- SCREEN 5, 7
                                IF( RDXLOW(0) = '0' ) THEN
                                    VRAMWRDATA <= LOGOPDESTCOL(3 DOWNTO 0) & VRAMRDDATA(3 DOWNTO 0);
                                ELSE
                                    VRAMWRDATA <= VRAMRDDATA(7 DOWNTO 4) & LOGOPDESTCOL(3 DOWNTO 0);
                                END IF;
                            ELSIF (VDPMODEGRAPHIC5 = '1') THEN
                                -- SCREEN 6
                                CASE RDXLOW IS
                                    WHEN "00" =>
                                        VRAMWRDATA <= LOGOPDESTCOL(1 DOWNTO 0) & VRAMRDDATA(5 DOWNTO 0);
                                    WHEN "01" =>
                                        VRAMWRDATA <= VRAMRDDATA(7 DOWNTO 6) & LOGOPDESTCOL(1 DOWNTO 0) & VRAMRDDATA(3 DOWNTO 0);
                                    WHEN "10" =>
                                        VRAMWRDATA <= VRAMRDDATA(7 DOWNTO 4) & LOGOPDESTCOL(1 DOWNTO 0) & VRAMRDDATA(1 DOWNTO 0);
                                    WHEN OTHERS =>
--                                  WHEN "11" =>
                                        VRAMWRDATA <= VRAMRDDATA(7 DOWNTO 2) & LOGOPDESTCOL(1 DOWNTO 0);
--                                  WHEN OTHERS =>
--                                      NULL; -- SHOULD NEVER OCCUR
                                END CASE;
                            ELSE
                                -- SCREEN 8 AND OTHER MODES
                                VRAMWRDATA <= LOGOPDESTCOL;
                            END IF;
                            STATE <= STWRVRAM;
                        END IF;

                    WHEN STWRVRAM =>
                        -- APPLICABLE TO HMMC, YMMM, HMMM, HMMV, LMMC, LMMM, LMMV, LINE, PSET
                        VDPVRAMACCESSY := DY;
                        VDPVRAMACCESSX := DXTMP(8 DOWNTO 0);
                        VRAMWRREQ <= NOT VRAMWRACK;
                        STATE <= STWAITWRVRAM;

                    WHEN STWAITWRVRAM =>
                        -- APPLICABLE TO HMMC, YMMM, HMMM, HMMV, LMMC, LMMM, LMMV, LINE, PSET
                        IF ( VRAMWRREQ = VRAMWRACK ) THEN
                            CASE CMR(7 DOWNTO 4) IS
                                WHEN PSET =>
                                    STATE <= STEXECEND;
                                WHEN LINE =>
                                    SXTMP <= SXTMP - NY;
                                    IF MM = '0' THEN
                                        DXTMP <= DXTMP + XCOUNTDELTA(9 DOWNTO 0);
                                    ELSE
                                        DY <= DY + YCOUNTDELTA;
                                    END IF;
                                    STATE <= STLINENEWPOS;
                                WHEN OTHERS =>
                                    DXTMP <= DXTMP + XCOUNTDELTA(9 DOWNTO 0);
                                    NXTMP <= NXTMP - 1;
                                    STATE <= STCHKLOOP;
                            END CASE;
                        END IF;

                    WHEN STLINENEWPOS =>
                        -- APPLICABLE TO LINE
                        IF (SXTMP(10) = '1') THEN
                            SXTMP <= '0' & (SXTMP(9 DOWNTO 0) + NX);
                            IF (MM = '0') THEN
                                DY <= DY + YCOUNTDELTA;
                            ELSE
                                DXTMP <= DXTMP + XCOUNTDELTA(9 DOWNTO 0);
                            END IF;
                        END IF;
                        STATE <= STLINECHKLOOP;

                    WHEN STLINECHKLOOP =>
                        -- APPLICABLE TO LINE
                        IF ((NXTMP = NX) OR
                                ((DXTMP(9 DOWNTO 8) AND MAXXMASK) = MAXXMASK)) THEN
                            STATE <= STEXECEND;
                        ELSE
                            VRAMWRDATA <= CLR;
                            -- COLOR MUST BE RE-MASKED, JUST IN CASE THAT SCREENMODE WAS CHANGED
                            CLR <= CLR AND COLMASK;
                            STATE <= STPRERDVRAM;
                        END IF;
                        NXTMP <= NXTMP + 1;

                    WHEN STSRCHCHKLOOP =>
                        -- APPLICABLE TO SRCH
                        IF (NXLOOPEND = '1') THEN
                            STATE <= STEXECEND;
                        ELSE
                            -- COLOR MUST BE RE-MASKED, JUST IN CASE THAT SCREENMODE WAS CHANGED
                            CLR <= CLR AND COLMASK;
                            STATE <= STRDVRAM;
                        END IF;

                    WHEN STCHKLOOP =>
                        -- WHEN INITIALIZING = '1':
                        --   APPLICABLE TO ALL COMMANDS
                        -- WHEN INITIALIZING = '0':
                        -- APPLICABLE TO HMMC, YMMM, HMMM, HMMV, LMMC, LMCM, LMMM, LMMV

                        -- DETERMINE NYLOOPEND
                        DYEND := '0';
                        SYEND := '0';
                        IF (DIY = '1') THEN
                            IF ((DY = 0) AND (CMR(7 DOWNTO 4) /= LMCM)) THEN
                                DYEND := '1';
                            END IF;
                            IF ((SY = 0) AND (CMR(5) /= CMR(4))) THEN
                                -- BIT5 /= BIT4 IS TRUE FOR COMMANDS YMMM, HMMM, LMCM, LMMM
                                SYEND := '1';
                            END IF;
                        END IF;
                        IF ((NY = 1) OR (DYEND = '1') OR (SYEND = '1')) THEN
                            NYLOOPEND := '1';
                        ELSE
                            NYLOOPEND := '0';
                        END IF;

                        IF ((INITIALIZING = '0') AND (NXLOOPEND = '1') AND (NYLOOPEND = '1')) THEN
                            STATE <= STEXECEND;
                        ELSE
                            -- COMMAND NOT YET FINISHED OR COMMAND INITIALIZING. DETERMINE NEXT/FIRST STEP
                            -- COLOR MUST BE (RE-)MASKED, JUST IN CASE THAT SCREENMODE WAS CHANGED
                            CLR <= CLR AND COLMASK;
                            CASE CMR(7 DOWNTO 4) IS
                                WHEN HMMC =>
                                    STATE <= STRDCPU;
                                WHEN YMMM =>
                                    STATE <= STRDVRAM;
                                WHEN HMMM =>
                                    STATE <= STRDVRAM;
                                WHEN HMMV =>
                                    VRAMWRDATA <= CLR;
                                    STATE <= STWRVRAM;
                                WHEN LMMC =>
                                    STATE <= STRDCPU;
                                WHEN LMCM =>
                                    STATE <= STWAITCPU;
                                WHEN LMMM =>
                                    STATE <= STRDVRAM;
                                WHEN LMMV | LINE | PSET =>
                                    VRAMWRDATA <= CLR;
                                    STATE <= STPRERDVRAM;
                                WHEN SRCH =>
                                    STATE <= STRDVRAM;
                                WHEN POINT =>
                                    STATE <= STRDVRAM;
                                WHEN OTHERS =>
                                    STATE <= STEXECEND;
                            END CASE;
                        END IF;
                        IF( (INITIALIZING = '0') AND (NXLOOPEND = '1') ) THEN
                            NXTMP <= NXCOUNT;
                            IF CMR(7 DOWNTO 4) = YMMM THEN
                                SXTMP <= "00" & DX;
                            ELSE
                                SXTMP <= "00" & SX;
                            END IF;
                            DXTMP <= '0' & DX;
                            NY <= NY - 1;
                            IF (CMR(5) /= CMR(4)) THEN
                                -- BIT5 /= BIT4 IS TRUE FOR COMMANDS YMMM, HMMM, LMCM, LMMM
                                SY <= SY + YCOUNTDELTA;
                            END IF;
                            IF (CMR(7 DOWNTO 4) /= LMCM) THEN
                                DY <= DY + YCOUNTDELTA;
                            END IF;
                        ELSE
                            SXTMP(10) <= '0';
                        END IF;
                        INITIALIZING := '0';
                    WHEN OTHERS =>
                        STATE <= STIDLE;
                        CE <= '0';
                        CMR <= (OTHERS => '0');
                END CASE;
            END IF;

            IF( VDPMODEGRAPHIC4 = '1' )THEN
                VRAMACCESSADDR <= VDPVRAMACCESSY(9 DOWNTO 0) & VDPVRAMACCESSX(7 DOWNTO 1);
            ELSIF( VDPMODEGRAPHIC5  = '1' )THEN
                VRAMACCESSADDR <= VDPVRAMACCESSY(9 DOWNTO 0) & VDPVRAMACCESSX(8 DOWNTO 2);
            ELSIF( VDPMODEGRAPHIC6  = '1' )THEN
                VRAMACCESSADDR <= VDPVRAMACCESSY(8 DOWNTO 0) & VDPVRAMACCESSX(8 DOWNTO 1);
            ELSE
                VRAMACCESSADDR <= VDPVRAMACCESSY(8 DOWNTO 0) & VDPVRAMACCESSX(7 DOWNTO 0);
            END IF;

        END IF;
    END PROCESS;
END RTL;
