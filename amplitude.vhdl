library ieee;
use ieee.std_logic_1164.all;

entity Amplitude_multiplier is
  generic (
    --! Does not impact anything.
    --! It is only to notice the relevance of the computation 
    DAC_cycles      : integer range 10 to 40;
    --! Does not impact anything.
    --! It is only to notice the relevance of the computation 
    Channels_number : integer range 2 to 300
    );
  port (
    --! Master clock
    CLK    : in  std_logic;
    RST    : in  std_logic;
    EN     : in  std_logic;
    N      : in  std_logic_vector;
    M      : in  std_logic_vector;
    --! Output. the length should not be greater than
    --!   the N'length + M'length
    theOut : out std_logic_vector);

end entity Amplitude_multiplier;


architecture arch of Amplitude_multiplier is


begin
  assert N'length > 1 report "to run, the N operand vector should have a length of at least 2" severity failure;
  assert M'length > 1 report "to run, the M operand vector should have a length of at least 2" severity failure;
  assert theOut'length > 3 report "to run, the M operand vector should have a length of at least 4" severity failure;
  assert theOut'length <= (N'length + M'length)
                          report " The size of the output (" & integer'image(theOut'length) & ")" &
                          " is bigger than the size of N+M (" & integer'image(N'length) & " and " &
                          integer'image(M'length) & "): irrelevant"
                          severity note;
  assert (DAC_cycles > M'length / 2) or (Channels_number * 8 > M'length / 2)
    report "The system can not process at least the half of the length of M (" & integer'image(M'length) &
    "), it is a non-sense"
    severity error;
  assert (DAC_cycles > M'length) or (Channels_number * 8 > M'length)
    report "The system can not process all the length of M (" & integer'image(M'length) &
    "), some precision is lost"
    severity warning;
  
  
end architecture arch;
