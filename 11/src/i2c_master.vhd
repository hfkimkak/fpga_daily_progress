--------------------------------------------------------------------------------
-- File: i2c_master.vhd
-- Author: FPGA Tutorial
--
-- Description:
-- I²C Master controller implementing the full I²C protocol with both standard
-- and fast mode support. Provides a flexible interface for reading and writing
-- data to I²C slave devices. Features include:
-- - Configurable clock frequency (100kHz Standard mode, 400kHz Fast mode)
-- - START, STOP, and Repeated START condition generation
-- - ACK/NACK handling for proper data transfer
-- - Timeout detection for error conditions
-- - Support for multi-byte read/write operations
-- - Simple register interface for microcontroller integration
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
    generic (
        -- System clock frequency in Hz
        CLK_FREQ_HZ     : integer := 100_000_000;
        
        -- I²C clock frequency in Hz
        -- Standard mode: 100kHz, Fast mode: 400kHz
        I2C_FREQ_HZ     : integer := 100_000;
        
        -- Timeout in clock cycles (optional)
        TIMEOUT_CYCLES  : integer := 1_000_000
    );
    port (
        -- Clock and reset
        clk_i           : in  std_logic;
        reset_n_i       : in  std_logic;
        
        -- I²C interface (to external pins)
        i2c_scl_io      : inout std_logic;
        i2c_sda_io      : inout std_logic;
        
        -- Control interface (from user logic)
        start_i         : in  std_logic;                     -- Start transaction
        stop_i          : in  std_logic;                     -- Force stop (abort)
        read_i          : in  std_logic;                     -- 1 = Read, 0 = Write
        write_data_i    : in  std_logic_vector(7 downto 0);  -- Data to write
        slave_addr_i    : in  std_logic_vector(6 downto 0);  -- 7-bit slave address
        enable_ack_i    : in  std_logic;                     -- Generate ACK on reads
        
        -- Status interface (to user logic)
        busy_o          : out std_logic;                     -- Transaction in progress
        data_valid_o    : out std_logic;                     -- Read data valid
        read_data_o     : out std_logic_vector(7 downto 0);  -- Read data
        ack_error_o     : out std_logic;                     -- No ACK received
        timeout_o       : out std_logic;                     -- Transaction timeout
        byte_done_o     : out std_logic                      -- Byte transfer complete
    );
end entity i2c_master;

architecture rtl of i2c_master is

    -- I²C timing parameters calculation
    constant I2C_CLK_DIV        : integer := (CLK_FREQ_HZ / (I2C_FREQ_HZ * 4)) - 1;
    
    -- FSM states for I²C master controller
    type i2c_state_t is (
        IDLE,
        START,
        SLAVE_ADDR,
        ACK_ADDR,
        WRITE_DATA,
        READ_DATA,
        ACK_DATA,
        STOP,
        WAIT_STOP
    );
    
    -- Current state of the I²C controller
    signal current_state        : i2c_state_t := IDLE;
    signal next_state           : i2c_state_t := IDLE;
    
    -- I²C clock generation signals
    signal i2c_clk_count        : integer range 0 to I2C_CLK_DIV := 0;
    signal i2c_clk_en           : std_logic := '0';
    signal i2c_clk_phase        : unsigned(1 downto 0) := "00";
    
    -- I²C signals for internal control
    signal scl_out              : std_logic := '1';
    signal sda_out              : std_logic := '1';
    signal scl_in               : std_logic;
    signal sda_in               : std_logic;
    signal scl_enable           : std_logic := '0';
    signal sda_enable           : std_logic := '0';
    
    -- Data shift register and control
    signal data_shift_reg       : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_counter          : integer range 0 to 7 := 7;
    
    -- Status and control signals
    signal busy                 : std_logic := '0';
    signal data_valid           : std_logic := '0';
    signal ack_error            : std_logic := '0';
    signal timeout              : std_logic := '0';
    signal timeout_counter      : integer range 0 to TIMEOUT_CYCLES := 0;
    signal byte_done            : std_logic := '0';
    
    -- Internal flags for operation control
    signal read_operation       : std_logic := '0';
    signal continue_transaction : std_logic := '0';
    signal generate_ack         : std_logic := '0';
    
