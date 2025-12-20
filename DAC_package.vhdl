library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;

--! Package to provide standard interface
--!   for the serial DAC the user wants.
--! The common restriction is all the DAC circuits should be identical.
--! More restrictions may apply on specific cases, see the components documentation.\n
--! Since all the project is synchronous and all the DAC are identical,
--!   the DAC CLK, transfer, update etc... signals are common for all the DACs.
--! However, for PCB drawing, more line can be requested.
--! Each control lines are an unconstrained vector to manage
--!   the number of required pins of the PCB.
--!   Especially for the FPGA, DACs can be connected to different IO banks.
--!   It is always a good idea to fetch the data and the control from the same one.\n
--! There are two possible modes:\n
--! * The single output is one DAC output per channel
--!   The DACs can be single, dual, triple etc...
--!   The output addresses inside the DACs are incremented by 1 channel after channel.
--!   The polarity is computed inside the value.\n
--! * Two outputs per channels provide the positive and the negative output.
--!   This is named totem-pole.
--!   The DACs SHOULD have an even number of output.
--!   The output addresses inside the DACs are incremented by 2 from the controller
--!     point of view, but the unity comes from the polarity from the register.\n
--!   The DAC addresses SHOULD be on N bits in the control command.
--! A configure statement chooses which one fits the PCB.
--! All the components intended to be configured have their default/dummy components
--!   for test purpose.
--! They may content some relevant common documentation.

package DAC_package is
  --! This work around is going to be used until I install a version of GHDL
  --! that fixes the 3102 issue.
  constant mode_totempole             : boolean  := true;
  constant channels_number            : positive := 1;
  constant data_size                  : positive := 4;
  constant DAC_data_size              : positive := 8;
  constant nbre_DACS_used             : positive := 1;
  constant MasterCLK_SampleCLK_ratio  : positive := 40;
  constant MasterCLK_DACCLK_ratio     : positive := 2;
  constant Negation_fast_not_accurate : boolean  := true;
--  generic (
  --! Mode one per output or totem-pole ( 2 per output )
--    mode_totempole             : boolean := false;
  --! Number of channels of the design using this DAC package.
--    channels_number            : integer range 2 to 300 := 4;
  --! Size of the data, except the sign, passed to the DAC
  --! It may be different from the DAC data size.
  --! In such case, the data is cut or is barrel shifted.
--    data_size                  : integer range 4 to 64 := 12;
  --! Data size handled by the DAC controller.
  --! In case of a longueur one, the bits are barrel shifted to fill up.
  --! In case of a shorter one, the bits are cut.
  --! This has an impact on the resources as it sizes the output registers
  --! Please note, it may be shorter than the device data size.
  --! In such case a padding with don't care is added as
  --!   some devices has a standard interface e.g. for the 12, 14 and 16 bits.
  --   DAC_data_size              : integer range 4 to 50 := 8;
  --   nbre_DACs_used             : integer range 1 to 64 := 1;
  --! Most serial DACs have a command of about 4 bits,
  --!   followed by the number of bits.
  --! Many DACs exists in 3 versions such as 8, 10 or 12 bits,
  --!   or 12, 14 or 16 bits. It is recommended to set the highest one
  --!   in case the chosen DAC is out of order.
  --! Some additional bits have to be consider for the protocol.
  --! In case of a multiple output, all of this is multiplied by the number
  --!   of outputs divided by 2.
--    MasterCLK_SampleCLK_ratio  : integer range 14 to 100 := 22;
  --! TODO handle more values such as 1
  --! However that can cause propagation delay problems
--    MasterCLK_DACCLK_ratio     : integer range 2 to 2 := 2;
  --! Since it is the totem-pole, no digital negation has to be done.
  --! To keep the same "footprint" for configuration purposes,
  --!   the generic is defined.
  --! However, it is ignored and set to false by default
--    Negation_fast_not_accurate : boolean  := true );


  --! Number of outputs per DAC.
  --! In case of a totem-pole, the real DAC should have twice this number.
  constant nbre_outputs_per_DAC : natural := channels_number / nbre_DACs_used;
  
