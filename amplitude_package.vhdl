library ieee;
use ieee.std_logic_1164.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers;

--! @brief 1 channel at a time amplitude computation
--!
--! During each lower level frame, the amplitude of 1 channel
--!   is computed.
--! For each computation, it takes
--!   * the volume
--!   * the normalized requested amplitude
--! For each computation, it produces
--!   * The actual amplitude
--! For resources optimisations
--!   * the multiplication is made using successive additions
--!     if the corresponding bit of the other operand is '1'
--!   * the output is modified to be close to the range 0 to rail.
--!     ** the product N.M has its result on N+M bits
--!     ** M is used to performed or not the addition
--!     ** N is placed into a M length signal descending
--!        starting at the high minus 1
--!     ** since M'length + N'length > N'length + 1,
--!        the low rest is barrel shifted from the high of N

package Amplitude_pac is

  component Amplitude_multiplier is
    generic (
      --! Does not impact anything.
      --! It is only to notice the relevance of the computation 
      DAC_cycles : integer range 10 to 40;
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

  end component Amplitude_multiplier;
  
end package Amplitude_pac;
