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
  constant counter_channel_max : unsigned(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0) :=
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
            counter_frame   <= counter_frame + 1;
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
      ready                      => open,
      start_vol_ampl_product     => open,
      RAM_addr_high              => open,
      RAM_addr_low               => open,
      RAM_read                   => open,
      RAM_write                  => open,
      requested_volume_oper      => open,
      requested_amplitude_update => open,
      computed_volume_writeback  => open
      );

end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.amplitude_package.global_volume_size,
  work.volume_package.all;


entity Volume_BCD_2_bin_test is
  generic (
    extra_computation_bits : natural := 3);
end entity Volume_BCD_2_bin_test;

architecture arch of Volume_BCD_2_bin_test is
  signal CLK                                   : std_logic                             := '0';
  signal RST                                   : std_logic                             := '1';
  signal main_counter                          : std_logic_vector(11 downto 0)         := (others => '0');
  signal main_counter_max                      : std_logic_vector(main_counter'range)  := (others => '1');
  signal opcode_counter                        : std_logic_vector(1 downto 0)          := "00";
  signal output_binary                         : std_logic_vector(global_volume_size - 1 downto 0);
  signal output_if_BCD                         : std_logic_vector(output_binary'range);
  signal output_if_BCD_max                     : std_logic_vector(output_binary'range) := (others => '0');
  signal output_if_BCD_last                    : std_logic_vector(output_binary'range) := (others => '0');
  signal output_incr, output_decr, output_same : natural                               := 0;
  constant digit_max                           : unsigned(3 downto 0)                  := "1001";  --  9 !
begin
  main_proc : process is
    variable ind_9         : integer;
    variable digit_extract : natural;
    variable is_BCD        : boolean;
  begin
    if main_counter /= main_counter_max then
      CLK_IF : if CLK = '1' then
        if opcode_counter = "01" or opcode_counter = "10" then
          opcode_counter <= std_logic_vector(unsigned(opcode_counter) + 1);
        elsif opcode_counter = "11" then
          -- The choice is to try all the possible numbers but verify only on the valid BCD
          opcode_counter <= (others => '0');
          is_BCD         := true;
          digit_extract  := 0;
          ind_9          := 0;
          BCD_check : for ind_val in main_counter'high downto main_counter'low loop
            digit_extract := digit_extract * 2;
            if main_counter(ind_val) = '1' then
              digit_extract := digit_extract + 1;
            end if;
            if ind_9 < 3 then
              ind_9 := ind_9 + 1;
            else
              ind_9 := 0;
              if digit_extract > 9 then
                is_BCD := false;
              end if;
              digit_extract := 0;
            end if;
          end loop BCD_check;
          if is_BCD then
            output_if_BCD      <= output_binary;
            output_if_BCD_last <= output_binary;
            -- Get the highest reachable value
            -- for the amplitude and the pulse gene part of the project 
            if output_binary > output_if_BCD_max then
              output_if_BCD_max <= output_binary;
            end if;
            -- One verification point if to check
            --   if a higher BCD gives an higher binary.
            -- Calculating against a model and comparing has always an error margin.
            -- This property may be "lost" in the margin.
            if to_integer(unsigned(output_binary)) > to_integer(unsigned(output_if_BCD_last)) then
              output_incr <= output_incr + 1;
            elsif to_integer(unsigned(output_binary)) > to_integer(unsigned(output_if_BCD_last)) then
              output_decr <= output_decr + 1;
            else
              output_same <= output_same + 1;
            end if;
          else
            -- For wave viewer only, tells this one is excluded
            output_if_BCD <= (others => 'Z');
          end if;
        else
          RST            <= '0';
          opcode_counter <= std_logic_vector(unsigned(opcode_counter) + 1);
          if RST = '0' then
            main_counter <= std_logic_vector(unsigned(main_counter) + 1);
          end if;
        end if;
      end if CLK_IF;
      CLK <= not CLK;
      wait for 1 ps;
    else
      assert output_decr /= 0 report "Volume BCD to binary increases " & integer'image(output_incr) &
        " times and is stable " & integer'image(output_same) & " times"
        severity note;
      assert output_decr = 0 report "Volume BCD to binary increases " & integer'image(output_incr) &
        " times, DECREASES " & integer'image(output_decr) &
        " times and is stable " & integer'image(output_same) & " times"
        severity error;
      assert false
        report "Volume BCD to binary maximum value: 0x" & to_hstring(output_if_BCD_max)
        severity note;

      wait;
    end if;
  end process main_proc;

  volume_BCD_2_binary_instanc : volume_BCD_2_binary
    generic map (
      extra_computation_bits => extra_computation_bits)
    port map (
      CLK,
      RST,
      requested_BCD_2_bin => opcode_counter,
      volume_BCD          => main_counter,
      volume_binary       => output_binary
      );


end architecture arch;
