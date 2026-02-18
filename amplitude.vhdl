library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.global_volume_size;

--! @brief Computes the product of the theoretical amplitude by the volume.
--!
--! A strategy has to apply in order to output values rail to rail.
--! If not, there is a need of a gain in the analogue part, or
--!   more operands bits.
--! The multiplication of the result by a constant is too costly.\n
--! The goal is to minimize the error.
--! The error, in %, is as low as the number of bits is high.
--! In theory the maximum output of N bits by M bits is:
--!   2**(N+M) - 1 - (2**M - 1) - (2**N - 1).
--! The analogue gain should be ( 2**(N+M) - 1 ) / ( (2**M - 1) * (2**N - 1) )\n
--! One strategy would have to increase the number of bits,
--!   in order to add 1/2, 3/4, 7/8 or more to the numbers.
--! Since, at the end, there is a cut, not a rounding, the result
--!   is closed to 2**(N+M) - 1.
--! To keep the linearity, it can be done while populating the right
--!   with a barrel shifting of the operand.
--! This solution is rejected as it increases the carry propagation time,
--!   then it decrease the maximum clock.\n
--! The strategy is to multiply the result by 1.0..1
--! That means the result is added to itself after a shift down
--! It consume one more CLK cycle. It has a pretty good result.
--! The number of shifts is the average value of N and M, floored, minus 1.
entity Amplitude_multiplier is
  port (
    --! Master clock
    CLK     : in  std_logic;
    --! 0's are introduced while shifting the operands.
    --! when the product is over, the registers shift 0's.
    --! This signal stops everything.
    EN      : in  std_logic;
    --! Loads new operands, otherwise computes
    load    : in  std_logic;
    --! Executes the rail to rail correction
    --! if load = 0 only
    --! If executed too early, the result is less corrected (but valid)
    execR2R : in  std_logic;
    M       : in  std_logic_vector;
    N       : in  std_logic_vector;
    --! The length should not be greater than the N'length + M'length
    --! It is not an error, but it is irrelevant
    theOut  : out std_logic_vector);

end entity Amplitude_multiplier;


