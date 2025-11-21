library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.DAC_package.all;

entity DAC_test is

end entity DAC_test;



architecture arch of DAC_test is
  signal CLK                    : std_logic                                   := '0';
  -- The DAC data size is added by 1 in order to include the protocol and the command
  signal DAC_counter            : unsigned(DAC_data_size + 1 - 1 downto 0)    := (others => '0');
  signal DAC_counter_max        : unsigned(DAC_counter'range)                 := (others => '1');
  -- TODO compute the minimum number of bits accroding with the channel size
  constant channel_counter_bits : positive                                    := 2;  -- 2 for 4 channels
  -- The channel counter selects which one is to set and the shifts of the data
  signal channel_counter        : unsigned(channel_counter_bits - 1 downto 0) := (others => '0');
  signal channel_counter_max    : unsigned(channel_counter'range) :=
    to_unsigned(channels_number - 1, channel_counter'length);
  -- The data size is added by 1 in order to have a "carry" bit
  -- The data size is added by 2 in order to have 4 windows for 4 channels
  signal data_counter : unsigned(1 + data_size + channels_number - 1 downto 0) := (others => '0');
  signal data_counter_max : unsigned(data_counter'range) := (data_counter'high    => '1',
                                                             data_counter'low + 2 => '1',
                                                             others               => '0');
  signal data_absolute_value : std_logic_vector(data_size - 1 downto 0);
  signal polar_pos_not_neg   : std_logic;
  signal EN                  : std_logic_vector(channels_number - 1 downto 0);
  signal RST                 : unsigned(20 downto 0) := (others => '1');
  signal the_start           : std_logic;
  signal data_serial         : std_logic_vector (8 downto 8);
  signal CLK_serial          : std_logic_vector (0 downto 1);
  signal transfer_serial     : std_logic_vector (5 downto 6);
  signal update_serial       : std_logic_vector (5 downto 6);

begin

-- GHDL 5 does not accept (xyz'high => '1', others => '0')
  -- claiming xyz'high is not constant
--  main_counter_max(main_counter'high)             <= '1';
  --main_counter_max(main_counter'high - data_size) <= '1';

  main_proc : process is
    variable EN_var : std_logic_vector(EN'range);
  begin
    if data_counter /= data_counter_max then
      RST(RST'high - 1 downto RST'low) <= RST(RST'high downto RST'low+1);
      RST(RST'high)                    <= '0';
      CLK_IF : if CLK = '1' then
        if DAC_counter = to_unsigned(0, DAC_counter'length) then
          DAC_counter                                      <= to_unsigned(1, DAC_counter'length);
          EN_var                                           := (others => '0');
          EN_var(EN_var'low + to_integer(channel_counter)) := '1';
          EN                                               <= EN_var;
        elsif DAC_counter = to_unsigned(1, DAC_counter'length) then
          DAC_counter <= to_unsigned(2, DAC_counter'length);
          EN          <= (others => '0');
          the_start   <= '1';
        elsif DAC_counter /= DAC_counter_max then
          the_start   <= '0';
          DAC_counter <= DAC_counter + 1;
        else
          DAC_counter       <= (others => '0');
                                        -- Get the sign
          polar_pos_not_neg <= data_counter(data_counter'high - 1);
                                        -- Get the data while shifting according to the current channel number
          data_absolute_value <= std_logic_vector(
            data_counter(data_counter'low + to_integer(channel_counter) + data_absolute_value'length - 1 downto
                         data_counter'low + to_integer(channel_counter)));
                                        -- Increment the upper level
          if channel_counter /= channel_counter_max then
            channel_counter <= channel_counter + 1;
          else
            channel_counter <= (others => '0');
            data_counter    <= data_counter + 1;
          end if;
        end if;
      end if CLK_IF;
      CLK <= not CLK;
      wait for 100 ns;
    else
      wait;
    end if;
  end process main_proc;



  DAC_bundle_instanc : DAC_bundle_dummy
    port map (
      CLK,
      polar_pos_not_neg,
      data_in         => data_absolute_value,
      EN              => EN,
      RST_init        => RST(RST'low),
      start           => the_start,
      data_serial     => data_serial,
      CLK_serial      => CLK_serial,
      transfer_serial => transfer_serial,
      update_serial   => update_serial
      );


end architecture arch;



configuration DAC_default_controler of DAC_test is
  for arch
    for DAC_bundle_instanc : DAC_bundle_dummy
      use entity work.DAC_bundle_real_outputs;
    end for;
  end for;

end configuration DAC_default_controler;
