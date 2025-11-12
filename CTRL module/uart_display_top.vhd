library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_display_top is
    port (
        CLOCK_50   : in  std_logic;                 -- 50 MHz systemklokke
        KEY0       : in  std_logic;                 -- reset (aktiv lav)
        UART_RX_IN : in  std_logic;                 -- RX fra AVR
        HEX0       : out std_logic_vector(6 downto 0);
        HEX1       : out std_logic_vector(6 downto 0);
        LEDR0      : out std_logic
    );
end entity uart_display_top;

architecture rtl of uart_display_top is

    --------------------------------------------------------------------
    -- uart_rx-komponent (matcher din uart_rx.vhd)
    --------------------------------------------------------------------
    component uart_rx is
        generic (
            g_CLK_FREQ   : integer := 50_000_000;
            g_BAUD       : integer := 9600;
            g_OVERSAMPLE : integer := 8
        );
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            rx_i        : in  std_logic;
            rx_data_o   : out std_logic_vector(7 downto 0);
            rx_ready_o  : out std_logic
        );
    end component;

    --------------------------------------------------------------------
    -- Signaler
    --------------------------------------------------------------------
    signal rst       : std_logic;
    signal rx_data   : std_logic_vector(7 downto 0);
    signal rx_ready  : std_logic;
    signal ascii_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- LED blink timer
    constant LED_PULSE_MS    : integer := 100;         -- ca. 100 ms blink
    constant CLK_FREQ        : integer := 50_000_000;
    constant LED_PULSE_COUNT : integer := (CLK_FREQ / 1000) * LED_PULSE_MS;
    signal led_cnt           : integer range 0 to LED_PULSE_COUNT := 0;

begin

    --------------------------------------------------------------------
    -- Reset (KEY0 er aktiv lav)
    --------------------------------------------------------------------
    rst <= not KEY0;

    --------------------------------------------------------------------
    -- Instans av UART mottaker
    --------------------------------------------------------------------
    u_rx : uart_rx
        generic map (
            g_CLK_FREQ   => 50_000_000,
            g_BAUD       => 9600,
            g_OVERSAMPLE => 8
        )
        port map (
            clk         => CLOCK_50,
            rst         => rst,
            rx_i        => UART_RX_IN,
            rx_data_o   => rx_data,
            rx_ready_o  => rx_ready
        );

    --------------------------------------------------------------------
    -- Lagring av mottatt byte + LED-puls
    --------------------------------------------------------------------
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if rst = '1' then
                ascii_reg <= (others => '0');
                led_cnt   <= 0;
            else
                if rx_ready = '1' then
                    ascii_reg <= rx_data;          -- ny ASCII-kode
                    led_cnt   <= LED_PULSE_COUNT;  -- start LED-timer
                elsif led_cnt > 0 then
                    led_cnt <= led_cnt - 1;
                end if;
            end if;
        end if;
    end process;

    -- LED lyser så lenge vi teller ned
    LEDR0 <= '1' when led_cnt > 0 else '0';

    --------------------------------------------------------------------
    -- 7-segment dekoding (ASCII-kode som to hex-siffer)
    -- Aktiv lav på DE10-Lite: "0" = segment på
    --------------------------------------------------------------------

    -- abcdefg, aktiv lav
       -- HEX0: lav nibble
                  with ascii_reg(3 downto 0) select
                        HEX0 <=
                              "1111110" when "0000",  -- 0
                              "0110000" when "0001",  -- 1
                              "1101101" when "0010",  -- 2
                              "1111001" when "0011",  -- 3
                              "0110011" when "0100",  -- 4
                              "1011011" when "0101",  -- 5
                              "1011111" when "0110",  -- 6
                              "1110000" when "0111",  -- 7
                              "1111111" when "1000",  -- 8
                              "1111011" when "1001",  -- 9
                              "1110111" when "1010",  -- A
                              "0011111" when "1011",  -- b
                              "1001110" when "1100",  -- C
                              "0111101" when "1101",  -- d
                              "1001111" when "1110",  -- E
                              "1000111" when others;  -- F
                  -- HEX1: høy nibble
                  with ascii_reg(7 downto 4) select
                        HEX1 <=
                              "1111110" when "0000",  -- 0
                              "0110000" when "0001",  -- 1
                              "1101101" when "0010",  -- 2
                              "1111001" when "0011",  -- 3
                              "0110011" when "0100",  -- 4
                              "1011011" when "0101",  -- 5
                              "1011111" when "0110",  -- 6
                              "1110000" when "0111",  -- 7
                              "1111111" when "1000",  -- 8
                              "1111011" when "1001",  -- 9
                              "1110111" when "1010",  -- A
                              "0011111" when "1011",  -- b
                              "1001110" when "1100",  -- C
                              "0111101" when "1101",  -- d
                              "1001111" when "1110",  -- E
                              "1000111" when others;  -- F


end architecture rtl;