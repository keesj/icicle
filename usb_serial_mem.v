`ifndef usb_serial_mem_v
`define usb_serial_mem_v

`include "usb_serial.v"

`define UART_REG_CLK_DIV 2'b00
`define UART_REG_STATUS  2'b01
`define UART_REG_DATA    2'b10


module usb_serial_mem(
	input clk,
	input clk_48mhz,
	input reset,
	output [1:0] debug,

	// physical layer
	inout usb_p,
	inout usb_n,
	output usb_pu,

	// memory bus
        input [31:0] address_in,
        input sel_in,
        input read_in,
        output [31:0] read_value_out,
        input [3:0] write_mask_in,
        input [31:0] write_value_in,
        output ready_out
);
	assign ready_out = sel_in; // always ready

	wire usb_tx_en;
	wire usb_p_tx;
	wire usb_n_tx;

	wire usb_p_rx_io;
	wire usb_n_rx_io;
	wire usb_p_rx = usb_tx_en ? 1'b1 : usb_p_rx_io;
	wire usb_n_rx = usb_tx_en ? 1'b0 : usb_n_rx_io;
	assign usb_pu = 1'b1;

	assign debug[0] = usb_p_tx;
	assign debug[1] = usb_p_rx;

	SB_IO #(
		.PIN_TYPE(6'b1010_01) // tristatable output
	) buffer [1:0] (
		.OUTPUT_ENABLE(usb_tx_en),
		.PACKAGE_PIN({usb_p, usb_n}),
		.D_IN_0({usb_p_rx_io, usb_n_rx_io}),
		.D_OUT_0({usb_p_tx, usb_n_tx})
	);

	reg uart_tx_strobe;
	reg [7:0] uart_tx_data;
	wire uart_tx_ready;
	reg uart_tx_busy;

	wire [7:0] uart_rx_data_in;
	reg [7:0] uart_rx_data;
	wire uart_rx_strobe;
	reg uart_rx_ready;

	wire fifo_space_available;
	wire fifo_data_available;
	reg [7:0] fifo_tx_data;
	reg fifo_tx_strobe;
	wire [7:0] fifo_rx_data;
	reg fifo_rx_strobe;
  
	fifo tx_buffer(
		.clk(clk),
		.reset(reset),
		.space_available(fifo_space_available),
		.data_available(fifo_data_available),
		.write_data(fifo_tx_data),
		.write_strobe(fifo_tx_strobe),
		.read_data(fifo_rx_data),
		.read_strobe(fifo_rx_strobe)
	);

	// feed the USB serial port from the outbound FIFO
	always @(posedge clk) if (!reset) begin
		if (uart_tx_ready
		&& !uart_tx_strobe
		&& !fifo_rx_strobe
		&&  fifo_data_available
		) begin
			uart_tx_data <= fifo_rx_data;
			uart_tx_strobe <= 1;
			fifo_rx_strobe <= 1;
		end else begin
			uart_tx_strobe <= 0;
			fifo_rx_strobe <= 0;
		end
	end

	usb_serial usb_serial_dev(
		.clk(clk),
		.clk_48mhz(clk_48mhz),
		.reset(reset),
		// physical layer
		.usb_p_rx(usb_p_rx),
		.usb_n_rx(usb_n_rx),
		.usb_p_tx(usb_p_tx),
		.usb_n_tx(usb_n_tx),
		.usb_tx_en(usb_tx_en),
		// fifo
		.uart_tx_ready(uart_tx_ready),
		.uart_tx_strobe(uart_tx_strobe),
		.uart_tx_data(uart_tx_data),
		.uart_rx_strobe(uart_rx_strobe),
		.uart_rx_data(uart_rx_data_in)
	);

	reg [31:0] read_value_out;
	initial read_value_out <= 0;

	always @(posedge clk) if (!reset)
	begin
		fifo_tx_strobe <= 0;

		if (sel_in)
		case(address_in[3:2])
		`UART_REG_STATUS: begin
			if (read_in)
			begin
				read_value_out[1] <= uart_rx_ready;
				read_value_out[0] <= fifo_space_available;
			end
		end
		`UART_REG_DATA: begin
			if (read_in)
			begin
				read_value_out[31] <= uart_rx_ready;
				read_value_out[7:0] <= uart_rx_data;
				uart_rx_ready <= 0;
			end else
			if (write_mask_in[0] && fifo_space_available)
			begin
				// store data in the outbound fifo
				fifo_tx_data <= write_value_in[7:0];
				fifo_tx_strobe <= 1;
			end
		end
		endcase

		if (uart_rx_strobe)
		begin
			// new byte has arrived on the USB port
			uart_rx_data <= uart_rx_data_in;
			uart_rx_ready <= 1;
		end
	end

endmodule


`endif
