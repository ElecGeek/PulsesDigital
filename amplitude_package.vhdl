library ieee;
use ieee.std_logic_1164.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers;

--! @brief 1 channel at a time amplitude computation
--!
--! During each lower level frame, the amplitude of 1 channel
--!   is computed.\n
--! Since the pulse length is dozen of low level frames,
--!   this latency is not an issue.\n
--! For each computation, it takes
--!   * the volume
--!   * the normalized requested amplitude
--! For each computation, it produces
--!   * The actual amplitude.\n
--! For resources optimisations
--!   * the multiplication is made using successive additions
--!     if the corresponding bit of the other operand is '1'
--!   * the output is slightly modified to be close to the range 0 to rail.
--!     For more information, see in the entity.

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
      --! Output. A length greater than N'length + M'length
      --! is irrelevant
      theOut : out std_logic_vector);

  end component Amplitude_multiplier;
  
end package Amplitude_pac;
