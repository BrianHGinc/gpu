module FIFO_3word_0_latency (

input wire clk,                  // CLK input
input wire reset,                // reset FIFO

input  wire shift_in,            // load a word into the FIFO.
input  wire shift_out,           // shift data out of the FIFO.
input  wire [bits-1:0] data_in,  // data word input.

output wire fifo_not_empty,      // High when there is data available.
output wire fifo_full,           // High when the FIFO is full.
output wire [bits-1:0] data_out  // FIFO data word output
);

parameter bits = 8 ;             // sets the width of the fifo
parameter zero_latency = 1;      // When set to 1, if the FIFO is empty, the data_out and fifo_empty flag will
                                 // immediately reflect the state of the inputs data_in and shift_in, 0 clock cycle delay.
                                 // When set to 0, like a normal synchronous FIFO, the shift_in will take 1 clock cycle before
                                 // the fifo_empty flag goes low.  A shift_out will be required to see the correct data_out.

wire [bits-1:0] fifo_data[3:0] ;           // Link to FIFO memory plus a transparent wire to the data input port
reg  [bits-1:0] fifo_data_reg[3:0] ;       // FIFO memory
reg  [2:0]      fifo_wr_pos, fifo_rd_pos, fifo_size ; // the amount of data stored in the fifo

assign fifo_data[3:0] = fifo_data_reg[3:0];

assign data_out       = (( fifo_size == 0 ) && (zero_latency )) ?  data_in : fifo_data[fifo_rd_pos[1:0]] ; // when FIFO is empty and
                                                                                    // shift_in is set, show the data_in on the data_out with 0 latency
                                                                                    // otherwise show the FIFO memory register once it is latched.

assign fifo_not_empty = (fifo_size != 0) || (zero_latency && shift_in); // set set high when there is data in the FIFO,
                                                                                    // make high immediate if there is a shift_in and zero_latency is set.
assign fifo_full      = (fifo_size >= 3'd3);                                        // set FIFO full when there are 3 words in the buffer.


always @ (posedge clk) begin

if (reset) begin

	fifo_data_reg[0] = 0 ;  // clear the FIFO's memory contents
	fifo_data_reg[1] = 0 ;  // clear the FIFO's memory contents
	fifo_data_reg[2] = 0 ;  // clear the FIFO's memory contents
	fifo_data_reg[3] = 0 ;  // clear the FIFO's memory contents

	fifo_rd_pos       = 3'd0;      // reset the FIFO memory counter
	fifo_wr_pos       = 3'd0;      // reset the FIFO memory counter
	fifo_size         = 3'd0;      // reset the FIFO memory counter

	end else begin

            if (  shift_in && ~shift_out ) fifo_size <= fifo_size + 1'b1; // Calculate the number of words stored in the FIFO
       else if ( ~shift_in &&  shift_out ) fifo_size <= fifo_size - 1'b1;

                 if ( shift_in ) begin
                      fifo_wr_pos                     <= fifo_wr_pos + 1'b1 ;
                      fifo_data_reg[fifo_wr_pos[1:0]] <= data_in ;
                      end
                 if ( shift_out ) begin
                      fifo_rd_pos                <= fifo_rd_pos + 1'b1 ;
                      end
        
   end // ~reset


end // always @ (posedge clk) begin
endmodule
