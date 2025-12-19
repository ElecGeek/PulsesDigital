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
  assert mode_totempole report "Elaborating " & integer'image(nbre_DACs_used) & " dac(s)," &
    "with " & integer'image(nbre_outputs_per_DAC) & " channels each" severity note;
  assert mode_totempole report "Each output is a positive and negative " &
    "with an offset of (<vector>'high=>'1', others=>'0')" severity note;
  assert not mode_totempole report "Elaborating totem-pole" & integer'image(nbre_DACs_used) & "Dac(s)," &
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
--!   If the mode is not totempole, the negative polarity is computed.
--!   If the mode is totempole, the data is left as it.
--! * The DAC address low bit is loaded from the polarity.
--!   It the mode is not totempole, this bit is never selected by the controller.\n
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
    --! In the case of totempole, it is the address multiplied by 2, plus one or not
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
  work.DAC_package.all;

entity Controler_default is
  port (
    CLK               : in  std_logic;
    RST_init          : in  std_logic;
    start             : in  std_logic;
    --! See in the type definition
    registers_control : out registers_control_st;
    CLK_serial        : out std_logic;
    transfer_serial   : out std_logic;
    update_serial     : out std_logic
    );
end entity Controler_default;


architecture arch of Controler_default is
  --! Counter to manage the command signal to send one output of the DAC
  -- Don't change the range without a code review
  signal main_counter          : std_logic_vector(3 downto 0);
  --! Counter to manage the address in case there is more
  --!   than one output per DAC to handle.
  signal address_counter       : std_logic_vector(1 downto 0);
  constant address_counter_min : std_logic_vector(address_counter'range) := (others => '0');
  constant address_counter_max : std_logic_vector(address_counter'range) := (others => '1');
begin  -- architecture arch
  assert mode_totempole or
    nbre_outputs_per_DAC >= 4
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than 4, some DAC outputs are lost" severity warning;
  assert mode_totempole or
    nbre_outputs_per_DAC <= 4
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than 4, some project outputs are lost" severity error;
  assert mode_totempole or
    nbre_outputs_per_DAC /= 4
    report "Instantiating a set/one DAC with 4 outputs in not totempole mode"
    severity note;
  assert not mode_totempole or
    nbre_outputs_per_DAC >= 2
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than 2, some DAC outputs are lost" severity warning;
  assert not mode_totempole or
    nbre_outputs_per_DAC <= 2
    report "The number of outputs (" & natural'image(nbre_outputs_per_DAC) &
    ") is lower than 2, some project outputs are lost" severity error;
  assert not mode_totempole or
    nbre_outputs_per_DAC /= 2
    report "Instantiating a set/one DAC with 4 outputs in totempole mode"
    severity note;


  CLK_serial    <= CLK;
  update_serial <= 'W';

  main_proc : process (CLK) is
    variable address_bits : std_logic_vector(address_counter'range);
  begin  -- process main_proc
    if rising_edge(CLK) then
      RST_IF : if RST_init = '0' then
        DAC_CLK_divider : if true then
          if mode_totempole then
            -- The low bit is going to come from the register.
            -- It is however set in order to keep a standard VHDL code
            --   to detect the end of the writings
            address_bits(address_bits'high downto address_bits'low + 1) :=
              address_counter(address_counter'high - 1 downto address_counter'low);
            address_bits(address_bits'low) :=
              address_counter(address_counter'low);
          else
            address_bits := address_counter;
          end if;
          if main_counter(3 downto 2) = "11" then
            main_counter <= "0000";
          elsif main_counter /= "0000" or
            start = '1' or
            address_bits /= address_counter_min then
            main_counter <= std_logic_vector(unsigned(main_counter) + 1);
          end if;
          case to_integer(unsigned(main_counter)) is
            when 0 =>
              if start = '1' then
                registers_control <= "011";
              elsif address_bits /= address_counter_min then
                registers_control <= "101";
              end if;
            when 1 =>
              -- Since there is a one bit latch (in the register component)
              -- after the selector 0, 1, -, data, address the transfer is delayed
              transfer_serial   <= '0';
              if address_counter /= address_counter_max then
                registers_control <= "100"; 
              else
                registers_control <= "101";
              end if;
           when 2 =>
              registers_control(2 downto 1) <= "10";
              registers_control(0)          <= address_bits(1);
            when 3 =>
              if mode_totempole then
                registers_control <= "001";
              else
                registers_control(2 downto 1) <= "10";
                registers_control(0)          <= address_bits(0);
              end if;

            when 4 to 9 =>
              registers_control <= "000";
            when 10 =>
              registers_control <= "110";
            when 11 =>
              -- Since there is a one bit latch (in the register component)
              -- after the selector 0, 1, -, data, address the transfer is delayed
              transfer_serial <= '1';
              -- This is probably simplified as it is a basic increment
              -- with a roll over when reach the mast one.
              -- Since it is an example, some other entities might handle
              --   for instance 6 outputs DAC, or 5 outputs DAC non totempole.
              if address_counter /= address_counter_max then
                address_counter <= std_logic_vector(unsigned(address_counter) + 1);
              else
                address_counter <= address_counter_min;
              end if;
            when others => null;
          end case;
        end if DAC_CLK_divider;
      else
        main_counter    <= (others => '0');
        address_counter <= address_counter_min;
      end if RST_IF;
    end if;
  end process main_proc;

end architecture arch;
