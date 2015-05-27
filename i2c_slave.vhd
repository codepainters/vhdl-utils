----------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
--
-- This module implements a simple I2C bus slave interface.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity i2c_slave is
    generic (
        -- address on the I2C bus
        address: std_logic_vector(6 downto 0)
    );
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
        tx_data : in std_logic_vector (7 downto 0);
        tx_data_req : out std_logic;
        tx_data_valid : in std_logic
    );
end i2c_slave;

architecture behavioral of i2c_slave is

    signal scl_in : std_logic;
    signal scl_pull : std_logic := '0';
    signal sda_in : std_logic;
    signal sda_pull : std_logic := '0';

    -- deglitcher shift registers
    signal scl_sreg : std_logic_vector(2 downto 0) := (others => '1');
    signal sda_sreg : std_logic_vector(2 downto 0) := (others => '1');

    -- reclocked and deglitched SCL/SDA inputs
    signal scl_in_clean : std_logic := '1';
    signal sda_in_clean : std_logic := '1';
    -- previous states
    signal scl_in_prev : std_logic;
    signal sda_in_prev : std_logic;

    -- helper signals - start/stop/edge conditions
    signal start_condition : boolean;
    signal stop_condition : boolean;
    signal rising_clk_edge : boolean;
    signal falling_clk_edge : boolean;

    -- FSM states
    type fsm_state_t is (s_idle, s_addr, s_addr_ack, s_read, s_write);
    signal fsm_state : fsm_state_t := s_idle;

    -- input shift register (1 extra bit for simple end detection)
    signal rx_sreg : std_logic_vector(8 downto 0);

begin

    -- concurrent statements for the bidirectional pins
    scl_in <= scl;
    scl <= '0' when scl_pull = '1' else 'Z';
    sda_in <= sda;
    sda <= '0' when sda_pull = '1' else 'Z';

    -- deglitching / reclocking (because I2C inputs are not aligned to CLK)
    i2c_deglitch: process(clk) is
    begin
        if rising_edge(clk) then
            -- shift SCL/SDA into MSB of the shift registers
            scl_sreg <= to_X01(scl_in) & scl_sreg(scl_sreg'high downto 1);
            sda_sreg <= to_X01(sda_in) & sda_sreg(sda_sreg'high downto 1);

            if scl_sreg = (scl_sreg'range => '1') then
                scl_in_clean <= '1';
            elsif scl_sreg = (scl_sreg'range => '0') then
                scl_in_clean <= '0';
            end if;

            if sda_sreg = (sda_sreg'range => '1') then
                sda_in_clean <= '1';
            elsif sda_sreg = (sda_sreg'range => '0') then
                sda_in_clean <= '0';
            end if;

            scl_in_prev <= scl_in_clean;
            sda_in_prev <= sda_in_clean;
        end if;
    end process;

    -- start/stop conditions
    start_condition <= scl_in_prev = '1' and scl_in_clean = '1' and
        sda_in_prev = '1' and sda_in_clean = '0';
    stop_condition <= scl_in_prev = '1' and scl_in_clean = '1' and
        sda_in_prev = '0' and sda_in_clean = '1';
    rising_clk_edge <= scl_in_prev = '0' and scl_in_clean = '1';
    falling_clk_edge <= scl_in_prev = '1' and scl_in_clean = '0';

    -- main I2C slave FSM
    i2c_fsm: process(clk) is
    begin
        if rising_edge(clk) then
            case fsm_state is
                when s_idle =>
                    -- detect start condition
                    if start_condition then
                        rx_sreg <= (0 => '1', others => '0');
                        fsm_state <= s_addr;
                    end if;

                when s_addr =>
                    -- shift in next bit on each rising SCL edge
                    if rising_clk_edge then
                        rx_sreg <= rx_sreg(7 downto 0) & sda_in_clean;

                        -- note: it's a signal, so we "see" previous state
                        -- if all 8 bits are clocked in, is it addressed to us?
                        if rx_sreg(8) = '1' then
                            if rx_sreg(7 downto 1) = address then
                                fsm_state <= s_addr_ack;
                            else
                                fsm_state <= s_idle;
                            end if;
                        end if;
                    end if;

                when s_addr_ack =>
                    -- note: sda_pull is set high in this state by concurrent statement
                    -- we only wait for the clock pulse
                    if falling_clk_edge then
                        if rx_sreg(0) = '1' then
                            fsm_state <= s_read;
                        else
                            fsm_state <= s_write;
                        end if;
                        rx_sreg <= (0 => '1', others => '0');
                    end if;

                when s_read =>

                when s_write =>

            end case;
        end if;
    end process;

    sda_pull <= '1' when fsm_state = s_addr_ack else '0';

end behavioral;

