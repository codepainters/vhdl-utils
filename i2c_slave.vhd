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

        -- TODO: rename s/rx_/wr_/
        -- The rx_data_valid goes high each time a new byte is received (available
        -- on rx_data). It is held high until receiving side acknowledges by putting
        -- rx_data_ack high for one clock cycle.
        rx_data : out std_logic_vector (7 downto 0);
        rx_data_valid : out std_logic;
        rx_data_ack : in std_logic;

        -- The rd_data_req goes high whenever there's a byte about to be transmitted
        -- to the master. It stays high until user puts the data on rd_data and sets
        -- rd_data_valid high for one clock cycle.
        rd_data : in std_logic_vector (7 downto 0);
        rd_data_req : out std_logic;
        rd_data_valid : in std_logic
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
    type fsm_state_t is (s_idle, s_addr, s_addr_ack, 
                         s_read_ws, s_read, s_read_ack,
                         s_write);
    signal fsm_state : fsm_state_t := s_idle;

    -- input shift register
    signal rx_sreg : std_logic_vector(7 downto 0);
    
    -- TODO: convert to SREG once we have FSM fully working
    -- count of rx/tx bits
    signal bit_counter : integer;

    -- TODO: check if it is better to latch SDA on raising or falling SCL edge

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
                        rx_sreg <= (others => '0');
                        bit_counter <= 8;
                        fsm_state <= s_addr;
                    end if;

                when s_addr =>
                    if stop_condition then
                        -- stop condition during the address phase - go back to idle
                        fsm_state <= s_idle;
                    elsif start_condition then
                        -- start condition means sync error, treat it as a (re)start
                        -- of a new transaction
                        rx_sreg <= (others => '0');
                        bit_counter <= 8;
                        fsm_state <= s_addr;
                    elsif rising_clk_edge then
                        -- shift in next bit on each rising SCL edge
                        rx_sreg <= rx_sreg(6 downto 0) & sda_in_clean;
                        bit_counter <= bit_counter - 1;
                    elsif falling_clk_edge then
                        -- note: it's a signal, so we "see" previous state
                        -- if all 8 bits are clocked in, is it addressed to us?
                        if bit_counter = 0 then
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
                            fsm_state <= s_read_ws;
                            scl_pull <= '1';
                            rd_data_req <= '1';
                        else
                            fsm_state <= s_write;
                        end if;
                        rx_sreg <= (0 => '1', others => '0');
                    end if;
                    
                -- read states

                when s_read_ws =>
                    -- in this state we pull SCL down and wait for the user to provide
                    -- a byte to send, then we go to s_read. Note: because we pull SCL
                    -- down, start/stop conditions can't occur.
                    if rd_data_valid = '1' then
                        -- latch the data
                        rd_data_req <= '0';  
                        rx_sreg <= rd_data;
                        
                        fsm_state <= s_read;
                        scl_pull <= '0';
                        bit_counter <= 8;
                    end if;
                    
                when s_read =>
                    -- there's a byte to send to master, 
                    if stop_condition then
                        fsm_state <= s_idle;
                    elsif start_condition then
                        -- start condition means sync error, treat it as a (re)start
                        -- of a new transaction
                        rx_sreg <= (others => '0');
                        bit_counter <= 8;
                        fsm_state <= s_addr;
                    elsif falling_clk_edge then
                        -- was it the last bit?
                        if bit_counter = 0 then
                            -- yes, go wait for master's ACK
                            fsm_state <= s_read_ack;
                        else
                            -- nope, continue
                            bit_counter <= bit_counter - 1;
                            rx_sreg <= rx_sreg(6 downto 0) & '0';
                        end if;
                    end if;                    
                    
                when s_read_ack =>
                    -- all bits shifted out, here we wait for falling edge to
                    -- check if master ACKs the byte
                    if stop_condition then                        
                        fsm_state <= s_idle;
                    elsif start_condition then
                        -- start condition means sync error, treat it as a (re)start
                        -- of a new transaction
                        rx_sreg <= (others => '0');
                        bit_counter <= 8;
                        fsm_state <= s_addr;
                    elsif falling_clk_edge then
                        if sda_in_clean = '1' then
                            -- byte acked, fetch the next one
                            fsm_state <= s_read_ws;
                            scl_pull <= '1';
                            rd_data_req <= '1';                        
                        else
                            -- shortcut - go idle before the stop condition
                            fsm_state <= s_idle;
                        end if;                        
                    end if;
                    
                -- write states
                    
                when s_write =>

            end case;
        end if;
    end process;

    -- SDA output is mux'ed based on fsm_state
    sda_pull <= '1' when fsm_state = s_addr_ack 
            else not rx_sreg(7) when fsm_state = s_read
            else '0';

end behavioral;

