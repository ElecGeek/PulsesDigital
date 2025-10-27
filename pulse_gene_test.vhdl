library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Pulses_pac.Pulses_stateMOut,
  work.Pulses_pac.Pulses_stateMachine;

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
  signal priv_polar_out       : std_logic;
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
      CLK               => CLK,
      RST               => RST,
      req_amplitude     => req_amplitude,
      state             => std_logic_vector(state_id(state_id'low + 3 downto state_id'low)),
      out_amplitude     => out_amplitude
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
      start            => '1',
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
  work.Pulses_pac.pulses_sequencer;

entity Pulses_sequencer_test is
  generic (
    chans_number              : integer range 2 to 300 := 4;
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 35
    );
end entity Pulses_sequencer_test;

architecture arch of Pulses_sequencer_test is
  signal CLK           : std_logic                    := '1';
  signal RST           : std_logic_vector(4 downto 0) := (others => '1');
  signal counter       : unsigned(6 downto 0)         := (others => '0');
  constant counter_max : unsigned(counter'range)      := (others => '1');
  signal RAM_addr_high : std_logic_vector(StateNumbers_2_BitsNumbers(chans_number+1) - 1 downto 0);
  signal RAM_addr_low  : std_logic_vector(0 downto 0);
  signal RAM_read      : std_logic;
  signal RAM_write     : std_logic;
  signal EN_process    : std_logic;
  signal EN            : std_logic_vector(chans_number - 1 downto 0);
  signal EN_out        : std_logic;

begin

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
      chans_number              => chans_number,
      MasterCLK_SampleCLK_ratio => MasterCLK_SampleCLK_ratio,
      has_extra_RAM_op          => false
      )
    port map(
      CLK           => CLK,
      RST           => RST(RST'low),
      RAM_addr_high => RAM_addr_high,
      RAM_addr_low  => RAM_addr_low,
      RAM_read      => RAM_read,
      RAM_write     => RAM_write,
      EN_process    => EN_process,
      EN            => EN,
      EN_out        => EN_out);

end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.Pulses_pac.pulses_bundle;
--! @brief Handles N pulse channels
--!
--! It bundles all the components of the package.
--! It provides the RAM needed to store the states and the other data.\n
--! 
entity Pulses_bundle_test is
  generic (
    chans_number              : integer range 2 to 300 := 4;
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 22
    );
end entity Pulses_bundle_test;

architecture arch of Pulses_bundle_test is
  signal pulses_counter      : unsigned(4 downto 0)            := (others        => '0');
  signal pulses_counter_max  : unsigned(pulses_counter'range)  := ('1', others   => '0');
  signal samples_counter     : unsigned(7 downto 0)            := (others        => '0');
  signal samples_counter_max : unsigned(samples_counter'range) := (others        => '1');
  signal DAC_counter         : unsigned(4 downto 0)            := (others        => '0');
  signal DAC_counter_max     : unsigned(DAC_counter'range)     := ("111", others => '0');
  signal RST                 : std_logic_vector(2 downto 0)    := (others        => '1');
  signal CLK                 : std_logic                       := '0';
  signal start_pulse         : std_logic;
  signal data_out            : std_logic_vector(chans_number - 1 downto 0);
  signal transfer            : std_logic_vector(3 downto 0);
begin
  main_proc : process is
  begin
    PULSES_COUNT_IF : if pulses_counter /= pulses_counter_max then
      CLK <= not CLK;
      CLK_IF : if CLK = '0' then
        DAC_IF : if DAC_counter /= DAC_counter_max then
          DAC_counter <= DAC_counter + 1;
        else
          start_pulse                      <= '0';
          DAC_counter                      <= (others => '0');
          RST(RST'high)                    <= '0';
          RST(RST'high - 1 downto RST'low) <= RST(RST'high downto RST'low + 1);
          samples_if : if samples_counter /= samples_counter_max then
            samples_counter <= samples_counter + 1;
            start_pulse     <= '0';
          else
            samples_counter <= (others=>'0');
            pulses_counter <= pulses_counter + 1;
            start_pulse    <= '1';
          end if samples_if;
        end if DAC_IF;
      end if CLK_IF;
      wait for 1 ps;
    else
      wait;
    end if PULSES_COUNT_IF;
  end process main_proc;

  Pulses_bundle_instanc : Pulses_bundle
    generic map(
      chans_number              => 4,
      MasterCLK_SampleCLK_ratio => 22
      )
    port map(
      --! Master clock
      CLK                => CLK,
      RST                => RST(RST'low),
      start              => start_pulse,
--! TEMPORARY
      priv_amplitude_new => ("011", others=>'0'),
      --! TODO set the inputs amplitude and the volume
      data_out           => data_out,
      transfer           => transfer
      );


end architecture arch;