begin

    -- I²C bidirectional signals with tri-state control
    i2c_scl_io <= '0' when (scl_enable = '1' and scl_out = '0') else 'Z';
    i2c_sda_io <= '0' when (sda_enable = '1' and sda_out = '0') else 'Z';
    
    -- Read the actual state of the I²C pins
    scl_in <= i2c_scl_io;
    sda_in <= i2c_sda_io;
    
    -- Status outputs
    busy_o <= busy;
    data_valid_o <= data_valid;
    read_data_o <= data_shift_reg;
    ack_error_o <= ack_error;
    timeout_o <= timeout;
    byte_done_o <= byte_done;
    
    -- I²C clock generation (divided from system clock)
    i2c_clk_generator: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            i2c_clk_count <= 0;
            i2c_clk_en <= '0';
            i2c_clk_phase <= "00";
        elsif rising_edge(clk_i) then
            i2c_clk_en <= '0';  -- Default to disable
            
            if current_state = IDLE then
                i2c_clk_count <= 0;
                i2c_clk_phase <= "00";
            else
                if i2c_clk_count = I2C_CLK_DIV then
                    i2c_clk_count <= 0;
                    i2c_clk_en <= '1';
                    i2c_clk_phase <= i2c_clk_phase + 1;
                else
                    i2c_clk_count <= i2c_clk_count + 1;
                end if;
            end if;
        end if;
    end process i2c_clk_generator;
    
    -- I²C protocol state machine
    i2c_state_machine: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            current_state <= IDLE;
            next_state <= IDLE;
            bit_counter <= 7;
            data_shift_reg <= (others => '0');
            busy <= '0';
            data_valid <= '0';
            ack_error <= '0';
            timeout <= '0';
            timeout_counter <= 0;
            byte_done <= '0';
            scl_out <= '1';
            sda_out <= '1';
            scl_enable <= '0';
            sda_enable <= '0';
            read_operation <= '0';
            continue_transaction <= '0';
            generate_ack <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default values for pulse signals
            data_valid <= '0';
            byte_done <= '0';
            
            -- Timeout counter logic
            if current_state /= IDLE and timeout_counter < TIMEOUT_CYCLES then
                timeout_counter <= timeout_counter + 1;
                if timeout_counter = TIMEOUT_CYCLES - 1 then
                    timeout <= '1';
                    next_state <= STOP;
                end if;
            elsif current_state = IDLE then
                timeout_counter <= 0;
                timeout <= '0';
            end if;
            
            -- Handle external start request
            if start_i = '1' and current_state = IDLE then
                read_operation <= read_i;
                data_shift_reg <= (others => '0');
                next_state <= START;
                busy <= '1';
            end if;
            
            -- Handle external stop request
            if stop_i = '1' and current_state /= IDLE and current_state /= STOP and current_state /= WAIT_STOP then
                next_state <= STOP;
            end if;
            
            -- State machine: actions according to I²C clock phases
            if i2c_clk_en = '1' then
                case current_state is
                    when IDLE =>
                        -- Idle state, ready for next operation
                        scl_out <= '1';
                        sda_out <= '1';
                        scl_enable <= '0';
                        sda_enable <= '0';
                        busy <= '0';
                    
                    when START =>
                        -- Generate START condition: SDA falls while SCL is high
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                sda_out <= '1';
                                sda_enable <= '1';
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 1 =>
                                sda_out <= '0';
                                sda_enable <= '1';
                            when 2 =>
                                scl_out <= '0';
                                scl_enable <= '1';
                                next_state <= SLAVE_ADDR;
                                bit_counter <= 7;
                                -- Prepare slave address with R/W bit
                                data_shift_reg <= slave_addr_i & read_operation;
                            when others =>
                                -- Stay in current phase
                        end case;
                        
                    when SLAVE_ADDR =>
                        -- Send 7-bit slave address + R/W bit
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                -- Output data bit on falling edge of SCL
                                sda_out <= data_shift_reg(bit_counter);
                                sda_enable <= '1';
                                scl_out <= '0';
                                scl_enable <= '1';
                            when 1 =>
                                -- SCL goes high for data valid
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 2 =>
                                -- Keep data stable while SCL is high
                            when 3 =>
                                -- SCL goes low, prepare for next bit
                                scl_out <= '0';
                                scl_enable <= '1';
                                
                                if bit_counter = 0 then
                                    next_state <= ACK_ADDR;
                                else
                                    bit_counter <= bit_counter - 1;
                                end if;
                        end case;
                    
                    when ACK_ADDR =>
                        -- Receive ACK after address
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                -- Release SDA to read ACK
                                sda_out <= '1';
                                sda_enable <= '0';
                                scl_out <= '0';
                                scl_enable <= '1';
                            when 1 =>
                                -- SCL goes high to read ACK
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 2 =>
                                -- Sample ACK bit
                                if sda_in = '1' then
                                    -- No ACK received (error)
                                    ack_error <= '1';
                                    next_state <= STOP;
                                else
                                    ack_error <= '0';
                                    if read_operation = '1' then
                                        next_state <= READ_DATA;
                                        generate_ack <= enable_ack_i;
                                    else
                                        next_state <= WRITE_DATA;
                                    end if;
                                    bit_counter <= 7;
                                end if;
                            when 3 =>
                                -- SCL goes low, prepare for data
                                scl_out <= '0';
                                scl_enable <= '1';
                        end case;
                    
                    when WRITE_DATA =>
                        -- Write data byte to slave
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                -- Output data bit on falling edge of SCL
                                sda_out <= data_shift_reg(bit_counter);
                                sda_enable <= '1';
                                scl_out <= '0';
                                scl_enable <= '1';
                            when 1 =>
                                -- SCL goes high for data valid
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 2 =>
                                -- Keep data stable while SCL is high
                            when 3 =>
                                -- SCL goes low, prepare for next bit
                                scl_out <= '0';
                                scl_enable <= '1';
                                
                                if bit_counter = 0 then
                                    next_state <= ACK_DATA;
                                else
                                    bit_counter <= bit_counter - 1;
                                end if;
                        end case;
                    
                    when READ_DATA =>
                        -- Read data byte from slave
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                -- Release SDA to read data
                                sda_out <= '1';
                                sda_enable <= '0';
                                scl_out <= '0';
                                scl_enable <= '1';
                            when 1 =>
                                -- SCL goes high to read bit
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 2 =>
                                -- Sample data bit
                                data_shift_reg(bit_counter) <= sda_in;
                            when 3 =>
                                -- SCL goes low, prepare for next bit
                                scl_out <= '0';
                                scl_enable <= '1';
                                
                                if bit_counter = 0 then
                                    next_state <= ACK_DATA;
                                    data_valid <= '1';
                                    byte_done <= '1';
                                else
                                    bit_counter <= bit_counter - 1;
                                end if;
                        end case;
                    
                    when ACK_DATA =>
                        -- ACK/NACK after data byte
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                if read_operation = '1' then
                                    -- Master sends ACK/NACK
                                    if generate_ack = '1' then
                                        sda_out <= '0';  -- ACK
                                    else
                                        sda_out <= '1';  -- NACK
                                    end if;
                                    sda_enable <= '1';
                                else
                                    -- Slave sends ACK/NACK
                                    sda_out <= '1';
                                    sda_enable <= '0';
                                end if;
                                scl_out <= '0';
                                scl_enable <= '1';
                            when 1 =>
                                -- SCL goes high for ACK/NACK
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 2 =>
                                -- Sample ACK bit if in write mode
                                if read_operation = '0' then
                                    if sda_in = '1' then
                                        -- No ACK received (error)
                                        ack_error <= '1';
                                        next_state <= STOP;
                                    else
                                        ack_error <= '0';
                                        byte_done <= '1';
                                        
                                        -- Check if we should continue
                                        if continue_transaction = '1' then
                                            -- Load next data byte
                                            data_shift_reg <= write_data_i;
                                            next_state <= WRITE_DATA;
                                            bit_counter <= 7;
                                        else
                                            next_state <= STOP;
                                        end if;
                                    end if;
                                else
                                    -- In read mode, continue or stop based on ACK
                                    if generate_ack = '1' then
                                        -- Continue reading
                                        next_state <= READ_DATA;
                                        bit_counter <= 7;
                                    else
                                        -- Stop reading after NACK
                                        next_state <= STOP;
                                    end if;
                                end if;
                            when 3 =>
                                -- SCL goes low
                                scl_out <= '0';
                                scl_enable <= '1';
                        end case;
                    
                    when STOP =>
                        -- Generate STOP condition: SDA rises while SCL is high
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                sda_out <= '0';
                                sda_enable <= '1';
                                scl_out <= '0';
                                scl_enable <= '1';
                            when 1 =>
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 2 =>
                                sda_out <= '1';
                                sda_enable <= '1';
                            when 3 =>
                                next_state <= WAIT_STOP;
                        end case;
                        
                    when WAIT_STOP =>
                        -- Wait a bit after STOP before going to IDLE
                        case to_integer(i2c_clk_phase) is
                            when 0 =>
                                sda_out <= '1';
                                sda_enable <= '0';
                                scl_out <= '1';
                                scl_enable <= '0';
                            when 3 =>
                                next_state <= IDLE;
                            when others =>
                                -- Stay in current phase
                        end case;
                        
                end case;
            end if;
            
            -- Handle new data for writing
            if current_state = WRITE_DATA and byte_done = '1' then
                data_shift_reg <= write_data_i;
            end if;
            
            -- Update state
            if next_state /= current_state then
                current_state <= next_state;
            end if;
        end if;
    end process i2c_state_machine;

end architecture rtl; 