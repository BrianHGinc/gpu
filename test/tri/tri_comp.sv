module tri_comp (

// inputs
	input  logic              clk,
	input  signed [3:0][11:0] in,
// outputs
	output logic [15:0]       in_a_eq_b,
	output logic [15:0]       in_a_gt_b,
	output logic [15:0]       in_a_lt_b

);

parameter bit CLOCK_OUTPUT = 0;

always_comb begin

	if ( ~CLOCK_OUTPUT ) begin
	
		for ( int i = 0 ; i <= 15 ; i++ ) begin
		
			in_a_eq_b[i] = ( in[ i[3:2] ] == in[ i[1:0] ] ) ;
			in_a_gt_b[i] = ( in[ i[3:2] ] >  in[ i[1:0] ] ) ;
			in_a_lt_b[i] = ( in[ i[3:2] ] <  in[ i[1:0] ] ) ;
			
		end
		
	end

end

always_ff @( posedge clk ) begin

	if ( CLOCK_OUTPUT ) begin
	
		for ( int i = 0 ; i <= 15 ; i++ ) begin
		
			in_a_eq_b[i] <= ( in[ i[3:2] ] == in[ i[1:0] ] ) ;
			in_a_gt_b[i] <= ( in[ i[3:2] ] >  in[ i[1:0] ] ) ;
			in_a_lt_b[i] <= ( in[ i[3:2] ] <  in[ i[1:0] ] ) ;
			
		end
		
	end

end

endmodule
