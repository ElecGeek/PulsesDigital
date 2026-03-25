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
    start_vol_ampl_product     : out std_logic;
    RAM_addr_high              : out std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
--! Which data
    RAM_addr_low               : out std_logic_vector(1 downto 0);
    RAM_read                   : out std_logic;
    RAM_write                  : out std_logic;
    requested_volume_oper      : out std_logic_vector(2 downto 0);
    requested_amplitude_update : out std_logic;
    computed_volume_writeback  : out std_logic;
    requested_BCD_2_bin        : out std_logic_vector(1 downto 0);
    end_super_frame            : out std_logic
    );

end entity Volume_sequencer;

architecture arch of Volume_sequencer is
  signal sequencer_state : std_logic_vector(4 downto 0);
begin
  assert channels_number > 1 report "The number of channels should be at least 2" severity failure;

  main_proc : process (CLK)
  begin
    if rising_edge(CLK) then
      RST_if : if RST = '0' then
        case sequencer_state is
          when "00001" | "00100" | "00111" =>
            RAM_read <= '1';
            if sequencer_state = "00111" then
              requested_volume_oper <= "101";
            end if;
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "00010" | "00101" | "01000" =>
            RAM_read <= '0';
            case sequencer_state is
              when "00010" => requested_volume_oper <= "010";
              when "00101" => requested_volume_oper <= "011";
              when "01000" =>
                requested_volume_oper      <= "110";
                requested_amplitude_update <= '1';
              when others => null;
            end case;
            sequencer_state <= std_logic_vector(unsigned(sequencer_state) + 1);
          when "00011" =>
            -- Now set the address to read the mute-stored volume
            RAM_addr_low          <= "01";
            requested_volume_oper <= "000";
            sequencer_state       <= "00100";
          when "00110" =>
            -- Now set the address to read the amplitude
            RAM_addr_low          <= "10";
            requested_volume_oper <= "100";
            sequencer_state       <= "00111";
          when "01001" =>
            requested_amplitude_update <= '0';
            sequencer_state            <= "01010";
          when "01010" =>
            requested_BCD_2_bin <= "01";
            -- write back the amplitude, the address low is already OK
            RAM_write           <= '1';
            sequencer_state     <= "01011";
          when "01011" =>
            RAM_write           <= '0';
            -- Now the BCD handler shows the new actual volume
            -- Save into the BCD working register
            requested_BCD_2_bin <= "10";
            sequencer_state     <= "01100";
          when "01100" =>
            -- Now prepare for the current amplitude write back
            RAM_addr_low        <= "00";
            requested_BCD_2_bin <= "11";
            sequencer_state     <= "01101";
          when "01101" =>
            -- Now the volume is ready,
            -- start the multiplication
            requested_BCD_2_bin    <= "00";
            RAM_write              <= '1';
            start_vol_ampl_product <= '1';
            sequencer_state        <= "01110";
          when "01110" =>
            start_vol_ampl_product <= '0';
            RAM_write              <= '0';
            -- multiplication, RAM and BCD to binary have already stored,
            -- Now the volume handler shows the stored volume
            requested_volume_oper  <= "111";
            sequencer_state        <= "01111";
          when "01111" =>
            RAM_addr_low          <= "01";
            requested_volume_oper <= "000";
            sequencer_state       <= "10000";
          when "10000" =>
            RAM_write       <= '1';
            sequencer_state <= "10001";
          when "10001" =>
            RAM_write       <= '0';
            sequencer_state <= "10010";
          when "10010" =>
            RAM_addr_low    <= "00";
            sequencer_state <= "00000";
          -- addr register with the register divided by 8
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
              sequencer_state <= "00001";
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
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.Pulse_amplitude_record,
  work.DAC_package.channels_number;

entity Volume_bundle is
  generic (
    bcd_volume_size                : positive := 8;
    bin2bcd_extra_computation_bits : natural  := 2
    );
  port (
    CLK                     : in  std_logic;
    volume_which_channel    : in  std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    volume_change_action    : in  std_logic_vector(2 downto 0);
    amplitude_which_channel : in  std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    new_amplitude_requested : in  std_logic_vector(requested_amplitude_size - 1 downto 0);
    amplitude_out           : out Pulse_amplitude_record;
    --! This is updated only when the channel number request matches
    --! Then it is to be taken around the end of the super frame.
    BCD_volume_display      : out std_logic_vector
    );

end entity Volume_bundle;


architecture arch of Volume_bundle is
  constant RAM_data_size           : positive := maximum(requested_amplitude_size, bcd_volume_size);
