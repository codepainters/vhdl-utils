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
        wr_data : out std_logic_vector(7 downto 0);
        wr_data_valid : out std_logic;
        wr_data_ack : in std_logic;
        
        -- transmitted data interface
        rd_data : in std_logic_vector(7 downto 0);
        rd_data_req : out std_logic;
        rd_data_valid : in  std_logic);
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
    signal wr_data : std_logic_vector(7 downto 0);
    signal wr_data_valid : std_logic;
    signal wr_data_ack : std_logic := '0';

 	-- TX interface
    signal rd_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rd_data_req : std_logic;
    signal rd_data_valid : std_logic := '0';

    -- 400kHz I2C clock
    constant i2c_clk_period : time := 2.5 us;

    procedure i2c_start(signal sda : out std_logic; signal scl : out std_logic) is
    begin
        sda <= '1';
        scl <= '1';
        wait for i2c_clk_period / 2;
        sda <= '0';
        wait for i2c_clk_period / 2;
        scl <= '0';
    end procedure;

    procedure i2c_stop(signal sda : out std_logic; signal scl : out std_logic) is
    begin
        sda <= '0';
        scl <= '0';
        wait for i2c_clk_period / 2;
        scl <= '1';
        wait for i2c_clk_period / 2;
        sda <= '1';
    end procedure;

    procedure i2c_clock_pulse(signal sda : out std_logic; signal scl : out std_logic) is
    begin
        scl <= '0';
        wait for i2c_clk_period / 4;
        scl <= '1';
        wait for i2c_clk_period / 2;
        scl <= '0';
        wait for i2c_clk_period / 4;
    end procedure;

    procedure i2c_send_addr(signal sda : out std_logic; signal scl : out std_logic;
                            address : std_logic_vector(6 downto 0); wr : boolean) is
    begin
        for i in address'high downto address'low loop
            sda <= address(i);
            i2c_clock_pulse(sda, scl);
        end loop; 
        if wr then
            sda <= '1';
        else 
            sda <= '0';
        end if;
        i2c_clock_pulse(sda, scl);
    end procedure;
    
    procedure i2c_ack(signal sda : out std_logic; signal scl : out std_logic;
                      signal sda_in : in std_logic; ack : out boolean) is
    begin
        sda <= '1';
        scl <= '0';
        wait for i2c_clk_period / 4;
        scl <= '1';
        ack := (sda_in = '0');
        wait for i2c_clk_period / 2;
        scl <= '0';
        wait for i2c_clk_period / 4;        
    end procedure;

begin
    uut: i2c_slave 
      generic map (address => "1010110")
      port map (
        clk => clk,
        scl => scl,
        sda => sda,
        wr_data => wr_data,
        wr_data_valid => wr_data_valid,
        wr_data_ack => wr_data_ack,
        rd_data => rd_data,
        rd_data_req => rd_data_req,
        rd_data_valid => rd_data_valid);

    -- clock generator
    clk <= not clk after clk_period / 2 when clk_enabled = true else '0';

    -- I2C drivers, note: weak H emulates pull-ups
    scl <= 'H' when scl_out = '1' else '0';
    sda <= 'H' when sda_out = '1' else '0';

    stimulation : process is
        variable ack : boolean;
    begin
        -- write with valid address
        i2c_start(sda_out, scl_out);
        i2c_send_addr(sda_out, scl_out, B"101_0110", true);
        i2c_ack(sda_out, scl_out, sda, ack);
        i2c_stop(sda_out, scl_out);
        assert ack report "test failed - no ACK" severity error;
        
        wait for 2 * i2c_clk_period;
        clk_enabled <= false;
        
        wait until false;
    end process;
    
end;
