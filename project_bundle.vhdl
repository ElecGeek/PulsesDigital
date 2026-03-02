library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.Dac_package.channels_number,
  work.Amplitude_package.Pulse_amplitude_record,
  work.Amplitude_package.Pulse_start_vector;


entity Project_bundle is
  generic (
    MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 22
    );
  port (
    --! Master clock
    CLK : in std_logic;
    RST : in std_logic;


    which_channel : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    the_amplitude : std_logic_vector(15 downto 0);

    enable         : std_logic_vector(3 downto 0);
    polarity_first : std_logic_vector(3 downto 0);



    --! The amplitude is involved in the frame end as well, at least for testing
    ready_amplitude : in  std_logic;
    --! The amplitude is involved in the frame end as well, at least for testing
    start_frame     : out std_logic;
    --! Dac interfaces
    data_serial     : out std_logic_vector(1 downto 0);
    CLK_serial      : out std_logic_vector(1 downto 0);
    transfer_serial : out std_logic_vector(1 downto 0);
    update_serial   : out std_logic_vector(1 downto 0)
    );
end entity Project_bundle;


architecture arch of Project_bundle is
  --! coming from the amplitude
  signal pulse_amplitude_data : pulse_amplitude_record;
  --! coming from the amplitude
  signal pulse_start_data     : pulse_start_vector;

  component Pulses_bundle is
    generic (
      MasterCLK_SampleCLK_ratio : integer range 10 to 40 := 22
      );
    port (
      --! Master clock
      CLK                  : in  std_logic;
      RST                  : in  std_logic;
      --! coming from the amplitude
      pulse_amplitude_data : in  pulse_amplitude_record;
      --! coming from the amplitude
      pulse_start_data     : in  pulse_start_vector;
      --! The amplitude is involved in the frame end as well, at least for testing
      ready_amplitude      : in  std_logic;
      --! The amplitude is involved in the frame end as well, at least for testing
      start_frame          : out std_logic;
      --! Dac interfaces
      data_serial          : out std_logic_vector;
      CLK_serial           : out std_logic_vector;
      transfer_serial      : out std_logic_vector;
      update_serial        : out std_logic_vector
      );
  end component Pulses_bundle;


begin  -- architecture arch

  signals_links : for ind in 0 to 3 generate
    pulse_start_data(ind).enable         <= enable(ind);
    pulse_start_data(ind).polarity_first <= polarity_first(ind);
  end generate signals_links;
  pulse_amplitude_data.which_channel <= which_channel;
  pulse_amplitude_data.the_amplitude <= the_amplitude;

  bundle_instanc : configuration work.DAC_default_controler port map (
    CLK,
    RST,
    pulse_amplitude_data,
    pulse_start_data,
    ready_amplitude,
    start_frame,
    data_serial => data_serial,
    CLK_serial => CLK_serial,
    transfer_serial => transfer_serial,
    update_serial => update_serial);

end architecture arch;


configuration PCB_bundle of Project_bundle is
  for arch
--    for bundle_instanc : Pulses_bundle
--      use configuration work.DAC_default_controler;
--    end for;
  end for;
end configuration PCB_bundle;
