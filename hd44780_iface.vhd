----------------------------------------------------------------------------------
-- Copyright (c) 2015, Przemyslaw Wegrzyn <pwegrzyn@codepainters.com>
-- This file is distributed under the Modified BSD License.
--
-- This modules implements a basic interface to HD44780-based LCD display
-- in 4-bit data bus mode.
--
-- Note: this module only takes care of intializing the display and switching it
-- to 4-bit mode, and ensures proper timing. Any further display intialization
-- has to be done by the user.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hd44780_iface is
    generic (time_base_period : time);
    port (  
        -- main clock
        clk : in std_logic;
        time_base : in std_logic;

        -- control interface
        db : in  std_logic_vector(7 downto 0);
        rs : in std_logic;
        strb : in std_logic;
        rdy : out std_logic;
			  
        -- outputs to LCD
        lcd_e  : out  std_logic;
        lcd_rs : out  std_logic;
        lcd_rw : out  std_logic;
        lcd_d  : out  std_logic_vector(7 downto 4));
end hd44780_iface;

architecture behavioral of hd44780_iface is

    -- intial delay after power - 50ms
    constant POWER_ON_DELAY : integer := 50 ms / time_base_period; 
    -- delay after each instruction in the init sequence. HD44780 requires 4.1ms
    -- after first instruction, for simplicty use 5ms for each 
    constant INIT_DELAY : integer := 5 ms / time_base_period;
    constant NIBBLE_DELAY : integer := 100 us / time_base_period;
    constant CMD_DELAY : integer := 2 ms / time_base_period;
 
    -- main FSM (sequencer) states
    type state_type is (power_on, init_write, init_wait, ready, d_write_nh, d_wait_nh, d_write_nl, d_wait_nl);
    signal state : state_type := power_on;
   
    -- initialization sequence
    subtype init_op is std_logic_vector(3 downto 0);
    type init_ops_array is array(0 to 3) of init_op;
    constant init_ops : init_ops_array := (x"3", x"3", x"3", x"2");
    signal init_ptr : integer range 0 to init_ops'high := 0;

    -- request latch
    signal r_data : std_logic_vector(7 downto 0);
    signal r_rs : std_logic;
  
    -- current nibble, 0 for high nibble
    signal nibble : integer range 0 to 1 := 1;

    -- writer FSM, starting in delay state allows for initial power-on delay
    type wr_state_type is (wr_ready, wr_setup, wr_strobe, wr_wait);
    signal wr_state : wr_state_type := wr_wait;       
    signal wr_start : std_logic := '0';

    -- helper function to calculate number of bits needed for delay counter
    function ceillog2 (constant n : natural) return natural is
    begin
        for m in 0 to 35 loop
            if 2**m >= n then
                return m;
            end if;
        end loop;
    end function;

    constant wr_delay_bits : integer := ceillog2(POWER_ON_DELAY) + 1;
    signal wr_delay : signed(wr_delay_bits - 2 downto 0); 
    signal wr_delay_cnt : signed(wr_delay_bits - 1 downto 0) := to_signed(POWER_ON_DELAY, wr_delay_bits); 
    signal wr_busy : std_logic;

begin
    -- main controller FSM
    sequencer : process(clk) is
    begin  
        if(clk'event and clk = '1') then
		    case state is
 
               when power_on =>
                    -- in this state we wait for the writer to become ready, 
                    -- it executes the initial power on delay
                    if wr_state = wr_ready then
                        state <= init_write;
                        wr_delay <= to_signed(INIT_DELAY, wr_delay_bits - 1);
                        wr_start <= '1';
                    end if;

                when init_write =>
                    -- wait until writer starts its job
                    if wr_state /= wr_ready then
                        state <= init_wait;
                        wr_start <= '0';
                    end if;

		        when init_wait =>
                    -- wait until writer is done
                    if wr_state = wr_ready then                        
                        if init_ptr = init_ops'high then
                            -- that was the last command, we are ready
                            state <= ready;
                        else
                            -- advance to the next instruction
                            init_ptr <= init_ptr + 1;
                            state <= init_write;
                            wr_delay <= to_signed(INIT_DELAY, wr_delay_bits - 1);
                            wr_start <= '1';
                        end if;
                    end if;
                    
                -- intialization done

                when ready =>
                    -- note: we use main clock here, so we "catch" input asap
                    if strb = '1' then
			            -- latch input data
			            r_data <= db;
				        r_rs <= rs;

                        -- start with high nibble
                        state <= d_write_nh;
                        wr_start <= '1';
                        wr_delay <= to_signed(NIBBLE_DELAY, wr_delay_bits - 1);
			        end if;

                when d_write_nh =>                   
                    if wr_state /= wr_ready then
				        state <= d_wait_nh;
                        wr_start <= '0';
                    end if;
		  
  		        when d_wait_nh =>                     
                    if wr_state = wr_ready then
                        state <= d_write_nl;
                        wr_start <= '1';
                        wr_delay <= to_signed(CMD_DELAY, wr_delay_bits - 1);
                    end if;

                when d_write_nl =>
                    if wr_state /= wr_ready then
				        state <= d_wait_nl;
                        wr_start <= '0';
                    end if;
		  
  		        when d_wait_nl => 
                    if wr_state = wr_ready then
                        state <= ready;
                    end if;
                    
            end case;
        end if;
    end process;
    
    -- output busy signal only goes low in 'ready' state
    rdy <= '1' when state = ready else '0';

    -- timer process waits for 1 on ws_start signal, then it preloads
    -- wr_delay_cnt from wr_delay and starts couting down 
    timer : process(clk)
    begin
        -- note: this process only changes state on time_base pulses
        if (clk'event and clk = '1' and time_base = '1') then
            if wr_start = '1' then               
                wr_delay_cnt <= '0' & wr_delay;
            else 
                if wr_delay_cnt(wr_delay_cnt'high) = '0' then
                    wr_delay_cnt <= wr_delay_cnt - 1;
                end if; 
            end if;
        end if;
    end process;
    
    -- this process is generating LCD E signal with proper timing    
    writer : process(clk)
    begin
        -- note: this process only changes state on time_base pulses
        if (clk'event and clk = '1' and time_base = '1') then
            case wr_state is
            
                when wr_ready =>
                    -- wait for 1 on wr_start (which also triggers delay counter)
                    if wr_start = '1' then
                        wr_state <= wr_setup;
                    end if;

                when wr_setup =>
                    -- this state introduces setup time of 1 time_base period
                    wr_state <= wr_strobe;

                when wr_strobe =>
                    -- set E high for 1 time_base period
                    wr_state <= wr_wait;

                when wr_wait =>
                    -- finally wait for the delay counter to wrap around and return to wr_ready
                    if wr_delay_cnt(wr_delay_cnt'high) = '1' then
                        wr_state <= wr_ready;
                    end if;

            end case; 
        end if;
    end process;

    -- E signal gets high only when writer FSM in wr_strobe state
    lcd_e <= '1' when wr_state = wr_strobe else '0';

    -- LCD data can come from latched input byte or init commands table
    lcd_d <= init_ops(init_ptr) when state = init_wait 
        else r_data(7 downto 4) when state = d_wait_nh
        else r_data(3 downto 0) when state = d_wait_nl
        else (others => 'X');  

    -- for init commands RS is 0, otherwise it comes from latched user input
    lcd_rs <= '0' when state = init_wait 
        else r_rs when state = d_wait_nh or state = d_wait_nl 
        else 'X';

    -- never read from the LCD controller
    lcd_rw <= '0';
    
end behavioral;

