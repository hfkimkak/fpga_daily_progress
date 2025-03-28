--------------------------------------------------------------------------------
-- File: i2c_slave.vhd
-- Author: FPGA Tutorial
--
-- Description:
-- I²C Slave controller implementing a flexible slave interface for the I²C protocol.
-- Can be used as a building block for any I²C peripheral implementation.
-- Features include:
-- - Configurable 7-bit device addressing
-- - START/STOP condition detection
-- - ACK/NACK signaling
-- - Clock stretching capability (optional)
-- - Data buffer for reads and writes
-- - Simple interface for connecting to device-specific logic
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_slave is
    generic (
        -- 7-bit slave address (without R/W bit)
        SLAVE_ADDR     : std_logic_vector(6 downto 0) := "1001000";  -- 0x48 (LM75 default)
        
        -- Number of bytes that can be buffered
        BUFFER_SIZE    : integer := 8;
        
        -- Enable clock stretching (holding SCL low)
        CLOCK_STRETCH  : boolean := true
    );
    port (
        -- Clock and reset
        clk_i          : in  std_logic;
        reset_n_i      : in  std_logic;
        
        -- I²C interface (to external pins)
        i2c_scl_io     : inout std_logic;
        i2c_sda_io     : inout std_logic;
        
        -- Control interface (to/from device-specific logic)
        read_req_o     : out std_logic;                     -- Request data from device
        read_data_i    : in  std_logic_vector(7 downto 0);  -- Data from device to send
        read_ack_i     : in  std_logic;                     -- Device ready for read
        
        write_data_o   : out std_logic_vector(7 downto 0);  -- Data received to device
        write_valid_o  : out std_logic;                     -- Write data valid
        write_ack_i    : in  std_logic;                     -- Device acknowledges write
        
        -- Status interface
        busy_o         : out std_logic;                     -- Transaction in progress
        addr_match_o   : out std_logic;                     -- Address matched
        data_ready_o   : out std_logic;                     -- Data ready for processing
        read_mode_o    : out std_logic                      -- Current mode: 1=read, 0=write
    );
end entity i2c_slave;

architecture rtl of i2c_slave is

    -- I²C condition detection
    type i2c_condition_t is (NONE, START, STOP, DATA, ACK);
    signal current_condition : i2c_condition_t := NONE;
    
    -- I²C state machine
    type i2c_state_t is (
        IDLE,
        ADDRESS,
        ADDRESS_ACK,
        WRITE_DATA,
        WRITE_ACK,
        READ_DATA,
        READ_ACK,
        WAIT_STOP
    );
    signal current_state : i2c_state_t := IDLE;
    
    -- I²C bus signals
    signal scl_in       : std_logic := '1';
    signal sda_in       : std_logic := '1';
    signal scl_prev     : std_logic := '1';
    signal sda_prev     : std_logic := '1';
    signal scl_falling  : std_logic := '0';
    signal scl_rising   : std_logic := '0';
    signal sda_falling  : std_logic := '0';
    signal sda_rising   : std_logic := '0';
    
    -- Control signals
    signal scl_out      : std_logic := '1';
    signal sda_out      : std_logic := '1';
    signal scl_enable   : std_logic := '0';  -- Drive SCL low for clock stretching
    signal sda_enable   : std_logic := '0';  -- Drive SDA for ACK and data
    
    -- Data handling
    signal bit_counter  : integer range 0 to 7 := 7;
    signal data_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_reg     : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Status flags
    signal addr_match   : std_logic := '0';
    signal read_mode    : std_logic := '0';
    signal ack_needed   : std_logic := '0';
    signal busy         : std_logic := '0';
    signal data_ready   : std_logic := '0';
    signal read_req     : std_logic := '0';

