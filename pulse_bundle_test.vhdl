library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.all,
  work.Amplitude_package.Pulse_start_vector,
  work.Amplitude_package.Pulse_amplitude_record,
  work.Pulses_pac.pulses_bundle,
  work.DAC_emulators_package.all;
--! @brief Handles N pulse channels
--!
--! It bundles all the components of the package.
--! It provides the RAM needed to store the states and the other data.\n
--! 
entity Pulses_bundle_test is
  generic (
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 22
    );
end entity Pulses_bundle_test;

architecture arch of Pulses_bundle_test is
  signal pulses_counter       : unsigned(6 downto 0)                       := (others        => '0');
  signal pulses_counter_max   : unsigned(pulses_counter'range)             := ("101", others => '0');
  signal samples_counter      : unsigned(6 downto 0)                       := (others        => '0');
  signal samples_counter_max  : unsigned(samples_counter'range)            := (others        => '1');
  signal channel_counter      : unsigned(channels_number + 1 - 1 downto 0) := (others        => '0');
  signal RST                  : std_logic                                  := '1';
  signal RST_count            : unsigned(7 downto 0)                       := (others        => '0');
  constant RST_max            : unsigned(RST_count'range)                  := (others        => '1');
  signal CLK                  : std_logic                                  := '0';
  signal data_serial          : std_logic_vector(nbre_DACS_used - 1 downto 0);
  signal CLK_serial           : std_logic_vector(2 downto 0);
  signal transfer_serial      : std_logic_vector(1 downto 0);
  signal update_serial        : std_logic_vector(0 downto 0);
  signal Pulse_start_data     : Pulse_start_vector;
  signal Pulse_amplitude_data : Pulse_amplitude_record;
  signal start_frame          : std_logic;
begin
  main_proc : process is
    variable amplitude_v : unsigned(15 downto 0);
  begin
    PULSES_COUNT_IF : if pulses_counter /= pulses_counter_max then
      CLK <= not CLK;
      CLK_IF : if CLK = '0' then
        if RST_count /= RST_max then
          RST_count <= RST_count + 1;
        else
          RST <= '0';
        end if;
        DAC_IF : if start_frame = '1' then
          samples_if : if samples_counter /= samples_counter_max then
            samples_counter <= samples_counter + 1;
            for ind in channels_number - 1 downto 0 loop
              Pulse_start_data(ind + Pulse_start_data'low).enable         <= '0';
              Pulse_start_data(ind + Pulse_start_data'low).polarity_first <= '0';
            end loop;  -- ind
          else
            samples_counter <= (others => '0');
            pulses_counter  <= pulses_counter + 1;
            for ind in channels_number - 1 downto 0 loop
              Pulse_start_data(ind + Pulse_start_data'low).enable <=
                channel_counter(ind + channel_counter'low);
              Pulse_start_data(ind + Pulse_start_data'low).polarity_first <=
                channel_counter(channels_number + channel_counter'low);
            end loop;  -- ind

            Pulse_amplitude_data.which_channel(Pulse_amplitude_data.which_channel'range) <=
              std_logic_vector( pulses_counter(Pulse_amplitude_data.which_channel'length - 1 + pulses_counter'low downto
                             pulses_counter'low));
            amplitude_v(15 downto 10)          := pulses_counter(5 downto 0);
            amplitude_v(9 downto 4)            := pulses_counter(5 downto 0);
            amplitude_v(3 downto 0)            := pulses_counter(5 downto 2);
            Pulse_amplitude_data.the_amplitude <= std_logic_vector(amplitude_v);
            channel_counter                    <= channel_counter + 1;
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
      MasterCLK_SampleCLK_ratio => 22
      )
    port map(
      --! Master clock
      CLK                  => CLK,
      RST                  => RST,
      pulse_start_data     => pulse_start_data,
      pulse_amplitude_data => pulse_amplitude_data,
      -- It is a test stand alone, there are no links to the amplitude module
      ready_amplitude      => '1',
      start_frame          => start_frame,
      data_serial          => data_serial,
      CLK_serial           => CLK_serial,
      transfer_serial      => transfer_serial,
      update_serial        => update_serial
      );


  DAC_emulator_instanc : DAC_emulator
    generic map (
      write_and_update_cmd => "000",
      write_only_cmd       => "000")
    port map(
      data_serial     => data_serial(data_serial'low),
      CLK_serial      => CLK_serial(CLK_serial'low),
      transfer_serial => transfer_serial(transfer_serial'low),
      update_serial   => update_serial(update_serial'low)
      );


end architecture arch;


configuration pulses_bundle_test_default_controler of pulses_bundle_test is
  for arch
    for Pulses_bundle_instanc : Pulses_bundle
      use configuration work.DAC_default_controler;
    end for;
    for DAC_emulator_instanc : DAC_emulator
      use entity work.DAC_emulator_model_1
        generic map (
          write_and_update_cmd => "--10",
          write_only_cmd       => "--11",
          address_size         => 2,
          data_bits            => 6);
    end for;
  end for;
end configuration pulses_bundle_test_default_controler;
