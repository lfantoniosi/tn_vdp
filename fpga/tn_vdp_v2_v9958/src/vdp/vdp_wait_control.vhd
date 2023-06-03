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
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"19E4", X"0F30",
        X"10F8", X"1288", X"8000", X"8000", X"119C", X"1964", X"1590", X"8000"
    );
    -- Sprite On, 192 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_502 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"18C8", X"0E80",
        X"1018", X"11B4", X"8000", X"8000", X"10B0", X"1848", X"1514", X"8000"
    );
    -- Sprite Off, 212 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_503 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1678", X"0A10",
        X"0CE4", X"10AC", X"8000", X"8000", X"0CA8", X"15F8", X"1520", X"8000"
    );
    -- Sprite Off, 192 Lines, 50Hz
    CONSTANT C_WAIT_TABLE_504 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"15B8", X"0A00",
        X"0C78", X"0FFC", X"8000", X"8000", X"0C5C", X"1538", X"144C", X"8000"
    );
    -- Blank, 50Hz (Test: Sprite On, 212 Lines)
    CONSTANT C_WAIT_TABLE_505 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"13C4", X"08D4",
        X"0CC4", X"0E68", X"8000", X"8000", X"0CAC", X"1384", X"12DC", X"8000"
    );
    ---------------------------------------------------------------------------
    --   "STOP",  "XXXX",  "XXXX",  "XXXX", "POINT",  "PSET",  "SRCH",  "LINE",
    --   "LMMV",  "LMMM",  "LMCM",  "LMMC",  "HMMV",  "HMMM",  "YMMM",  "HMMC"
    ---------------------------------------------------------------------------
    -- Sprite On, 212 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_601 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1AC4", X"10F0",
        X"13DC", X"15B4", X"8000", X"8000", X"14CC", X"1A44", X"182C", X"8000"
    );
    -- Sprite On, 192 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_602 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"18E4", X"0FC0",
        X"1274", X"1424", X"8000", X"8000", X"1318", X"1864", X"16FC", X"8000"
    );
    -- Sprite Off, 212 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_603 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1674", X"0AB0",
        X"0E24", X"12B4", X"8000", X"8000", X"0DFC", X"15F4", X"17B4", X"8000"
    );
    -- Sprite Off, 192 Lines, 60Hz
    CONSTANT C_WAIT_TABLE_604 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1564", X"0A40",
        X"0D7C", X"11AC", X"8000", X"8000", X"0D58", X"14E4", X"167C", X"8000"
    );
    -- Blank, 60Hz (Test: Sprite On, 212 Lines)
    CONSTANT C_WAIT_TABLE_605 : WAIT_TABLE_T :=(
        X"8000", X"8000", X"8000", X"8000", X"8000", X"8000", X"1278", X"08F0",
        X"0D58", X"0EFC", X"8000", X"8000", X"0D38", X"11F8", X"13D4", X"8000"
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
