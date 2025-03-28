---------------------------------------------------------------------------------------------------
-- Author      :  Halil Furkan KIMKAK
-- Description :  LM75 Temperature Sensor Emulator
--                - Emulates LM75/LM75A digital temperature sensor
--                - I²C interface with 7-bit addressing (default 0x48)
--                - Temperature register (read-only, 11-bit, 0.125°C resolution)
--                - Configuration register (8-bit)
--                - Hysteresis (Thyst) and Overtemperature (Tos) registers
--                - Configurable temperature generation for testing
--                - Compatible with standard I²C read/write operations
---------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_temp_sensor is
    generic (
        SLAVE_ADDR_g    : std_logic_vector(6 downto 0) := "1001000";  --! I2C slave address (0x48)
        DEFAULT_TEMP_g  : integer := 25;                              --! Default temperature in °C
        TEMP_STEP_g     : integer := 50;                              --! Temperature step in 0.01°C
        TEMP_MIN_g      : integer := -20;                             --! Minimum temperature in °C
        TEMP_MAX_g      : integer := 100                              --! Maximum temperature in °C
    );
    port (
        -- System signals
        clk_i           : in    std_logic;                --! System clock
        reset_n_i       : in    std_logic;               --! Active low reset
        
        -- I2C interface
        scl_io          : inout std_logic;               --! I2C Serial Clock
        sda_io          : inout std_logic;               --! I2C Serial Data
        
        -- Optional debug/monitoring outputs
        temp_value_o    : out   std_logic_vector(15 downto 0);  --! Current temperature value
        reg_access_o    : out   std_logic;                      --! Register access indicator
        i2c_active_o    : out   std_logic                       --! I2C activity indicator
    );
end entity i2c_temp_sensor;

architecture rtl of i2c_temp_sensor is

    --------------------------------------------------------------------------------------------------------------------
    -- CONSTANT DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- LM75 Register addresses (pointer values)
    constant REG_TEMP_c          : std_logic_vector(7 downto 0) := x"00";  -- Temperature register
    constant REG_CONFIG_c        : std_logic_vector(7 downto 0) := x"01";  -- Configuration register
    constant REG_THYST_c         : std_logic_vector(7 downto 0) := x"02";  -- Temperature hysteresis register
    constant REG_TOS_c           : std_logic_vector(7 downto 0) := x"03";  -- Overtemperature shutdown threshold register
    
    -- Default register values
    constant DEFAULT_CONFIG_c    : std_logic_vector(7 downto 0) := x"00";  -- Default configuration
    constant DEFAULT_THYST_c     : std_logic_vector(15 downto 0) := x"4B00"; -- Default 75°C
    constant DEFAULT_TOS_c       : std_logic_vector(15 downto 0) := x"5000"; -- Default 80°C
    
    -- Configuration bit definitions
    constant CFG_SHUTDOWN_POS_c  : integer := 0;  -- Shutdown mode bit position
    constant CFG_OS_COMP_INT_c   : integer := 1;  -- OS operation mode bit position
    constant CFG_OS_POL_c        : integer := 2;  -- OS polarity bit position
    constant CFG_OS_FAULT_Q0_c   : integer := 3;  -- OS fault queue bit 0
    constant CFG_OS_FAULT_Q1_c   : integer := 4;  -- OS fault queue bit 1
    
    -- Temperature scaling factors
    constant TEMP_SCALING_c      : integer := 100;  -- For internal fixed-point math (centidegrees)
    constant TEMP_RESOLUTION_c   : integer := 125;  -- LM75A has 0.125°C resolution

    --------------------------------------------------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Sensor state machine
    type sensor_state_t is (
        IDLE_ST,          -- Waiting for I2C transaction
        READ_POINTER_ST,  -- Reading pointer register
        WRITE_REG_ST,     -- Writing to register
        READ_REG_ST       -- Reading from register
    );
    
    -- LM75 register type
    type lm75_registers_t is record
        temperature : std_logic_vector(15 downto 0);
        config      : std_logic_vector(7 downto 0);
        thyst       : std_logic_vector(15 downto 0);
        tos         : std_logic_vector(15 downto 0);
    end record;

    --------------------------------------------------------------------------------------------------------------------
    -- I2C SLAVE COMPONENT
    --------------------------------------------------------------------------------------------------------------------
    
    component i2c_slave is
        generic (
            SLAVE_ADDR_g        : std_logic_vector(6 downto 0) := "1001000";
            BUFFER_SIZE_g       : integer := 16;
            CLOCK_STRETCHING_g  : boolean := true
        );
        port (
            clk_i               : in    std_logic;
            reset_n_i           : in    std_logic;
            busy_o              : out   std_logic;
            addr_detected_o     : out   std_logic;
            read_req_o          : out   std_logic;
            write_req_o         : out   std_logic;
            data_valid_o        : out   std_logic;
            tx_data_i           : in    std_logic_vector(7 downto 0);
            rx_data_o           : out   std_logic_vector(7 downto 0);
            tx_ready_i          : in    std_logic;
            rx_ack_i            : in    std_logic;
            scl_io              : inout std_logic;
            sda_io              : inout std_logic
        );
    end component i2c_slave;

    --------------------------------------------------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- I2C interface signals
    signal i2c_busy_s           : std_logic;
    signal i2c_addr_detected_s  : std_logic;
    signal i2c_read_req_s       : std_logic;
    signal i2c_write_req_s      : std_logic;
    signal i2c_data_valid_s     : std_logic;
    signal i2c_tx_data_s        : std_logic_vector(7 downto 0);
    signal i2c_rx_data_s        : std_logic_vector(7 downto 0);
    signal i2c_tx_ready_s       : std_logic := '1';
    signal i2c_rx_ack_s         : std_logic := '1';
    
    -- LM75 registers
    signal registers_s          : lm75_registers_t := (
        temperature => (others => '0'),
        config      => DEFAULT_CONFIG_c,
        thyst       => DEFAULT_THYST_c,
        tos         => DEFAULT_TOS_c
    );
    
    -- Register pointer and access control
    signal pointer_reg_s        : std_logic_vector(7 downto 0) := REG_TEMP_c;
    signal reg_access_s         : std_logic := '0';
    signal read_reg_ready_s     : std_logic := '0';
    signal byte_count_s         : integer range 0 to 2 := 0;
    
    -- State machine
    signal current_state_s      : sensor_state_t := IDLE_ST;
    
    -- Temperature generation
    signal temp_counter_s       : integer := 0;
    signal current_temp_s       : integer := DEFAULT_TEMP_g * TEMP_SCALING_c;
    signal temp_direction_s     : std_logic := '1';  -- '1' = increasing, '0' = decreasing
    
