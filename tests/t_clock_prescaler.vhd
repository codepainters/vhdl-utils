--------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
-- 
-- Testbench for SRL16-based clock prescaler.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
 
entity t_clock_prescaler is
end t_clock_prescaler;


architecture behavior of t_clock_prescaler is
 
    component clock_prescaler
        generic (n : integer range 2 to 16;
                 exp : integer range 0 to 10);
        port(clk : in  std_logic;
             q : out  std_logic);
    end component;

    -- main clock
    signal clk : std_logic := '0';
    signal stop_simulation : std_logic := '0';
    constant clock_period : time := 10ns;
   
    -- outputs
    signal q_div2 : std_logic;
    signal q_div16 : std_logic;
    signal q_div300 : std_logic;

    procedure clock_checker(signal q_clk : std_logic;
                            divider : integer) is
        variable last_rising : time;    
    begin
        wait until q_clk = '1';
        while stop_simulation = '0' loop
            last_rising := now;
            wait until q_clk = '0';
            assert now - last_rising = clock_period severity error; 
            wait until q_clk = '1';
            assert now - last_rising = divider * clock_period severity error;             
        end loop;

    end procedure;
 
begin
    clk <= not clk after clock_period / 2 when stop_simulation /= '1' else '0';
    stop_simulation <= '1' after 15us;
    
    -- we test division by 2 and 16 to check edge cases with only a single stage,
    -- division by 300 checks the case with 1 + 2 stages
    uut_d2: clock_prescaler 
        generic map (n => 2, exp => 0)
        port map (clk => clk, q => q_div2);

    uut_d16: clock_prescaler 
        generic map (n => 16, exp => 0)
        port map (clk => clk, q => q_div16);

    uut_d300: clock_prescaler 
        generic map (n => 3, exp => 2)
        port map (clk => clk, q => q_div300);
      
    process
    begin
        clock_checker(q_div2, 2);
    end process;

    process
    begin
        clock_checker(q_div16, 16);
    end process;

    process
    begin
        clock_checker(q_div300, 300);
    end process;

end;
