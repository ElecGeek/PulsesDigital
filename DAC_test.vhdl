library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.Test_utils.all,
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.global_volume_size,
  work.DAC_package.all,
  work.DAC_emulators_package.all;

--! @brief Test of the DAC signal generator using a wave viewer
--!
--! Generates a couple of values and cast them
--!   in the same way the pulse bundle would have do.
--! Runs the DAC controler to generate the serial data and the hanshake signals.
--! Runs a DAC emulator, in order to convert (back) into parrallel for verification.\n
--! That assume the emulator has verified by proof reading.\n
--! The assertion notes display the configuration that has been understood.\n
--! It is supposed to be re-run in case the DAC configuration is changed.
--! The scope can be the channels number and organisation
--!   found in the DAC_package.vhdl file
--! The scope can be the DAC model found in the DAC_configure.vhdl file TODO.
--! However, there is no need in case the quantity of control line is changed
--!   during the PCB design.\n
--! TODO Check automatically the result is correct.\n
--! TODO Ensure all the constants of the configuration
--!   come from the DAC_package, rather than the generics. 

entity DAC_test is

end entity DAC_test;



architecture arch of DAC_test is
  signal CLK : std_logic := '0';
  -- We assume here:
  --   the command size is no longuer than 8,
  --   the 3 extra states (as in the controler)
  --   4 more idles states to improve readability using a wave viewer
  -- Since it is for testing
  signal DAC_counter : unsigned(StateNumbers_2_BitsNumbers(
    channels_number * (8 + DAC_data_size + 3 + 4)) - 1 downto 0) := (others => '0');
  signal DAC_counter_max        : unsigned(DAC_counter'range) := (others => '1');
  -- TODO compute the minimum number of bits accroding with the channel size
  constant channel_counter_bits : natural :=
    StateNumbers_2_BitsNumbers(nbre_outputs_per_DAC);
  -- The channel counter selects which one is to set and the shifts of the data
  signal channel_counter     : unsigned(channel_counter_bits - 1 downto 0) := (others => '0');
  -- The data size is added by 1 in order to have a "carry" bit.
  --   The max is counter'high and some re-run of the first simulations
  --   that may be wrong due to the reset, warm up etc...
  -- The data size is added by 1 in order to contain the sign bit.
  -- The data size is added by N which is the smallest value
  --   that channels_number <= 2**N
  signal relevant_data : unsigned(1 +
                                  1 +
                                  requested_amplitude_size + global_volume_size +
                                  StateNumbers_2_BitsNumbers(channels_number) -
                                  1
                                  downto 0);
  signal data_counter       : unsigned(1 + 3 + 3 + 1 - 1 downto 0);
  signal data_counter_max   : unsigned(data_counter'range);
  -- Send some keep alive messages
  constant debug_size       : positive                                                         := 5;
  signal data_counter_debug : unsigned(data_counter'high - debug_size downto data_counter'low) := (others => '1');

  signal data_absolute_value : std_logic_vector(requested_amplitude_size + global_volume_size - 1 downto 0);
  signal polar_pos_not_neg   : std_logic;
  signal EN                  : std_logic_vector(channels_number - 1 downto 0);
  signal RST                 : unsigned(20 downto 0) := (others => '1');
  signal the_start           : std_logic;
  signal data_serial         : std_logic_vector (nbre_DACs_used + 8 - 1 downto 8);
  signal CLK_serial          : std_logic_vector (4 downto 2);
  signal transfer_serial     : std_logic_vector (5 downto 5);
  signal update_serial       : std_logic_vector (5 downto 5);

begin

-- GHDL 5 does not accept (xyz'high => '1', others => '0')
  -- claiming xyz'high is not constant
--  main_counter_max(main_counter'high)             <= '1';
  --main_counter_max(main_counter'high - requested_amplitude_size + global_volume_size) <= '1';

  main_proc : process is
    variable EN_var             : std_logic_vector(EN'range);
    variable data_counter_max_v : unsigned(data_counter_max'range);
  begin
    if data_counter /= data_counter_max then
      if RST(RST'high) = '1' then
        data_counter                                                                           <= (others => '0');
        data_counter_max_v                                                                     := (others => '0');
        data_counter_max_v(data_counter_max'high)                                              := '1';
        data_counter_max_v(data_counter_max'low + StateNumbers_2_BitsNumbers(channels_number)) := '1';
        data_counter_max                                                                       <= data_counter_max_v;
      end if;
      RST(RST'high - 1 downto RST'low) <= RST(RST'high downto RST'low+1);
      RST(RST'high)                    <= '0';
      CLK_IF : if CLK = '1' then
        if DAC_counter < to_unsigned(channels_number, DAC_counter'length) then
          DAC_counter <= DAC_counter + 1;
          EN_var      := (others => '0');
          EN_var(EN_var'low + to_integer(DAC_counter)) := '1';
          EN <= EN_var;
        elsif DAC_counter = to_unsigned(channels_number, DAC_counter'length) then
          the_start   <= '1';
          EN          <= (others => '0');
          DAC_counter <= DAC_counter + 1;
        elsif DAC_counter /= DAC_counter_max then
          the_start   <= '0';
          DAC_counter <= DAC_counter + 1;
        else
          DAC_counter       <= (others => '0');
                                        -- Get the sign
          polar_pos_not_neg <= relevant_data(relevant_data'high - 1);
                                        -- Get the data while shifting according to the current channel number
          if channel_counter'length > 0 then
            data_absolute_value <= std_logic_vector(
              relevant_data(relevant_data'low + to_integer(channel_counter) + data_absolute_value'length - 1 downto
                            relevant_data'low + to_integer(channel_counter)));
          else
            data_absolute_value <= std_logic_vector(
              relevant_data(relevant_data'low + data_absolute_value'length - 1 downto
                            relevant_data'low));
          end if;
          if channel_counter'length > 0 then
                                        -- Increment the upper level
            if channel_counter /= to_unsigned(channels_number / TotempoleOutputUsage(mode_totempole ) - 1,
                                              channel_counter'length) then
              channel_counter <= channel_counter + 1;
            else
              channel_counter <= (others => '0');
              data_counter    <= data_counter + 1;
            end if;
          else
            data_counter <= data_counter + 1;
            if data_counter(data_counter_debug'high downto data_counter_debug'low) = data_counter_debug then
              assert false report integer'image(to_integer(data_counter(data_counter'high downto data_counter'high - debug_size + 1))+1) &
                "/" & integer'image(2**(debug_size - 1)) & " done" severity note;
            end if;
          end if;
        end if;
      end if CLK_IF;
      CLK <= not CLK;
      wait for 100 ns;
    else
      wait;
    end if;
  end process main_proc;

  test_accelerator_instanc : test_accelerator
    generic map (
      left_bits  => 3,
      right_bits => 3)
    port map (
      the_input  => data_counter(data_counter'high - 1 downto data_counter'low),
      the_output => relevant_data);


  DAC_bundle_instanc : DAC_bundle_dummy
    port map (
      CLK,
      polar_pos_not_neg,
      data_in         => data_absolute_value,
      EN              => EN,
      RST_init        => RST(RST'low),
      start_frame     => the_start,
      ready           => open,
      data_serial     => data_serial,
      CLK_serial      => CLK_serial,
      transfer_serial => transfer_serial,
      update_serial   => update_serial
      );


  emulators_instanc : for ind in 1 to nbre_DACS_used generate
  begin
    DAC_emulator_instanc : DAC_emulator
      generic map (
        write_and_update_cmd => "000",
        write_only_cmd       => "000")
      port map(
        data_serial     => data_serial(data_serial'low + ind - 1),
        CLK_serial      => CLK_serial(CLK_serial'low),
        transfer_serial => transfer_serial(transfer_serial'low),
        update_serial   => update_serial(update_serial'low)
        );
  end generate emulators_instanc;


end architecture arch;



configuration DAC_test_default_controler of DAC_test is
  for arch
    for DAC_bundle_instanc : DAC_bundle_dummy
      use entity work.DAC_bundle_real_outputs;
    end for;
    for emulators_instanc
      for all : DAC_emulator
        use entity work.DAC_emulator_model_1
          generic map (
            write_and_update_cmd => "--10",
            write_only_cmd       => "--11",
            address_size         => 2,
            data_bits            => 6);
      end for;
    end for;
  end for;
end configuration DAC_test_default_controler;

