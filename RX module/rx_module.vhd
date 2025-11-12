library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        g_CLK_FREQ   : integer := 100_000_000;  -- systemklokke
        g_BAUD       : integer := 9600;         -- minst 9600 bit/s
        g_OVERSAMPLE : integer := 8             -- 8x oversampling
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        rx_i        : in  std_logic;
        rx_data_o   : out std_logic_vector(7 downto 0); -- lagret byte
        rx_ready_o  : out std_logic                    -- puls: ny byte klar
    );
end entity;

architecture rtl of uart_rx is

    -- 8x baud-tick
    constant c_TICKS_PER_SAMPLE : integer :=
        g_CLK_FREQ / (g_BAUD * g_OVERSAMPLE);

    type state_t is (S_IDLE, S_START, S_DATA, S_STOP);
    signal state        : state_t := S_IDLE;

    signal tick_cnt     : integer range 0 to c_TICKS_PER_SAMPLE-1 := 0;
    signal sample_tick  : std_logic := '0';

    signal os_cnt       : integer range 0 to g_OVERSAMPLE-1 := 0;
    signal bit_cnt      : integer range 0 to 7 := 0;

    signal shift_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal data_ready   : std_logic := '0';

    -- synkroniser RX
    signal rx_sync      : std_logic_vector(1 downto 0) := (others => '1');

begin

    --------------------------------------------------------------------
    -- Synkronisering av RX
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_sync <= (others => '1');
            else
                rx_sync <= rx_sync(0) & rx_i;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Oversample-tick generator (8x baud)
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tick_cnt    <= 0;
                sample_tick <= '0';
            else
                if tick_cnt = c_TICKS_PER_SAMPLE-1 then
                    tick_cnt    <= 0;
                    sample_tick <= '1';
                else
                    tick_cnt    <= tick_cnt + 1;
                    sample_tick <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- UART RX state machine: 1 start, 8 data, 1 stopp, ingen paritet
    -- 8x oversampling, sampling i midten av bitperioden
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= S_IDLE;
                os_cnt     <= 0;
                bit_cnt    <= 0;
                shift_reg  <= (others => '0');
                data_reg   <= (others => '0');
                data_ready <= '0';
            else
                -- default: puls én syklus når ny byte kommer
                data_ready <= '0';

                if sample_tick = '1' then
                    case state is

                        when S_IDLE =>
                            os_cnt  <= 0;
                            bit_cnt <= 0;
                            if rx_sync(1) = '0' then
                                state <= S_START;  -- startbit oppdaget
                            end if;

                        when S_START =>
                            -- sjekk midten av startbit
                            if os_cnt = g_OVERSAMPLE/2 - 1 then
                                if rx_sync(1) = '0' then
                                    os_cnt <= 0;
                                    state  <= S_DATA;
                                else
                                    state <= S_IDLE; -- falsk start
                                end if;
                            else
                                os_cnt <= os_cnt + 1;
                            end if;

                        when S_DATA =>
                            -- sample midten av databiten
                            if os_cnt = g_OVERSAMPLE/2 - 1 then
                                shift_reg <= shift_reg(6 downto 0) & rx_sync(1);
                            end if;

                            if os_cnt = g_OVERSAMPLE-1 then
                                os_cnt <= 0;
                                if bit_cnt = 7 then
                                    bit_cnt <= 0;
                                    state   <= S_STOP;
                                else
                                    bit_cnt <= bit_cnt + 1;
                                end if;
                            else
                                os_cnt <= os_cnt + 1;
                            end if;

                        when S_STOP =>
                            -- sample midten av stoppbit (skal være høy)
                            if os_cnt = g_OVERSAMPLE/2 - 1 then
                                if rx_sync(1) = '1' then
                                    data_reg   <= shift_reg;
                                    data_ready <= '1';
                                end if;
                            end if;

                            if os_cnt = g_OVERSAMPLE-1 then
                                os_cnt <= 0;
                                state  <= S_IDLE;
                            else
                                os_cnt <= os_cnt + 1;
                            end if;

                    end case;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Utganger
    --------------------------------------------------------------------
    rx_data_o  <= data_reg;
    rx_ready_o <= data_ready;

end architecture rtl;