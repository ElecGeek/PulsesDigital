library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;


--! @brief State machine to generate one pulse
--!
--! Gets the state, the start signal and produces the new state
--! 
entity Pulses_stateMachine is
  generic (
    --! Delay between the positive and the negative pulse (or vice versa).
    --! It should be at least one to send a 0 in case of a totem-pole output.
    --! For more information, see in the DAC package.
    separ_pulses : positive := 1;
    pulse_length : positive := 10;
    --! Delay before the next pulse.
    --! It should be at least one to send a 0 in case of a totem-pole output.
    --! The delay is always larger for other reasons.
    dead_time    : positive := 50
    );
  port (
    RST              : in  std_logic;
    --! Enable: high only once to compute the new state
    start_pulse      : in  std_logic;
    polar_first      : in  std_logic;
    priv_state_in    : in  std_logic_vector(3 downto 0);
    priv_polar_in    : in  std_logic;
    priv_counter_in  : in  std_logic_vector;
    state_out        : out std_logic_vector(3 downto 0);
    priv_polar_out   : out std_logic;
    priv_counter_out : out std_logic_vector
    );
end entity Pulses_stateMachine;

architecture arch of Pulses_stateMachine is
  constant counter_reset : std_logic_vector(priv_counter_out'range) := (others => '0');
begin
-- State variable definition
  -- 0000 : wait for start, 0 negative
  -- 0001 : 1/4 positive
  -- 0010 : 1/2 positive
  -- 0011 : 3/4 positive
  -- 0100 : full positive, wait for counter
  -- 0101 : 3/4 positive
  -- 0110 : 1/2 positive
  -- 0111 : 1/4 positive
  -- 1000 : 0 positive, wait for separ_count
  -- 1001 : 1/4 negative
  -- 1010 : 1/2 negative
  -- 1011 : 3/4 negative
  -- 1100 : full negative, wait for counter
  -- 1101 : 3/4 negative
  -- 1110 : 1/2 negative
  -- 1111 : 1/4 negative

  state_proc : process(RST, start_pulse, polar_first, priv_state_in, priv_polar_in, priv_counter_in) is
  begin
    STATE_CASE : case priv_state_in(1 downto 0) is
      when "00" =>
        if RST = '1' then
          -- Go to the next state to set all the DAC to 0
          state_out        <= "0001";
          priv_counter_out <= counter_reset;
          priv_polar_out <= '0';
        elsif priv_counter_in = std_logic_vector(to_unsigned(0, priv_counter_in'length)) then
          -- The counter is 0
          if priv_state_in(3 downto 2) /= "00" then
            -- Got to the next state
            state_out(1 downto 0) <= "01";
            if priv_state_in(3 downto 2) = "10" then
              priv_polar_out <= not priv_polar_in;
            else
              priv_polar_out <= priv_polar_in;
            end if;
          elsif start_pulse = '1' then
            -- Ready and the start is requested
            state_out(1 downto 0) <= "01";
            priv_polar_out        <= polar_first;
          else
            -- Wait
            state_out(1 downto 0) <= "00";
            priv_polar_out        <= priv_polar_in;
          end if;
          state_out(3 downto 2) <= priv_state_in(3 downto 2);
          priv_counter_out      <= priv_counter_in;
        else
          -- The counter is not 0, wait (and decrease)
          state_out        <= priv_state_in;
          priv_counter_out <= std_logic_vector(unsigned(priv_counter_in) - 1);
          priv_polar_out   <= priv_polar_in;
        end if;
      when "01" | "10" =>
        state_out(3 downto 2) <= priv_state_in(3 downto 2);
        state_out(1 downto 0) <= std_logic_vector(unsigned(priv_state_in(1 downto 0)) + 1);
        priv_counter_out      <= priv_counter_in;
        priv_polar_out        <= priv_polar_in;
      when others =>
        -- Use others, rather than 11 to allow the start-up while simulating
        state_out(1 downto 0) <= "00";
        -- Load the counter among 3, according with the state
        if priv_state_in(3 downto 2) = "00" then
          state_out(3 downto 2) <= std_logic_vector(unsigned(priv_state_in(3 downto 2)) + 1);
          priv_counter_out      <= std_logic_vector(to_unsigned(pulse_length - 1, priv_counter_out'length));
        elsif priv_state_in(3 downto 2) = "10" then
          state_out(3 downto 2) <= std_logic_vector(unsigned(priv_state_in(3 downto 2)) + 1);
          priv_counter_out      <= std_logic_vector(to_unsigned(pulse_length - 1, priv_counter_out'length));
        elsif priv_state_in(3 downto 2) = "01" then
          state_out(3 downto 2) <= "10";
          priv_counter_out      <= std_logic_vector(to_unsigned(separ_pulses - 1, priv_counter_out'length));
        else
          state_out(3 downto 2) <= "00";
          priv_counter_out      <= std_logic_vector(to_unsigned(dead_time - 1, priv_counter_out'length));
        end if;
        priv_polar_out   <= priv_polar_in;
    end case STATE_CASE;
  end process state_proc;
end architecture arch;



library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;
--! @brief State machine to compute one pulse
--!
--! Gets the state the requested value and produces the pulse output
--! It can be parallel or after the state machine run.
--! 
entity Pulses_stateMOut is
  port (
    --! Master clock
    CLK           : in  std_logic;
    RST           : in  std_logic;
    --! Enable: high only once to compute the new state
    req_amplitude : in  std_logic_vector;
    state         : in  std_logic_vector(3 downto 0);
    --! Tells which polarity has to be update
    out_amplitude : out std_logic_vector
    );
end entity Pulses_stateMOut;

architecture arch of Pulses_stateMOut is

begin
  assert req_amplitude'length = out_amplitude'length report "requested amplitude (" & integer'image(req_amplitude'length)
    & ") and output amplitude (" & integer'image(out_amplitude'length) & ") should have the same size"
    severity failure;

  output_proc : process(CLK) is
    variable output_rise_fall : std_logic_vector(1 downto 0);
    variable padding_1        : unsigned(1 downto 1);
    variable padding_2        : unsigned(1 downto 0);
  begin
    --! Step one: compute the new state
    -- 00 : full (or full null)
    -- 01 : 1/4
    -- 10 : 1/2
    -- 11 : 3/4
    if rising_edge(CLK) then
      if state(2) = '0' then
        output_rise_fall := state(1 downto 0);
      else
        output_rise_fall := std_logic_vector(- signed (state(1 downto 0)));
      end if;
      OUTPUT_CASE : case output_rise_fall is
        when "00" =>
          if state(2) = '1' then
            out_amplitude <= req_amplitude;
          else
            -- others =>'0' is rejected as out_amplitude is unconstrained
            out_amplitude <= std_logic_vector(to_unsigned(0, out_amplitude'length));
          end if;
        when "01" =>
          out_amplitude(out_amplitude'high - 2 downto out_amplitude'low) <=
            req_amplitude(req_amplitude'high downto req_amplitude'low + 2);
          out_amplitude(out_amplitude'high downto out_amplitude'high - 1) <= "00";
        when "10" =>
          out_amplitude(out_amplitude'high - 1 downto out_amplitude'low) <=
            req_amplitude(req_amplitude'high downto req_amplitude'low + 1);
          out_amplitude(out_amplitude'high) <= '0';
        when "11" =>
          padding_2 := "00";
          padding_1 := "0";
          out_amplitude <= std_logic_vector(
            (padding_1 & unsigned(req_amplitude(req_amplitude'high downto req_amplitude'low + 1))) +
            (padding_2 & unsigned(req_amplitude(req_amplitude'high downto req_amplitude'low + 2)))
            );
        when others => null;
      end case;
    end if;
  end process output_proc;

end architecture arch;

--! @brief Handles all the internal controls and RAM addresses
--!
--! The design is optimized for global safety and validation efforts
--!   rather than large number of channels.\n
--!
--! The lowest frame is clocked by the main clock.
--! It handles the state machine and the DACs for all the channels.\n
--! Its length is the number of cycles
--!   for a sample to be written (in parallel) in all channels,
--!   or the process of all states machines,
--!   whatever come last.\n
--! The mid frame is clocked by the low frame.
--! Its length is the number of channels.\n
--! The high frames TODO\n
--! 
library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;
entity Pulses_sequencer is
  generic (
    MasterCLK_SampleCLK_ratio : integer range 10 to 40;
    --! Does one more RAM operation.
    --! This is set by the bundle, and should be modified
    has_extra_RAM_op          : boolean
    );
  port (
    --! Master clock
    CLK           : in  std_logic;
    RST           : in  std_logic;
--!
    start_frame   : in  std_logic;
--! The frame is over
    ready         : out std_logic;
--! Which channel    
    RAM_addr_high : out std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
--! Which data
    RAM_addr_low  : out std_logic_vector(0 downto 0);
    RAM_read      : out std_logic;
    RAM_write     : out std_logic;
--! Active between the read and the write of the RAM,
--!   in the second step (addr_low = "1")
    EN_process    : out std_logic;
--! Enables one DAC wrapper
    EN            : out std_logic_vector(channels_number - 1 downto 0));
end entity Pulses_sequencer;

architecture arch of Pulses_sequencer is
  constant extra_RAM_addr_bits : natural := 0;
  --! The high bits of the RAM are the channel number. The low bits are the internal data to be processed
--  signal RAM_global_addr       : std_logic_vector(RAM_addr'length + extra_RAM_addr_bits - 1 downto 0);
  signal sequencer_state       : std_logic_vector(3 downto 0);
  -- Round to the power 2 above
  signal EN_shift              : std_logic_vector(2**StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
begin
  EN <= EN_shift(EN_shift'low - 1 + EN'length downto EN_shift'low);

  main_proc : process (CLK)
  begin
    if rising_edge(CLK) then
      RST_if : if RST = '0' then
        -- We are running the individual state machines
        case sequencer_state is
          when "0001" | "0111" =>
            RAM_read        <= '1';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0010" | "1000" =>
            RAM_read        <= '0';
            EN_process      <= '1';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0011" | "1001" =>
            EN_process      <= '0';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0100" | "1010" =>
            RAM_write       <= '1';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0101" =>
            RAM_write       <= '0';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "1011" =>
            RAM_write                                                    <= '0';
            EN_shift(EN_shift'low + to_integer(unsigned(RAM_addr_high))) <= '1';
            sequencer_state                                              <= (others => '0');
          when "0110" =>
            RAM_addr_low(0) <= '1';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          -- In fact $0000
          when others =>
            EN_shift        <= (others => '0');
            RAM_addr_low(0) <= '0';
            if RAM_addr_high /= std_logic_vector(to_unsigned(channels_number - 1, RAM_addr_high'length)) then
              RAM_addr_high   <= std_logic_vector(unsigned(RAM_addr_high) + 1);
              sequencer_state <= "0001";
            elsif start_frame = '1' then
              ready           <= '0';
              RAM_addr_high   <= (others => '0');
              sequencer_state <= "0001";
            else
              ready <= '1';
            end if;
        end case;
      else
        ready <='0';
        sequencer_state <= ( others => '0' );
        RAM_addr_high <= ( others => '0' );
      end if RST_if;
    end if;
  end process main_proc;
end architecture arch;



entity Pulses_amplitude_volume is

end entity Pulses_amplitude_volume;

