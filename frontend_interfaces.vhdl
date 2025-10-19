library ieee;
use ieee.std_logic_1164.all;

--! Front-ends for segments displays interfaces 
--!
--! There are groups of components in which displays can be chosen.
--! The selection is done using the configure statement.
package frontend_segments_package is
  --! PURE COMBINATORIAL LUT to convert binary to 7 segments
  --!
  component convert_bin_2_7seg is
    port (
      --! The 7 segments can display some letters or some pseudo graphic
      --! In case this feature is used, the high bits are passed here.
      ext_in     : in  std_logic_vector(0 downto 0) := "0";
      --! Input the regular 0 to 9 and A to F
      bin_in     : in  std_logic_vector(3 downto 0);
      --! The decimal point is a part of the 7 segments
      dp_in      : in  std_logic;
      --! Output
      the_output : out std_logic_vector(7 downto 0)
      );
  end component convert_bin_2_7seg;

  --! PURE COMBINATORIAL LUT for testing or other non PCB 7 segments
  --!
  --! This is fully transparent
  component convert_7seg_2_output_default is
    generic (
      common_anode_not_cathode : boolean := false
      );
    port (
      the_input  : in  std_logic_vector;
      the_output : out std_logic_vector
      );
  end component convert_7seg_2_output_default;

  --! PURE COMBINATORIAL LUT to handle some easy PCB
  --!
  --! There are as many architecture as output schema.
  --! It is related to the output mode, the displays and the PCB.
  --! For more information, see in the architectures,
  --seg in  out 595 pin display
  -- a   0   4   3 -> 7
  -- B   1   3   4 -> 6
  -- C   2   1   6 -> 4
  -- D   3   2   5 -> 2
  -- E   4   7  15 -> 1
  -- F   5   5   2 -> 9
  -- G   6   6   1 -> 10
  -- dp  7   0   7 -> 5
  -- The segments in this LUT are in the order
  -- by segments names: E G F A B D C dp
  -- front view
  -- *--4--+
  -- |     |
  -- 5     3
  -- |     |
  -- +--6--+
  -- |     |
  -- 7     1
  -- |     |
  -- +--2--+ 0
  component convert_7seg_2_output_PCBeasy is
    generic (
      common_anode_not_cathode : boolean
      );
    port(
      the_input  : in  std_logic_vector(7 downto 0);
      the_output : out std_logic_vector(7 downto 0)
      );
  end component convert_7seg_2_output_PCBeasy;

  function boolean_2_stdlogic(constant i : boolean) return std_logic;
  
end package frontend_segments_package;

package body frontend_segments_package is
  function boolean_2_stdlogic(constant i : boolean) return std_logic is
  begin
    if i then
      return '1';
    else
      return '0';
    end if;
  end function boolean_2_stdlogic;
end package body frontend_segments_package;

library ieee;
use ieee.std_logic_1164.all;

--! Front-ends for vumeters display interfaces
--!
--! There are groups of components in which displays can be chosen.
--! The selection is done using the configure statement.

package frontend_vumeters_package is

  --! PURE COMBINATORIAL LUT to handle a 3 LEDS dot graph
  --!
  --! The display is intended to check presence of a signal and the saturation.
  --! The green is 100% on at the level 0
  --! The green decreases and the yellow increases from 1 to 3
  --! The yellow is 100% on from level 4 to level 11
  --! The yellow decreases and the red increases from 12 to 14
  --! The red is 100% on at the level 15
  component convert_bin_2_signalsatur_dotgraph is
    port (
      the_input  : in  std_logic_vector(3 downto 0);
      --! PWM input, 4 states to handle 25, 50, 75 or 100%
      pwm_input  : in  std_logic_vector(1 downto 0);
      the_output : out std_logic_vector(2 downto 0)
      );
  end component convert_bin_2_signalsatur_dotgraph;

  
end package frontend_vumeters_package;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;

entity convert_bin_2_7seg is
  port (
    --! The 7 segments can display some letters or some pseudo graphic
    --! In case this feature is used, the high bits are passed here.
    ext_in     : in  std_logic_vector(0 downto 0) := "0";
    --! Input the regular 0 to 9 and A to F
    bin_in     : in  std_logic_vector(3 downto 0);
    --! The decimal point is a part of the 7 segments
    dp_in      : in  std_logic;
    --! Output
    the_output : out std_logic_vector(7 downto 0)
    );
end entity convert_bin_2_7seg;

--! Test 7 segments LuT architecture
--!
--! The extension and the bit 3 of the input are ignored.
--! The bits 2 down to 0 of the input illuminate the segment
--!   according with the value, 0->A 7->G
--! If the DP is 1, all the outputs are inverted.

architecture test of convert_bin_2_7seg is
begin
  main_proc : process(bin_in, dp_in)
    variable tmp : std_logic_vector(7 downto 0);
  begin
    --for ind in 0 to 7 loop
    --  if ind = to_integer(unsigned(bin_in(2 downto 0))) then
    --    the_output := (ind => '1', others => '0');
    --  end if;
    --end loop;
    tmp                                           := (others => '0');
    tmp(to_integer(unsigned(bin_in(2 downto 0)))) := '1';
    the_output                                    <= tmp xor dp_in;
  end process main_proc;

end architecture test;