begin

    -- I²C bidirectional signals with tri-state control
    i2c_scl_io <= '0' when (scl_enable = '1' and scl_out = '0') else 'Z';
    i2c_sda_io <= '0' when (sda_enable = '1' and sda_out = '0') else 'Z';
    
    -- Read the actual state of the I²C pins
    scl_in <= i2c_scl_io;
    sda_in <= i2c_sda_io;
    
    -- Status outputs
    busy_o <= busy;
    addr_match_o <= addr_match;
    data_ready_o <= data_ready;
    read_mode_o <= read_mode;
    
    -- Data outputs
    write_data_o <= data_reg;
    read_req_o <= read_req;
    
    -- Synchronize and detect I²C signal edges
    edge_detection: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            scl_prev <= '1';
            sda_prev <= '1';
            scl_falling <= '0';
            scl_rising <= '0';
            sda_falling <= '0';
            sda_rising <= '0';
        elsif rising_edge(clk_i) then
            -- Store previous values
            scl_prev <= scl_in;
            sda_prev <= sda_in;
            
            -- Detect edges
            scl_falling <= '0';  -- Default to no edge
            scl_rising <= '0';
            sda_falling <= '0';
            sda_rising <= '0';
            
            -- Check for edges
            if scl_prev = '1' and scl_in = '0' then
                scl_falling <= '1';
            elsif scl_prev = '0' and scl_in = '1' then
                scl_rising <= '1';
            end if;
            
            if sda_prev = '1' and sda_in = '0' then
                sda_falling <= '1';
            elsif sda_prev = '0' and sda_in = '1' then
                sda_rising <= '1';
            end if;
        end if;
    end process edge_detection;
    
    -- Detect START and STOP conditions
    condition_detection: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            current_condition <= NONE;
        elsif rising_edge(clk_i) then
            current_condition <= NONE;  -- Default
            
            -- START condition: SDA falls while SCL is high
            if scl_in = '1' and sda_falling = '1' then
                current_condition <= START;
            
            -- STOP condition: SDA rises while SCL is high
            elsif scl_in = '1' and sda_rising = '1' then
                current_condition <= STOP;
            
            -- Data bit: SDA stable while SCL rises
            elsif scl_rising = '1' then
                current_condition <= DATA;
            
            -- ACK bit: SCL rising after 8 data bits
            elsif scl_rising = '1' and bit_counter = 0 and ack_needed = '1' then
                current_condition <= ACK;
            end if;
        end if;
    end process condition_detection;
    
    -- I²C protocol state machine
    i2c_state_machine: process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            current_state <= IDLE;
            bit_counter <= 7;
            data_reg <= (others => '0');
            addr_reg <= (others => '0');
            addr_match <= '0';
            read_mode <= '0';
            busy <= '0';
            data_ready <= '0';
            read_req <= '0';
            ack_needed <= '0';
            write_valid_o <= '0';
            
            -- Default tri-state (high-Z)
            scl_out <= '1';
            sda_out <= '1';
            scl_enable <= '0';
            sda_enable <= '0';
            
        elsif rising_edge(clk_i) then
            -- Default pulse-width signals
            write_valid_o <= '0';
            data_ready <= '0';
            read_req <= '0';
            
            -- Handle I²C conditions
            case current_condition is
                when START =>
                    -- Detected START condition
                    current_state <= ADDRESS;
                    bit_counter <= 7;
                    addr_match <= '0';
                    busy <= '1';
                    
                when STOP =>
                    -- Detected STOP condition
                    current_state <= IDLE;
                    busy <= '0';
                    sda_enable <= '0';
                    scl_enable <= '0';
                    
                when DATA =>
                    -- Handle data according to current state
                    case current_state is
                        when ADDRESS =>
                            -- Receiving slave address
                            addr_reg(bit_counter) <= sda_in;
                            
                            if bit_counter = 0 then
                                -- Address complete, prepare for ACK
                                ack_needed <= '1';
                                
                                -- Check if address matches + read/write bit
                                if addr_reg(7 downto 1) = SLAVE_ADDR then
                                    addr_match <= '1';
                                    read_mode <= sda_in;  -- R/W bit
                                else
                                    addr_match <= '0';
                                end if;
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                            
                        when WRITE_DATA =>
                            -- Receiving data from master
                            data_reg(bit_counter) <= sda_in;
                            
                            if bit_counter = 0 then
                                -- Data byte complete, prepare for ACK
                                ack_needed <= '1';
                                data_ready <= '1';
                                write_valid_o <= '1';
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                            
                        when READ_DATA =>
                            -- Send next bit to master
                            if bit_counter = 7 then
                                -- First bit, request data from device
                                read_req <= '1';
                                
                                -- Load data if device is ready
                                if read_ack_i = '1' then
                                    data_reg <= read_data_i;
                                end if;
                            end if;
                            
                            -- Output the current bit
                            sda_out <= data_reg(bit_counter);
                            sda_enable <= '1';
                            
                            if bit_counter = 0 then
                                -- Data byte complete, prepare for ACK from master
                                ack_needed <= '1';
                                bit_counter <= 7;
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                            
                        when others =>
                            -- No data handling in other states
                            null;
                    end case;
                    
                when ACK =>
                    -- Handle acknowledgment
                    case current_state is
                        when ADDRESS =>
                            -- ACK after address
                            if addr_match = '1' then
                                -- Our address matched, send ACK (pull SDA low)
                                sda_out <= '0';
                                sda_enable <= '1';
                                
                                -- Prepare for data phase
                                bit_counter <= 7;
                                
                                -- Move to appropriate state based on R/W bit
                                if read_mode = '1' then
                                    current_state <= READ_DATA;
                                    read_req <= '1';  -- Request data from device
                                else
                                    current_state <= WRITE_DATA;
                                end if;
                            else
                                -- Not our address, remain passive
                                sda_enable <= '0';
                                current_state <= WAIT_STOP;
                            end if;
                            
                        when WRITE_DATA =>
                            -- ACK after receiving data
                            if write_ack_i = '1' then
                                -- Device ready to receive, send ACK
                                sda_out <= '0';
                                sda_enable <= '1';
                                
                                -- Prepare for next byte
                                bit_counter <= 7;
                                current_state <= WRITE_DATA;
                            else
                                -- Device not ready, send NACK
                                sda_enable <= '0';
                                current_state <= WAIT_STOP;
                            end if;
                            
                        when READ_DATA =>
                            -- Check if master ACKed our data
                            if sda_in = '0' then
                                -- Master wants more data
                                current_state <= READ_DATA;
                                bit_counter <= 7;
                                read_req <= '1';
                            else
                                -- Master sent NACK, end of transmission
                                sda_enable <= '0';
                                current_state <= WAIT_STOP;
                            end if;
                            
                        when others =>
                            -- No ACK handling in other states
                            null;
                    end case;
                    
                    -- Reset ACK flag
                    ack_needed <= '0';
                    
                when NONE =>
                    -- No special condition, continue current state
                    -- Add clock stretching if enabled and required
                    if CLOCK_STRETCH then
                        if current_state = WRITE_DATA and data_ready = '1' and write_ack_i = '0' then
                            -- Hold SCL low until device acknowledges
                            scl_out <= '0';
                            scl_enable <= '1';
                        elsif current_state = READ_DATA and read_req = '1' and read_ack_i = '0' then
                            -- Hold SCL low until device provides data
                            scl_out <= '0';
                            scl_enable <= '1';
                        else
                            -- Release SCL
                            scl_enable <= '0';
                        end if;
                    end if;
            end case;
        end if;
    end process i2c_state_machine;

end architecture rtl; 