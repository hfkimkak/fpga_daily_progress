--------------------------------------------------------------------------------
-- File: i2c_temp_reader.vhd
-- Author: FPGA Tutorial
--
-- Description:
-- Temperature reader module for LM75/LM75A temperature sensor via I²C.
-- Periodically reads temperature from the sensor and formats it for display.
-- Features include:
-- - Automatic temperature reading at configurable intervals
-- - User-triggered temperature reading
-- - BCD conversion for 7-segment display
-- - Error detection and reporting
-- - Debug outputs for monitoring I²C activity
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_temp_reader is
    generic (
        -- System clock frequency in Hz
        CLK_FREQ_HZ       : integer := 100_000_000;
        
        -- I²C clock frequency in Hz
        -- Standard mode: 100kHz, Fast mode: 400kHz
        I2C_CLK_FREQ_HZ   : integer := 400_000;
        
        -- LM75 I²C slave address (7-bit)
        I2C_SLAVE_ADDR    : std_logic_vector(6 downto 0) := "1001000";  -- 0x48
        
        -- Temperature update interval in milliseconds
        TEMP_UPDATE_MS    : integer := 1000
    );
    port (
        -- Clock and reset
        clk_i             : in  std_logic;
        reset_n_i         : in  std_logic;
        
        -- I²C interface
        i2c_scl_io        : inout std_logic;
        i2c_sda_io        : inout std_logic;
        
        -- User interface
        start_read_i      : in  std_logic;                      -- Trigger reading
        temp_data_o       : out std_logic_vector(15 downto 0);  -- Raw temperature data
        temp_valid_o      : out std_logic;                      -- Temperature data valid
        temp_sign_o       : out std_logic;                      -- 1=negative, 0=positive
        i2c_busy_o        : out std_logic;                      -- I²C bus busy
        error_o           : out std_logic;                      -- Error indicator
        
        -- Display interface (7-segment)
        segments_o        : out std_logic_vector(7 downto 0);   -- Segment control (a-g,dp)
        digits_o          : out std_logic_vector(3 downto 0)    -- Digit select (active high)
    );
end entity i2c_temp_reader;

