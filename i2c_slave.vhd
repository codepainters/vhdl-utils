----------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
--
-- This module implements a simple I2C bus slave interface.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;

entity i2c_slave is
    port (
        -- should be ~10 times the I2C bitrate or more
        clk : in  std_logic;

        -- I2C bidirectional pins (should be connected directly to FPGA pins,
        -- allowing fot the synthesis tool to infer proper 3-state buffers)
        scl : inout  std_logic;
        sda : inout  std_logic;

        -- received data interface (from I2C bus)
        din : out  std_logic_vector (7 downto 0);

        -- transmitted data interface (towards I2C bus)
        dout : in  std_logic_vector (7 downto 0));
end i2c_slave;

architecture behavioral of i2c_slave is

    signal scl_in : std_logic;
    signal scl_pull : std_logic := '0';
    signal sda_in : std_logic;
    signal sda_pull : std_logic := '0';

begin

end behavioral;

