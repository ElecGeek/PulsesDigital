library ieee;
use ieee.std_logic_1164.all,
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.global_volume_size,
  work.Amplitude_package.Amplitude_multiplier;

--! @brief Check the strategy to be close to the rail to rail
--!
--!
entity Amplitudes_multiplier_R2R_test is
  generic (
    M_min : integer range 2 to 300     := 2;
    N_min : integer range 2 to 300     := 2;
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
        MasterCLK_SampleCLK_ratio => 30
        )
        port map(
          CLK     => '0',
          load    => '0',
          execR2R => '0',
          M       => M(M'low - 1 + ind1 downto M'low),
          N       => N(N'low - 1 + ind2 downto N'low),
          theOut  => theOut(theOut'low - 1 + ind1 + ind2 downto theOut'low));
    end generate N_gene;
  end generate M_gene;
end architecture arch;



library ieee;
use ieee.std_logic_1164.all,
  ieee.numeric_std.all,
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.global_volume_size,
  work.Amplitude_package.Amplitude_multiplier;

entity Amplitudes_multiplier_test is
end entity Amplitudes_multiplier_test;

architecture arch of Amplitudes_multiplier_test is
  signal M             : std_logic_vector(requested_amplitude_size - 1 downto 0);
  signal N             : std_logic_vector(global_volume_size - 1 downto 0);
  signal theOut        : std_logic_vector(requested_amplitude_size + global_volume_size - 1 downto 0);
  signal CLK           : std_logic               := '0';
  signal load          : std_logic;
  signal counter       : unsigned(12 downto 0)   := (others      => '0');
  constant counter_max : unsigned(counter'range) := ("1", others => '0');
  component Amplitude_multiplier_CXX_wrap is
    port (
      --! For more information see in the wrapped entity
      CLK     : in  std_logic;
      --! For more information see in the wrapped entity
      load    : in  std_logic;
      --! For more information see in the wrapped entity
      execR2R : in  std_logic;
      --! For more information see in the wrapped entity
      M       : in  std_logic_vector(requested_amplitude_size - 1 downto 0);
      --! For more information see in the wrapped entity
      N       : in  std_logic_vector(global_volume_size - 1 downto 0);
      --! For more information see in the wrapped entity
      theOut  : out std_logic_vector(requested_amplitude_size + global_volume_size - 1 downto 0)
      );
  end component Amplitude_multiplier_CXX_wrap;

begin

  main_proc : process is
  begin
    if counter /= counter_max then
      if CLK = '0' then
        counter <= counter + 1;
        if counter(counter'low+3 downto counter'low) = "0000" then
          load <= '1';
        elsif counter(counter'low+3 downto counter'low) = "1111" then
          M <= (std_logic_vector(counter(counter'high - 1 downto counter'high - 4)), others => '1');
          N <= (std_logic_vector(counter(counter'high - 5 downto counter'high - 8)), others => '1');
        else
          load <= '0';
        end if;
      end if;
      CLK <= not CLK;
      wait for 1 us;
    else
      wait;
    end if;
  end process main_proc;

  main_instanc : Amplitude_multiplier_CXX_wrap
    --generic map (
    --MasterCLK_SampleCLK_ratio      => 30,
    --Channels_number                => 2
    --)
    port map(
      CLK     => CLK,
      load    => load,
      execR2R => '0',
      M       => M,
      N       => N,
      theOut  => theOut);

end architecture arch;
