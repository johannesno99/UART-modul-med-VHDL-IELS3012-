-- rx_module_tb.vhd  (VHDL-2008)
-- Minimal, intuitiv test: send én byte og verifiser mottak.
-- Forutsetter at rx_module.vhd er i samme katalog.

library ieee;
use ieee.std_logic_1164.all;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
use ieee.numeric_std.all;
                                                                                     
entity rx_module_tb is
end entity;

architecture tb of rx_module_tb is
    -- Generics (må matche DUT eller settes som ønsket)
    constant g_CLK_FREQ_c   : integer := 100_000_000;  -- 100 MHz
    constant g_BAUD_c       : integer := 9600;
    constant g_OVERSAMPLE_c : integer := 8;

    -- Klokkeperiode for 100 MHz
    constant c_CLK_PERIOD   : time := 10 ns;

    -- Avledede konstanter (samme logikk som i DUT)
    constant c_TICKS_PER_SAMPLE : integer := g_CLK_FREQ_c / (g_BAUD_c * g_OVERSAMPLE_c);
    constant c_BIT_CYCLES       : integer := g_OVERSAMPLE_c * c_TICKS_PER_SAMPLE;  -- clk-edges per bit

    -- Signaler mot DUT
    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal rx_i       : std_logic := '1'; 
    signal rx_data_o  : std_logic_vector(7 downto 0);
    signal rx_ready_o : std_logic;

    -- Liten hjelpefunksjon for pen hex (unngår to_hstring-avhengighet)
    function to_hex8(slv : std_logic_vector(7 downto 0)) return string is
        variable u   : unsigned(7 downto 0) := unsigned(slv);
        constant hex : string := "0123456789ABCDEF";
        variable s   : string(1 to 2);
    begin
        s(1) := hex(to_integer(u(7 downto 4)) + 1);
        s(2) := hex(to_integer(u(3 downto 0)) + 1);
        return s;
    end function;

begin
    --------------------------------------------------------------------
    -- Klokke
    --------------------------------------------------------------------
    clk <= not clk after c_CLK_PERIOD/2;

    --------------------------------------------------------------------
    -- DUT-instans
    --------------------------------------------------------------------
    dut: entity work.rx_module
        generic map (
            g_CLK_FREQ   => g_CLK_FREQ_c,
            g_BAUD       => g_BAUD_c,
            g_OVERSAMPLE => g_OVERSAMPLE_c
        )
        port map (
            clk        => clk,
            rst        => rst,
            rx_i       => rx_i,
            rx_data_o  => rx_data_o,
            rx_ready_o => rx_ready_o
        );

    --------------------------------------------------------------------
    -- Stimuli (enkel og nødvendig verifikasjon)
    --------------------------------------------------------------------
    stim: process
        -- Vent N rising edges
        procedure wait_cycles(constant n : integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Send én UART-byte (LSB først): start(0) + 8 data + stopp(1)
        procedure uart_send_byte(constant data : std_logic_vector(7 downto 0)) is
        begin
            -- startbit
            rx_i <= '0';
            wait_cycles(c_BIT_CYCLES);

            -- data LSB -> MSB
            for i in 0 to 7 loop
                rx_i <= data(i);
                wait_cycles(c_BIT_CYCLES);
            end loop;

            -- stoppbit
            rx_i <= '1';
            wait_cycles(c_BIT_CYCLES);
        end procedure;

        -- Vent på ready med enkel timeout og sjekk data
        procedure await_and_check(constant exp : std_logic_vector(7 downto 0)) is
            variable timeout : integer := 20 * c_BIT_CYCLES; -- god margin
        begin
            while (rx_ready_o = '0' and timeout > 0) loop
                wait until rising_edge(clk);
                timeout := timeout - 1;
            end loop;

            assert timeout > 0
                report "Timeout: rx_ready_o kom ikke."
                severity failure;

            assert rx_data_o = exp
                report "Feil data: forventet 0x" & to_hex8(exp) &
                       ", fikk 0x" & to_hex8(rx_data_o)
                severity failure;

            report "OK: mottok korrekt byte 0x" & to_hex8(exp);
        end procedure;

        constant TEST_BYTE : std_logic_vector(7 downto 0) := x"A5";
    begin
        -- Reset
        rst  <= '1';
        rx_i <= '1';
        wait_cycles(10);
        rst  <= '0';
        wait_cycles(10);

        -- Send og verifiser én byte
        report "Sender 0x" & to_hex8(TEST_BYTE);
        uart_send_byte(TEST_BYTE);
        await_and_check(TEST_BYTE);

        -- Ferdig
        report "ALLE TESTER OK." severity note;
        std.env.stop;  -- VHDL-2008
        wait;
    end process;

end architecture tb;
