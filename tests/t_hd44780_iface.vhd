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
    generic (time_base_period : integer);
    port(clk : in std_logic;
         time_base : in std_logic;
         db : in std_logic_vector(7 downto 0);
         rs : in std_logic;
         strb : in std_logic;
         rdy : out std_logic;

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

    signal ready : std_logic;
    signal lcd_e : std_logic;
    signal lcd_rs : std_logic;
    signal lcd_rw : std_logic;
    signal lcd_d : std_logic_vector(7 downto 4);

    -- 50MHz main clock, 1kHz time base
    constant clk_period : time := 20 ns;    
    constant time_base_ratio : integer := 5_000;
    constant time_base_period : integer := 100; -- microseconds

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

    -- datasheet says 37us (+ 4us for RAM access), let's add some margin
    constant normal_cmd_delay : time := 50 us;
    -- can't find it stated explicitely anywhere - assuming same
    -- as command delay (probably much longer than needed)
    constant high_nibble_delay : time := normal_cmd_delay;
    -- Clear Display and Return Home need more time (1.6 ms + margin)
    constant long_cmd_delay : time := 2 ms;

    -- init sequence
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

    -- user commands
    type t_user_command is record
        rs : std_logic;
        data: std_logic_vector(7 downto 0);
    end record;
    type t_user_commands is array (0 to 3) of t_user_command;
    signal user_commands : t_user_commands := (
        ('0', X"01"),   -- Display Clear command
        ('0', X"02"),   -- Return Home command
        ('1', X"41"),
        ('1', X"5A"));

begin
    -- TODO: check ready signal handling

    uut: hd44780_iface 
        generic map (time_base_period => time_base_period)
        port map (
            clk => clk,
            time_base => time_base,
            db => db,
            rs => rs,
            strb => strb,
            rdy => ready,
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
        variable minimum_delay: time;
    begin
        -- note: we can't progress on the same edge when ready goes '1'
        wait until ready = '1' and falling_edge(clk);

        for i in user_commands'low to user_commands'high loop
            rs <= user_commands(i).rs;
            db <= user_commands(i).data;
            strb <= '1';
            wait for clk_period;
            strb <= '0';
            -- after one clk period 'ready' should be low
            assert ready = '0' report "ready not low after submitting a byte" severity error;

            wait until ready = '1';
            -- ensure enough time was given for the command to execute
            if user_commands(i).data = B"00000001" or user_commands(i).data(7 downto 1) = B"0000001" then
                -- Clear Display or Return Home
                minimum_delay := long_cmd_delay;
            else
                minimum_delay := normal_cmd_delay;
            end if;

            assert lcd_e = '0' and lcd_e'last_event > minimum_delay
                report "command execution time not respected" severity error;

            wait until falling_edge(clk);
        end loop;

        -- TODO: stop clocks to terminate simulation

        wait until False;
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
        variable cmd_start : time;
    begin
        wait until lcd_e = '1';
        assert now > min_power_up_delay report "initial power-up delay time violated" severity error;

        for i in init_sequence'low to init_sequence'high loop
            wait until lcd_e = '0';
            cmd_start := now;
            assert lcd_d = init_sequence(i).data report "invalid init sequence" severity error;

            -- check enough time is given for each command to execute
            wait until lcd_e = '1';
            assert now - cmd_start >= init_sequence(i).delay report "init sequence delay violation" severity error;
        end loop;

        -- when we get here, lcd_e is '1' - first user command was just submitted (high nibble)

        wait until False;
    end process;

end;
