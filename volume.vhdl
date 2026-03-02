library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;
entity Volume_sequencer is

  port (
    --! Master clock
    CLK                        : in  std_logic;
    RST                        : in  std_logic;
--!
    start_frame                : in  std_logic;
--! The frame is over
    ready                      : out std_logic;
    start_amplitude            : out std_logic;
    RAM_addr_high              : out std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
--! Which data
    RAM_addr_low               : out std_logic_vector(1 downto 0);
    RAM_read                   : out std_logic;
    RAM_write                  : out std_logic;
    request_amplitude_store    : out std_logic;
    requested_volume_oper      : out std_logic_vector(1 downto 0);
    requested_amplitude_update : out std_logic;
    requested_BCD_2_bin        : out std_logic_vector(1 downto 0);
    end_super_frame            : out std_logic
    );

end entity Volume_sequencer;

architecture arch of Volume_sequencer is
  signal sequencer_state : std_logic_vector(3 downto 0);
begin
  assert channels_number > 1 report "The number of channels should be at least 2" severity failure;

  main_proc : process (CLK)
  begin
    if rising_edge(CLK) then
      RST_if : if RST = '0' then
        case sequencer_state is
          when "0001" =>
            RAM_read        <= '1';
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0010" =>
            RAM_read              <= '0';
            -- Save into the BCD working register
            requested_volume_oper <= "01";
            sequencer_state       <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0011" =>
            -- Start the BCD processing if so
            requested_volume_oper <= "10";
            -- Set the address for the requested amplitude
            RAM_addr_low          <= "01";
            sequencer_state       <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0100" =>
            RAM_read              <= '1';
            -- Continue the BCD processing
            requested_volume_oper <= "11";
            sequencer_state       <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "0101" =>
            -- Continue the BCD processing
            requested_volume_oper      <= "00";
            requested_amplitude_update <= '1';
            RAM_read                   <= '0';
            sequencer_state            <= std_logic_vector(unsigned(sequencer_state) + 1);
            requested_BCD_2_bin <= "01";
          when "0110" =>
            -- store in the 2 registers
            requested_amplitude_update <= '0';
            sequencer_state            <= std_logic_vector(unsigned(sequencer_state) + 1);
            requested_BCD_2_bin <= "10";
          when "0111" =>
            RAM_write       <= '1';
            -- add register with the register divided by 2
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
            requested_BCD_2_bin <= "11";
          when "1000" =>
            -- addr register with the register divided by 8
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
            RAM_write       <= '0';
            requested_BCD_2_bin <= "00";
          when "1001" =>
            RAM_addr_low    <= "00";
            -- addr register with the register divided by 8
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
            start_amplitude <= '1';
          when "1010" =>
            RAM_addr_low    <= "00";
            -- addr register with the register divided by 8
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
            RAM_write       <= '1';
            start_amplitude <= '0';
          when "1011" =>
            RAM_addr_low    <= "00";
            -- addr register with the register divided by 8
            sequencer_state <= "0000";
            RAM_write       <= '0';

-- In fact $0000
          when others =>
            NEW_READY_IF : if ready = '0' then
              if RAM_addr_high /= std_logic_vector(to_unsigned(channels_number - 1, RAM_addr_high'length)) then
                RAM_addr_high <= std_logic_vector(unsigned(RAM_addr_high) + 1);
              else
                RAM_addr_high <= (others => '0');
              end if;
            end if NEW_READY_IF;
            if start_frame = '1' then
              ready           <= '0';
              sequencer_state <= "0001";
            else
              ready <= '1';
            end if;
        end case;
      else
        ready           <= '0';
        sequencer_state <= (others => '0');
        RAM_addr_high   <= (others => '0');
      end if RST_IF;
    end if;
  end process main_proc;
end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;

entity Volume_bundle is
  port (
    volume_change : in  std_logic_vector(2 downto 0);
    BCD_volume    : out std_logic
    );

end entity Volume_bundle;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;

entity volume_BCD_request is
  port (
    CLK        : in  std_logic;
    RST        : in  std_logic;
--!
    load       : in  std_logic;
    actual_vol : in  std_logic_vector;
    speed      : in  std_logic_vector;
    --! 00 = idle, 01 = mute, 10 = down, 01 = up
    --! In case of mute, speed=0 mute one, speed > 0 mute all
    request    : in  std_logic_vector(1 downto 0);
    output_vol : out std_logic_vector
    );
end entity volume_BCD_request;

architecture arch of volume_BCD_request is
  type BCD_type is array(integer range<>) of std_logic_vector(3 downto 0);
  signal the_BCD  : BCD_type(1 downto 0);
  signal temp_BCD : std_logic_vector(actual_vol'range);
begin  -- architecture arch


-- TEMP TEMP TEMP

  main_proc : process (CLK) is
  begin  -- process main_proc
    if rising_edge(CLK) then
      case request is
        when "01" =>
          temp_BCD <= actual_vol;
        when "10" =>
          if request = "10" then
            temp_BCD <= (others => '0');
          end if;
        when "11" =>
          output_vol <= temp_BCD;
        when others => null;
      end case;
    end if;
  end process main_proc;

end architecture arch;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;

entity amplitude_request is
  port (
    CLK                 : in  std_logic;
    RST                 : in  std_logic;
    request             : in  std_logic;
    --! Channel currently modified
    --! It should be stable during the super frame.
    which_channel       : in  std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    amplitude_in        : in  std_logic_vector;
    amplitude_requested : in  std_logic_vector;
    amplitude_out       : out std_logic_vector
    );
end entity amplitude_request;
