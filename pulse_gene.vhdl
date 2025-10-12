library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;


--! @brief State machine to generate one pulse
--!
--! Gets the state, the start signal and produces the new state
--! 
entity Pulses_stateMachine is
  generic (
    separ_pulses : positive := 1;
    pulse_length : positive := 10;
    dead_time    : positive := 50
    );
  port (
    RST              : in  std_logic;
    --! Enable: high only once to compute the new state
    start            : in  std_logic;
    priv_state_in    : in  std_logic_vector(3 downto 0);
    priv_counter_in  : in  std_logic_vector;
    state_out        : out std_logic_vector(3 downto 0);
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
  
  state_proc : process(RST, start, priv_state_in, priv_counter_in) is
  begin
    STATE_CASE : case priv_state_in(1 downto 0) is
      when "00" =>
        if RST = '1' then
          -- Go to the next state to set all the DAC to 0
          state_out        <= "0001";
          priv_counter_out <= counter_reset;
        elsif priv_counter_in = std_logic_vector(to_unsigned(0, priv_counter_in'length)) then
          -- The counter is 0
          if priv_state_in(3 downto 2) /= "00" then
            -- Got to the next state
            state_out(1 downto 0) <= "01";
          elsif start = '1' then
            -- Ready and the start is requested
            state_out(1 downto 0) <= "01";
          else
            -- Wait
            state_out(1 downto 0) <= "00";
          end if;
          state_out(3 downto 2) <= priv_state_in(3 downto 2);
          priv_counter_out      <= priv_counter_in;
        else
          -- The counter is not 0, wait (and decrease)
          state_out        <= priv_state_in;
          priv_counter_out <= std_logic_vector(unsigned(priv_counter_in) - 1);
        end if;
      when "01" | "10" =>
        state_out(3 downto 2) <= priv_state_in(3 downto 2);
        state_out(1 downto 0) <= std_logic_vector(unsigned(priv_state_in(1 downto 0)) + 1);
        priv_counter_out      <= priv_counter_in;
      when others =>
        -- Use others, rather than 11 to allow the start-up while simulating
        state_out(1 downto 0) <= "00";
        -- Load the counter among 3, according with the state
        if priv_state_in(3 downto 2) = "00" or priv_state_in(3 downto 2) = "10" then
          state_out(3 downto 2) <= std_logic_vector(unsigned(priv_state_in(3 downto 2)) + 1);
          priv_counter_out      <= std_logic_vector(to_unsigned(pulse_length - 1, priv_counter_out'length));
        elsif priv_state_in(3 downto 2) = "01" then
          state_out(3 downto 2) <= "10";
          priv_counter_out      <= std_logic_vector(to_unsigned(separ_pulses - 1, priv_counter_out'length));
        else
          state_out(3 downto 2) <= "00";
          priv_counter_out      <= std_logic_vector(to_unsigned(dead_time - 1, priv_counter_out'length));
        end if;
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
    CLK               : in  std_logic;
    RST               : in  std_logic;
    --! Enable: high only once to compute the new state
    req_amplitude     : in  std_logic_vector;
    state             : in  std_logic_vector(3 downto 0);
    --! Tells which polarity has to be update
    polar_pos_not_neg : out std_logic;
    out_amplitude     : out std_logic_vector
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
      polar_pos_not_neg <= state(3);
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
  work.Utils_pac.StateNumbers_2_BitsNumbers;
entity Pulses_sequencer is
  generic (
    chans_number              : integer range 2 to 300 := 4;
    MasterCLK_SampleCLK_ratio : integer range 10 to 40;
    --! Does one more RAM operation.
    --! This is set by the bundle, and should be modified
    has_extra_RAM_op          : boolean
    );
  port (
    --! Master clock
    CLK           : in  std_logic;
    RST           : in  std_logic;
--! Which channel    
    RAM_addr_high : out std_logic_vector(StateNumbers_2_BitsNumbers(chans_number + 1) - 1 downto 0);
--! Which data
    RAM_addr_low  : out std_logic_vector(0 downto 0);
    RAM_read      : out std_logic;
    RAM_write     : out std_logic;
--! Active between the read and the write of the RAM,
--!   in the second step (addr_low = "1")
    EN_process    : out std_logic;
--! Enables one DAC wrapper
    EN            : out std_logic_vector(chans_number - 1 downto 0);
--! Enable all the DACS to transfer into their running registers
    EN_out        : out std_logic);
end entity Pulses_sequencer;

architecture arch of Pulses_sequencer is
  constant extra_RAM_addr_bits : natural := 0;
  --! The high bits of the RAM are the channel number. The low bits are the internal data to be processed
--  signal RAM_global_addr       : std_logic_vector(RAM_addr'length + extra_RAM_addr_bits - 1 downto 0);
  signal sequencer_state       : std_logic_vector(2 downto 0);
  signal channel_not_global    : std_logic;
  signal current_chan          : std_logic_vector(StateNumbers_2_BitsNumbers(chans_number + 1) - 1 downto 0);
  constant extra_cycles_max    : integer := StateNumbers_2_BitsNumbers(MasterCLK_SampleCLK_ratio - (chans_number+1)*4);
  signal extra_cycles_count    : std_logic_vector(extra_cycles_max - 1 downto 0);
  -- Round to the power 2 above
  signal EN_shift              : std_logic_vector(2**StateNumbers_2_BitsNumbers(chans_number + 1) - 1 downto 0);
begin
  EN <= EN_shift(EN_shift'low - 1 + EN'length downto EN_shift'low);

  main_proc : process (CLK)
  begin
    if rising_edge(CLK) then
      RST_if : if RST = '0' then
        if channel_not_global = '1' then
          -- We are running the individual state machines
          case sequencer_state is
            when "001" | "101" =>
              RAM_read <= '0';
              EN_process <= '1';
              sequencer_state(sequencer_state'low + 1 downto sequencer_state'low) <= "10";
            when "010" =>
              EN_process      <= '0';
              RAM_write       <= '1';
              sequencer_state <= "011";
            when "110" =>
              EN_process      <= '0';
              RAM_write       <= '1';
              sequencer_state <= "111";
            when "011" =>
              RAM_write       <= '0';
              sequencer_state <= "100";
            when "111" =>
              RAM_write                                                    <= '0';
              sequencer_state                                              <= "000";
              EN_shift(EN_shift'low + to_integer(unsigned(RAM_addr_high))) <= '1';
              if RAM_addr_high = std_logic_vector(to_unsigned(chans_number - 1, RAM_addr_high'length)) then
                channel_not_global <= '0';
              end if;
            when "100" =>
              RAM_read        <= '1';
              RAM_addr_low    <= "1";
              sequencer_state <= "101";
            -- In fact "000"
            when others =>
              EN_shift        <= (others => '0');
              RAM_read        <= '1';
              RAM_addr_high   <= std_logic_vector(unsigned(RAM_addr_high) + 1);
              RAM_addr_low    <= "0";
              sequencer_state <= "001";
          end case;
        else
          -- We are activating the global enable or waiting TODO for longer DAC
          case sequencer_state is
            -- Only "100" is used in the series "1xx". But be symmetric in order
            --   to avoid un-useful logic
            when "001" | "101" =>
              EN_out          <= '0';
              RAM_read        <= '0';
              sequencer_state <= "010";
            when "010" =>
              RAM_write       <= '1';
              sequencer_state <= "011";
            when "110" =>
              RAM_write       <= '1';
              sequencer_state <= "111";
            when "011" | "111" =>
              RAM_write          <= '0';
              extra_cycles_count <= (others => '0');
              sequencer_state    <= "100";
            when "100" =>
              EN_out <= '0';
              -- Check now for the extra clock cycles
              EXTRA_C_if : if extra_cycles_max > 0 then
                if extra_cycles_count /= std_logic_vector(to_unsigned(extra_cycles_max, extra_cycles_count'length)) then
                  extra_cycles_count <= std_logic_vector(unsigned(extra_cycles_count) + 1);
                else
                  sequencer_state    <= "001";
                  RAM_addr_high      <= (others => '0');
                  RAM_addr_low       <= "0";
                  channel_not_global <= '1';
                  RAM_read           <= '1';
                end if;
              else
                sequencer_state    <= "001";
                RAM_addr_high      <= (others => '0');
                RAM_addr_low       <= "0";
                channel_not_global <= '1';
                RAM_read           <= '1';
              end if EXTRA_C_if;
            -- in fact "000"
            when others =>
              EN_out        <= '1';
              EN_shift      <= (others => '0');
              RAM_addr_high <= std_logic_vector(to_unsigned(chans_number, RAM_addr_high'length));
              RAM_addr_low  <= "0";
              if has_extra_RAM_op then
                sequencer_state <= "001";
                RAM_read        <= '1';
              else
                extra_cycles_count <= (others => '0');
                sequencer_state    <= "100";
              end if;
          end case;
        end if;
      else
        RAM_addr_high <= (others => '0');
      end if RST_if;
    end if;
  end process main_proc;
end architecture arch;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;
entity Pulses_DAC_wrapper is
  generic (
    --! The entity should, check the DAC requirement is lower or equal
    MasterCLK_SampleCLK_ratio : integer range 10 to 40
    );
  port (
    --! Master clock
    CLK               : in  std_logic;
    RST               : in  std_logic;
    EN                : in  std_logic;
                                        --! Tells which polarity has to be update
    polar_pos_not_neg : in  std_logic;
    in_amplitude      : in  std_logic_vector;
    EN_out            : in  std_logic;
    DAC_data          : out std_logic;
    DAC_transfer      : out std_logic
    );
end entity Pulses_DAC_wrapper;

architecture arch of Pulses_DAC_wrapper is
  component Pulses_DAC_generic is
    --! Tells the number of clock cycles available for a writing
    generic (
      MasterCLK_SampleCLK_ratio : integer range 10 to 40
      );
    port (
      --! Master clock
      CLK               : in  std_logic;
      RST               : in  std_logic;
      EN                : in  std_logic;
      --! Tells which polarity has to be update
      polar_pos_not_neg : in  std_logic;
      in_amplitude      : in  std_logic_vector;
      EN_out            : in  std_logic;
      DAC_data          : out std_logic;
      DAC_transfer      : out std_logic
      );
  end component Pulses_DAC_generic;
begin
  Pulses_DAC_instanc : Pulses_DAC_generic
    generic map (
      MasterCLK_SampleCLK_ratio => MasterCLK_SampleCLK_ratio)
    port map (
      CLK               => CLK,
      RST               => RST,
      EN                => EN,
      polar_pos_not_neg => polar_pos_not_neg,
      in_amplitude      => in_amplitude,
      EN_out            => EN_out,
      DAC_data          => DAC_data,
      DAC_transfer      => DAC_transfer
      );
end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;
--! @brief converts parallel into serial for DAC
--!
--! It takes the value and the polarity. It produces the serial output.\n
--! In order to synchronize all the outputs,
--!   it buffers the input and transfers into a register when required.\n
--! This one sends a $3 followed by the polarity followed by the value
--!   in big endian mode
--! The diagrams may be buggy or even does not fit any DAC
--! It is a sample code to write the DAC in use.
entity Pulses_DAC_generic is
  generic (
    --! The entity should, check the DAC requirement is lower or equal
    MasterCLK_SampleCLK_ratio : integer range 10 to 40
    );
  port (
    --! Master clock
    CLK               : in  std_logic;
    RST               : in  std_logic;
    EN                : in  std_logic;
    --! Tells which polarity has to be update
    polar_pos_not_neg : in  std_logic;
    in_amplitude      : in  std_logic_vector;
    EN_out            : in  std_logic;
    DAC_data          : out std_logic;
    DAC_transfer      : out std_logic
    );
end entity Pulses_DAC_generic;

architecture arch of Pulses_DAC_generic is
  signal super_world      : std_logic_vector(4 + 1 + in_amplitude'length - 1 downto 0);
  signal amplitude_next   : std_logic_vector(in_amplitude'range);
  signal polar_next       : std_logic;
  --! TODO TODO make the size dynamic
  signal count_length     : std_logic_vector(4 downto 0);
  signal to_be_transfered : std_logic;
begin
  DAC_data <= super_world(super_world'high);

  main_proc : process(CLK) is
  begin
    if rising_edge(CLK) then
      RST_if : if RST = '0' then
        if EN = '1' then
          polar_next     <= polar_pos_not_neg;
          amplitude_next <= in_amplitude;
        end if;
        EN_out_if : if EN_out = '1' then
          super_world(super_world'high downto super_world'high - 3) <= "0011";
          super_world(super_world'high - 4)                         <= polar_next;
          super_world(super_world'high - 5 downto super_world'low)  <= amplitude_next;
          count_length                                              <= std_logic_vector(to_unsigned(4 + 1 + in_amplitude'length - 1, count_length'length));
          to_be_transfered                                          <= '1';
        elsif count_length /= std_logic_vector(to_unsigned(0, count_length'length)) then
          super_world(super_world'high downto super_world'low + 1)<=
            super_world(super_world'high - 1 downto super_world'low);
          super_world(super_world'low) <= '-';
          count_length                 <= std_logic_vector(unsigned(count_length) - 1);
        elsif to_be_transfered = '1' then
          -- This does not change anything but makes the debug more easy
          super_world(super_world'high downto super_world'low + 1)<=
            super_world(super_world'high - 1 downto super_world'low);
          DAC_transfer     <= '1';
          to_be_transfered <= '0';
        else
          DAC_transfer <= '0';
        end if EN_out_if;
      --else
      -- Should discuss what to do during the reset
      end if RST_IF;
    end if;
  end process main_proc;

end architecture arch;


entity Pulses_amplitude_volume is

end entity Pulses_amplitude_volume;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.Pulses_pac.all;
--! @brief Handles N pulse channels
--!
--! It bundles all the components of the package.
--! It provides the RAM needed to store the states and the other data.\n
--! 
entity Pulses_bundle is
  generic (
    chans_number              : integer range 2 to 300 := 4;
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 22
    );
  port (
    --! Master clock
    CLK                : in  std_logic;
    RST                : in  std_logic;
    start              : in  std_logic;
--! TEMPORARY
    priv_amplitude_new : in  std_logic_vector (15 downto 0);
    --! TODO set the inputs amplitude and the volume
    data_out           : out std_logic_vector(chans_number - 1 downto 0);
    transfer           : out std_logic_vector(chans_number - 1 downto 0)
    );
end entity Pulses_bundle;

architecture arch of Pulses_bundle is
  --! TODO TODO make the size dynamic
  signal RST_delayed       : std_logic_vector(2 downto 0);
  --! Subject to move to generic
  constant counter_length  : integer range 2 to 20 := 8;
  signal priv_counter_out  : std_logic_vector(counter_length - 1 downto 0);
  signal priv_amplitude_in : std_logic_vector (15 downto 0);
  constant state_length    : positive              := 4;
  signal priv_state_S_2_A  : std_logic_vector(state_length - 1 downto 0);
  signal priv_state_out    : std_logic_vector(state_length - 1 downto 0);
--  signal priv_amplitude_new : std_logic_vector(priv_amplitude_in'range);

  constant RAM_addr_size : positive := StateNumbers_2_BitsNumbers(chans_number+1);
  signal RAM_addr_high   : std_logic_vector(StateNumbers_2_BitsNumbers(chans_number+1) - 1 downto 0);
  signal RAM_addr_low    : std_logic_vector(0 downto 0);
  type state_RAM_elem is record
    padding : std_logic_vector(priv_amplitude_in'length - state_length - counter_length - 1
                               downto 0);
    state   : std_logic_vector(3 downto 0);
    counter : std_logic_vector(7 downto 0);
  end record state_RAM_elem;
  signal RAM_write_struct  : state_RAM_elem;
  signal RAM_read_struct   : state_RAM_elem;
  signal RAM_unioned       : std_logic_vector(priv_amplitude_in'length - 1 downto 0);
  type RAM_t is array(0 to 2 ** RAM_addr_size) of state_RAM_elem;
  signal the_RAM           : RAM_t;
  signal RAM_read          : std_logic;
  signal RAM_write         : std_logic;
  signal EN_process        : std_logic;
  signal EN                : std_logic_vector(chans_number - 1 downto 0);
  signal polar_pos_not_neg : std_logic;
  signal amplitude_for_DAC : std_logic_vector(15 downto 0);
  signal EN_out            : std_logic;
begin
  assert priv_amplitude_in'length >= (state_length + counter_length)
    report "in this version, the amplitude size should be at least the state size (3) plus the counter size"
    severity error;
  
  main_proc : process(CLK) is
  begin
    CLK_IF : if rising_edge(CLK) then
      if RST = '1' then
        RST_delayed <= (others => '1');
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
          priv_state_S_2_A         <= (others => '0');
        elsif RAM_addr_low = "0" then
          -- Even words of the RAM
          -- We collect the outpout of the state machine
          --   to buffer it into the RAM write data.
          RAM_write_struct.padding <= (others => '0');
          RAM_write_struct.counter <= priv_counter_out;
          RAM_write_struct.state   <= priv_state_out;
          -- We collect the state to be used by the pulse amplitude calculator
          priv_state_S_2_A         <= priv_state_out;
        else
          -- Odd words of the RAM
          -- This time, there is a mapping to the data structure
          --   as we don't have the union type
          -- The amplitude is re written as it if
          --   a pulse cycle is currently running
          -- The amplitude is the one supplied, which is ready to be "photographied"
          if priv_state_S_2_A = "0000" then
            -- Wait state or reset, we can accept new amplitude
            RAM_write_struct.padding <= priv_amplitude_new(15 downto 12);
            RAM_write_struct.state   <= priv_amplitude_new(11 downto 8);
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
      chans_number              => chans_number,
      MasterCLK_SampleCLK_ratio => MasterCLK_SampleCLK_ratio
      )
    port map(
      CLK           => CLK,
      RST           => RST,
      RAM_addr_high => RAM_addr_high,
      RAM_addr_low  => RAM_addr_low,
      RAM_read      => RAM_read,
      RAM_write     => RAM_write,
      EN_process    => EN_process,
      EN            => EN,
      EN_out        => EN_out);

-- This runs on the second step of each channel
--   (RAM_addr_low = '1'), then it takes the
--   OUT of the state and the amplitude
--RAM_unioned(15 downto 12) <= RAM_read_struct.padding;
--RAM_unioned(11 downto 8)  <= RAM_read_struct.state;
--RAM_unioned(7 downto 0)   <= RAM_read_struct.counter;
  RAM_unioned <= RAM_read_struct.padding & RAM_read_struct.state & RAM_read_struct.counter;

  Pulses_stateMOut_instanc : Pulses_stateMOut
    port map(
      CLK               => CLK,
      RST               => RST,
      req_amplitude     => RAM_unioned,
      state             => priv_state_S_2_A,
      polar_pos_not_neg => polar_pos_not_neg,
      out_amplitude     => amplitude_for_DAC
      );

  Pulses_stateMachine_instanc : Pulses_stateMachine
    generic map (
      separ_pulses => 2,
      pulse_length => 3,
      dead_time    => 4
      )
    port map(
      --! Master clock
      RST              => RST,
      --! Enable: high only once to compute the new state
      start            => start,
      priv_state_in    => RAM_read_struct.state,
      priv_counter_in  => RAM_read_struct.counter,
      state_out        => priv_state_out,
      priv_counter_out => priv_counter_out
      );


  chan_DAC : for ind in 0 to chans_number - 1 generate

    chan_instanc : Pulses_DAC_wrapper generic map
      (
        MasterCLK_SampleCLK_ratio => MasterCLK_SampleCLK_ratio
        )
      port map
      (
        CLK               => CLK,
        RST               => RST,
        EN                => EN(ind),
        polar_pos_not_neg => polar_pos_not_neg,
        in_amplitude      => amplitude_for_DAC,
        EN_out            => EN_out,
        DAC_data          => data_out(ind),
        DAC_transfer      => transfer(ind));
  end generate chan_DAC;
  
end architecture arch;

--configuration Pulses_DAC_config of Pulses_DAC_wrapper is
--  for arch
--    for Pulses_DAC_instanc : Pulses_DAC_wrapped;
--      use entity work.Pulses_DAC_generic;
--    end for;
--  end for;
--end configuration Pulses_DAC_config;

