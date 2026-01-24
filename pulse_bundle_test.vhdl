library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.all,
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
  signal pulses_counter      : unsigned(4 downto 0)            := (others        => '0');
  signal pulses_counter_max  : unsigned(pulses_counter'range)  := ('1', others   => '0');
  signal samples_counter     : unsigned(7 downto 0)            := (others        => '0');
  signal samples_counter_max : unsigned(samples_counter'range) := (others        => '1');
  signal DAC_counter         : unsigned(4 downto 0)            := (others        => '0');
  signal DAC_counter_max     : unsigned(DAC_counter'range)     := ("111", others => '0');
  signal RST                 : std_logic_vector(2 downto 0)    := (others        => '1');
  signal CLK                 : std_logic                       := '0';
  signal start_pulse         : std_logic;
  signal data_serial         : std_logic_vector(nbre_DACS_used - 1 downto 0);
  signal CLK_serial          : std_logic_vector(2 downto 0);
  signal transfer_serial     : std_logic_vector(1 downto 0);
  signal update_serial       : std_logic_vector(0 downto 0);

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
            samples_counter <= (others => '0');
            pulses_counter  <= pulses_counter + 1;
            start_pulse     <= '1';
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
      CLK                => CLK,
      RST                => RST(RST'low),
      start              => start_pulse,
--! TEMPORARY
      priv_amplitude_new => ("011", others => '0'),
      --! TODO set the inputs amplitude and the volume
      data_serial        => data_serial,
      CLK_serial         => CLK_serial,
      transfer_serial    => transfer_serial,
      update_serial      => update_serial
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
          DAC_numbers          => 4,
          data_bits            => 6);
    end for;
  end for;
end configuration pulses_bundle_test_default_controler;
