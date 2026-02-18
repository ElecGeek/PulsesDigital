library ieee;
use ieee.std_logic_1164.all,
  work.Amplitude_package.requested_amplitude_size,
  work.Amplitude_package.global_volume_size,
  work.Amplitude_package.Amplitude_multiplier;

entity Amplitude_multiplier_CXX_wrap is
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
end entity Amplitude_multiplier_CXX_wrap;

architecture arch of Amplitude_multiplier_CXX_wrap is

begin
  instanc : Amplitude_multiplier
    port map (
      CLK     => CLK,
      EN      => '1',
      load    => load,
      execR2R => execR2R,
      M       => M,
      N       => N,
      theOut  => theOut);
end architecture arch;
