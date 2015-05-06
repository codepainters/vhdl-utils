--------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
--
-- Testbench for teh HD44780 LCD interface.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity t_hd44780_iface is
end t_hd44780_iface;

architecture behavior of t_hd44780_iface is

    component hd44780_iface
    port(clk : in std_logic;
         time_base : in std_logic;
         db : in std_logic_vector(7 downto 0);
         rs : in std_logic;
         strb : in std_logic;
         busy : out std_logic;

         lcd_e : out std_logic;
         lcd_rs : out std_logic;
         lcd_rw : out std_logic;
         lcd_d : out std_logic_vector(7 downto 4)
        );
    end component;

    signal clk : std_logic := '0';
    signal time_base : std_logic := '0';
    signal db : std_logic_vector(7 downto 0) := (others => '0');
    signal rs : std_logic := '0';
    signal strb : std_logic := '0';

    signal busy : std_logic;
    signal lcd_e : std_logic;
    signal lcd_rs : std_logic;
    signal lcd_rw : std_logic;
    signal lcd_d : std_logic_vector(7 downto 4);

    -- 50MHz main clock, 1kHz time base
    constant clk_period : time := 20 ns;
    constant time_base_ratio : integer := 50_000;

    -- E pulse timing paramters, from the Hitachi HD44780U datahseet,
    -- worst case (VCC 2.7..4.5V)
    constant min_power_up_delay : time := 40 ms;
    constant min_addr_setup_time : time := 60 ns;
    constant min_addr_hold_time : time := 20 ns;
    constant min_data_setup_time : time := 195 ns;
    constant min_data_hold_time : time := 10 ns;
    constant min_e_pulse_width : time := 450 ns;
    -- minimum time between E rising edges
    constant min_e_cycle_time : time := 1000 ns;

    type t_init_sequence_entry is record
        data : std_logic_vector(7 downto 4);
        delay : time;
    end record;
    type t_init_sequence is array (0 to 3) of t_init_sequence_entry;
    signal init_sequence : t_init_sequence := (
        (X"3", 4.1 ms),
        (X"3", 100 us),
        (X"3", 100 us),
        (X"2", 100 us));

begin

    uut: hd44780_iface port map (
        clk => clk,
        time_base => time_base,
        db => db,
        rs => rs,
        strb => strb,
        busy => busy,
        lcd_e => lcd_e,
        lcd_rs => lcd_rs,
        lcd_rw => lcd_rw,
        lcd_d => lcd_d);

    -- Clock process definitions
    clk_process : process
        variable i : integer;
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    time_base_process : process
    begin
        time_base <= '0';
        wait for clk_period * (time_base_ratio - 1);
        time_base <= '1';
        wait for clk_period;
    end process;

    user_process : process
    begin
        -- TODO: write a process that waits for the controller to become idle
        -- and sends some arbitrary byte
        -- TODO: check busy signal handling
        wait for 100ms;
        rs <= '1';
        db <= X"A5";
        strb <= '1';
        wait for clk_period;
        strb <= '0';
    end process;

    t_lcd_timing : process
        variable e_prev : time;
        variable e_start : time := 0 ns;
    begin
        -- wait for E raising edge
        wait until lcd_e = '1';
        e_prev := e_start;
        e_start := now;

        assert e_start > min_power_up_delay report "initial power-up delay time violated" severity error;

        -- check minimum cycle time
        if e_prev /= 0 ns then
            assert e_start - e_prev > min_e_cycle_time report "lcd_e minimum cycle time violated" severity error;
        end if;

        -- check setup time
        assert lcd_rs'stable(min_addr_setup_time) report "lcd_rs setup time violated" severity error;
        assert lcd_d'stable(min_data_setup_time) report "lcd_d setup time violated" severity error;

        -- wait for E falling edge, check pulse width
        wait until lcd_e = '0';
        assert now - e_start > min_e_pulse_width report "lcd_e minimum pulse width violated" severity error;

        -- check hold time
        assert lcd_rs'stable(min_addr_hold_time) report "lcd_rs hold time violated" severity error;
        assert lcd_d'stable(min_data_hold_time) report "lcd_d hold time violated" severity error;
    end process;

    t_lcd_init : process
    begin
        wait until lcd_e = '1';
        assert now > min_power_up_delay report "initial power-up delay time violated" severity error;

        -- TODO: check timing
        for i in init_sequence'low to init_sequence'high loop
            wait until lcd_e = '0';
            assert lcd_d = init_sequence(i).data report "invalid init sequence" severity error;
        end loop;

        wait until lcd_e = '1';

        wait until False;
    end process;

end;
