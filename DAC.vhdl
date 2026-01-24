library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.DAC_package.all;


--! Private entity to latch one channel
entity DAC_dummy_channel is
  port (
    CLK               : in std_logic;
    EN                : in std_logic;
    polar_pos_not_neg : in std_logic;
    data_in           : in std_logic_vector(data_size -1 downto 0));
end entity DAC_dummy_channel;

architecture arch of DAC_dummy_channel is
  signal latched_channel : std_logic_vector(data_size downto 0);
begin  -- architecture arch

  main_proc : process (CLK) is
  begin  -- process main_proc
    if rising_edge(CLK) then
      if EN = '1' then
        latched_channel(latched_channel'high - 1 downto latched_channel'low) <=
          data_in xor polar_pos_not_neg;
        latched_channel(latched_channel'high) <= polar_pos_not_neg;
      end if;
    end if;
  end process main_proc;

end architecture arch;
library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.DAC_package.all;

--! This is intended to test the other parts of the project
--! The internal signals latch the input
--!   in order to check the values.
entity DAC_bundle_dummy is
  port(
    CLK               : in  std_logic;
    polar_pos_not_neg : in  std_logic;
    data_in           : in  std_logic_vector(data_size - 1 downto 0);
    EN                : in  std_logic_vector(channels_number - 1 downto 0);
    RST_init          : in  std_logic;
    start             : in  std_logic;
    --! The frame is over
    ready             : out std_logic;
    data_serial       : out std_logic_vector;
    CLK_serial        : out std_logic_vector;
    transfer_serial   : out std_logic_vector;
    update_serial     : out std_logic_vector
    );
end entity DAC_bundle_dummy;

architecture arch of DAC_bundle_dummy is
  component DAC_dummy_channel is
    port (
      CLK               : in std_logic;
      EN                : in std_logic;
      polar_pos_not_neg : in std_logic;
      data_in           : in std_logic_vector(data_size -1 downto 0));
  end component DAC_dummy_channel;
begin
  data_serial_fill : for ind in data_serial'high downto data_serial'low generate
    data_serial(ind) <= 'W';
  end generate;
  CLK_serial_fill : for ind in CLK_serial'high downto CLK_serial'low generate
    CLK_serial(ind) <= 'W';
  end generate;
  transfer_serial_fill : for ind in transfer_serial'high downto transfer_serial'low generate
    transfer_serial(ind) <= 'W';
  end generate;
  update_serial_fill : for ind in update_serial'high downto update_serial'low generate
    update_serial(ind) <= 'W';
  end generate;

  ready <= not start;
  channel_generate : for ind in 0 to channels_number - 1 generate
    DAC_dummy_channel_instanc : DAC_dummy_channel port map(
      CLK,
      EN                => EN(ind),
      polar_pos_not_neg => polar_pos_not_neg,
      data_in           => data_in);
  end generate;

end architecture arch;



library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.DAC_package.all;


--! This is intended to test the other parts of the project
--! The internal signals latch the input
--!   in order to check the values.
entity DAC_bundle_real_outputs is
  port(
    CLK               : in  std_logic;
    polar_pos_not_neg : in  std_logic;
    --! To be passed to the registers modules for the data
    data_in           : in  std_logic_vector(data_size - 1 downto 0);
    --! To be passed to the registers modules for the strobe
    EN                : in  std_logic_vector(channels_number - 1 downto 0);
    --! To be passed to the sequencer for the DAC initialization
    RST_init          : in  std_logic;
    --! To be passed to the sequencer for the start
    start             : in  std_logic;
    --! The frame is over
    ready             : out std_logic;
    --! One bit per DAC circuit
    data_serial       : out std_logic_vector(nbre_DACs_used - 1 downto 0);
    --! One bit or more, depending the PCB
    CLK_serial        : out std_logic_vector;
    --! One bit or more, depending the PCB
    transfer_serial   : out std_logic_vector;
    --! One bit or more, depending the PCB
    update_serial     : out std_logic_vector
    );
end entity DAC_bundle_real_outputs;

architecture arch of DAC_bundle_real_outputs is
  signal registers_control : registers_control_st;
  type registers_chain_st is array(nbre_DACs_used - 1 downto 0) of
    std_logic_vector(nbre_outputs_per_DAC - 1 downto 0);
  signal registers_chain_data  : registers_chain_st := (others => (others => 'W'));
  signal registers_chain_polar : registers_chain_st := (others => (others => 'W'));
  signal CLK_serial_s          : std_logic;
  signal transfer_serial_s     : std_logic;
  signal update_serial_s       : std_logic;
begin
  assert channels_number mod nbre_DACs_used = 0 report
    "The number of channels (" & integer'image(channels_number) &
    ") should be a multiple of the number of DAC circuits (" & integer'image(data_serial'length) & ")"
    severity failure;
  assert nbre_outputs_per_DAC > 0 report
    "Each DAC should have at least one channel. " &
    "The error may be due to the number of channels (" & integer'image(channels_number) &
    ") strictly lower than the number of DACs used (" & integer'image(nbre_DACs_used)
    severity failure;
  assert mode_totempole report "Elaborating " & integer'image(nbre_DACs_used) & " dac(s), " &
    "with " & integer'image(nbre_outputs_per_DAC) & " channels each" severity note;
  assert mode_totempole report "Each output is a positive and negative " &
    "with an offset of (<vector>'high=>'1', others=>'0')" severity note;
  assert not mode_totempole report "Elaborating totem-pole" & integer'image(nbre_DACs_used) & "Dac(s), " &
    "with " & integer'image(2*nbre_outputs_per_DAC) & " channels each" severity note;
  assert not mode_totempole report "Each output is sent to the odd or the even " &
    "output address, according with the polarity" severity note;

  gene_DAC : for ind_DAC in 0 to data_serial'length - 1 generate
    gene_output : for ind_output in 0 to nbre_outputs_per_DAC - 1 generate
      first_in_chain : if ind_output = 0 generate
        Buffer_and_working_registers_first : Buffer_and_working_registers
          generic map (
            register_position => 0,
            DAC_chain_number  => ind_DAC)
          port map (
            CLK                => CLK,
            polar_pos_not_neg  => polar_pos_not_neg,
            data_in            => data_in,
            data_strobe        => EN(ind_DAC * nbre_outputs_per_DAC),
            registers_control  => registers_control,
            chain_data_in      => registers_chain_data(ind_DAC)(0),
            chain_data_out     => open,
            chain_polarity_in  => registers_chain_polar(ind_DAC)(0),
            chain_polarity_out => open,
            data_out           => data_serial(data_serial'low + ind_DAC));
--      else generate
      end generate first_in_chain;
      next_in_chain : if ind_output /= 0 generate
        Buffer_and_working_registers_others : Buffer_and_working_registers
          generic map (
            register_position => ind_output,
            DAC_chain_number  => ind_DAC)
          port map (
            CLK                => CLK,
            polar_pos_not_neg  => polar_pos_not_neg,
            data_in            => data_in,
            data_strobe        => EN(ind_DAC * nbre_outputs_per_DAC + ind_output),
            registers_control  => registers_control,
            chain_data_in      => registers_chain_data(ind_DAC)(ind_output),
            chain_data_out     => registers_chain_data(ind_DAC)(ind_output - 1),
            chain_polarity_in  => registers_chain_polar(ind_DAC)(ind_output),
            chain_polarity_out => registers_chain_polar(ind_DAC)(ind_output - 1),
            data_out           => open);

      --   end generate first_in_chain;
      end generate next_in_chain;
    end generate gene_output;
    -- For debug purpose, set the end of the chain to something different
    --   that should never appear
--    registers_chain_data(ind_DAC)(nbre_outputs_per_DAC - 1) <= '-';
    registers_chain_data(ind_DAC)(nbre_outputs_per_DAC - 1) <= 'W';


  end generate gene_DAC;


  CLK_serial_fill : for ind in CLK_serial'high downto CLK_serial'low generate
    CLK_serial(ind) <= CLK_serial_s;
  end generate;
  transfer_serial_fill : for ind in transfer_serial'high downto transfer_serial'low generate
    transfer_serial(ind) <= transfer_serial_s;
  end generate;
  update_serial_fill : for ind in update_serial'high downto update_serial'low generate
    update_serial(ind) <= update_serial_s;
  end generate;


  Controler_default_instanc : Controler_default
    port map (
      CLK,
      RST_init,
      start,
      ready,
      registers_control,
      CLK_serial      => CLK_serial_s,
      transfer_serial => transfer_serial_s,
      update_serial   => update_serial_s
      );
end architecture arch;

--! Registers management
--! This is a "slave" component.
--! For more information, see the controller.\n
--! There are 2 registers:
--! * The data working register is (parallel) loaded from the data register.
--!   If the mode is not totem-pole, the negative polarity is computed.
--!   If the mode is totem-pole, the data is left as it.
--! * The DAC address low bit is loaded from the polarity.
--!   It the mode is not totem-pole, this bit is never selected by the controller.\n
--! The controller asks:
--! * to take the low address bit, and shift from the previous component
--! * to take the low bit of the working register, to shift it and
--!   to take the low bit of the register of the previous component (chaining).
--! * to set to a predefined value 0, 1 or don't care.
--! The result is latched in a single bit and send to the output.

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.DAC_package.all;

entity Buffer_and_working_registers is
  generic (
    --! Used for multiple output DACs,
    --! In the case of totem-pole, it is the address multiplied by 2, plus one or not
    --!   in case of the polarity.
    --! Otherwise, it is the full address.
    register_position : natural;
    DAC_chain_number  : natural);
  port (
    CLK                : in  std_logic;
    --! Polarity, void if compute_sign is false
    polar_pos_not_neg  : in  std_logic;
    data_in            : in  std_logic_vector(data_size - 1 downto 0);
    --! Load value registers, not the shift registers to convert parallel to serial.
    data_strobe        : in  std_logic;
    --! Run the shifts registers or force to 0, 1 or don't care.
    registers_control  : in  registers_control_st;
    --! Private chain between multiple outputs per DAC 
    chain_data_in      : in  std_logic;
    --! Private chain between multiple outputs per DAC 
    chain_data_out     : out std_logic;
    --! Private chain between multiple outputs per DAC 
    chain_polarity_in  : in  std_logic;
    --! Private chain between multiple outputs per DAC 
    chain_polarity_out : out std_logic;
    --! Sent to the DAC if the first one in the chain, void otherwise.
    data_out           : out std_logic
    );
end entity Buffer_and_working_registers;

architecture arch of Buffer_and_working_registers is
  signal buffer_data_in           : std_logic_vector(data_size - 1 downto 0);
  signal buffer_polar_pos_not_neg : std_logic;

  signal working_register : std_logic_vector(DAC_data_size -1 downto 0);
  signal working_polar    : std_logic;
  signal out_buffer       : std_logic;
begin  -- architecture arch
  assert Negation_fast_not_accurate
    report "The negation is set to the accurate, this is not yet supported"
    severity error;
  assert false
    report "DAC output, instantiating the register of the address " & natural'image(register_position) &
    ", of the DAC " & natural'image(DAC_chain_number)
    severity note;

  chain_data_out     <= working_register(working_register'high);
  chain_polarity_out <= working_polar;

  main_proc : process (CLK) is
    variable ind_buffer : integer;
  begin
    if rising_edge(CLK) then
      if data_strobe = '1' then
        buffer_data_in           <= data_in;
        buffer_polar_pos_not_neg <= polar_pos_not_neg;
      end if;
      case? registers_control is
        when "000" =>
          working_register(working_register'low) <= chain_data_in;
          working_register(working_register'high downto working_register'low + 1) <=
            working_register(working_register'high - 1 downto working_register'low);
          data_out <= working_register(working_register'high);
        when "001" =>
          working_polar <= chain_polarity_in;
          data_out      <= working_polar;
        when "10-" =>
          data_out <= registers_control(0);
        when "110" =>
          data_out <= '-';
        when "111" =>
          data_out <= 'X';
--          data_out <= '-';
        when "01-" =>
          data_out <= registers_control(0);

          if mode_totempole then
            -- The working register is loaded from the buffer as it.
            -- The sizes may differ. A barrel shifting fixes the differences
            -- while keeping a rail to rail.
            ind_buffer := buffer_data_in'high;
            WORKING_LOOP_1 : for ind_working in working_register'high downto working_register'low loop
              working_register(ind_working) <= buffer_data_in(ind_buffer);
              if ind_buffer > buffer_data_in'low then
                ind_buffer := ind_buffer - 1;
              else
                ind_buffer := buffer_data_in'high;
              end if;
            end loop WORKING_LOOP_1;
            -- The polarity register is loaded from the polarity
            -- It is the low DAC address bit.
            -- The controller sets the other in case there are 4 or more
            --   channels in the DAC.
            working_polar <= polar_pos_not_neg;
          elsif buffer_polar_pos_not_neg = '1' then
            working_register(working_register'high) <= '0';
            ind_buffer                              := buffer_data_in'high;
            WORKING_LOOP_2 : for ind_working in working_register'high - 1 downto working_register'low loop
              working_register(ind_working) <= not buffer_data_in(ind_buffer);
              if ind_buffer > buffer_data_in'low then
                ind_buffer := ind_buffer - 1;
              else
                ind_buffer := buffer_data_in'high;
              end if;
            end loop WORKING_LOOP_2;
          -- The polarity is never triggered as the controller
          -- sets all the DAC addresses bits
          else
            working_register(working_register'high) <= '1';
            ind_buffer                              := buffer_data_in'high;
            WORKING_LOOP_3 : for ind_working in working_register'high - 1 downto working_register'low loop
              working_register(ind_working) <= buffer_data_in(ind_buffer);
              if ind_buffer > buffer_data_in'low then
                ind_buffer := ind_buffer - 1;
              else
                ind_buffer := buffer_data_in'high;
              end if;
            end loop WORKING_LOOP_3;
          -- The polarity is never triggered as the controller
          -- sets all the DAC addresses bit.
          end if;

        when others => null;
      end case?;
    end if;
  end process main_proc;

end architecture arch;


--! Controller default. It is a 4 outputs with 2 address bits and 8 data bits.
--! The command string is:
--! 1 0 a1 a0 d7 d6 d5 d4 d3 d2 d1 d0

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.all;

entity Controler_default is
  generic (
    --! Write and update command, vector( m TO n )
    write_and_update_cmd : std_logic_vector := "--11";
    --! Write only command, vector( m TO n )
    write_only_cmd       : std_logic_vector := "--10";
    --! Initialization command, vector( m TO n )
    initialization_cmd   : std_logic_vector := "1010";
    --! Address bits
    address_size         : positive         := 2;
    --! Number of channels per DAC, only for validation
    --!   as this is a part of the DAC definition, not the project definition
    DAC_number_outputs   : positive         := 2;
    --! Device data size.
    --! It may be longer than the device data size.
    --! In such case a padding with don't care is added as
    --!   some devices has a standard interface e.g. for the 12, 14 and 16 bits.
    device_data_size     : positive         := 10
    );
  port (
    CLK               : in  std_logic;
    RST_init          : in  std_logic;
    start             : in  std_logic;
    ready             : out std_logic;
    --! See in the type definition
    registers_control : out registers_control_st;
    CLK_serial        : out std_logic;
    transfer_serial   : out std_logic;
    update_serial     : out std_logic
    );
end entity Controler_default;


architecture arch of Controler_default is
  --! Size of the main counter. 
  constant main_counter_size : natural := StateNumbers_2_BitsNumbers(write_and_update_cmd'length +
                                                                     address_size +
                                                                     device_data_size +
                                                                     3);
  --! Counter to manage the command signal to send one output of the DAC
  signal main_counter : std_logic_vector(main_counter_size - 1 downto 0);
  function TotempoleOutputUsage (
    constant is_totempole : boolean)
    return positive is
  begin
    if is_totempole then
      return 2;
    else
      return 1;
    end if;
  end function TotempoleOutputUsage;
  --! Counter to manage the address in case there is more
  --!   than one output per DAC to handle.
  signal address_counter       : std_logic_vector(address_size - 1 downto 0);
  constant address_counter_min : std_logic_vector(address_counter'range) := (others => '0');
  constant address_counter_max : std_logic_vector(address_counter'range) :=
    std_logic_vector(to_unsigned(DAC_number_outputs / TotempoleOutputUsage(mode_totempole) - 1,
                                 address_counter'length));
  signal is_initialised : std_logic;
begin  -- architecture arch
  assert DAC_number_outputs <= 2**address_size report "The number of address bits (" & positive'image(address_size) &
                               ") is not enough for " & positive'image(DAC_number_outputs) & " DAC outputs"
                               severity failure;
  assert DAC_data_size <= device_data_size report "The device data size (" & positive'image(device_data_size) &
                          ") should not be smaller than the DAC data size (" & positive'image(DAC_data_size) & ")"
                          severity failure;
  assert write_and_update_cmd'length = write_only_cmd'length report
    "The size of the command write and update (" & integer'image(write_and_update_cmd'length) &
    ") should be equal to the write only(" & integer'image(write_only_cmd'length) & ")"
    severity failure;
  assert initialization_cmd'length = write_only_cmd'length or initialization_cmd'length = 0 report
    "The size of the command initialize (" & integer'image(initialization_cmd'length) &
    ") should be equal to the write only(" & integer'image(write_only_cmd'length) & ")"
    severity failure;
  assert write_and_update_cmd'ascending and write_only_cmd'ascending report
    "The commands with and without updates are defined big endian in an ascending vector" severity error;
  assert mode_totempole or
    nbre_outputs_per_DAC >= DAC_number_outputs
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than " & positive'image(DAC_number_outputs) & ", some DAC outputs are lost" severity warning;
  assert mode_totempole or
    nbre_outputs_per_DAC <= DAC_number_outputs
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than " & positive'image(DAC_number_outputs) & ", some project outputs are lost" severity error;
  assert mode_totempole or
    nbre_outputs_per_DAC /= DAC_number_outputs
    report "Instantiating a set/one DAC with " & positive'image(DAC_number_outputs) & " outputs in not totem-pole mode"
    severity note;
  assert not mode_totempole or
    nbre_outputs_per_DAC >= (DAC_number_outputs / 2)
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than " & positive'image(DAC_number_outputs/2) & ", some DAC outputs are lost" severity warning;
  assert not mode_totempole or
    nbre_outputs_per_DAC <= (DAC_number_outputs / 2)
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than " & positive'image(DAC_number_outputs/2) & ", some project outputs are lost" severity error;
  assert not mode_totempole or
    nbre_outputs_per_DAC /= (DAC_number_outputs / 2)
    report "Instantiating a set/one DAC with " & positive'image(DAC_number_outputs/2) & " outputs in totem-pole mode"
    severity note;


  CLK_serial    <= CLK;
  update_serial <= 'W';

  main_proc : process (CLK) is
    variable address_bits                     : std_logic_vector(address_counter'length - 1 downto 0);
    variable write_with_or_without_update_cmd : std_logic_vector(write_and_update_cmd'reverse_range);
  begin  -- process main_proc
    if rising_edge(CLK) then
      RST_IF : if RST_init = '0' then
        DAC_CLK_divider : if true then
          if is_initialised = '0' and initialization_cmd'length > 0 then
            write_with_or_without_update_cmd := initialization_cmd;
          elsif address_counter /= address_counter_max then
            write_with_or_without_update_cmd := write_and_update_cmd;
          else
            write_with_or_without_update_cmd := write_only_cmd;
          end if;
          -- Compute the address that is going to be used
          if mode_totempole then
            -- The low bit is going to come from the register.
            -- It is however set in order to keep a standard VHDL code
            --   to detect the end of the writings
            address_bits(address_bits'high downto address_bits'low + 1) :=
              address_counter(address_counter'high - 1 downto address_counter'low);
            address_bits(address_bits'low) :=
              address_counter(address_counter'low);
          else
            address_bits(address_bits'low + address_counter'length - 1 downto 0)             := address_counter;
            -- If the padding is > 0, populate the high part with 0's
            -- otherwise do nothing the range is NULL (VHDL2008)
            address_bits(address_bits'high downto address_bits'low + address_counter'length) := (others => '0');
          end if;

          -- Run the main, parallel to serial conversion of
          --   the command, the address and the data
          MAIN_IF_DISPATCH : if to_integer(unsigned(main_counter)) = 0 then
            START_CONT_WAIT : if start = '1' then
              if write_with_or_without_update_cmd(write_with_or_without_update_cmd'high) = '-' then
                registers_control <= "010";
              else
                registers_control(2 downto 1) <= "01";
                registers_control(0)          <= write_with_or_without_update_cmd(write_with_or_without_update_cmd'high);
              end if;
              main_counter <= std_logic_vector(unsigned(main_counter) + 1);
              ready <= '0';
              -- The frame contains more then one data to send.
              -- Then it respawns automatically
            elsif address_bits /= address_counter_min then
              if write_with_or_without_update_cmd(write_with_or_without_update_cmd'high) = '-' then
                registers_control <= "110";
              else
                registers_control(2 downto 1) <= "10";
                registers_control(0)          <= write_with_or_without_update_cmd(write_with_or_without_update_cmd'high);
              end if;
              main_counter <= std_logic_vector(unsigned(main_counter) + 1);
              -- The frame is over and we are waiting for the next start
            else
              -- To avoid a dead lock,
              -- or in case there is a need to have more idles (see below)
              ready <= '1';
            end if START_CONT_WAIT;

          elsif to_integer(unsigned(main_counter)) < write_with_or_without_update_cmd'length then
            if write_with_or_without_update_cmd(write_with_or_without_update_cmd'high -
                                                to_integer(unsigned(main_counter))
                                                ) = '-' then
              registers_control <= "110";
            else
              registers_control(2 downto 1) <= "10";
              registers_control(0) <= write_with_or_without_update_cmd(write_with_or_without_update_cmd'high -
                                                                       to_integer(unsigned(main_counter)));
            end if;
            main_counter    <= std_logic_vector(unsigned(main_counter) + 1);
            -- Since there is a one bit latch (in the register component)
            -- after the selector 0, 1, -, data, address the transfer is delayed
            transfer_serial <= '0';

          -- Now transferring the address blocs
          elsif to_integer(unsigned(main_counter)) < (write_with_or_without_update_cmd'length + address_size - 1) then
            registers_control(2 downto 1) <= "10";
            registers_control(0) <= address_bits(
              address_size - 1 - to_integer(unsigned(main_counter)) + write_with_or_without_update_cmd'length
              );
            main_counter <= std_logic_vector(unsigned(main_counter) + 1);

          elsif to_integer(unsigned(main_counter)) = (write_with_or_without_update_cmd'length + address_size - 1) then
            if mode_totempole then
              registers_control <= "001";
            else
              registers_control(2 downto 1) <= "10";
              registers_control(0)          <= address_bits(address_bits'low);
            end if;
            main_counter <= std_logic_vector(unsigned(main_counter) + 1);

          -- Run and shift the data
          elsif to_integer(unsigned(main_counter)) <
            (write_with_or_without_update_cmd'length + address_size + DAC_data_size) then
            registers_control <= "000";
            main_counter      <= std_logic_vector(unsigned(main_counter) + 1);

          -- Data is over, set the don't care one clock cycle before ...
          elsif to_integer(unsigned(main_counter)) <
            (write_with_or_without_update_cmd'length + address_size + device_data_size + 1) then
            registers_control <= "110";
            main_counter      <= std_logic_vector(unsigned(main_counter) + 1);

          -- ... and reset the enable
          else
            --elsif to_integer(unsigned(main_counter)) <
            --(write_with_or_without_update_cmd'length + address_size + DAC_data_size + 2) then
            -- Since there is a one bit latch (in the register component)
            -- after the selector 0, 1, -, data, address the transfer is delayed
            transfer_serial <= '1';
            -- This is probably simplified as it is a basic increment
            -- with a roll over when reach the mast one.
            -- Since it is an example, some other entities might handle
            --   for instance 6 outputs DAC, or 5 outputs DAC non totem-pole.
            if address_counter /= address_counter_max then
              address_counter <= std_logic_vector(unsigned(address_counter) + 1);
            else
              address_counter <= address_counter_min;
              is_initialised  <= '1';
            end if;
            main_counter    <= (others => '0');
            -- Since there is a one bit latch (in the register component)
            -- after the selector 0, 1, -, data, address the transfer is delayed
            transfer_serial <= '1';
            if address_bits = address_counter_max then
            -- The ready is set to 1 now. The idle cycle is only 1
              ready <= '1';
            end if;
          end if MAIN_IF_DISPATCH;

        end if DAC_CLK_divider;
      else
        ready <= '1';
        is_initialised  <= '0';
        main_counter    <= (others => '0');
        address_counter <= address_counter_min;
      end if RST_IF;
    end if;
  end process main_proc;

end architecture arch;
