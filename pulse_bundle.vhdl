library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.global_volume_size,
  work.Dac_package.all,
  work.Pulses_pac.all;
--! @brief Handles N pulse channels
--!
--! It bundles all the components of the package.
--! It provides the RAM needed to store the states and the other data.\n
--! 
entity Pulses_bundle is
  generic (
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 22;
    output_offset             : natural := 7
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
end entity Pulses_bundle;

architecture arch of Pulses_bundle is
  --! TODO TODO make the data size dynamic
  signal RST_delayed       : std_logic_vector(2 downto 0);
  --! Subject to move to generic
  constant counter_length  : integer range 2 to 20 := 8;
  signal priv_counter_out  : std_logic_vector(counter_length - 1 downto 0);
  signal priv_amplitude_in : std_logic_vector (15 downto 0);
  constant state_length    : positive              := 4;
  signal priv_state_S_2_A  : std_logic_vector(state_length - 1 downto 0);
  signal priv_polar_S_2_A  : std_logic;
  signal priv_state_out    : std_logic_vector(state_length - 1 downto 0);
  signal priv_polar_out    : std_logic;
--  signal priv_amplitude_new : std_logic_vector(priv_amplitude_in'range);

  constant RAM_data_size : positive := maximum( counter_length + state_length + 1, -- 1 is polar
                                                requested_amplitude_size + global_volume_size );
  constant RAM_padding : std_logic_vector( RAM_data_size - counter_length + state_length + 1 - 1 downto 0 ) :=
    ( others => '-' );
  constant RAM_addr_size : positive := StateNumbers_2_BitsNumbers(channels_number+1);
  signal RAM_addr_high   : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number+1) - 1 downto 0);
  signal RAM_addr_low    : std_logic_vector(0 downto 0);
  type state_RAM_elem is record
    padding : std_logic_vector(priv_amplitude_in'length - state_length - counter_length - 1 - 1
                               downto 0);
    state   : std_logic_vector(3 downto 0);
    polar   : std_logic;
    counter : std_logic_vector(7 downto 0);
  end record state_RAM_elem;
  signal RAM_write_struct     : state_RAM_elem;
  signal RAM_read_struct      : state_RAM_elem;
  signal RAM_unioned          : std_logic_vector(priv_amplitude_in'length - 1 downto 0);
  type RAM_t is array(0 to 2 ** RAM_addr_size) of state_RAM_elem;
  signal the_RAM              : RAM_t;
  signal RAM_read             : std_logic;
  signal RAM_write            : std_logic;
  signal EN_process           : std_logic;
  signal EN                   : std_logic_vector(channels_number - 1 downto 0);
  signal computed_amplitude   : std_logic_vector(requested_amplitude_size + global_volume_size - 1 downto 0);
  signal start_frame          : std_logic;
  signal ready_DAC, ready_SEQ : std_logic;
begin
  assert priv_amplitude_in'length >= (state_length + counter_length)
    report "in this version, the amplitude size should be at least the state size (3) plus the counter size"
    severity error;

  main_proc : process(CLK) is
  begin
    CLK_IF : if rising_edge(CLK) then
      if RST = '1' then
        RST_delayed <= (others => '1');
        start_frame <= '0';
      else
        start_frame <= ready_DAC and ready_SEQ;
      end if;

      R_W_if : if RAM_read = '1' then
        RAM_read_struct <= the_RAM(to_integer(unsigned(RAM_addr_high) & unsigned(RAM_addr_low)));
      elsif RAM_write = '1' then
        the_RAM(to_integer(unsigned(RAM_addr_high) & unsigned(RAM_addr_low))) <= RAM_write_struct;
      elsif EN_process = '1' then
        RST_if : if RST = '0' then
          if RST_delayed /= std_logic_vector(to_unsigned(0, RST_delayed'length)) then
            RST_delayed <= std_logic_vector(unsigned(RST_delayed) - 1);
          end if;
        end if RST_if;

        PROC_if : if RST_delayed /= std_logic_vector(to_unsigned(0, RST_delayed'length)) then
          RAM_write_struct.counter <= priv_counter_out;
          RAM_write_struct.state   <= (others => '0');
          RAM_write_struct.polar   <= '0';
          priv_state_S_2_A         <= (others => '0');
        elsif RAM_addr_low = "0" then
          -- Even words of the RAM
          -- We collect the output of the state machine
          --   to buffer it into the RAM write data.
          RAM_write_struct.padding <= (others => '0');
          RAM_write_struct.counter <= priv_counter_out;
          RAM_write_struct.state   <= priv_state_out;
          RAM_write_struct.polar   <= priv_polar_out;
          -- We collect the state to be used by the pulse amplitude calculator
          priv_state_S_2_A         <= priv_state_out;
          priv_polar_S_2_A         <= priv_polar_out;
        else
          -- Odd words of the RAM
          -- This time, there is a mapping to the data structure
          --   as we don't have the union type
          -- The amplitude is re written as it if
          --   a pulse cycle is currently running
          -- The amplitude is the one supplied, which is ready to be "photographed"
          if priv_state_S_2_A = "0000" then
            -- Wait state or reset, we can accept new amplitude
            RAM_write_struct.padding <= priv_amplitude_new(15 downto 13);
            RAM_write_struct.state   <= priv_amplitude_new(12 downto 9);
            RAM_write_struct.polar   <= priv_amplitude_new(8);
            RAM_write_struct.counter <= priv_amplitude_new(7 downto 0);
          else
            -- Running, keep the old amplitude
            RAM_write_struct <= RAM_read_struct;
          end if;

        end if PROC_if;
      end if R_W_if;
    end if CLK_IF;
  end process main_proc;

  Pulses_sequencer_instanc : Pulses_sequencer
    generic map(
      MasterCLK_SampleCLK_ratio => MasterCLK_SampleCLK_ratio
      )
    port map(
      CLK,
      RST,
      start         => start_frame,
      ready         => ready_SEQ,
      RAM_addr_high => RAM_addr_high,
      RAM_addr_low  => RAM_addr_low,
      RAM_read      => RAM_read,
      RAM_write     => RAM_write,
      EN_process    => EN_process,
      EN            => EN);

-- This runs on the second step of each channel
--   (RAM_addr_low = '1'), then it takes the
--   OUT of the state and the amplitude
--RAM_unioned(15 downto 13) <= RAM_read_struct.padding;
--RAM_unioned(12 downto 9)  <= RAM_read_struct.state;
--RAM_unioned(8 downto 8)  <= RAM_read_struct.polar;
--RAM_unioned(7 downto 0)   <= RAM_read_struct.counter;
  RAM_unioned <= RAM_read_struct.padding & RAM_read_struct.state & RAM_read_struct.polar & RAM_read_struct.counter;

  Pulses_stateMOut_instanc : Pulses_stateMOut
    port map(
      CLK           => CLK,
      RST           => RST,
      req_amplitude => RAM_unioned,
      state         => priv_state_S_2_A,
      out_amplitude => computed_amplitude
      );

  
  Pulses_stateMachine_instanc : Pulses_stateMachine
    generic map (
      separ_pulses => 1,
      pulse_length => 3,
      dead_time    => 4
      )
    port map(
      --! Master clock
      RST              => RST,
      --! Enable: high only once to compute the new state
      start            => start,
      polar_first      => '0',
      priv_state_in    => RAM_read_struct.state,
      priv_polar_in    => RAM_read_struct.polar,
      priv_counter_in  => RAM_read_struct.counter,
      state_out        => priv_state_out,
      priv_polar_out   => priv_polar_out,
      priv_counter_out => priv_counter_out
      );


  DAC_bundle_instanc : DAC_bundle_dummy
    port map (
      CLK,
      polar_pos_not_neg => priv_polar_S_2_A,
      data_in           => computed_amplitude,
      EN                => EN,
      RST_init          => or(RST_delayed),
      start             => start_frame,
      ready             => ready_DAC,
      data_serial       => data_serial,
      CLK_serial        => CLK_serial,
      transfer_serial   => transfer_serial,
      update_serial     => update_serial
      );


end architecture arch;


configuration DAC_default_controler of Pulses_bundle is
  for arch
    for DAC_bundle_instanc : DAC_bundle_dummy
      use entity work.DAC_bundle_real_outputs
        generic map (
          output_offset => output_offset);
    end for;

  end for;
end configuration DAC_default_controler;


