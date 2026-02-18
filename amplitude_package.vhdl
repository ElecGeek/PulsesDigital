library ieee;
use ieee.std_logic_1164.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;


--! @brief 1 channel at a time amplitude computation
--!
--! @anchor amplitude_package_anchor 
--! During each lower level frame, the amplitude of 1 channel is computed,
--!   and stored into the pulse generator, see @ref pulse_gene_package_anchor.\n
--! It takes the requested amplitude and the volume from the volume package,
--!   see @ref volume_package_anchor.\n

--! That is done for one channel during the frame
--!   before the frame that generates all the pulses.
--! Then, the worst case of a volume change in this part of the project
--!   is N+1 frames/samples. the best case is 1.\n

--! The volume package is the storage and the sequencer of the data.

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
  --!   all channels are computed in each super frame).
  type Pulse_amplitude_record is record
    --
    --! TO BE clarified: why channel_numbers + 1
    -- TEMPORARY, the channels number should have a constraint to be at least 2
    -- but for the design investigation, it is faster to run with only 1.
    --! 
    which_channel : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    --! TEMPORARY until the size is dynamic everywhere in the project
    the_amplitude : std_logic_vector(requested_amplitude_size + global_volume_size - 1 downto 0);
  end record Pulse_amplitude_record;

  --! This is temporary for test as the starting is going to be a real package.

  --! These two signal always go together as
  --!   a pulse is always triggered with its polarity.
  --! @anchor Pulse_start_record_anchor
  type Pulse_start_element is record
    enable         : std_logic;
    polarity_first : std_logic;
  end record Pulse_start_element;

  --! All the channels are subject to be triggered at the same time
  type Pulse_start_vector is array(channels_number - 1 downto 0) of Pulse_start_element;

  component Amplitude_multiplier is
    port (
      --! Master clock
      CLK     : in  std_logic;
      --! Strobe. Not really relevant for FPGA, relevant for ASIC
      EN      : in  std_logic;
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


  component amplitude_bundle is
    port (
      CLK                 : in  std_logic;
      RST                 : in  std_logic;
      --! Starts the product
      --! In case of a concurrent run with the volume,
      --!   connect both with start_frame
      --! In case of a serial run after the volume,
      --!   connect to the ready output of the volume
      start_prod          : in  std_logic;
      --! Always connected to the global start frame
      --! It clears the ready output
      start_frame         : in  std_logic;
      which_channel       : in  std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
      requested_amplitude : in  std_logic_vector;
      requested_volume    : in  std_logic_vector;
      ready               : out std_logic;
      pulse_amplitude     : out Pulse_amplitude_record);
  end component amplitude_bundle;


end package Amplitude_package;
