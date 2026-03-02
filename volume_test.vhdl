library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number,
  work.volume_package.all;


entity Volume_sequencer_test is
end entity Volume_sequencer_test;

architecture arch of Volume_sequencer_test is
  signal CLK                        : std_logic                            := '0';
  signal RST                        : std_logic                            := '1';
  signal start_frame                : std_logic;
  signal ready                      : std_logic;
  signal counter_inside_frame       : unsigned(4 downto 0)                 := (others => '0');
  constant counter_inside_frame_max : unsigned(counter_inside_frame'range) := (others => '1');
  signal counter_channel            : unsigned(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0)
    := (others => '0');
  constant counter_channel_max      : unsigned(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0) :=
    to_unsigned(channels_number - 1, counter_channel'length);
  signal counter_frame           : unsigned(2 downto 0)          := (others => '0');
  constant counter_frame_max     : unsigned(counter_frame'range) := (others => '1');
  signal RAM_addr_high           : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
  signal RAM_addr_low            : std_logic_vector(1 downto 0);
  signal RAM_read                : std_logic;
  signal RAM_write               : std_logic;
  signal request_amplitude_store : std_logic;

begin

  main_proc : process is
  begin
    if counter_frame /= counter_frame_max then
      CLK_IF : if CLK = '1' then
        if counter_inside_frame /= counter_inside_frame_max then
          counter_inside_frame <= counter_inside_frame + 1;
          start_frame          <= '0';
        else
          RST                  <= '0';
          counter_inside_frame <= (others => '0');
          start_frame          <= '1';
          if counter_channel /= counter_channel_max then
            counter_channel <= counter_channel + 1;
          else
            counter_channel <= (others => '0');
          counter_frame        <= counter_frame + 1;
          end if;
        end if;
      end if CLK_IF;
      CLK <= not CLK;
      wait for 50 ns;
    else
      wait;
    end if;
  end process main_proc;

  Volume_sequencer_instanc : Volume_sequencer
    port map(
      CLK,
      RST,
      start_frame,
      ready => open,
      start_amplitude => open,
      RAM_addr_high => open,
      RAM_addr_low => open,
      RAM_read => open,
      RAM_write => open,
      request_amplitude_store => request_amplitude_store,
      requested_volume_oper => open,
      requested_amplitude_update => open
      );

end architecture arch;
