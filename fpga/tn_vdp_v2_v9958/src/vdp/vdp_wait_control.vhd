--
-- vdp_wait_control.vhd
--   VDP wait controller for VDP command
--   Revision 1.00
--
-- Copyright (c) 2008 Takayuki Hara
-- All rights reserved.
--
-- Redistribution and use of this source code or any derivative works, are
-- permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Redistributions may not be sold, nor may they be used in a commercial
--    product or activity without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
-- OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
-- OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- Revision History
--
-- 2nd,Jun,2021 modified by KdL
--  - LMMV is reverted to previous speed in accordance with current VDP module
--
-- 9th,Jan,2020 modified by KdL
--  - LMMV fix which improves the Sunrise logo a bit (temporary solution?)
--    Some glitches appear to be unrelated to the VDP_COMMAND entity and
--    the correct speed is not yet reached
--
-- 20th,May,2019 modified by KdL
--  - Optimization of speed parameters for greater game compatibility
--
-- 14th,May,2018 modified by KdL
--  - Improved the speed accuracy of SRCH, LINE, LMMV, LMMM, HMMV, HMMM and YMMM
--  - Guidelines at http://map.grauw.nl/articles/vdp_commands_speed.php
--
--  - Some evaluation tests:
--    - overall duration of the SPACE MANBOW game intro at 3.58MHz
--    - uncorrupted music in the FRAY game intro at 3.58MHz, 5.37MHz and 8.06MHz
--    - amount of artifacts in the BREAKER game at 5.37MHz
--

LIBRARY IEEE;
    USE IEEE.STD_LOGIC_1164.ALL;
    USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY VDP_WAIT_CONTROL IS
    PORT(
        RESET           : IN    STD_LOGIC;
        CLK21M          : IN    STD_LOGIC;

        VDP_COMMAND     : IN    STD_LOGIC_VECTOR(  7 DOWNTO  4 );

        VDPR9PALMODE    : IN    STD_LOGIC;      -- 0=60Hz (NTSC), 1=50Hz (PAL)
        REG_R1_DISP_ON  : IN    STD_LOGIC;      -- 0=Display Off, 1=Display On
        REG_R8_SP_OFF   : IN    STD_LOGIC;      -- 0=Sprite On, 1=Sprite Off
        REG_R9_Y_DOTS   : IN    STD_LOGIC;      -- 0=192 Lines, 1=212 Lines

        VDPSPEEDMODE    : IN    STD_LOGIC;
        DRIVE           : IN    STD_LOGIC;

        ACTIVE          : OUT   STD_LOGIC
    );
END VDP_WAIT_CONTROL;

ARCHITECTURE RTL OF VDP_WAIT_CONTROL IS

    SIGNAL FF_WAIT_CNT  : STD_LOGIC_VECTOR( 15 DOWNTO  0 );

    TYPE WAIT_TABLE_T IS ARRAY(  0 TO 15 ) OF STD_LOGIC_VECTOR( 15 DOWNTO  0 );
    ---------------------------------------------------------------------------
    --   "STOP",  "XXXX",  "XXXX",  "XXXX", "POINT",  "PSET",  "SRCH",  "LINE",
    --   "LMMV",  "LMMM",  "LMCM",  "LMMC",  "HMMV",  "HMMM",  "YMMM",  "HMMC"
    ---------------------------------------------------------------------------
    -- Sprite On, 212 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_501 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1498", X"0C14",
X"0D7F", X"0EBD", X"8000", X"8000", X"0E01", X"1432", X"1126", X"8000"
    );
    -- Sprite On, 192 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_502 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"13B6", X"0B88",
X"0CCD", X"0E15", X"8000", X"8000", X"0D46", X"1350", X"10C4", X"8000"
    );
    -- Sprite Off, 212 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_503 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"11DF", X"0801",
X"0A41", X"0D43", X"8000", X"8000", X"0A11", X"1179", X"10CD", X"8000"
    );
    -- Sprite Off, 192 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_504 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1146", X"07F4",
X"09EB", X"0CB7", X"8000", X"8000", X"09D4", X"10E0", X"1025", X"8000"
    );
    -- Blank, 50Hz (Test: Sprite On, 212 Lines)
    CONSTANT C_WAIT_TABLE_505 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"0FB9", X"0705",
