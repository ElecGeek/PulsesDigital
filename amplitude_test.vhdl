library ieee;
use ieee.std_logic_1164.all,
  work.Amplitude_pac.Amplitude_multiplier;

--! @brief Check the strategy to be close to the rail to rail
--!
--!
entity Amplitudes_multiplier_R2R_test is
  generic (
    M_min : integer range 2 to 300 := 2;
    N_min : integer range 2 to 300 := 2;
    M_max : integer range M_min to 300 := 7;
    N_max : integer range N_min to 300 := 7
    );
end entity Amplitudes_multiplier_R2R_test;

architecture arch of Amplitudes_multiplier_R2R_test is
  constant M    : std_logic_vector(50 downto 1) := (others => '0');
  constant N    : std_logic_vector(50 downto 1) := (others => '0');
  signal theOut : std_logic_vector(100 downto 1);
begin
  assert (7 / 4) /= 1 report "Ensure that the integer Arithmetic cuts not rounds as it should, 7/4 = " &
    integer'image(7 / 4)
    severity note;
  assert (7 / 4) = 1 report "The Arithmetic division rounds not cuts 7/4 = " &
    integer'image(7 / 4) & ", language conversion?"
    severity error;

  
  M_gene : for ind1 in M_min to M_max generate
    N_gene : for ind2 in N_min to N_max generate
      
      main_instanc : Amplitude_multiplier generic map (
        DAC_cycles      => 30,
        Channels_number => 2
        )
        port map(
          CLK    => '0',
          RST    => '0',
          EN     => '0',
          M      => M(M'low - 1 + ind1 downto M'low),
          N      => N(N'low - 1 + ind2 downto N'low),
          theOut => theOut(theOut'low - 1 + ind1 + ind2 downto theOut'low));
    end generate N_gene;
  end generate M_gene;
end architecture arch;