architecture arch of Amplitude_multiplier is
  signal opOut                   : std_logic_vector(M'length + N'length - 1 downto 0);
  signal opA                     : std_logic_vector(opOut'range);
  signal opB                     : std_logic_vector(N'range);
  function GetShifts(constant NL : positive; constant ML : positive) return positive is
    variable shifts : positive := 1;
  begin
    main_loop : while real (2**(NL+ML) - 1) /
                  real((2**ML - 1) * (2**NL - 1) +
                       (2**ML - 1) * (2**NL - 1) / (2**(shifts))) < 1.0 loop
      shifts := shifts + 1;
    end loop main_loop;
    return shifts;
  end function GetShifts;
  constant N_shifts : natural := GetShifts(N'length, M'length);
begin
  assert theOut'length > 3 report "to run, the M operand vector should have a length of at least 4" severity failure;
  assert theOut'length <= (N'length + M'length)
                          report " The size of the output (" & integer'image(theOut'length) & ")" &
                          " is bigger than the size of N+M (" & integer'image(N'length) & " and " &
                          integer'image(M'length) & "): irrelevant"
                          severity note;
  assert false
    report "Lengths [" & integer'image(N'length) & "]x[" & integer'image(M'length) &
    "] gain: " &
    real'image(real(2**(N'length+M'length) - 1) / real((2**M'length - 1) * (2**N'length - 1))) &
    ", " & integer'image(N_shifts - 1) & " shifts, gain is " &
    real'image(real (2**(N'length+M'length) - 1) /
               real((2**M'length - 1) * (2**N'length - 1) +
                    (2**M'length - 1) * (2**N'length - 1) / (2**(N_shifts - 1)))) &
    ", " & integer'image(N_shifts) & " shifts, gain is " &
    real'image(real (2**(N'length+M'length) - 1) /
               real((2**M'length - 1) * (2**N'length - 1) +
                    (2**M'length - 1) * (2**N'length - 1) / (2**(N_shifts)))) &
    ", " & integer'image(N_shifts+1) & " shifts, gain is " &
    real'image(real (2**(N'length+M'length) - 1) /
               real((2**M'length - 1) * (2**N'length - 1) +
                    (2**M'length - 1) * (2**N'length - 1) / (2**(N_shifts+1))))
    severity note;

  theOut <= opOut(opOut'high downto opOut'high - theOut'length + 1);

  main_proc : process(CLK)
    variable padding_shifts : std_logic_vector(N_shifts - 1 downto 0);
    variable padding_M      : std_logic_vector(N'length - 1 -1 downto 0);
  begin
    if rising_edge(CLK) then
      IF_cmd : if load = '1' then
        -- opA       <= ('0', M(M'high downto M'low), others => '0');
        padding_M := (others => '0');
        opA       <= "0" & M & padding_M;
        opB       <= N;
        opOut     <= (others => '0');
      elsif EN = '1' then
        if execR2R = '1' then
          padding_shifts := (others => '0');
          opOut <= std_logic_vector(unsigned(opOut) +
                                    unsigned(padding_shifts & opOut(opOut'high downto opOut'low + N_shifts)));
        else
          if opB(opB'high) = '1' then
            opOut <= std_logic_vector(unsigned(opOut) + unsigned(opA));
          end if;
          opA(opA'high - 1 downto opA'low) <= opA(opA'high downto opA'low + 1);
          opA(opA'high)                    <= '0';
          opB(opB'high downto opB'low + 1) <= opB(opB'high - 1 downto opB'low);
          opB(opB'low)                     <= '0';
        end if;
      end if IF_cmd;
    end if;
  end process main_proc;
end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Utils_pac.StateNumbers_2_BitsNumbers,
  work.DAC_package.channels_number,
  work.Amplitude_package.all;


entity amplitude_bundle is
  port (
    CLK                 : in  std_logic;
    RST                 : in  std_logic;
    --! Starts the product
    --! In case of a concurrent run with the volume,
    --!   connect both with start_frame
    --! In case of a serial run after the volume,
    --!   connect to the ready output of the volume
    start_prod          : in  std_logic;
    --! Always connected to the global start frame
    --! It clears the ready output
    start_frame         : in  std_logic;
    which_channel       : in  std_logic_vector(StateNumbers_2_BitsNumbers(channels_number) - 1 downto 0);
    requested_amplitude : in  std_logic_vector;
    requested_volume    : in  std_logic_vector;
    ready               : out std_logic;
    pulse_amplitude     : out Pulse_amplitude_record);
end entity amplitude_bundle;

architecture arch of amplitude_bundle is
  signal load              : std_logic;
  signal sequencer_counter : std_logic_vector(StateNumbers_2_BitsNumbers(requested_volume'length + 2) - 1 downto 0);
begin  -- architecture arch

  main_proc : process (CLK) is
  begin  -- process main_proc
    if rising_edge(CLK) then
      RST_IF : if RST = '0' then
        if sequencer_counter = std_logic_vector(to_unsigned(0, sequencer_counter'length)) then
          if start_prod = '1' then
            sequencer_counter <= std_logic_vector(to_unsigned(1, sequencer_counter'length));
            ready <= '0';
            load <= '1';
          elsif start_frame = '1' then
            ready <= '0';
          end if;
        elsif to_integer( unsigned(sequencer_counter)) = ( requested_volume'length + 1) then
          ready <= '1';
        else
          load <= '0';
          sequencer_counter <= std_logic_vector(unsigned (sequencer_counter) + 1);
        end if;
      else
        ready             <= '1';
        sequencer_counter <= (others => '0');
      end if RST_IF;
    end if;
  end process main_proc;

  Amplitude_multiplier_instanc : Amplitude_multiplier port map (
    CLK     => CLK,
    EN      => '1',
    load    => load,
    execR2R => '0',
    M       => requested_amplitude,
    N       => requested_volume,
    theOut  => pulse_amplitude.the_amplitude);
end architecture arch;