X"0A27", X"0B75", X"8000", X"8000", X"0A14", X"0F86", X"0F00", X"8000"
    );
    ---------------------------------------------------------------------------
    --   "STOP",  "XXXX",  "XXXX",  "XXXX", "POINT",  "PSET",  "SRCH",  "LINE",
    --   "LMMV",  "LMMM",  "LMCM",  "LMMC",  "HMMV",  "HMMM",  "YMMM",  "HMMC"
    ---------------------------------------------------------------------------
    -- Sprite On, 212 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_601 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"154A", X"0D79",
X"0FCC", X"1143", X"8000", X"8000", X"108B", X"14E4", X"133A", X"8000"
    );
    -- Sprite On, 192 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_602 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"13CC", X"0C87",
X"0EAD", X"1005", X"8000", X"8000", X"0F30", X"1366", X"1248", X"8000"
    );
    -- Sprite Off, 212 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_603 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"11DC", X"0880",
X"0B3F", X"0EE0", X"8000", X"8000", X"0B1F", X"1176", X"12DA", X"8000"
    );
    -- Sprite Off, 192 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_604 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1103", X"0827",
X"0AB9", X"0E0E", X"8000", X"8000", X"0A9D", X"109E", X"11E2", X"8000"
    );
    -- Blank, 60Hz (Test: Sprite On, 212 Lines)
    CONSTANT C_WAIT_TABLE_605 : WAIT_TABLE_T :=(
X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"0EB0", X"071C",
X"0A9D", X"0BEB", X"8000", X"8000", X"0A83", X"0E4B", X"0FC5", X"8000"
    );
BEGIN

    PROCESS( RESET, CLK21M )
    BEGIN
        IF( CLK21M'EVENT AND CLK21M = '1' )THEN
            IF( RESET = '1' )THEN
                FF_WAIT_CNT <= (OTHERS => '0');
            ELSE
                IF( DRIVE = '1' )THEN
                    -- 50Hz (PAL)
                    IF( VDPR9PALMODE = '1' )THEN
                        -- Display On
                        IF( REG_R1_DISP_ON = '1' )THEN
                            -- Sprite On
                            IF( REG_R8_SP_OFF = '0' )THEN
                                -- 212 Lines
                                IF( REG_R9_Y_DOTS = '1' )THEN
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_501( CONV_INTEGER( VDP_COMMAND ) );
                                -- 192 Lines
                                ELSE
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_502( CONV_INTEGER( VDP_COMMAND ) );
                                END IF;
                            -- Sprite Off
                            ELSE
                                -- 212 Lines
                                IF( REG_R9_Y_DOTS = '1' )THEN
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_503( CONV_INTEGER( VDP_COMMAND ) );
                                -- 192 Lines
                                ELSE
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_504( CONV_INTEGER( VDP_COMMAND ) );
                                END IF;
                            END IF;
                        -- Display Off (Blank)
                        ELSE
                            FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_505( CONV_INTEGER( VDP_COMMAND ) );
                        END IF;
                    -- 60Hz (NTSC)
                    ELSE
                        -- Display On
                        IF( REG_R1_DISP_ON = '1' )THEN
                            -- Sprite On
                            IF( REG_R8_SP_OFF = '0' )THEN
                                -- 212 Lines
                                IF( REG_R9_Y_DOTS = '1' )THEN
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_601( CONV_INTEGER( VDP_COMMAND ) );
                                -- 192 Lines
                                ELSE
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_602( CONV_INTEGER( VDP_COMMAND ) );
                                END IF;
                            -- Sprite Off
                            ELSE
                                -- 212 Lines
                                IF( REG_R9_Y_DOTS = '1' )THEN
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_603( CONV_INTEGER( VDP_COMMAND ) );
                                -- 192 Lines
                                ELSE
                                    FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_604( CONV_INTEGER( VDP_COMMAND ) );
                                END IF;
                            END IF;
                        -- Display Off (Blank)
                        ELSE
                            FF_WAIT_CNT <= ('0' & FF_WAIT_CNT(14 DOWNTO  0)) + C_WAIT_TABLE_605( CONV_INTEGER( VDP_COMMAND ) );
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ACTIVE <= FF_WAIT_CNT(15) OR VDPSPEEDMODE;
END RTL;