--! This is the default in order to perform tests faster
  --! The goal is to get all the outputs in parallel.
  component DAC_bundle_dummy is
    port(
      CLK               : in  std_logic;
      polar_pos_not_neg : in  std_logic;
      data_in           : in  std_logic_vector(data_size - 1 downto 0);
      -- Temporary, may be replaced by the channel number
      EN                : in  std_logic_vector(channels_number - 1 downto 0);
      --! The sequencer always run. During the reset, 0 values are coming
      --!   then the reset is not that relevant.
      --! However, some DAC needs initialization "strings".
      RST_init          : in  std_logic;
      --! Start signal
      start             : in  std_logic;
      --! Not used
      data_serial       : out std_logic_vector(nbre_DACs_used - 1 downto 0);
      --! Not used
      CLK_serial        : out std_logic_vector;
      --! Not used
      transfer_serial   : out std_logic_vector;
      --! Not used
      update_serial     : out std_logic_vector
      );
  end component DAC_bundle_dummy;


  --! The one output per channel requires a single DAC or a multiple DAC
  --! However, in the case of multiple, the master clock on the sample rate ratio
  --!   have to be higher, as there are N data to pass.
  --! The unsigned value is updated according with the polarity bit.\n

  --! The totem-pole output requires a DAC with an even number of outputs.
  --! The half is the positive outputs set, the other is the negative set.\n
  --! A restriction is the positive is always connected to the even outputs
  --!   while the negative one to the odd outputs.\n
  --! The pulse state machine has to always send a 0 at the end of each polarity,
  --!   as this component updates only one polarity value.
  --! This is an hard assume of the state-machine.
  --! The master clock on the sample rate ratio is "normal" for a dual DAC,
  --!   and is higher only for a quad, a 6th etc...
  component DAC_bundle_real_outputs is
    port(
      CLK               : in  std_logic;
      polar_pos_not_neg : in  std_logic;
      data_in           : in  std_logic_vector(data_size - 1 downto 0);
      -- Temporary, may be replaced by the channel number
      EN                : in  std_logic_vector(channels_number - 1 downto 0);
      --! The sequencer always run. During the reset, 0 values are coming
      --!   then the reset is not that relevant.
      --! However, some DAC needs initialization "strings".
      RST_init          : in  std_logic;
      --! Start signal
      start             : in  std_logic;
      --!
      --! The vector is one element per DAC circuit on the PCB
      data_serial       : out std_logic_vector;
      --! The vector is as many as required output pins on the PCB
      CLK_serial        : out std_logic_vector;
      --! The vector is as many as required output pins on the PCB
      --! This is named transfer, depending the DAC, it can be a start signal.
      transfer_serial   : out std_logic_vector;
      --! The vector is as many as required output pins on the PCB or null for some DACs.
      --! This may or may not be used as many DACs have a write and update command.
      --! TODO check it is possible at the top level to define a 0 down-to 1 vector
      update_serial     : out std_logic_vector
      );
  end component DAC_bundle_real_outputs;

  --! This component is private to the bundle.\n.
  --! In case of multiple channels per DACs, there is one controller and many registers.
  --! The controller has to send some data for the DAC command.
  --! Since this command is common, their registers are in the controller.\n
  --! To fix delay problems, there is a one bit latch in the working registers
  --!   that take data from its register or from the controller registers.\n
  --! Also, some DAC can be multiple. Then more than one set of command and data
  --!   has to be sent. Then the internal registers are chained.\n
  --! This type intended take and scroll or to force a value.
  --! For debug purposes, a don't care can be sent when no data is relevant.\n
  --! 000= run and scroll data,
  --! 001=run and scroll DAC address
  --! 01a= load the working registers from the buffers, while forcing to a the output.
  --! Since the DAC requires a command, sending 0's or 1's can be done
  --!   at the same time the polarity is processed and the working registers are loaded.
  --! 10b= force b,
  --! 110= force don't care,
  --! 111= force error. Check the comments in the case? of the Buffer_and_working_registers.\n
  --! Don't change the range without a full code review
  subtype registers_control_st is std_logic_vector(2 downto 0);

  --! This component is private to the bundle.\n.
  --! DOC TODO
  --! In case of full scale output, the polarity/sign has to be computed.\n
  --! In case of totem-pole, the controller addresses one or the other output..
  component Buffer_and_working_registers is
    generic (
      --! Used for multiple output DACs, to generate the index for some debug notes
      register_position : natural;
      --! Used for multiple DACs, to generate its index for some debug notes      
      DAC_chain_number  : natural);
    port (
      CLK                : in  std_logic;
      --! The data values are always sent to the DAC component as
      --! a sign and a value.
      --! The process depends if the mode is totempole or not.
      polar_pos_not_neg  : in  std_logic;
      data_in            : in  std_logic_vector(data_size - 1 downto 0);
      data_strobe        : in  std_logic;
      --! See in the type definition
      registers_control  : in  registers_control_st;
      --! In case of multiple channels per DAC,
      --! this takes the data from the previous register,
      --! without passing throw the last buffer.
      chain_data_in      : in  std_logic;
      --! similar of chain_data_in but for the polarity,
      --! used only in totem-pole mode
      chain_polarity_in  : in  std_logic;
      --! In case of multiple channels per DAC,
      --! this send the data to the next register,
      --! without passing throw the last buffer.     
      chain_data_out     : out std_logic;
      --! similar of chain_data_out but for the polarity,
      --! used only in totem-pole mode
      chain_polarity_out : out std_logic;
      --! Data out for one DAC, only the first in chain is used.
      data_out           : out std_logic
      );
  end component Buffer_and_working_registers;
  --! This component may go out as the controller is going to handle
  component Initialisation_register_default is

  end component Initialisation_register_default;
  --! This component is private to the bundle.\n.
  --! This is the default/dummy component to
  --!   send $c followed by the value.\n
  --! The generic data_register_size is used to configure the component.
  --! However, for many DACs, it is fix.
  --! Then the size in a real controller is, in general void.
  --! For this default component, it is mostly used for test and validation,
  --! as the size can be greater or lower of the data size supplied.\n
  --! Since the control outputs passe through the register component,
  --!   some care should be taken on the latencies.
  component Controler_default is
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
  end component Controler_default;
--end package DAC_package_t;
end package DAC_package;
-- This should move into a configuration file

-- library ieee;
-- use ieee.std_logic_1164.all,
--   ieee.numeric_std.all;

-- package DAC_package is
--   new work.DAC_package_t generic map (
--     mode_totempole             => false,
--     channels_number            => 4,
--     data_size                  => 12,
--     DAC_data_size              => 8,
--     nbre_DACS_used             => 1,
--     MasterCLK_SampleCLK_ratio  => 22,
--     MasterCLK_DACCLK_ratio     => 2,
--     Negation_fast_not_accurate => true);

