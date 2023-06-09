--
-- ram.vhd
--   256 bytes of block memory
--   Revision 1.00
--
-- Copyright (c) 2006 Kazuhiro Tsujikawa (ESE Artists' factory)
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ram is
  port (
    adr     : in  std_logic_vector(7 downto 0);
    clk     : in  std_logic;
    we      : in  std_logic;
    dbo     : in  std_logic_vector(7 downto 0);
    dbi     : out std_logic_vector(7 downto 0)
  );
end ram;

architecture RTL of ram is
  type typram is array (255 downto 0) of std_logic_vector(7 downto 0);
  signal blkram : typram;
  signal iadr   : std_logic_vector(7 downto 0);

  begin

  process (clk)
  begin
    if (clk'event and clk ='1') then
      if (we = '1') then
        blkram(conv_integer(adr)) <= dbo;
      end if;
      iadr <= adr;
    end if;
  end process;

  dbi <= blkram(conv_integer(iadr));

end RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ram10 is
  port (
    adr     : in  std_logic_vector(7 downto 0);
    clk     : in  std_logic;
    we      : in  std_logic;
    dbo     : in  std_logic_vector(9 downto 0);
    dbi     : out std_logic_vector(9 downto 0)
  );
end ram10;

architecture RTL of ram10 is
  type typram is array (255 downto 0) of std_logic_vector(9 downto 0);
  signal blkram : typram;
  signal iadr   : std_logic_vector(7 downto 0);

  begin

  process (clk)
  begin
    if (clk'event and clk ='1') then
      if (we = '1') then
        blkram(conv_integer(adr)) <= dbo;
      end if;
      iadr <= adr;
    end if;
  end process;

  dbi <= blkram(conv_integer(iadr));

end RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity palette_rb is
  port (
    adr     : in  std_logic_vector(7 downto 0);
    clk     : in  std_logic;
    we      : in  std_logic;
    dbo     : in  std_logic_vector(7 downto 0);
    dbi     : out std_logic_vector(7 downto 0)
  );
end palette_rb;

architecture RTL of palette_rb is
  type typram is array (0 to 255) of std_logic_vector(0 to 7);
  signal blkram : typram :=
(
x"00",x"00",x"11",x"33",x"26",x"37",x"52",x"27",x"62",x"63",x"52",x"63",x"11",x"55",x"55",x"77",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00"

);
  signal iadr   : std_logic_vector(7 downto 0);

  begin

  process (clk)
  begin
    if (clk'event and clk ='1') then
      if (we = '1') then
        blkram(conv_integer(adr)) <= dbo;
      end if;
      iadr <= adr;
    end if;
  end process;

  dbi <= blkram(conv_integer(iadr));

end RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity palette_g is
  port (
    adr     : in  std_logic_vector(7 downto 0);
    clk     : in  std_logic;
    we      : in  std_logic;
    dbo     : in  std_logic_vector(7 downto 0);
    dbi     : out std_logic_vector(7 downto 0)
  );
end palette_g;

architecture RTL of palette_g is
  type typram is array (0 to 255) of std_logic_vector(0 to 7);
  signal blkram : typram :=
(
x"00",x"00",x"05",x"06",x"02",x"03",x"02",x"06",x"02",x"03",x"05",x"06",x"04",x"02",x"05",x"07",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00"

);
  signal iadr   : std_logic_vector(7 downto 0);

  begin

  process (clk)
  begin
    if (clk'event and clk ='1') then
      if (we = '1') then
        blkram(conv_integer(adr)) <= dbo;
      end if;
      iadr <= adr;
    end if;
  end process;

  dbi <= blkram(conv_integer(iadr));

end RTL;
