--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   23:56:56 05/13/2015
-- Design Name:   
-- Module Name:   /home/czajnik/work/vhdl-utils/tests/t_i2c_slave.vhd
-- Project Name:  vhdl-utils
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: i2c_slave
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY t_i2c_slave IS
END t_i2c_slave;
 
ARCHITECTURE behavior OF t_i2c_slave IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT i2c_slave
    PORT(
         clk : IN  std_logic;
         scl : INOUT  std_logic;
         sda : INOUT  std_logic;
         rx_data : OUT  std_logic_vector(7 downto 0);
         rx_data_valid : OUT  std_logic;
         rx_data_ack : IN  std_logic;
         tx_data : IN  std_logic_vector(7 downto 0);
         tx_data_req : OUT  std_logic;
         tx_data_valid : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rx_data_ack : std_logic := '0';
   signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
   signal tx_data_valid : std_logic := '0';

	--BiDirs
   signal scl : std_logic;
   signal sda : std_logic;

 	--Outputs
   signal rx_data : std_logic_vector(7 downto 0);
   signal rx_data_valid : std_logic;
   signal tx_data_req : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: i2c_slave PORT MAP (
          clk => clk,
          scl => scl,
          sda => sda,
          rx_data => rx_data,
          rx_data_valid => rx_data_valid,
          rx_data_ack => rx_data_ack,
          tx_data => tx_data,
          tx_data_req => tx_data_req,
          tx_data_valid => tx_data_valid
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
