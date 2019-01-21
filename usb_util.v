`ifndef usb_util_v
`define usb_util_v

`define CLOG2(x) \
   x <= 2	 ? 1 : \
   x <= 4	 ? 2 : \
   x <= 8	 ? 3 : \
   x <= 16	 ? 4 : \
   x <= 32	 ? 5 : \
   x <= 64	 ? 6 : \
   x <= 128	 ? 7 : \
   x <= 256	 ? 8 : \
   x <= 512	 ? 9 : \
   x <= 1024	 ? 10 : \
   x <= 2048	 ? 11 : \
   x <= 4096	 ? 12 : \
   x <= 8192	 ? 13 : \
   x <= 16384	 ? 14 : \
   x <= 32768	 ? 15 : \
   x <= 65536	 ? 16 : \
   -1

module fifo(
	input clk,
	input reset,
	output data_available,
	output space_available,
	input [WIDTH-1:0] write_data,
	input write_strobe,
	output [WIDTH-1:0] read_data,
	input read_strobe
);
	parameter WIDTH = 8;
	parameter NUM = 256;

	reg [WIDTH-1:0] buffer[0:NUM-1];
	reg [`CLOG2(NUM)-1:0] write_ptr;
	reg [`CLOG2(NUM)-1:0] read_ptr;

	assign read_data = buffer[read_ptr];
	assign data_available = write_ptr != read_ptr;
	assign space_available = write_ptr + 1 != read_ptr;

	always @(posedge clk) begin
		if (reset) begin
			write_ptr <= 0;
			read_ptr <= 0;
		end else begin
			if (write_strobe) begin
				buffer[write_ptr] <= write_data;
				write_ptr <= write_ptr + 1;
			end
			if (read_strobe) begin
				read_ptr <= read_ptr + 1;
			end
		end
	end
endmodule

module rising_edge_detector ( 
  input clk,
  input in,
  output out
);
  reg in_q;

  always @(posedge clk) begin
    in_q <= in;
  end

  assign out = !in_q && in;
endmodule


module falling_edge_detector ( 
  input clk,
  input in,
  output out
);
  reg in_q;

  always @(posedge clk) begin
    in_q <= in;
  end

  assign out = in_q && !in;
endmodule


module strobe(
	input clk_in,
	input clk_out,
	input strobe_in,
	output strobe_out,
	input [WIDTH-1:0] data_in,
	output [WIDTH-1:0] data_out
);
	parameter WIDTH = 1;
	parameter DELAY = 2; // 2 for metastability, larger for testing

	reg flag;
	reg prev_strobe;
	reg [DELAY:0] sync;
	reg [WIDTH-1:0] data;

	// flip the flag and clock in the data when strobe is high
	always @(posedge clk_in) begin
		//if ((strobe_in && !prev_strobe)
		//|| (!strobe_in &&  prev_strobe))
		flag <= flag ^ strobe_in;

		if (strobe_in)
			data <= data_in;

		prev_strobe <= strobe_in;
	end

	// shift through a chain of flipflop to ensure stability
	always @(posedge clk_out)
		sync <= { sync[DELAY-1:0], flag };

	assign strobe_out = sync[DELAY] ^ sync[DELAY-1];
	assign data_out = data;
endmodule


module dflip(
	input clk,
	input in,
	output out
);
	reg [2:0] d;
	always @(posedge clk)
		d <= { d[1:0], in };
	assign out = d[2];
endmodule


module delay(
	input clk,
	input in,
	output out
);
	parameter DELAY = 1;

	generate
	if (DELAY == 0) begin
		assign out = in;
	end else
	if (DELAY == 1) begin
		reg buffer;
		always @(posedge clk)
			buffer <= in;
		assign out = buffer;
	end else begin
		reg [DELAY-1:0] buffer;
		always @(posedge clk)
			buffer <= { buffer[DELAY-2:0], in };
		assign out = buffer[DELAY-1];
	end
	endgenerate
endmodule

`endif
