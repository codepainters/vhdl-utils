----------------------------------------------------------------------------------
-- This file is only used for some quick synthesis checks
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.ALL;

entity top is
    port(clk : in std_logic;
         strb : in std_logic;
         rs : in std_logic;
         busy : out std_logic;
         db : in  std_logic_vector(7 downto 0);
         -- LCD interface
	     lcd_e   : out  STD_LOGIC;
         lcd_rs  : out  STD_LOGIC;
		 lcd_rw  : out  STD_LOGIC;
		 sf_d    : inout  STD_LOGIC_VECTOR(11 downto 8);
			  
		 -- StrataFlash chip enable
		 sf_ce0  : out STD_LOGIC);
end top;

architecture rtl of top is

    component clock_prescaler is
        generic (n : integer range 2 to 16;
                 exp : integer range 0 to 10);
        port(clk : in  std_logic;
             q : out  std_logic);
    end component;

	component hd44780_iface is 
        port(
       -- main clock
        clk : in std_logic;
        time_base : in std_logic;

        -- control interface
        db : in  std_logic_vector(7 downto 0);
        rs : in std_logic;
        strb : in std_logic;
        busy : out std_logic;
			  
        -- outputs to LCD
        lcd_e  : out  std_logic;
        lcd_rs : out  std_logic;
        lcd_rw : out  std_logic;
        lcd_d  : out  std_logic_vector(7 downto 4));		
	end component;

    signal time_base : std_logic;

begin
   
    sf_ce0 <= '0';
      
    prescaler : clock_prescaler 
        generic map(n => 3, exp => 3)
        port map(clk => clk, q => time_base);
   
    lcd : hd44780_iface
        port map(clk => clk,
                 lcd_e => lcd_e,
                 lcd_rs => lcd_rs,
                 lcd_rw => lcd_rw,
                 lcd_d => sf_d,
                 db => db,
                 rs => rs,
                 strb => strb,
                 busy => busy,
                 time_base => time_base
                 );
        
   
end rtl;

