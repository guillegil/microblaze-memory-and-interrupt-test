#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xgpio.h"
#include "xintc.h"
#include "xuartlite.h"


/*
* Definitions
*/

#define INTC_DEVICE_ID  	(XPAR_PROCESSOR_MICROBLAZE_0_AXI_INTC_DEVICE_ID)

#define UART_ID				(XPAR_PERIPHERALS_UART_DEVICE_ID)
#define UARTLITE_INT_IRQ_ID (XPAR_INTC_0_UARTLITE_0_VEC_ID)

#define LEDS_ID 			(XPAR_PERIPHERALS_GPIO_LEDS_DEVICE_ID)

#define SW_BTNS_ID			(XPAR_PERIPHERALS_GPIO_SW_BTNS_DEVICE_ID)
#define SW_CHANNEL			(1)
#define BTNS_CHANNEL		(2)
#define SW_BTNS_INT_IRQ_ID	(XPAR_INTC_0_GPIO_1_VEC_ID)

#define DDR_BASE_ADDR		(XPAR_PERIPHERALS_MIG_7SERIES_0_BASEADDR)
#define DDR_HIGH_ADDR		(XPAR_PERIPHERALS_MIG_7SERIES_0_HIGHADDR)

/*
* Interrupt handlers
*/

void UARTRecvHandler(void *CallBackRef, unsigned int EventData);
void SwBtnsIntHandler(void *CallBackRef, unsigned int EventData);

/*
* Function prototypes
*/

int SetupSystem();

/*
* Global variables
*/

XIntc InterruptController;
XUartLite uart;
XGpio leds, sw_btns;


int main()
{
	print("Program started\r\n");
	print("Setting up system...\r\n");
	SetupSystem();

    volatile u32 *ddr_mem = (volatile u32 *)DDR_BASE_ADDR;

    print("Starting memory write/read test\r\n");
    print("Writing into memory\r\n");
    for (u32 offset = 0; offset < ((DDR_HIGH_ADDR - DDR_BASE_ADDR) >> 2); offset = offset + 8192)
    {
    	/*
    	* Uncomment the next line to see the current transaction. It'll increase the time to end up the loop.
    	*/

    	// xil_printf("Writing 0x%08x address 0x%08x. Offset = %d\r\n", offset, (ddr_mem + offset), offset);
    	*(ddr_mem + offset) = offset;
    }

    u8 flag = 0;

    print("Reading from memory and check data\r\n");
    for (u32 offset = 0; offset < ((DDR_HIGH_ADDR - DDR_BASE_ADDR) >> 2); offset = offset + 8192)
    {
    	/*
    	* Uncomment the next line to see the current transaction. It'll increase the time to end up the loop.
    	*/

    	// xil_printf("Reading at address 0x%08x. Offset = %d\r\n", (ddr_mem + offset), offset);

    	if (*(ddr_mem + offset) != offset)
    	{
    		flag = 1;
    		break;
    	}
    }

    if (1 == flag)
    {
    	print("ERROR: Data read from memory does no match with previous write\r\n");
    } else
    {
    	print("Memory test was SUCCESSFUL\r\n");
    }


    while(1);

    cleanup_platform();
    return 0;
}


int SetupSystem()
{
    init_platform();

    XUartLite_Initialize(&uart, UART_ID);

    XGpio_Initialize(&leds, LEDS_ID);
    XGpio_SetDataDirection(&leds, 1, 0);
    XGpio_DiscreteWrite(&leds, 1, 0xA5);

    XGpio_Initialize(&sw_btns, SW_BTNS_ID);
    XGpio_SetDataDirection(&sw_btns, 1, 0xFF);

	int Status;

	/*
	*	Initialize the interrupt controller
	*/
	Status = XIntc_Initialize(&InterruptController, INTC_DEVICE_ID);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}


	/*
	 * Connect a device driver handler that will be called when an interrupt
	 * for the device occurs, the device driver handler performs the
	 * specific interrupt processing for the device.
	 */
	Status = XIntc_Connect(&InterruptController, UARTLITE_INT_IRQ_ID, (XInterruptHandler)XUartLite_InterruptHandler, (void *)&uart);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	Status = XIntc_Connect(&InterruptController, SW_BTNS_INT_IRQ_ID, (Xil_ExceptionHandler)SwBtnsIntHandler, &sw_btns);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}


	/*
	* Start the interrupt controller such that interrupts are enabled for
	* all devices that cause interrupts.
	*/
	Status = XIntc_Start(&InterruptController, XIN_REAL_MODE);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/*
	 * Enable the interrupt for the devices.
	 */
	XIntc_Enable(&InterruptController, UARTLITE_INT_IRQ_ID);
	XIntc_Enable(&InterruptController, SW_BTNS_INT_IRQ_ID);


	/*
	 * Initialize the exception table.
	 */
	Xil_ExceptionInit();


	/*
	 * Register the interrupt controller handler with the exception table.
	 */
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XIntc_InterruptHandler, &InterruptController);

	/*
	 * Enable exceptions.
	 */
	Xil_ExceptionEnable();


	XGpio_InterruptEnable(&sw_btns, BTNS_CHANNEL);
	XGpio_InterruptEnable(&sw_btns, SW_CHANNEL);
	XGpio_InterruptGlobalEnable(&sw_btns);

	XUartLite_SetRecvHandler(&uart, UARTRecvHandler, &uart);
	XUartLite_EnableInterrupt(&uart);

	return XST_SUCCESS;
}



void UARTRecvHandler(void *CallBackRef, unsigned int EventData)
{
	u8 data;

	XUartLite_Recv(&uart, &data, 1);
	XGpio_DiscreteWrite(&leds, 1, data);
}

void SwBtnsIntHandler(void *CallBackRef, unsigned int EventData)
{
	u32 channel = XGpio_InterruptGetStatus(&sw_btns);
	XGpio *ThisDevice = (XGpio *)CallBackRef;

	if ( (channel & SW_CHANNEL) == SW_CHANNEL )
	{
		print("Switches interrupted!\r\n");
	} else
	{
		print("Buttons interrupted!\r\n");
	}

	XGpio_InterruptClear(ThisDevice, channel);
}
