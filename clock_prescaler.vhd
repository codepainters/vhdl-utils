----------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
--
-- This is an implementation of an efficient clock prescaler for Xilinx FPGAs,
-- based on SRL16 shift register primitive. 
-- 
-- It divides the input clock by n * (10 ^ exp), where n is in range 2..16 and
-- exp is in range 0..10. Output goes 1 for one cycle of the input clock, 
-- every n * (10 ^ exp) cycles of the input clock.
--
-- It uses only exp + 1 LUTs, which is a significant improvement over a prescaler
-- based on a simple counter.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity clock_prescaler is
    generic (n : integer range 2 to 16;
             exp : integer range 0 to 10);
    port(clk : in  std_logic;
         q : out  std_logic);
end clock_prescaler;

architecture rtl of clock_prescaler is
    
    -- first stage length
    constant first_stage_tap : std_logic_vector(3 downto 0) := std_logic_vector(to_signed(n - 1, 4));
    
    -- feedback signal inside each stage
    signal sreg_fb : std_logic_vector(0 to exp);
    -- those signals go between stages
    signal stage_q : std_logic_vector(0 to exp);

begin
    -- first stage divides by n
    first_reg : SRLC16E
        generic map(INIT => X"0001")
        port map (Q => sreg_fb(0), Q15 => open, 
                  A0 => first_stage_tap(0), A1 => first_stage_tap(1), 
                  A2 => first_stage_tap(2), A3 => first_stage_tap(3),
                  CE => '1', D => sreg_fb(0), CLK => clk );
    stage_q(0) <= sreg_fb(0);
                      
    -- subsequent exp stages each divides by 10
    exp_divides : for i in 1 to exp generate
    begin
        sreg : SRLC16E
            generic map(INIT => X"0001")
            port map (Q => sreg_fb(i), Q15 => open, 
                      A0 => '1', A1 => '0', A2 => '0', A3 => '1',
                      CE => stage_q(i - 1), D => sreg_fb(i),
                      CLK => clk );
        
        -- shift reg output must be AND-ed with previous stage output, 
        -- so the pulse is only 1 clk period long
        q_and : AND2 port map (I0 => sreg_fb(i), I1 => stage_q(i - 1), O => stage_q(i));
    end generate;
    
    -- output of the last stage is prescaler's output
    q <= stage_q(exp);

end rtl;

