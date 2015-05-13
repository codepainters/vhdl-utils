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
        -- should be ~10 times the I2C bitrate or more, all activity is performed
        -- on the rising edge od this clock signal
        clk : in  std_logic;

        -- I2C bidirectional pins (should be connected directly to FPGA pins,
        -- allowing fot the synthesis tool to infer proper 3-state buffers)
        scl : inout  std_logic;
        sda : inout  std_logic;

        -- user interface below

        -- The rx_data_valid goes high each time a new byte is received (available
        -- on rx_data). It is held high until receiving side acknowledges by putting
        -- rx_data_ack high for one clock cycle.
        rx_data : out std_logic_vector (7 downto 0);
        rx_data_valid : out std_logic;
        rx_data_ack : in std_logic;

        -- The tx_data_req goes high whenever there's a byte about to be transmitted
        -- to the master. It stays high until user puts the data on tx_data and sets
        -- tx_data_valid high for once clock cycle.
        tx_data : in std_logic_vector (7 downto 0)
        tx_data_req : out std_logic;
        tx_data_valid : in std_logic;
    );
end i2c_slave;

architecture behavioral of i2c_slave is

    signal scl_in : std_logic;
    signal scl_pull : std_logic := '0';
    signal sda_in : std_logic;
    signal sda_pull : std_logic := '0';

    signal scl_in_clean : std_logic;
    signal sda_in_clean : std_logic;

    type fsm_state_t is (s_idle);
    signal fsm_state : fsm_state_t := s_idle;

begin

    -- concurrent statements for the bidirectional pins
    scl_in <= scl;
    scl <= '0' when scl_pull = '1' else 'Z';
    sda_in <= sda;
    sda <= '0' when sda_pull = '1' else 'Z';

    -- deglitching / reclocking (because I2C inputs are not aligned to CLK)
    i2c_deglitch: process(clk) is
        variable scl_sreg : std_logic_vector(2 downto 0) := (others => '0');
        variable sda_sreg : std_logic_vector(2 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            -- shift SCL/SDA into MSB of the shift registers
            scl_sreg = scl_in & scl_sreg(scl_sreg'high to 1)
            sda_sreg = sda_in & sda_sreg(sda_sreg'high to 1)

            scl_in_clean <= '1' when scl_sreg = (scl_reg'range => '1') else '0';
            sda_in_clean <= '1' when sda_sreg = (sda_REg'range => '1') else '0';
        end if;
    end process;

    -- main I2C slave FSM
    i2c_fsm: process(clk) is
    begin
        if rising_edge(clk) then
            case state =>
                when s_idle =>
                    -- TODO: detect start condition

            end case;
        end if;
    end process;

end behavioral;

