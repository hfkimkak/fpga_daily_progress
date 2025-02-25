library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_blink is
    Port ( 
        clk     : in  STD_LOGIC;         -- System clock (100 MHz on Zedboard)
        reset   : in  STD_LOGIC;         -- Reset signal (active high)
        leds    : out STD_LOGIC_VECTOR(7 downto 0) -- 8 LEDs on Zedboard (LD0-LD7)
    );
end led_blink;

architecture Behavioral of led_blink is
    -- Constants
    constant CLK_FREQ   : integer := 100_000_000;  -- 100 MHz clock
    constant BLINK_FREQ : integer := 2;            -- 2 Hz blink rate (0.5 seconds on, 0.5 seconds off)
    constant MAX_COUNT  : integer := CLK_FREQ / (2 * BLINK_FREQ) - 1;
    
    -- Signals
    signal counter      : unsigned(26 downto 0) := (others => '0');
    signal led_state    : std_logic := '0';
    
begin
    -- Counter process
    process(clk, reset)
    begin
        if reset = '1' then
            counter <= (others => '0');
            led_state <= '0';
        elsif rising_edge(clk) then
            if counter = MAX_COUNT then
                counter <= (others => '0');
                led_state <= not led_state;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    -- Assign LED outputs
    -- All LEDs will blink together
    leds <= (others => led_state);
    
end Behavioral; 