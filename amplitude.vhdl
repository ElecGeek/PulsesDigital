library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all;

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
    CLK     : in  std_logic;
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

  theOut <= opOut(opOut'high downto opOut'high - theOut'length + 1);

  main_proc : process(CLK)
    variable padding_shifts : std_logic_vector(N_shifts - 1 downto 0);
    variable padding_M      : std_logic_vector(N'length - 1 -1 downto 0);
  begin
    if rising_edge(CLK) then
      IF_cmd : if load = '1' then
        -- opA       <= ('0', M(M'high downto M'low), others => '0');
        padding_M := (others                              => '0');
        opA       <= "0" & M & padding_M;
        opB       <= N;
        opOut     <= (others                              => '0');
      elsif execR2R = '1' then
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
      end if IF_cmd;
    end if;
  end process main_proc;
end architecture arch;


library ieee;
use ieee.std_logic_1164.all,
  work.Amplitude_pac.Amplitude_multiplier;

--! @brief Wrapper on the Amplitude multiplier for post synthesis exports
--!
--! Since the amplifier is exported as a top level,
--!   the vectors should not be unconstrained.
--! This entity is designed to set the sizes.
--! It should not be called, for any reason, anywhere in the code
--!   as the sizes can be changed without notice.
--!
--! There is a problem with Yosys 0.50 or its dependencies, see in the vhdl file
--After setting sizes of the 3 vectors and default values of the 2 generics
--After deleting the wrapper
--After modifying the Makefile
--I got:
--
--ghdl -a --std=08 utils_package.vhdl
--ghdl -a --std=08 amplitude.vhdl
--mkdir -p CXX/
--yosys -m ghdl -p 'ghdl --std=08 Amplitude_multiplier; synth_ice40 -json Synth/amplitude_lowlevel.ice40.json' 2>&1 |tee Synth/amplitude_lowlevel.synth.out.txt

-- /----------------------------------------------------------------------------\
-- |  yosys -- Yosys Open SYnthesis Suite                                       |
-- |  Copyright (C) 2012 - 2025  Claire Xenia Wolf <claire@yosyshq.com>         |
-- |  Distributed under an ISC-like license, type "license" to see terms        |
-- \----------------------------------------------------------------------------/
-- Yosys 0.50 (git sha1 b5170e1394f602c607e75bdbb1a2b637118f2086, g++ 8.5.0 -fPIC -O3)

---- Running command `ghdl --std=08 Amplitude_multiplier; synth_ice40 -json Synth/amplitude_lowlevel.ice40.json' --

--1. Executing GHDL.
--amplitude.vhdl:93:3:(assert note): Lengths [6]x[6] gain: 1.0317460317460319, 4 shifts, gain is 9.710694806734645e-1, 5 shifts, gain is 1.0004886391399952, 6 shifts, gain is 1.0158769536095262
--Importing module Amplitude_multiplier.
--ERROR: Assert `GetSize(conn.first) == GetSize(conn.second)' failed in kernel/rtlil.cc:2602.
--! The downgrade to Yosys 0.43 fixed it

entity Amplitude_multiplier_CXX_wrap is
  generic (
    M_size   : positive := 6;
    N_size   : positive := 6;
    Out_size : positive := 12);
  port (
    --! For more information see in the wrapped entity
    CLK     : in  std_logic;
    --! For more information see in the wrapped entity
    load    : in  std_logic;
    --! For more information see in the wrapped entity
    execR2R : in  std_logic;
    --! For more information see in the wrapped entity
    M       : in  std_logic_vector(M_size - 1 downto 0);
    --! For more information see in the wrapped entity
    N       : in  std_logic_vector(N_size - 1 downto 0);
    --! For more information see in the wrapped entity
    theOut  : out std_logic_vector(Out_size - 1 downto 0)
    );
end entity Amplitude_multiplier_CXX_wrap;

architecture arch of Amplitude_multiplier_CXX_wrap is

begin
  instanc : Amplitude_multiplier
    generic map (
      DAC_cycles      => 20,
      Channels_number => 2)
    port map (
      CLK     => CLK,
      load    => load,
      execR2R => execR2R,
      M       => M,
      N       => N,
      theOut  => theOut);
end architecture arch;