architecture rtl of i2c_temp_reader is

    -- Component declaration for I²C Master
    component i2c_master is
        generic (
            CLK_FREQ_HZ     : integer := 100_000_000;
            I2C_FREQ_HZ     : integer := 100_000;
            TIMEOUT_CYCLES  : integer := 1_000_000
        );
        port (
            clk_i           : in  std_logic;
            reset_n_i       : in  std_logic;
            i2c_scl_io      : inout std_logic;
            i2c_sda_io      : inout std_logic;
            start_i         : in  std_logic;
            stop_i          : in  std_logic;
            read_i          : in  std_logic;
            write_data_i    : in  std_logic_vector(7 downto 0);
            slave_addr_i    : in  std_logic_vector(6 downto 0);
            enable_ack_i    : in  std_logic;
            busy_o          : out std_logic;
            data_valid_o    : out std_logic;
            read_data_o     : out std_logic_vector(7 downto 0);
            ack_error_o     : out std_logic;
            timeout_o       : out std_logic;
            byte_done_o     : out std_logic
        );
    end component;
    
    -- LM75 registers
    constant LM75_REG_TEMP       : std_logic_vector(7 downto 0) := x"00";  -- Temperature register
    constant LM75_REG_CONFIG     : std_logic_vector(7 downto 0) := x"01";  -- Configuration register
    constant LM75_REG_THYST      : std_logic_vector(7 downto 0) := x"02";  -- Temperature hysteresis
    constant LM75_REG_TOS        : std_logic_vector(7 downto 0) := x"03";  -- Over-temp shutdown

    -- State machine for temperature reader
    type reader_state_t is (
        IDLE_ST,
        START_WRITE_ST,
        SEND_ADDR_ST,
        SEND_POINTER_ST,
        START_READ_ST,
        READ_TEMP_MSB_ST,
        READ_TEMP_LSB_ST,
        PROCESS_TEMP_ST,
        WAIT_ST,
        ERROR_ST
    );
    
    -- Current state and next state
    signal current_state      : reader_state_t := IDLE_ST;
    signal next_state         : reader_state_t := IDLE_ST;
    
    -- Temperature data registers
    signal temp_msb           : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_lsb           : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_data          : std_logic_vector(15 downto 0) := (others => '0');
    signal temp_valid         : std_logic := '0';
    signal temp_sign          : std_logic := '0';  -- 0 = positive, 1 = negative
    
    -- Processed temperature values (for display)
    signal temp_integer       : integer range -128 to 127 := 0;  -- Integer part
    signal temp_fraction      : integer range 0 to 875 := 0;     -- Fractional part (0.0, 0.125, 0.25, 0.375, etc.)
    
    -- Type definition for BCD digits
    type bcd_digits_t is array (0 to 3) of integer range 0 to 9;
    signal temp_bcd_s         : bcd_digits_t := (0, 0, 0, 0);
    
    -- I²C control signals
    signal i2c_start          : std_logic := '0';
    signal i2c_stop           : std_logic := '0';
    signal i2c_read           : std_logic := '0';
    signal i2c_write_data     : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_enable_ack     : std_logic := '0';
    
    -- I²C status signals
    signal i2c_busy           : std_logic;
    signal i2c_data_valid     : std_logic;
    signal i2c_read_data      : std_logic_vector(7 downto 0);
    signal i2c_ack_error      : std_logic;
    signal i2c_timeout        : std_logic;
    signal i2c_byte_done      : std_logic;
    
    -- Error flag
    signal error              : std_logic := '0';
    
    -- Update timing
    constant UPDATE_CYCLES    : integer := (CLK_FREQ_HZ / 1000) * TEMP_UPDATE_MS;
    signal update_counter     : integer range 0 to UPDATE_CYCLES := 0;
    signal update_trigger     : std_logic := '0';
    
    -- Display timing and control
    signal digit_index        : integer range 0 to 3 := 0;
    signal digit_enable       : std_logic_vector(3 downto 0) := "0001";
    signal segment_pattern    : std_logic_vector(7 downto 0);  -- Renamed to avoid duplicate
    
    -- 7-segment display patterns for digits 0-9
    type segment_array_t is array (0 to 9) of std_logic_vector(7 downto 0);
    constant SEGMENT_PATTERNS : segment_array_t := (
        "00111111",  -- 0
        "00000110",  -- 1
        "01011011",  -- 2
        "01001111",  -- 3
        "01100110",  -- 4
        "01101101",  -- 5
        "01111101",  -- 6
        "00000111",  -- 7
        "01111111",  -- 8
        "01101111"   -- 9
    );
    
    -- Special patterns
    constant PATTERN_MINUS    : std_logic_vector(7 downto 0) := "01000000";  -- Minus sign
    constant PATTERN_DEGREE   : std_logic_vector(7 downto 0) := "01100011";  -- Degree symbol
    constant PATTERN_C        : std_logic_vector(7 downto 0) := "00111001";  -- Letter C
    constant PATTERN_ERR      : std_logic_vector(7 downto 0) := "01111001";  -- Letter E
    constant PATTERN_BLANK    : std_logic_vector(7 downto 0) := "00000000";  -- Blank/off
    