architecture arch of convert_bin_2_7seg is
  -- an 8 bits vector model is used in order to initialise
  --   using hexadecimal.
  type LUT_7seg_t is array(integer range<>) of std_logic_vector(7 downto 0);
  constant LUT_7seg : LUT_7seg_t(0 to 31) := (
    x"3f", x"06", x"5b", x"4f", x"66", x"6d", x"7d", x"07",  -- 0 1 2 3 4 5 6 7
    x"7f", x"6f", x"77", x"7c", x"39", x"5e", x"79", x"71",  -- 8 9 A B C D E F
    x"3d", x"76", x"1e", x"38", x"54", x"5c", x"73", x"50",  -- G H J L M O P R
    x"07", x"61", x"3e", x"6e",         -- (Tleft) Tright U Y
    x"00", x"08", x"40", x"01"          -- blank -low -mid -high
    );
begin
  main_proc : process(ext_in, bin_in, dp_in)
    variable f : std_logic_vector(ext_in'length + bin_in'length - 1 downto 0);
  begin
    f                      := ext_in & bin_in;
    the_output(6 downto 0) <= LUT_7seg(to_integer(unsigned(f)))(6 downto 0);
    the_output(7)          <= dp_in;
  end process main_proc;
end architecture arch;

library ieee;
use ieee.std_logic_1164.all,
  work.frontend_segments_package.boolean_2_stdlogic;

entity convert_7seg_2_output_default is
  generic (
    common_anode_not_cathode : boolean := false
    );
  port(
    the_input  : in  std_logic_vector;
    the_output : out std_logic_vector
    );
end entity convert_7seg_2_output_default;

architecture arch of convert_7seg_2_output_default is
  constant canc : std_logic := boolean_2_stdlogic(common_anode_not_cathode);
begin
  assert the_input'length = the_output'length report
    "The size of both input vector (" & integer'image(the_output'length) &
    ") and output vector '" & integer'image(the_input'length) &
    ") should be the same"
    severity error;
  assert false report "Using the default 7 segments mapping" severity note;

  the_output <= canc xor the_input;
end architecture arch;

library ieee;
use ieee.std_logic_1164.all,
  work.frontend_segments_package.boolean_2_stdlogic;

entity convert_7seg_2_output_PCBeasy is
  generic (
    common_anode_not_cathode : boolean
    );
  port(
    the_input  : in  std_logic_vector(7 downto 0);
    the_output : out std_logic_vector(7 downto 0)
    );
end entity convert_7seg_2_output_PCBeasy;

--! This is a SPI output using 74HC595, some standard displays
--! and an easy PCB in which the routing is the most easy.
--! One should check against the pin-out of his display
--! For more details, see in the code
architecture arch of convert_7seg_2_output_PCBeasy is
  constant canc : std_logic := boolean_2_stdlogic(common_anode_not_cathode);
begin
  assert false report "Using the PCBeasy 7 segments mapping" severity note;

  the_output(0) <= canc xor the_input(7);  -- DP
  the_output(1) <= canc xor the_input(2);  -- C
  the_output(2) <= canc xor the_input(3);  -- D
  the_output(3) <= canc xor the_input(1);  -- B
  the_output(4) <= canc xor the_input(0);  -- A
  the_output(5) <= canc xor the_input(5);  -- F
  the_output(6) <= canc xor the_input(6);  -- G
  the_output(7) <= canc xor the_input(4);  -- E
end architecture arch;

library ieee;
use ieee.std_logic_1164.all;

entity convert_bin_2_signalsatur_dopgraph is
  port (
    the_input  : in  std_logic_vector(3 downto 0);
    --! PWM input, 4 states to handle 25, 50, 75 or 100%
    pwm_input  : in  std_logic_vector;
    the_output : out std_logic_vector(2 downto 0)
    );
end entity convert_bin_2_signalsatur_dopgraph;

architecture arch of convert_bin_2_signalsatur_dopgraph is
begin
  main_proc : process(the_input, pwm_input)
  begin
    case the_input is
      -- 100% green
      when "0000" => the_output    <= "001";
      -- 75% green 25% yellow
      when "0001" => the_output(2) <= '0';
                     the_output(1) <= and pwm_input(pwm_input'high downto pwm_input'high - 1);
                     the_output(0) <= or (not pwm_input(pwm_input'high downto pwm_input'high - 1));
      -- 50/50
      when "0010" => the_output(2) <= '0';
                     the_output(1) <= pwm_input(pwm_input'high);
                     the_output(0) <= not pwm_input(pwm_input'high);
      -- 75% yellow 25% green
      when "0011" => the_output(2) <= '0';
                     the_output(1) <= or (not pwm_input(pwm_input'high downto pwm_input'high - 1));
                     the_output(0) <= and pwm_input(pwm_input'high downto pwm_input'high - 1);
      -- 75% yellow 25% red
      when "1100" => the_output(2) <= and pwm_input(pwm_input'high downto pwm_input'high - 1);
                     the_output(1) <= or (not pwm_input(pwm_input'high downto pwm_input'high - 1));
                     the_output(0) <= '0';
      -- 50/50
      when "1101" => the_output(2) <= pwm_input(pwm_input'high);
                     the_output(1) <= not pwm_input(pwm_input'high);
                     the_output(0) <= '0';
      -- 25% yellow 75% red
      when "1110" => the_output(2) <= or (not pwm_input(pwm_input'high downto pwm_input'high - 1));
                     the_output(1) <= and pwm_input(pwm_input'high downto pwm_input'high - 1);
                     the_output(0) <= '0';
      -- 100% red
      when "1111" => the_output <= "100";
      -- from 0100 to 1011 100% yellow
      when others => the_output <= "010";
    end case;
  end process main_proc;
  
end architecture arch;


