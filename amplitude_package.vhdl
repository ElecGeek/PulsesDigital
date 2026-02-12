library ieee;
use ieee.std_logic_1164.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;

--! @brief 1 channel at a time amplitude computation
--!
--! @anchor amplitude_package_anchor
--! During each lower level frame, the amplitude of 1 channel is computed.
--! At the end of a super frame, all the channels are computed.
--!   Since the pulse length is dozen of low level frames,
--!   this latency is not an issue.\n
--! During each lower level frame, the volume of the requested channel is computed.
--! Since these two tasks are concurent, the new volume is not available
--!   in case the requested channel is the same than the actual amplitude channel.\n
--! Then, the worst case of a volume change request is N+1 frames/samples.
--!   the best case is 1.\n
--! For each computation, it takes
--!   * the volume modification request.
--!   * the normalized requested amplitude.
--! For each computation, it produces
--!   * The actual volume in BCD mode.
--!   * The actual amplitude.\n
--! For resources optimizations
--!   * the multiplication is made using successive additions
--!     if the corresponding bit of the other operand is '1'
--!   * The RAM is a basic one without multiple accesses.
--!     During the time the multiplication is computed,
--!     the volume is updated and stored in the RAM.\n
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

  --! These two signals always go together as
  --!   only one amplitude is computed per frame.
  --! (The amplitude should be linked to the channel and
  --!   all channels are compuited in each super frame).
  type Pulse_amplitude_record is record
  --
    --! TO BE clarified: why channel_numbers + 1
    -- TEMPORARY, the channels number should have a constraint to be at least 2
    -- but for the design investigation, it is faster to run with only 1.
    --! 
    which_channel  : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    --! TEMPORARY until the size is dynamic everywhere in the project
    the_amplitude  : std_logic_vector( 15 downto 0 );
  end record Pulse_amplitude_record;
  
  --! These two signal always go together as
  --!   a pulse is always triggered with its polarity.
  --! @anchor Pulse_start_record_anchor
  type Pulse_start_element is record
    enable         : std_logic;
    polarity_first : std_logic;
  end record Pulse_start_element;

  --! All the channels are subject to be trigered at the same time
  type Pulse_start_record is array( channels_number - 1 downto 0 ) of Pulse_start_element;
  
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

  component Amplitude_sequencer is
    port (
      CLK :  in std_logic );
  end component Amplitude_sequencer;

  component amplitude_bundle is
    port (
      CLK              : in  std_logic;
      pulse_start_data : out Pulse_start_record);
  end component amplitude_bundle;
    
  
end package Amplitude_package;