begin

    -- I²C Master instantiation
    i2c_master_inst: i2c_master
        generic map (
            CLK_FREQ_HZ     => CLK_FREQ_HZ,
            I2C_FREQ_HZ     => I2C_CLK_FREQ_HZ,
            TIMEOUT_CYCLES  => CLK_FREQ_HZ / 10  -- 100ms timeout
        )
        port map (
            clk_i           => clk_i,
            reset_n_i       => reset_n_i,
            i2c_scl_io      => i2c_scl_io,
            i2c_sda_io      => i2c_sda_io,
            start_i         => i2c_start,
            stop_i          => i2c_stop,
            read_i          => i2c_read,
            write_data_i    => i2c_write_data,
            slave_addr_i    => I2C_SLAVE_ADDR,
            enable_ack_i    => i2c_enable_ack,
            busy_o          => i2c_busy,
            data_valid_o    => i2c_data_valid,
            read_data_o     => i2c_read_data,
            ack_error_o     => i2c_ack_error,
            timeout_o       => i2c_timeout,
            byte_done_o     => i2c_byte_done
        );
    
    -- Connect output signals
    temp_data_o <= temp_data;
    temp_valid_o <= temp_valid;
    temp_sign_o <= temp_sign;
    i2c_busy_o <= i2c_busy;
    error_o <= error;
    segments_o <= segment_pattern;  -- Renamed
    digits_o <= digit_enable;
    
    -- Periodic update counter
    update_timer: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            update_counter <= 0;
            update_trigger <= '0';
        elsif rising_edge(clk_i) then
            update_trigger <= '0';  -- Default to no trigger
            
            if current_state = IDLE_ST then
                if update_counter >= UPDATE_CYCLES - 1 then
                    update_counter <= 0;
                    update_trigger <= '1';
                else
                    update_counter <= update_counter + 1;
                end if;
            end if;
        end if;
    end process update_timer;
    
    -- Temperature reading state machine
    temp_reader_fsm: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            current_state <= IDLE_ST;
            next_state <= IDLE_ST;
            temp_msb <= (others => '0');
            temp_lsb <= (others => '0');
            temp_data <= (others => '0');
            temp_valid <= '0';
            temp_sign <= '0';
            error <= '0';
            i2c_start <= '0';
            i2c_stop <= '0';
            i2c_read <= '0';
            i2c_write_data <= (others => '0');
            i2c_enable_ack <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default values for pulse signals
            i2c_start <= '0';
            i2c_stop <= '0';
            temp_valid <= '0';
            
            -- State machine
            case current_state is
                when IDLE_ST =>
                    -- Wait for a trigger to start reading
                    if start_read_i = '1' or update_trigger = '1' then
                        next_state <= START_WRITE_ST;
                    end if;
                    
                when START_WRITE_ST =>
                    -- Start I²C transaction in write mode
                    if i2c_busy = '0' then
                        i2c_start <= '1';
                        i2c_read <= '0';  -- Write mode
                        next_state <= SEND_ADDR_ST;
                    end if;
                    
                when SEND_ADDR_ST =>
                    -- Sending slave address done, now send register pointer
                    if i2c_byte_done = '1' then
                        if i2c_ack_error = '1' then
                            -- No ACK received (device not present)
                            i2c_stop <= '1';
                            error <= '1';
                            next_state <= ERROR_ST;
                        else
                            -- Address acknowledged, send register pointer
                            i2c_write_data <= LM75_REG_TEMP;
                            next_state <= SEND_POINTER_ST;
                        end if;
                    end if;
                    
                when SEND_POINTER_ST =>
                    -- Register pointer sent, now start reading
                    if i2c_byte_done = '1' then
                        if i2c_ack_error = '1' then
                            -- No ACK received (register pointer not accepted)
                            i2c_stop <= '1';
                            error <= '1';
                            next_state <= ERROR_ST;
                        else
                            -- Pointer acknowledged, prepare for reading
                            next_state <= START_READ_ST;
                        end if;
                    end if;
                    
                when START_READ_ST =>
                    -- Generate repeated START in read mode
                    if i2c_busy = '0' then
                        i2c_start <= '1';
                        i2c_read <= '1';  -- Read mode
                        i2c_enable_ack <= '1';  -- ACK first byte
                        next_state <= READ_TEMP_MSB_ST;
                    end if;
                    
                when READ_TEMP_MSB_ST =>
                    -- Read MSB of temperature
                    if i2c_data_valid = '1' then
                        temp_msb <= i2c_read_data;
                        i2c_enable_ack <= '0';  -- NACK next byte (last byte)
                        next_state <= READ_TEMP_LSB_ST;
                    elsif i2c_timeout = '1' or i2c_ack_error = '1' then
                        -- Error during read
                        i2c_stop <= '1';
                        error <= '1';
                        next_state <= ERROR_ST;
                    end if;
                    
                when READ_TEMP_LSB_ST =>
                    -- Read LSB of temperature
                    if i2c_data_valid = '1' then
                        temp_lsb <= i2c_read_data;
                        i2c_stop <= '1';  -- End transaction
                        next_state <= PROCESS_TEMP_ST;
                    elsif i2c_timeout = '1' or i2c_ack_error = '1' then
                        -- Error during read
                        i2c_stop <= '1';
                        error <= '1';
                        next_state <= ERROR_ST;
                    end if;
                    
                when PROCESS_TEMP_ST =>
                    -- Process temperature data
                    -- LM75 format: 11-bit signed, with bits:
                    -- MSB[7:0]: [7]=sign, [6:0]=integer part
                    -- LSB[7:0]: [7:5]=fractional part, [4:0]=unused
                    
                    -- Combine MSB and LSB
                    temp_data <= temp_msb & temp_lsb;
                    
                    -- Extract sign
                    temp_sign <= temp_msb(7);
                    
                    -- Process integer part (signed)
                    if temp_msb(7) = '0' then
                        -- Positive temperature
                        temp_integer <= to_integer(unsigned(temp_msb(6 downto 0)));
                    else
                        -- Negative temperature (two's complement)
                        temp_integer <= -to_integer(unsigned(not(temp_msb(6 downto 0))) + 1);
                    end if;
                    
                    -- Process fractional part (3 bits: 0.5, 0.25, 0.125)
                    case temp_lsb(7 downto 5) is
                        when "000" => temp_fraction <= 0;     -- 0.000
                        when "001" => temp_fraction <= 125;   -- 0.125
                        when "010" => temp_fraction <= 250;   -- 0.250
                        when "011" => temp_fraction <= 375;   -- 0.375
                        when "100" => temp_fraction <= 500;   -- 0.500
                        when "101" => temp_fraction <= 625;   -- 0.625
                        when "110" => temp_fraction <= 750;   -- 0.750
                        when "111" => temp_fraction <= 875;   -- 0.875
                        when others => temp_fraction <= 0;
                    end case;
                    
                    -- Set valid flag
                    temp_valid <= '1';
                    error <= '0';
                    
                    -- Wait before next reading
                    next_state <= WAIT_ST;
                    
                when WAIT_ST =>
                    -- Wait for I²C bus to be idle before accepting new commands
                    if i2c_busy = '0' then
                        next_state <= IDLE_ST;
                    end if;
                    
                when ERROR_ST =>
                    -- Error state, wait before retrying
                    if i2c_busy = '0' then
                        -- Go back to idle after bus is free
                        next_state <= IDLE_ST;
                    end if;
                    
            end case;
            
            -- Update state
            if next_state /= current_state then
                current_state <= next_state;
            end if;
        end if;
    end process temp_reader_fsm;
    
    -- BCD conversion for 7-segment display
    bcd_conversion_proc : process(clk_i, reset_n_i)
        variable temp_deg_v : integer range 0 to 999;
        variable bcd_v : bcd_digits_t;
    begin
        if reset_n_i = '0' then
            temp_bcd_s <= (0, 0, 0, 0);
            
        elsif rising_edge(clk_i) then
            -- Only update when there's valid temperature data
            if temp_valid = '1' and current_state = WAIT_ST then
                -- Format: [-]XX.Y (XX = integer, Y = tenths degree)
                
                -- Prepare absolute temperature value (integer * 10 + fraction/100)
                -- This will give us degrees in tenths (e.g., 23.5°C = 235)
                temp_deg_v := abs(temp_integer) * 10;
                
                -- Add fraction rounded to tenths
                if temp_fraction >= 750 then
                    temp_deg_v := temp_deg_v + 8;
                elsif temp_fraction >= 500 then
                    temp_deg_v := temp_deg_v + 5;
                elsif temp_fraction >= 250 then
                    temp_deg_v := temp_deg_v + 3;
                end if;
                
                -- Extract BCD digits to local variable first
                -- Hundreds digit (will be blank if zero, unless it's 100 or more)
                bcd_v(3) := temp_deg_v / 100;
                
                -- Tens digit
                bcd_v(2) := (temp_deg_v / 10) mod 10;
                
                -- Units digit
                bcd_v(1) := temp_deg_v mod 10;
                
                -- Decimal point position will be handled in display process
                -- Last digit is set to special symbol °C
                bcd_v(0) := 0;  -- Will be replaced with °C
                
                -- Assign all values at once to avoid multiple signal assignments
                temp_bcd_s <= bcd_v;
            end if;
        end if;
    end process bcd_conversion_proc;
    
    -- Display multiplexing for 7-segment display
    display_mux_proc : process(clk_i, reset_n_i)
        variable digit_val : integer range 0 to 9;
        variable digit_pattern : std_logic_vector(7 downto 0);
        constant DIGIT_COUNTER_MAX : integer := CLK_FREQ_HZ / 1000;  -- 1ms per digit
        variable digit_counter : integer range 0 to DIGIT_COUNTER_MAX := 0;
    begin
        if reset_n_i = '0' then
            digit_index <= 0;
            digit_enable <= "0001";
            segment_pattern <= PATTERN_BLANK;  -- Renamed
            
        elsif rising_edge(clk_i) then
            -- Digit counter for multiplexing
            if digit_counter >= DIGIT_COUNTER_MAX - 1 then
                digit_counter := 0;
                
                -- Rotate to next digit
                case digit_index is
                    when 0 => digit_index <= 1; digit_enable <= "0010";
                    when 1 => digit_index <= 2; digit_enable <= "0100";
                    when 2 => digit_index <= 3; digit_enable <= "1000";
                    when 3 => digit_index <= 0; digit_enable <= "0001";
                end case;
            else
                digit_counter := digit_counter + 1;
            end if;
            
            -- Determine pattern for current digit
            if error = '1' then
                -- Display "Err " in case of error
                case digit_index is
                    when 3 => digit_pattern := PATTERN_ERR;        -- E
                    when 2 => digit_pattern := "10001110";         -- r
                    when 1 => digit_pattern := "10001110";         -- r
                    when 0 => digit_pattern := PATTERN_BLANK;      --
                end case;
            else
                -- Normal temperature display
                case digit_index is
                    when 3 =>
                        -- First digit: either minus sign, or hundreds digit, or blank
                        if temp_sign = '1' then
                            -- Negative temperature
                            digit_pattern := PATTERN_MINUS;
                        elsif temp_bcd_s(3) > 0 then
                            -- Hundreds digit
                            digit_pattern := SEGMENT_PATTERNS(temp_bcd_s(3));
                        else
                            -- Blank for small positive temperatures
                            digit_pattern := PATTERN_BLANK;
                        end if;
                        
                    when 2 =>
                        -- Second digit: tens or units for small temperatures
                        if temp_bcd_s(3) > 0 or temp_bcd_s(2) > 0 or temp_sign = '1' then
                            -- Display tens digit
                            digit_pattern := SEGMENT_PATTERNS(temp_bcd_s(2));
                        else
                            -- For small temps (0-9.9), move units here
                            digit_pattern := SEGMENT_PATTERNS(temp_bcd_s(1));
                            -- Add decimal point
                            digit_pattern(7) := '1';
                        end if;
                        
                    when 1 =>
                        -- Third digit: units or tenths
                        if temp_bcd_s(3) > 0 or temp_bcd_s(2) > 0 or temp_sign = '1' then
                            -- Normal display: units digit with decimal point
                            digit_pattern := SEGMENT_PATTERNS(temp_bcd_s(1));
                            -- Add decimal point
                            digit_pattern(7) := '1';
                        else
                            -- For small temps: tenths digit
                            -- digit_pattern := SEGMENT_PATTERNS(temp_bcd_s(0));
                            -- Combine with degree symbol
                            digit_pattern := PATTERN_DEGREE;
                        end if;
                        
                    when 0 =>
                        -- Fourth digit: tenths or degree/C
                        if temp_bcd_s(3) > 0 or temp_bcd_s(2) > 0 or temp_sign = '1' then
                            -- Normal display: tenths
                            digit_pattern := SEGMENT_PATTERNS(temp_bcd_s(0));
                        else
                            -- For small temps: degree C
                            digit_pattern := PATTERN_C;
                        end if;
                end case;
            end if;
            
            -- Assign pattern to output
            segment_pattern <= digit_pattern;  -- Renamed
        end if;
    end process display_mux_proc;

end architecture rtl; 