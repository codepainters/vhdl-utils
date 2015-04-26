----------------------------------------------------------------------------------
-- This file is only used for some quick synthesis checks
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.ALL;

entity top is
    port(clk : in std_logic;
           q : out std_logic);
end top;

architecture rtl of top is

    component clock_prescaler is
        generic (n : integer range 2 to 16;
                 exp : integer range 0 to 10);
        port(clk : in  std_logic;
             q : out  std_logic);
    end component;

begin
   
    prescaler : clock_prescaler 
        generic map(n => 3, exp => 8)
        port map(clk => clk, q => q);
   
end rtl;

