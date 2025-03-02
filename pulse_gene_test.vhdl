library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Pulses_pac.all;

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
  signal state_out           : std_logic_vector(3 downto 0);
  signal priv_counter_in     : std_logic_vector(10 downto 0)                 := (others        => '0');
  signal priv_counter_out    : std_logic_vector(10 downto 0)                 := (others        => '0');
  signal priv_counter_loaded : boolean                                       := false;
  signal req_amplitude       : std_logic_vector(size_amplitude - 1 downto 0) := ("111", others => '0');
  signal out_amplitude       : std_logic_vector(size_amplitude - 1 downto 0);
  signal polar_pos_not_neg   : std_logic;
begin
  RST <= state_id(state_id'high);

  -- The entity under test is a pure combinatory
  state_proc : process is
  begin
    end_sim : if state_id /= "100000" then
      if CLK = '1' then
        priv_counter_loaded <= priv_counter_out = std_logic_vector(to_unsigned(0, priv_counter_out'length));
        priv_counter_in     <= priv_counter_out;
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
      polar_pos_not_neg => polar_pos_not_neg,
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
      priv_state_in    => std_logic_vector(state_id(state_id'low + 3 downto state_id'low)),
      priv_counter_in  => priv_counter_in,
      state_out        => state_out,
      priv_counter_out => priv_counter_out
      );
end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.Pulses_pac.all;

entity Pulses_sequencer_test is
  generic (
    chans_number : integer range 2 to 300 := 4;
    DAC_cycles   : integer range 10 to 40 := 35
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
      chans_number     => chans_number,
      DAC_cycles       => DAC_cycles,
      has_extra_RAM_op => false
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

