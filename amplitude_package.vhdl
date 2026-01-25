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
--! For resources optimizations
--!   * the multiplication is made using successive additions
--!     if the corresponding bit of the other operand is '1'
--!   * TODO the output is slightly modified to be close to the range 0 to rail.
--!     For more information, see in the entity.
--! The propagation delays of the carry should be able to handle
--!   a vector with a size of the sum requested_amplitude_size plus global_volume_size.

package Amplitude_package is
  --! This work around is going to be used until I install a version of GHDL
  --! that fixes the 3102 issue.
  constant requested_amplitude_size : integer range 2 to 100 := 10;
  constant global_volume_size       : integer range 2 to 100 := 6; 
  --! generic (
  --!     requested_amplitude_size    : integer range 2 to 100 := 4;
  --!     constant global_volume_size : integer range 2 to 100 := 4
  --! );
  
  component Amplitude_multiplier is
    generic (
      --! Does not impact anything.
      --! It is only to notice the relevance of the computation 
      MasterCLK_SampleCLK_ratio      : integer range 10 to 100
      );
    port (
      --! Master clock
      CLK     : in  std_logic;
      --! Loads new operands, otherwise computes
      load    : in  std_logic;
      --! Executes the rail to rail correction
      --! if load = 0 only
      --! If executed too early, the result is less corrected (but valid)
      execR2R : in  std_logic;
      M       : in  std_logic_vector;
      N       : in  std_logic_vector;
      --! The value grows as long as there are 1 bits in N
      --! The value remains if there are no more 1 bits in N
      theOut  : out std_logic_vector);

  end component Amplitude_multiplier;
  
end package Amplitude_package;
