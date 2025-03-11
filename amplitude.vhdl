library ieee;
use ieee.std_logic_1164.all;

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
  generic (
    --! Does not impact anything.
    --! It is only to notice the relevance of the computation 
    DAC_cycles      : integer range 10 to 40;
    --! Does not impact anything.
    --! It is only to notice the relevance of the computation 
    Channels_number : integer range 2 to 300
    );
  port (
    --! Master clock
    CLK    : in  std_logic;
    RST    : in  std_logic;
    EN     : in  std_logic;
    M      : in  std_logic_vector;
    N      : in  std_logic_vector;
    --! Output. the length should not be greater than
    --!   the N'length + M'length
    theOut : out std_logic_vector);

end entity Amplitude_multiplier;


architecture arch of Amplitude_multiplier is
  signal opOut                   : std_logic_vector(M'length + N'length + 1 - 1 downto 0);
  signal opA                     : std_logic_vector(opOut'range);
  signal opB                     : std_logic_vector(N'range);
  function GetShifts(constant NL : positive; constant ML : positive) return positive is
    variable shifts : positive := 1;
  begin
    main_loop: while real (2**(NL+ML) - 1) /
               real((2**ML - 1) * (2**NL - 1) +
                    (2**ML - 1) * (2**NL - 1) / (2**(shifts))) < 1.0 loop
      shifts := shifts + 1;
      end loop main_loop;
    return shifts;
  end function GetShifts;
  constant N_shifts : natural := GetShifts( N'length, M'length );
begin
  assert N'length > 1
    report "The N operand vector length " & integer'image(N'length) &
    ") should have a length of at least 2"
    severity failure;
  assert M'length > 1
    report "The M operand vector length " & integer'image(M'length) &
    ") should have a length of at least 2"
    severity failure;
  assert theOut'length > 3 report "to run, the M operand vector should have a length of at least 4" severity failure;
  assert theOut'length <= (N'length + M'length)
                          report " The size of the output (" & integer'image(theOut'length) & ")" &
                          " is bigger than the size of N+M (" & integer'image(N'length) & " and " &
                          integer'image(M'length) & "): irrelevant"
                          severity note;
  assert (DAC_cycles > M'length / 2) or (Channels_number * 8 > M'length / 2)
    report "The system can not process at least the half of the length of M (" & integer'image(M'length) &
    "), it is a non-sense"
    severity error;
  assert (DAC_cycles > M'length) or (Channels_number * 8 > M'length)
    report "The system can not process all the length of M (" & integer'image(M'length) &
    "), some precision is lost"
    severity warning;
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
  
end architecture arch;
