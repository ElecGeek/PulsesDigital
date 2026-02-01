library ieee;
use ieee.numeric_std.all;

package Test_utils is

  --! @brief Accelerates the test while keeping only the relevant values
  --!
  --! It tests samples of value including the low and the high values.
  --! That tests the values at the limits and some value in between.
  --! A low number of bits vector has to be provided,
  --!   the high bits are copied to the high bits of the output,
  --!   the low bits are copied to the low bits of the output,
  --!   the remaining bit in between is duplicated to
  --!   the remaining central output bits.
  component Test_Accelerator is
    generic (
      left_bits  : positive := 2;
      right_bits : positive := 2);
    port (
      the_input  : in  unsigned(left_bits + right_bits + 1 - 1 downto 0);
      the_output : out unsigned);
  end component Test_Accelerator;

end package Test_utils;


library ieee;
use ieee.numeric_std.all;

entity Test_Accelerator is
  generic (
    left_bits  : positive := 2;
    right_bits : positive := 2);
  port (
    the_input  : in  unsigned(left_bits + right_bits + 1 - 1 downto 0);
    the_output : out unsigned);
end entity Test_Accelerator;

architecture arch of Test_Accelerator is

begin

  assert left_bits + right_bits + 1 <= the_output'length report
    "The size of the output (" & integer'image( the_output'length ) &
    ") should be at least the size of the left (" & integer'image( left_bits ) &
    ") plus the size of the right (" & integer'image( right_bits ) &
    ") plus 1"  severity FAILURE;

  main_proc : process( the_input ) is
    variable filler : unsigned( the_output'length - left_bits - right_bits - 1 downto 0 );
    begin
      filler := ( others => the_input( the_input'low + right_bits )); 
      the_output <=
        ( the_input( the_input'high downto the_input'high - left_bits + 1 ),
          filler,
          the_input( the_input'low + right_bits - 1 downto the_input'low )
        );
    end process main_proc;

end architecture arch;
