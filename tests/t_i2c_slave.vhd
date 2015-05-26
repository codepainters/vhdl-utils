--------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
--
-- Testbench for I2C slave interface
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
 
entity t_i2c_slave is
end t_i2c_slave;
 
architecture behavior of t_i2c_slave is
    component i2c_slave
    generic (
        address: std_logic_vector(6 downto 0));
    port(
        clk : in std_logic;
    
        -- I2C interface
        scl : inout std_logic;
        sda : inout std_logic;
         
        -- received data interface
        rx_data : out std_logic_vector(7 downto 0);
        rx_data_valid : out std_logic;
        rx_data_ack : in std_logic;
        
        -- transmitted data interface
        tx_data : in std_logic_vector(7 downto 0);
        tx_data_req : out std_logic;
        tx_data_valid : in  std_logic);
    end component;

    -- clock 
    signal clk : std_logic := '0';
    constant clk_period : time := 20 ns;
    signal clk_enabled : boolean := true;

    -- I2C interface
    signal scl : std_logic;
    signal sda : std_logic;
   
    signal scl_out : std_logic := '1';
    signal sda_out : std_logic := '1';
   
    -- RX interface
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_data_valid : std_logic;
    signal rx_data_ack : std_logic := '0';

 	-- TX interface
    signal tx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_data_req : std_logic;
    signal tx_data_valid : std_logic := '0';

    -- 400kHz I2C clock
    constant i2c_clk_period : time := 2.5 us;

    procedure i2c_start(signal sda : out std_logic; signal scl : out std_logic) is
    begin
        sda <= '1';
        scl <= '1';
        wait for i2c_clk_period / 2;
        sda <= '0';
        wait for i2c_clk_period / 2;
    end procedure;

    procedure i2c_stop(signal sda : out std_logic; signal scl : out std_logic) is
    begin
        sda <= '0';
        scl <= '1';
        wait for i2c_clk_period / 2;
        sda <= '1';
        wait for i2c_clk_period / 2;
    end procedure;

begin
    uut: i2c_slave 
      generic map (address => "1010110")
      port map (
        clk => clk,
        scl => scl,
        sda => sda,
        rx_data => rx_data,
        rx_data_valid => rx_data_valid,
        rx_data_ack => rx_data_ack,
        tx_data => tx_data,
        tx_data_req => tx_data_req,
        tx_data_valid => tx_data_valid);

    -- clock generator
    clk <= not clk after clk_period / 2 when clk_enabled = true else '0';

    -- I2C drivers, note: weak H emulates pull-ups
    scl <= 'H' when scl_out = '1' else '0';
    sda <= 'H' when sda_out = '1' else '0';

    stimulation : process is
    begin
        i2c_start(sda_out, scl_out);
        wait for 5 * i2c_clk_period;
        i2c_stop(sda_out, scl_out);
        wait for 2 * i2c_clk_period;
        clk_enabled <= false;
        
        wait until false;
    end process;
    
end;
