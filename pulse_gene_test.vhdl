library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Pulses_pac.Pulses_stateMOut,
  work.Pulses_pac.Pulses_stateMachine;


--! @brief Test one pulse state machine using a wave viewer
--!
--! Runs a full elementary pulse generation sequence
--!   contained in a frame.\n
--! It is more intended as a developer test to verify the sequence.
--! Indeed the sequence does not relay on anything else
--!   than waiting a start signal,
--!   and computes a value based on the state only
--!   (not based on the past)

entity Pulses_lowlevel_test is
  generic (
    size_amplitude : integer range 4 to 128 := 16;
    size_ampl_test : integer range 4 to 32  := 4
    );
end entity Pulses_lowlevel_test;

architecture arch of Pulses_lowlevel_test is
  signal CLK                 : std_logic                                     := '1';
  signal RST                 : std_logic;
  signal EN                  : std_logic                                     := '1';
  signal state_id            : unsigned(5 downto 0)                          := ("111101");
  signal state_id_max        : unsigned(state_id'range)                      := ('1', others   => '0');
  signal state_out           : std_logic_vector(3 downto 0);
  signal priv_counter_in     : std_logic_vector(10 downto 0)                 := (others        => '0');
  signal priv_counter_out    : std_logic_vector(10 downto 0)                 := (others        => '0');
  signal priv_polar_in       : std_logic;
  signal priv_polar_out      : std_logic;
  signal priv_counter_loaded : boolean                                       := false;
  signal req_amplitude       : std_logic_vector(size_amplitude - 1 downto 0) := ("111", others => '0');
  signal out_amplitude       : std_logic_vector(size_amplitude - 1 downto 0);
begin
  RST <= state_id(state_id'high);

  -- The entity under test is a pure combinatorial
  state_proc : process is
  begin
    end_sim : if state_id /= state_id_max then
      if CLK = '1' then
        priv_counter_loaded <= priv_counter_out = std_logic_vector(to_unsigned(0, priv_counter_out'length));
        priv_counter_in     <= priv_counter_out;
        priv_polar_in       <= priv_polar_out;
        if priv_counter_loaded or RST = '1' then
          state_id <= state_id + 1;
        end if;
      end if;
      CLK <= not CLK;
      wait for 1 ps;
    else
      wait;
    end if end_sim;
  end process state_proc;

  Pulses_stateMOut_instanc : Pulses_stateMOut
    port map(
      CLK           => CLK,
      RST           => RST,
      req_amplitude => req_amplitude,
      state         => std_logic_vector(state_id(state_id'low + 3 downto state_id'low)),
      out_amplitude => out_amplitude
      );

  Pulses_stateMachine_instanc : Pulses_stateMachine
    generic map (
      separ_pulses => 2,
      pulse_length => 3,
      dead_time    => 4
      )
    port map(
      RST              => RST,
      --! Enable: high only once to compute the new state
      start_pulse      => '1',
      polar_first      => '0',
      priv_state_in    => std_logic_vector(state_id(state_id'low + 3 downto state_id'low)),
      priv_counter_in  => priv_counter_in,
      priv_polar_in    => priv_polar_in,
      state_out        => state_out,
      priv_counter_out => priv_counter_out,
      priv_polar_out   => priv_polar_out
      );
end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number,
  work.Pulses_pac.pulses_sequencer;

--! @brief Test one full frame generating the pulses using a wave viewer
--!
--! Runs the state machine for each channel.\n
--! Handles the RAM that stores data from the previous frame
--!   and to the next frame.\n
--! TODO integrate the pulses and compare to the theoretical results
--!   and issue the result using the assertions note or assertion error.\n

entity Pulses_sequencer_test is
  generic (
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 35
    );
end entity Pulses_sequencer_test;

architecture arch of Pulses_sequencer_test is
  signal CLK           : std_logic                    := '1';
  signal RST           : std_logic_vector(4 downto 0) := (others => '1');
  signal start         : std_logic;
  signal ready         : std_logic;
  signal counter       : unsigned(6 downto 0)         := (others => '0');
  constant counter_max : unsigned(counter'range)      := (others => '1');
  signal RAM_addr_high : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number+1) - 1 downto 0);
  signal RAM_addr_low  : std_logic_vector(0 downto 0);
  signal RAM_read      : std_logic;
  signal RAM_write     : std_logic;
  signal EN_process    : std_logic;
  signal EN            : std_logic_vector(channels_number - 1 downto 0);

begin
  start <= ready;
  
  state_proc : process is
  begin
    end_sim : if counter /= counter_max then
      if CLK = '1' then
        RST(RST'high - 1 downto RST'low) <= RST(RST'high downto RST'low+1);
        RST(RST'high)                    <= '0';
        counter                          <= counter + 1;
      end if;
      CLK <= not CLK;
      wait for 1 ps;
    else
      wait;
    end if end_sim;
  end process state_proc;

  Pulses_sequencer_instanc : Pulses_sequencer
    generic map(
      MasterCLK_SampleCLK_ratio => MasterCLK_SampleCLK_ratio,
      has_extra_RAM_op          => false
      )
    port map(
      CLK           => CLK,
      RST           => RST(RST'low),
      start_frame   => start,
      ready         => ready,
      RAM_addr_high => RAM_addr_high,
      RAM_addr_low  => RAM_addr_low,
      RAM_read      => RAM_read,
      RAM_write     => RAM_write,
      EN_process    => EN_process,
      EN            => EN);

end architecture arch;


