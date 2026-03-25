library ieee;
use ieee.std_logic_1164.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number;


--! @brief 1 channel at a time amplitude computation
--!
--! @anchor volume_package_anchor
--! At the end of a super frame, all the channels are updated.
--!   Since the pulse length is dozen of low level frames,
--!   this latency is not an issue.\n
--! The analogue version (see the PulsesGene project) uses
--!   potentiometers, resistors etc... They are calculated to provide
--!   a volume between 0 and 100%.
--! The precision is not that bad with precision 1% for passive and 10% for potentiometers.\n
--! This is easy to reach (or increase).
--! The amplitude can, even, be adjusted by the gain of the analogue part.\n

--! The digital project may have some computations errors,
--!   especially some values are not 100% rail to rail.
--!   but even with the worst solution, it is better than the analogue one.
--! In the case of the totem pole mode, the not rail to rail
--!   allows to insert a small polarization to the outputs.\n
--! The computations are provided with test entities that simulate the behavior,
--!   especially the rail to rail.\n
--! Regardless the choice what is stored and what is converted, they all
--!   have advantages and drawbacks.\n

--! Prerequisites:\n
--! * chose the channel using a digital encoder
--!   and choose the volume using another one.
--! * The volume has to be displayed in BCD mode.
--! * change up or down at slow, mid or fast speed.
--! * have a mute and one or two half mute.
--! * RAM modules are not that configurable.
--!   For instance, if the Latice ICE40 series are used,
--!   even to get 16 bits, it is an address space of 128 or 256.\n

--! The BCD arithmetic is even better as
--!   * in the mid mode, it is nice to see 17, 22, 27, 32 etc...
--!   * in the fast mode, it is nice to see 34, 44, 54 etc...\n

--! The conversion BCD to binary is (re)done for all the channels
--!   at each super frame.
--! For each computation, it takes
--!   * the volume modification request.
--!   * the normalized requested amplitude.
--! For each computation, it produces
--!   * The actual volume in BCD mode.
--!   * The actual volume in binary
--!   * The actual amplitude.\n
--! For resources optimizations
--!   * the multiplication is made using successive additions
--!     if the corresponding bit of the other operand is '1'
--!   * The RAM is a basic one without multiple accesses.\n
--! The propagation delays of the carry should be able to handle
--!   a vector with a size of the sum requested_amplitude_size plus global_volume_size.\n

--! TODO FOR ALL THE PACKAGES: add timing signals.
--! Every input should be stable before a certain point
--!   from or to the start of a frame or super frame.
--! Every outputs are stable before a certain point
--!   from or to the end of a frame or super frame,
--!   and still stable after its start.\n
--! New signals are going to simulate that.
--! * A verification has to be done against the design.
--! * A compare of these signals validates the global design.
--! The signal are intended to be left open for the synthesis.

package Volume_package is

  --! @brief sequencer of the volume computation
  --!
  --! The sequencer is separated from the operation themselves\n
  --! * to make things independent tin order to improve the verification.\n
  --! * to allow to raise the frequency, using a specific RAM.
  --!   If there is an assert on raising/falling edge or on state,
  --!   the clock cycles for every operation is reduced.\n

  --! The sequencer increments the channel at each frame.\n
  --! If the requests match the channel:\n
  --! * the volume modification is computed.\n
  --! * The new amplitude is updated.\n
  --! If the requests does not match the channel, the data is left as it.
  --! The data is written back to the RAM.\n
  --! The request should be stable for all the super frame.
  --! The channel number is passed to the amplitude and the pulse gene for update.\n

  --! Since the multiplication can run only with both the volume and the amplitude,
  --!   the volume is read first as its computation needs clock cycles.
  --! Second, the volume is processed and
  --!   the amplitude is read, checked for update and written back.\n
  --!
  --!
  --! *** OUTDATED ***, now the stored volume for the mute and back has been inserted
  --! Step 1A: read the BCD volume request  oper="001"
  --! Step 1B: generates the pulse of the end of the super frame ***if so***
  --!          ... or create a low frequency clock
  --!          TO BE DECIDED
  --!          it raises at channel 0 end falls at channel 1
  --! Step 2A: read the requested amplitude
  --! Step 2B: process the new volume ***if the channel matches***  oper = "010" to "100"
  --!          or process an all mute
  --! Step 3A: save into the two 1.101 product registers while computing the first addition.
  --! Step 3B: update the BCD output for display
  --! Step 3C: update the amplitude, ***if the channel matches***
  --! Step 4A: second addition of the 1.101 product
  --! Step 4B: write back the volume to the RAM. if the channel does not match
  --!          the old one is written back.
  --! Step 4C: write back the amplitude. if the channel does not match
  --!          the old one is written back.
  --! Step  5: start the amplitude product.\n
  --! Another choice would have been to store the binary volume in the RAM
  --!   and take it earlier.
  --! This would have been relevant only for a low number of channels,
  --!   then a low number of clock cycles.

  component Volume_sequencer is

    port (
      --! Master clock
      CLK                        : in  std_logic;
      RST                        : in  std_logic;
--!
      start_frame                : in  std_logic;
--! The frame is over
      ready                      : out std_logic;
      start_vol_ampl_product          : out std_logic;
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

  end component Volume_sequencer;

  component volume_BCD_request is
    port (
      CLK                  : in  std_logic;
      RST                  : in  std_logic;
      does_channel_matches : in  std_logic;
--!
--! 00- = idle, 010 = load actual volume, 011 = load stored volume and mute recover
--! 100 = run the addition or subtraction, 101 = check BCD carries
--! 110 = apply corrections
      action               : in  std_logic_vector(2 downto 0);
      volumes_input        : in  std_logic_vector;
      mute_recover_in     : in  std_logic;
--! Speed of the up and down.\n
--! The increment or decrement can be performed for 5, 2 or 1
--!   of a certain digit.
--! the inc/dec of the highest digit can only be 1.\n
--! the value others=>'0' is for this highest digit.
--! Highest values of the speed act on the inc/dec of lower digits. 
      speed                : in  std_logic_vector;
      --! 00 = idle, 01 = mute, 10 = down, 11 = up
      --! In case of mute, speed=0 mute one, speed > 0 mute all
      request              : in  std_logic_vector(1 downto 0);
      volumes_output       : out std_logic_vector;
      mute_recover_out     : out std_logic
      );
  end component volume_BCD_request;


  component volume_BCD_2_binary is
    generic (
      extra_computation_bits : natural := 2);
    port (
      CLK                 : in  std_logic;
      RST                 : in  std_logic;
      requested_BCD_2_bin : in  std_logic_vector(1 downto 0);
      volume_BCD          : in  std_logic_vector;
      volume_binary       : out std_logic_vector);
  end component volume_BCD_2_binary;

end package Volume_package;
