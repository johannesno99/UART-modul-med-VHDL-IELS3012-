/*
 * AVR128DB48 ? TX via USART1 (PC1), 9600 8N1.
 * Setter OSCHF = 24 MHz, no prescale. Sender en byte ('TX_BYTE') en gang.
 * Tidligere USART3-oppsett (for Tera Term) er kommentert ut for testing senere.
 */

#define F_CPU 24000000UL
#include <avr/io.h>
#include <avr/cpufunc.h>  

#define UART_BAUD 9600UL
#define TX_BYTE   0x41 // Hex verdi for 'A'

// AVR BAUD-beregning
#define BAUD_REG(FCPU, BAUD) \
    ((uint16_t)((((uint32_t)(FCPU)) * 64ULL) / (16ULL * (BAUD)) + 0.5S))

static inline void clock_24mhz_no_prescale(void)
{
    // Velg høyfrekvent oscillator som hovedklokke
    _PROTECTED_WRITE(CLKCTRL.MCLKCTRLA, CLKCTRL_CLKSEL_OSCHF_gc);

    // Sett OSCHF til 24 MHz
    _PROTECTED_WRITE(CLKCTRL.OSCHFCTRLA, CLKCTRL_FRQSEL_24M_gc);

    // Ingen prescaler
    _PROTECTED_WRITE(CLKCTRL.MCLKCTRLB, 0x00);
}

int main(void)
{
    clock_24mhz_no_prescale();   // må gjøres før baud settes

    /* USART1-oppsett (aktivt) */
    // PC1 = USART1 TX (brukes mot FPGA)
    PORTC.DIRSET = PIN0_bm;

    // Konfigurer USART1: 9600 baud, 8 databiter, ingen paritet, 1 stoppbit (8N1)
    USART1.BAUD  = BAUD_REG(F_CPU, UART_BAUD);
    USART1.CTRLC = USART_CHSIZE_8BIT_gc | USART_PMODE_DISABLED_gc;
    USART1.CTRLB = USART_TXEN_bm;

    // Send en byte (TX_BYTE) via USART1
    while ((USART1.STATUS & USART_DREIF_bm) == 0) { }
    USART1.TXDATAL = TX_BYTE;
    while ((USART1.STATUS & USART_TXCIF_bm) == 0) { }
    USART1.STATUS = USART_TXCIF_bm;


    /* Tidligere USART3-oppsett (Tera term) */
    /*
    // PB0 = USART3 TX (Koblet til via USB - tilkobling)
    PORTB.DIRSET = PIN0_bm;

    USART3.BAUD  = BAUD_REG(F_CPU, UART_BAUD);
    USART3.CTRLC = USART_CHSIZE_8BIT_gc | USART_PMODE_DISABLED_gc;
    USART3.CTRLB = USART_TXEN_bm;

    while ((USART3.STATUS & USART_DREIF_bm) == 0) { }
    USART3.TXDATAL = TX_BYTE;
    while ((USART3.STATUS & USART_TXCIF_bm) == 0) { }
    USART3.STATUS = USART_TXCIF_bm;
    */

    for(;;) { /* ferdig */ }
}
