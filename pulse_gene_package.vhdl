library ieee;
use ieee.std_logic_1164.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers;

--! @brief N channels pulses generator
--!
--! Each channel is intended to run with a dedicated 2 output DAC.\n
--! One output is for the positive part of the pulse,
--!   the other is for the negative part.\n
--! For each channel, it takes
--!   * a starting signal
--!   * a pulse amplitude
--! For each channel, it produces
--!   * the transfer
--!   * the serial data\n
--! For resources optimization, it is designed to run the channels
--!   one after the other, with some pipelines in some components.\n
--! The pulse amplitude output comes from the level up.
--! It is the "product" of the required amplitude by the volume.\n
--! To optimize the verification effort,
--!   the amplitude is passed using parallel, one channel per frame.
--!   the starting is passed using parallel, one bit per channel.
package Pulses_pac is
  --! @brief State machine to generate one pulse
  --!
  --! Gets the state, the start signal and produces the new state
  --! This is a pure combinatorial process
  --! The bundeler is responsible to latch the result
  component Pulses_stateMachine is
    --! State machine
    --!
    --! The machine inputs the private state (per channel) and the start.
    --! It should be stored from the previous sample without any modification.\n
    --! The machine outputs the new state.
    --! It is used both to be stored for the next sample and
    --!   to be used to generate the output.
    generic (
      separ_pulses : positive := 1;
      pulse_length : positive := 10;
      dead_time    : positive := 50
      );
    port (
      RST              : in  std_logic;
      --! Enable: high only once to compute the new state
      start            : in  std_logic;
      --! First pulse is negative not positive
      polar_first      : in  std_logic;
      --! From the output of the previous sample without any modification.
      priv_state_in    : in  std_logic_vector(3 downto 0);
      --! From the output of the previous sample without any modification.
      priv_polar_in    : in  std_logic;
      --! From the output of the previous sample without any modification.
      priv_counter_in  : in  std_logic_vector;
      --! Current state to generate the output value and to be stored.
      state_out        : out std_logic_vector(3 downto 0);
      --! Current polarity to be passed to the DAC and to be stored
      priv_polar_out   : out std_logic;
      --! Internal counter to be stored only.
      priv_counter_out : out std_logic_vector
      );
  end component Pulses_stateMachine;

--! @brief State machine to compute one pulse
--!
--! Gets the state the requested value and produces the pulse output\n
--! It can be parallel
--!   in such case there is a latency of one DAC update
--! It can be placed after the state machine run.
--!    in such case, more latches are required.
  component Pulses_stateMOut is
    port (
      --! Master clock
      CLK               : in  std_logic;
      RST               : in  std_logic;
      --! Enable: high only once to compute the new state
      req_amplitude     : in  std_logic_vector;
      state             : in  std_logic_vector(3 downto 0);
      --! Tells which polarity has to be update
      out_amplitude     : out std_logic_vector
      );
  end component Pulses_stateMOut;

  --! @brief Handles all the internal controls and RAM addresses
  --!
  --! The design is optimized for global safety and validation efforts
  --!   rather than large number of channels.
  --! It is compatible with many implementations of RAM,
  --!   designed using many tools, see in the entity.\n 
  --! The assume is all the DAC are serial, needing a command and the data.\n
  --! That means a clock frequency of about 20 to 30 times the sampling rate
  --!   is required.
  --! Then there a time to "slowly" process the pulse generation.\n
  --! The latency is not an issue as well, see in the entity.\n
  --! The sequence is:
  --!   * make a first read at address 2 * channel number
  --!   * wait one cycle
  --!   * process the state machine
  --!   * write back to that address
  --!   * make a second read at this address + 1
  --!   * wait one cycle
  --!   * handles the amplitude
  --!     * in wait mode if the channel number matches, collect it
  --!     * otherwise keep the one found in the RAM
  --!   * process the DAC values according with the pulse amplitude
  --!   * write back to that address and enable the relevant DAC component
  --!   * repeat until all the channels are processed
  --!   * send a one cycle global enable to the DACs
  --!     to transfer into their working registers
  --!   * in case the serial DACs need more cycles, do nothing
  --!   * loop
  component Pulses_sequencer is
    generic (
      chans_number              : integer range 2 to 300 := 4;
      MasterCLK_SampleCLK_ratio : integer range 10 to 40;
      --! Does one more RAM operation.
      --! This is set by the bundle, and should be modified
      has_extra_RAM_op          : boolean                := false
      );
    port (
      --! Master clock
      CLK           : in  std_logic;
      RST           : in  std_logic;
      --!
      start         : in  std_logic;
      --! The frame is over
      ready         : out std_logic;
      --! Addr to be concatenated with the low. Should only be passed to the RAM.
      RAM_addr_high : out std_logic_vector(StateNumbers_2_BitsNumbers(chans_number+1) - 1 downto 0);
      --! Addr to be concatenated with the high. Tells which data is performed.
      RAM_addr_low  : out std_logic_vector(0 downto 0);
      RAM_read      : out std_logic;
      RAM_write     : out std_logic;
      --! Active between the read and the write of the RAM,
      --!   in the second step (addr_low = '1')
      EN_process    : out std_logic;
      --! Enables one DAC wrapper
      EN            : out std_logic_vector(chans_number - 1 downto 0));
  end component Pulses_sequencer;

--! @brief Handles N pulse channels
--!
--! It bundles all the components of the package.
--! It provides the RAM needed to store the states and the other data.\n
--! TODO document the commands
  component Pulses_bundle is
    generic (
      chans_number              : integer range 2 to 300 := 4;
      MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 24
      );
    port (
      --! Master clock
      CLK                : in  std_logic;
      RST                : in  std_logic;
      start              : in  std_logic;
--! TEMPORARY
      priv_amplitude_new : in  std_logic_vector (15 downto 0);
      --! TODO set the inputs amplitude and the volume
    data_serial        : out std_logic_vector;
    CLK_serial         : out std_logic_vector;
    transfer_serial    : out std_logic_vector;
    update_serial      : out std_logic_vector
      );
  end component Pulses_bundle;


end package Pulses_pac;