begin

    --------------------------------------------------------------------------------------------------------------------
    -- COMPONENT INSTANTIATIONS
    --------------------------------------------------------------------------------------------------------------------
    
    -- I2C slave interface
    i2c_slave_inst : i2c_slave
        generic map (
            SLAVE_ADDR_g       => SLAVE_ADDR_g,
            BUFFER_SIZE_g      => 16,
            CLOCK_STRETCHING_g => false
        )
        port map (
            clk_i              => clk_i,
            reset_n_i          => reset_n_i,
            busy_o             => i2c_busy_s,
            addr_detected_o    => i2c_addr_detected_s,
            read_req_o         => i2c_read_req_s,
            write_req_o        => i2c_write_req_s,
            data_valid_o       => i2c_data_valid_s,
            tx_data_i          => i2c_tx_data_s,
            rx_data_o          => i2c_rx_data_s,
            tx_ready_i         => i2c_tx_ready_s,
            rx_ack_i           => i2c_rx_ack_s,
            scl_io             => scl_io,
            sda_io             => sda_io
        );

    --------------------------------------------------------------------------------------------------------------------
    -- CONCURRENT ASSIGNMENTS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Output current temperature value for monitoring
    temp_value_o <= registers_s.temperature;
    
    -- Output status signals
    reg_access_o <= reg_access_s;
    i2c_active_o <= i2c_busy_s;

    --------------------------------------------------------------------------------------------------------------------
    -- TEMPERATURE GENERATION PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Generate slowly changing temperature for simulation
    temp_gen_proc : process(clk_i, reset_n_i)
        variable temp_fixed_v : integer;
    begin
        if reset_n_i = '0' then
            temp_counter_s <= 0;
            current_temp_s <= DEFAULT_TEMP_g * TEMP_SCALING_c;
            temp_direction_s <= '1';
            registers_s.temperature <= (others => '0');
            
        elsif rising_edge(clk_i) then
            -- Only update temperature if not in shutdown mode
            if registers_s.config(CFG_SHUTDOWN_POS_c) = '0' then
                -- Slow counter for temperature changes
                if temp_counter_s = 1000000 then
                    temp_counter_s <= 0;
                    
                    -- Update temperature direction if at limits
                    if temp_direction_s = '1' then
                        if current_temp_s >= TEMP_MAX_g * TEMP_SCALING_c then
                            temp_direction_s <= '0';
                        end if;
                    else
                        if current_temp_s <= TEMP_MIN_g * TEMP_SCALING_c then
                            temp_direction_s <= '1';
                        end if;
                    end if;
                    
                    -- Update current temperature
                    if temp_direction_s = '1' then
                        current_temp_s <= current_temp_s + TEMP_STEP_g;
                    else
                        current_temp_s <= current_temp_s - TEMP_STEP_g;
                    end if;
                    
                    -- Convert temperature to LM75 format
                    -- LM75A: 11-bit resolution, 0.125°C per step, two's complement
                    -- Format: MSB[15:8] = Integer part, LSB[7:0] = Fractional part (bit 7 = 0.5, bit 6 = 0.25, bit 5 = 0.125)
                    
                    -- Calculate integer and fractional parts
                    temp_fixed_v := (current_temp_s * TEMP_RESOLUTION_c) / TEMP_SCALING_c;
                    
                    -- Convert to LM75 format (shift left by 5 as only bits 7:5 are used in LSB)
                    if current_temp_s < 0 then
                        -- Negative temperature (two's complement)
                        registers_s.temperature <= std_logic_vector(to_signed(temp_fixed_v, 11) & "00000");
                    else
                        -- Positive temperature
                        registers_s.temperature <= std_logic_vector(to_signed(temp_fixed_v, 11) & "00000");
                    end if;
                else
                    temp_counter_s <= temp_counter_s + 1;
                end if;
            end if;
        end if;
    end process temp_gen_proc;

    --------------------------------------------------------------------------------------------------------------------
    -- I2C INTERFACE PROCESS
    --------------------------------------------------------------------------------------------------------------------
    
    -- Handle I2C transactions and register access
    i2c_interface_proc : process(clk_i, reset_n_i)
    begin
        if reset_n_i = '0' then
            current_state_s <= IDLE_ST;
            pointer_reg_s <= REG_TEMP_c;
            byte_count_s <= 0;
            i2c_tx_ready_s <= '1';
            i2c_rx_ack_s <= '1';
            reg_access_s <= '0';
            read_reg_ready_s <= '0';
            
            -- Reset registers to default values
            registers_s.config <= DEFAULT_CONFIG_c;
            registers_s.thyst <= DEFAULT_THYST_c;
            registers_s.tos <= DEFAULT_TOS_c;
            
        elsif rising_edge(clk_i) then
            -- Default values
            reg_access_s <= '0';
            read_reg_ready_s <= '0';
            
            -- State machine
            case current_state_s is
                
                when IDLE_ST =>
                    -- Reset byte counter
                    byte_count_s <= 0;
                    
                    -- Check for I2C requests
                    if i2c_addr_detected_s = '1' then
                        if i2c_write_req_s = '1' then
                            -- Write transaction: first byte is pointer register
                            current_state_s <= READ_POINTER_ST;
                        elsif i2c_read_req_s = '1' then
                            -- Read transaction: use current pointer register
                            current_state_s <= READ_REG_ST;
                            -- Prepare first data byte based on pointer
                            case pointer_reg_s is
                                when REG_TEMP_c =>
                                    -- Temperature register (MSB first)
                                    i2c_tx_data_s <= registers_s.temperature(15 downto 8);
                                when REG_CONFIG_c =>
                                    -- Config register (single byte)
                                    i2c_tx_data_s <= registers_s.config;
                                when REG_THYST_c =>
                                    -- Hysteresis register (MSB first)
                                    i2c_tx_data_s <= registers_s.thyst(15 downto 8);
                                when REG_TOS_c =>
                                    -- Overtemp register (MSB first)
                                    i2c_tx_data_s <= registers_s.tos(15 downto 8);
                                when others =>
                                    -- Invalid register, return zeros
                                    i2c_tx_data_s <= (others => '0');
                            end case;
                            read_reg_ready_s <= '1';
                        end if;
                    end if;
                
                when READ_POINTER_ST =>
                    -- Wait for data from I2C master (pointer register)
                    if i2c_data_valid_s = '1' then
                        -- Store new pointer value
                        pointer_reg_s <= i2c_rx_data_s;
                        reg_access_s <= '1';
                        
                        -- Next state depends on continued transaction
                        if i2c_busy_s = '1' then
                            -- More data to follow, must be a write to register
                            current_state_s <= WRITE_REG_ST;
                        else
                            -- End of transaction, just updating pointer
                            current_state_s <= IDLE_ST;
                        end if;
                    end if;
                
                when WRITE_REG_ST =>
                    -- Wait for data from I2C master (register value)
                    if i2c_data_valid_s = '1' then
                        reg_access_s <= '1';
                        
                        -- Write to appropriate register based on pointer
                        case pointer_reg_s is
                            when REG_CONFIG_c =>
                                -- Config register (single byte)
                                registers_s.config <= i2c_rx_data_s;
                                
                            when REG_THYST_c =>
                                -- Hysteresis register (2 bytes, MSB first)
                                if byte_count_s = 0 then
                                    -- MSB
                                    registers_s.thyst(15 downto 8) <= i2c_rx_data_s;
                                    byte_count_s <= 1;
                                else
                                    -- LSB
                                    registers_s.thyst(7 downto 0) <= i2c_rx_data_s;
                                    byte_count_s <= 0;
                                end if;
                                
                            when REG_TOS_c =>
                                -- Overtemp register (2 bytes, MSB first)
                                if byte_count_s = 0 then
                                    -- MSB
                                    registers_s.tos(15 downto 8) <= i2c_rx_data_s;
                                    byte_count_s <= 1;
                                else
                                    -- LSB
                                    registers_s.tos(7 downto 0) <= i2c_rx_data_s;
                                    byte_count_s <= 0;
                                end if;
                                
                            when others =>
                                -- Temperature is read-only or invalid register, ignore
                                null;
                        end case;
                        
                        -- Check if transaction continues
                        if i2c_busy_s = '0' then
                            current_state_s <= IDLE_ST;
                        end if;
                    end if;
                
                when READ_REG_ST =>
                    -- Send data to I2C master (register value)
                    i2c_tx_ready_s <= read_reg_ready_s;
                    
                    if i2c_read_req_s = '1' and read_reg_ready_s = '0' then
                        -- Prepare next byte for multi-byte registers
                        case pointer_reg_s is
                            when REG_TEMP_c =>
                                -- Temperature register (2 bytes)
                                if byte_count_s = 0 then
                                    -- Next is LSB
                                    i2c_tx_data_s <= registers_s.temperature(7 downto 0);
                                    byte_count_s <= 1;
                                else
                                    -- Repeated read returns MSB again
                                    i2c_tx_data_s <= registers_s.temperature(15 downto 8);
                                    byte_count_s <= 0;
                                end if;
                                
                            when REG_CONFIG_c =>
                                -- Config register (1 byte, repeated reads return same value)
                                i2c_tx_data_s <= registers_s.config;
                                
                            when REG_THYST_c =>
                                -- Hysteresis register (2 bytes)
                                if byte_count_s = 0 then
                                    -- Next is LSB
                                    i2c_tx_data_s <= registers_s.thyst(7 downto 0);
                                    byte_count_s <= 1;
                                else
                                    -- Repeated read returns MSB again
                                    i2c_tx_data_s <= registers_s.thyst(15 downto 8);
                                    byte_count_s <= 0;
                                end if;
                                
                            when REG_TOS_c =>
                                -- Overtemp register (2 bytes)
                                if byte_count_s = 0 then
                                    -- Next is LSB
                                    i2c_tx_data_s <= registers_s.tos(7 downto 0);
                                    byte_count_s <= 1;
                                else
                                    -- Repeated read returns MSB again
                                    i2c_tx_data_s <= registers_s.tos(15 downto 8);
                                    byte_count_s <= 0;
                                end if;
                                
                            when others =>
                                -- Invalid register, return zeros
                                i2c_tx_data_s <= (others => '0');
                        end case;
                        
                        read_reg_ready_s <= '1';
                        reg_access_s <= '1';
                    end if;
                    
                    -- Check if transaction completes
                    if i2c_busy_s = '0' then
                        current_state_s <= IDLE_ST;
                    end if;
                
                when others =>
                    -- Invalid state, return to idle
                    current_state_s <= IDLE_ST;
                    
            end case;
        end if;
    end process i2c_interface_proc;

end architecture rtl; 