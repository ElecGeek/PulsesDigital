
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
  type latch_data_t is array(channels_number - 1 downto 0) of std_logic_vector(data_size downto 0);
  signal latch_data : latch_data_t;
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

  main_proc : process(CLK) is
  begin
    CLK_IF : if rising_edge(CLK) then
      main_loop : for ind in 0 to channels_number - 1 loop
        if EN(ind) = '1' then
          latch_data(ind)(latch_data(ind)'high - 1 downto latch_data(ind)'low) <=
            data_in xor polar_pos_not_neg;
          latch_data(ind)(latch_data(ind)'high) <= polar_pos_not_neg;
        end if;
      end loop main_loop;
    end if CLK_IF;
  end process main_proc;
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
    --! To be passed to the sequencer for the DAC initialisation
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
  signal get_control       : std_logic;
  signal val_control       : std_logic;
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
  assert mode_totempole report "Elaborating " & integer'image(nbre_DACs_used) & "Dac(s)," &
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
          port map (
            CLK                => CLK,
            polar_pos_not_neg  => polar_pos_not_neg,
            data_in            => data_in,
            data_strobe        => EN(ind_DAC * nbre_outputs_per_DAC + ind_output),
            registers_control  => registers_control,
            chain_data_in      => registers_chain_data(ind_DAC)(ind_output - 1),
            chain_data_out     => registers_chain_data(ind_DAC)(ind_output),
            chain_polarity_in  => registers_chain_polar(ind_DAC)(ind_output - 1),
            chain_polarity_out => registers_chain_polar(ind_DAC)(ind_output),
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
      get_control,
      val_control,
      CLK_serial      => CLK_serial_s,
      transfer_serial => transfer_serial_s,
      update_serial   => update_serial_s
      );
end architecture arch;



library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.DAC_package.all;

entity Buffer_and_working_registers is
  generic (
    DAC_data_size : integer range 4 to 50;
    --! Set to true from single output, false from totem-pole
    compute_sign  : boolean
    );
  port (
    CLK               : in  std_logic;
    --! Polarity, void if compute_sign is false
    polar_pos_not_neg : in  std_logic;
    data_in           : in  std_logic_vector(data_size - 1 downto 0);
    --! Load value registers, not the shift registers to convert parallel to serial.
    data_strobe       : in  std_logic;
    --! Run the shifts registers or force to 0, 1 or don't care.
    registers_control : in  registers_control_st;
    --! Private chain between multiple outputs per DAC 
    chain_data_in     : in  std_logic;
    --! Private chain between multiple outputs per DAC 
    chain_data_out    : out std_logic;
    --! Sent to the DAC if the first one in the chain, void otherwise.
    data_out          : out std_logic
    );
end entity Buffer_and_working_registers;
