library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;
--  work.DAC_package.all;


--! @brief Configurable emulator for many DACS
--!
--! The specifications are:
--! * Serial transfer, one DAC at a time
--! * Don'"t care bits or not
--! * Command, see details in the code
--! * DAC adress, with or without left don't care bits (see in the code)
--! * data keft justified
--! A transfer signal is asserted at the begining and negated or not at the end.
--!   Additional bits are ignored.
package DAC_emulators_package is
    component DAC_emulator is
    generic(
      write_and_update_cmd : std_logic_vector;
      write_only_cmd       : std_logic_vector;
      address_size         : positive              := 10;
      DAC_numbers          : positive              := 10;
      --! This generic has 2 purposes:
      --! * set the size of the data registers.
      --! * consider as canceled if the transfer_serial return early to high
      data_bits            : integer range 4 to 30 := 12
      );
    port(
      data_serial     : in std_logic;
      CLK_serial      : in std_logic;
      transfer_serial : in std_logic;
      update_serial   : in std_logic
      );
  end component DAC_emulator;
end package DAC_emulators_package;

library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;


entity DAC_emulator_model_1 is
  generic(
    write_and_update_cmd : std_logic_vector;
    write_only_cmd       : std_logic_vector;
    address_size         : positive              := 2;
    DAC_numbers          : positive              := 4;
    --! This generic has 2 purposes:
    --! * set the size of the data registers.
    --! * consider as canceled if the transfer_serial return early to high
    data_bits            : integer range 4 to 30 := 6
    );
  port(
    data_serial     : in std_logic;
    CLK_serial      : in std_logic;
    transfer_serial : in std_logic;
    update_serial   : in std_logic
    );
end entity DAC_emulator_model_1;



architecture arch of DAC_emulator_model_1 is
  constant total_message_length : positive :=
    write_and_update_cmd'length + address_size + data_bits;
  signal serial_counter   : natural;
  signal command_register : std_logic_vector(write_and_update_cmd'length - 1 downto 0);
  signal address_register : std_logic_vector(address_size -1 downto 0);
  signal working_register : std_logic_vector(data_bits - 1 downto 0);
  type shifted_data_t is array (DAC_numbers - 1 downto 0) of unsigned(working_register'range);
  signal written_data     : shifted_data_t;
  signal uploaded_data    : shifted_data_t;
  -- For the whoose does not have the GHW format
  signal uploaded_data_0  : unsigned(working_register'range);
  signal uploaded_data_1  : unsigned(working_register'range);
  signal uploaded_data_2  : unsigned(working_register'range);
  signal uploaded_data_3  : unsigned(working_register'range);
begin
  assert 2 ** address_size >= DAC_numbers report
    "The address size (2**" & integer'image(address_size) & ") is not enough for " &
    integer'image(DAC_numbers) & "DACs"
    severity failure;
  assert write_and_update_cmd'length = write_only_cmd'length report
    "The size of the command write and upodate (" & integer'image(write_and_update_cmd'length) &
    ") should be equal to the write only(" & integer'image(write_only_cmd'length) & ")"
    severity failure;

  main_proc : process (CLK_serial) is
    variable data_register_v : shifted_data_t;
  begin
    if falling_edge(CLK_serial) then
      TRANSF_IF : if transfer_serial = '0' then
        if serial_counter < total_message_length then
          if serial_counter < write_and_update_cmd'length then
            command_register(command_register'high downto command_register'low + 1) <=
              command_register(command_register'high - 1 downto command_register'low);
            command_register(command_register'low) <= data_serial;

            serial_counter <= serial_counter + 1;
          elsif serial_counter < (write_and_update_cmd'length + address_size) then
            address_register(address_register'high downto address_register'low + 1) <=
              address_register(address_register'high - 1 downto address_register'low);
            address_register(address_register'low) <= data_serial;

            serial_counter <= serial_counter + 1;
          elsif serial_counter < (write_and_update_cmd'length + address_size + data_bits) then
            working_register(working_register'high downto working_register'low + 1) <=
              working_register(working_register'high - 1 downto working_register'low);
            working_register(working_register'low) <= data_serial;

            serial_counter <= serial_counter + 1;
          end if;
        end if;
      elsif serial_counter = total_message_length then
        -- The trnasfert is negated but the message is complete
        data_register_v := written_data;
        if std_match(command_register, write_only_cmd) or std_match(command_register, write_and_update_cmd) then
          data_register_v(to_integer(unsigned(address_register))) := unsigned( working_register );
        end if;
        if std_match(command_register, write_and_update_cmd) then
-- If you have GHW, uncomment this line and comment out the following
--          uploaded_data <= data_register_v;
          uploaded_data_0 <= data_register_v(0);
          uploaded_data_1 <= data_register_v(1);
          uploaded_data_2 <= data_register_v(2);
          uploaded_data_3 <= data_register_v(3);
        end if;
        written_data   <= data_register_v;
        serial_counter <= 0;
      else
        serial_counter <= 0;
      end if TRANSF_IF;
    end if;
  end process main_proc;

end architecture arch;