--  constant RAM_padding : std_logic_vector( RAM_data_size - counter_length + state_length + 1 - 1 downto 0 ) :=
--    ( others => '-' );
  constant RAM_addr_size           : positive := 4 * StateNumbers_2_BitsNumbers(channels_number);
  signal RAM_addr_high             : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
  signal RAM_addr_low              : std_logic_vector(1 downto 0);
  signal RAM_write_struct          : std_logic_vector(RAM_data_size - 1 downto 0);
  signal RAM_read_struct           : std_logic_vector(RAM_write_struct'range);
  type RAM_t is array(0 to 2 ** RAM_addr_size - 1) of std_logic_vector(RAM_write_struct'range);
  signal the_RAM                   : RAM_t;
  signal RAM_read                  : std_logic;
  signal RAM_write                 : std_logic;
  signal amplitude_process         : std_logic;
  signal computed_volume_writeback : std_logic;
  signal current_channel           : std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
  --! Channel match.\n
  --! It is stable after one CLK cycle, however no module need it immediately
  --!   after the channel number change at the frame change. 
  signal does_channel_matches      : std_logic;
begin  -- architecture arch

  main_proc : process(CLK) is
  begin
    CLK_IF : if rising_edge(CLK) then
      if amplitude_which_channel = current_channel then
        does_channel_matches <= '1';
      else
        does_channel_matches <= '0';
      end if;
      R_W_if : if RAM_read = '1' then
        RAM_read_struct <= the_RAM(to_integer(unsigned(RAM_addr_high) & unsigned(RAM_addr_low)));
      elsif RAM_write = '1' then

      elsif amplitude_process = '1' then
        if does_channel_matches then
          RAM_write_struct <= new_amplitude_requested;
        else
          RAM_write_struct <= RAM_read_struct;
        end if;
      elsif computed_volume_writeback = '1' then
      -- RAM_write_struct <=        
      end if R_W_if;
    end if CLK_IF;
  end process main_proc;

end architecture arch;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;

entity volume_BCD_request is
  port (
    CLK                  : in  std_logic;
    RST                  : in  std_logic;
--!
    does_channel_matches : in  std_logic;
    action               : in  std_logic_vector(2 downto 0);
    volumes_input        : in  std_logic_vector;
    mute_recover_in      : in  std_logic;
--! speed of up and down. See in the package for details 
    speed                : in  std_logic_vector;
--! 00 = idle, 01 = mute, 10 = down, 11 = up
--! In case of mute, speed=0 mute one, speed > 0 mute all
    request              : in  std_logic_vector(1 downto 0);
    volumes_output       : out std_logic_vector;
    mute_recover_out     : out std_logic
    );
end entity volume_BCD_request;

architecture arch of volume_BCD_request is
  type BCD_type is array(integer range<>) of std_logic_vector(3 downto 0);
  signal stored_volume  : std_logic_vector(volumes_input'range);
  signal mute_recover   : std_logic;
  --! The internals is a vector of the volume size
  --!   if multiple of 4 or ceiled to the next multiple of 4
  signal volume_working : std_logic_vector(4 * ((volumes_input'length + 3) / 4) - 1 downto 0);
  signal volume_add_sub : std_logic_vector(volume_working'range);
begin
  assert volumes_input'length = volumes_output'length
    report "The size of the input volume vector ( " & integer'image(volumes_input'length) & ")" &
    " should be the same than the output volume vector (" & integer'image(volumes_output'length) & ")"
    severity failure;
  assert speed'length > 1
    report "The power 2 of the size of the speed vector ( " & integer'image(speed'length) & ")" &
    " should be at least 1"
    severity failure;
  assert (4*2**speed'length/3-3) <= ( volumes_input'length - 2 )
    report "The power 2 of the size the the speed vector (" & integer'image(speed'length) & ") " &
    "is extravagant against the size of the volume vector (" & integer'image(volumes_input'length) & ")"
    severity warning;
  assert (4*2**speed'length/3+3) >= ( volumes_input'length - 2 )
    report "The power 2 of the size the the speed vector (" & integer'image(speed'length) & ") " &
    "is low against the size of the volume vector (" & integer'image(volumes_input'length) & ")"
    severity warning;

  volumes_output <= volume_working(volume_working'high downto volume_working'high - volumes_output'length + 1);

-- TEMP TEMP TEMP
  volume_add_sub <= X"200";
  
  main_proc : process (CLK) is
    variable ind_8_4_2_1      : integer;
    variable op_A, op_B, op_S : signed(4 downto 0);
  begin  -- process main_proc
    if rising_edge(CLK) then
      ACTION_CASE : case action is
        when "010" =>
          volume_working <= (volumes_input, others => '0');
        when "011" =>
          stored_volume <= volumes_input;
          mute_recover  <= mute_recover_in;
        when "100" =>
          REQUEST_CASE : case request is
            when "01" =>
              -- Does the mute concerns here?
              if does_channel_matches = '1' or or(speed) = '1' then

-- TEMP TEMP TEMP


              -- else NULL
              end if;
            when "10" | "11" =>
              if does_channel_matches = '1' then
                -- Since only one digit is changed at a time,
                -- the digits are add or subtracted individually
                for ind in 0 to volume_working'length / 4 - 1 loop
                  op_A := ("0", signed(volume_working(volume_working'low + (ind + 1) * 4 - 1 downto
                                                        volume_working'low + ind * 4)));
                  op_B := ("0", signed(volume_add_sub(volume_add_sub'low + (ind + 1) * 4 - 1 downto
                                                        volume_add_sub'low + ind * 4)));
                  if request = "10" then
                    op_S := op_A + op_B;
                  else
                    op_S := op_A - op_B;
                  end if;
                  volume_working(volume_working'low + (ind + 1) * 4 - 1 downto
                                 volume_working'low + ind * 4) <=
                    std_logic_vector ( op_S(3 downto 0));
                end loop;
              end if;
            when others =>
              null;
          end case REQUEST_CASE;
        when "101" =>
          null;
        when "110" =>
          -- Last step: if > 9..9 or < 0, set this value to 9..9 or 0
          -- Since the speed on the high digit can not be more than 2
          --   only the values $A, $B are reachable if the volume goes up and
          --   only the values $F, $E are reachable if the volume goes down
          -- $C and $D can normally noit be reached, the volume is reset
          if volume_working(volume_working'high downto volume_working'high - 2) = "101" then
            ind_8_4_2_1 := 1;
            for ind in volume_working'high downto volume_working'low loop
              if ind_8_4_2_1 = 0 or ind_8_4_2_1 = 1 then
                volume_working(ind) <= '1';
              else
                volume_working(ind) <= '0';
              end if;
              if ind_8_4_2_1 > 2 then
                ind_8_4_2_1 := 0;
              else
                ind_8_4_2_1 := ind_8_4_2_1 + 1;
              end if;
            end loop;
          elsif volume_working(volume_working'high downto volume_working'high - 2) = "110" or
            volume_working(volume_working'high downto volume_working'high - 2) = "111" then
            volume_working <= (others => '0');
          end if;
        when "111" =>
          volume_working <= (stored_volume, others => '0');
        when others =>
          null;
      end case ACTION_CASE;
    end if;
  end process main_proc;

end architecture arch;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number,
  work.Amplitude_package.global_volume_size;

--! @brief Converts the BCD value into binary
--!
--! 

entity volume_BCD_2_binary is
  generic (
    extra_computation_bits : natural := 2);
  port (
    CLK                 : in  std_logic;
    RST                 : in  std_logic;
    requested_BCD_2_bin : in  std_logic_vector(1 downto 0);
    volume_BCD          : in  std_logic_vector;
    volume_binary       : out std_logic_vector(global_volume_size - 1 downto 0)
    );
end entity volume_BCD_2_binary;


architecture arch of volume_BCD_2_binary is
  signal the_result  : std_logic_vector(volume_binary'length + extra_computation_bits - 1 downto 0);
  signal the_operand : std_logic_vector(the_result'range);
begin  -- architecture arch

  assert volume_BCD'length > 4
    report "The size of the BCD volume (" & integer'image(volume_BCD'length) &
    ") should be at least 5 (one digit and half)"
    severity error;
  assert volume_BCD'length mod 4 = 0 or volume_BCD'length mod 4 = 1
    report "It is discourageous to have a BCD volume (" & integer'image(volume_BCD'length) &
    ") not multiple of 4 (entire digits) or multiple of 4 +1 (entire digits + 1/2)"
    severity warning;
  assert volume_BCD'length mod 4 /= 0 report "Instantiating the volume BCD to binary conversion with exactly " &
    integer'image(volume_BCD'length / 4) & " BCD digits, " &
    integer'image(volume_binary'length) & " output bits, " &
    integer'image(extra_computation_bits) & " extra computation bits."
    severity note;
  assert volume_BCD'length mod 4 = 0 report "Instantiating the volume BCD to binary conversion " &
    integer'image(volume_BCD'length / 4) & " BCD digits and a " &
    "and 1/" & integer'image(2 ** (volume_BCD'length mod 4)) & ", " &
    integer'image(volume_binary'length) & " output bits, " &
    integer'image(extra_computation_bits) & " extra computation bits."
    severity note;

  volume_binary <= the_result(the_result'high downto the_result'high - volume_binary'length + 1);

  main_proc : process (CLK) is
    variable ind_sce  : integer;
    variable result_v : std_logic_vector(the_result'range);
  begin  -- process main_proc
    if rising_edge(CLK) then            -- rising clock edge
      case requested_BCD_2_bin is
        when "01" =>
          ind_sce := volume_BCD'high;
          for ind_dest in result_v'high downto result_v'low loop
            result_v(ind_dest) := volume_BCD(ind_sce);
            if ind_sce > volume_BCD'low then
              ind_sce := ind_sce - 1;
            else
              ind_sce := volume_BCD'high;
            end if;
          end loop;
          the_result                    <= result_v;
          the_operand(the_operand'high) <= '0';
          the_operand(the_operand'high - 1 downto the_operand'low) <=
            result_v(result_v'high downto result_v'low + 1);
        when "10" =>
          the_result                                                    <= std_logic_vector(unsigned(the_result) + unsigned(the_operand));
          -- the_operand( the_operand'high ) is already '0', the the shift is
          -- 0 x y z t   to
          -- 0 0 0 x y
          the_operand(the_operand'high - 1 downto the_operand'high - 2) <= "00";
          the_operand(the_operand'high - 3 downto the_operand'low) <=
            result_v(the_operand'high - 1 downto the_operand'low + 2);
        when "11" =>
          the_result <= std_logic_vector(unsigned(the_result) + unsigned(the_operand));
        when others => null;
      end case;
    end if;
  end process main_proc;

end architecture arch;
