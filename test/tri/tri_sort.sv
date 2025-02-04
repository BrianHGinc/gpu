module tri_sort (

// inputs
	input logic [3:0][11:0] inX,
	input logic [3:0][11:0] inY,
// outputs	
	output logic [3:0][11:0] aX,
	output logic [3:0][11:0] bX,
	output logic [3:0][11:0] aY,
	output logic [3:0][11:0] bY

);

always_comb begin

	if ( inY[0] >= inY[1] && inY[1] >= inY[2] ) begin

		aX[0] = inX[2] ;
		aY[0] = inY[2] ;
		bX[0] = inX[0] ;
		bY[0] = inY[0] ;
		
		aX[1] = inX[2] ;
		aY[1] = inY[2] ;
		bX[1] = inX[1] ;
		bY[1] = inY[1] ;
		
		aX[2] = inX[1] ;
		aY[2] = inY[1] ;
		bX[2] = inX[0] ;
		bY[2] = inY[0] ;

	end else if ( inY[1] >= inY[2] && inY[2] >= inY[0] ) begin
	
		aX[0] = inX[0] ;
		aY[0] = inY[0] ;
		bX[0] = inX[1] ;
		bY[0] = inY[1] ;
		
		aX[1] = inX[0] ;
		aY[1] = inY[0] ;
		bX[1] = inX[2] ;
		bY[1] = inY[2] ;
		
		aX[2] = inX[2] ;
		aY[2] = inY[2] ;
		bX[2] = inX[1] ;
		bY[2] = inY[1] ;
	
	end else if ( inY[2] >= inY[0] && inY[0] >= inY[1] ) begin
	
		aX[0] = inX[1] ;
		aY[0] = inY[1] ;
		bX[0] = inX[2] ;
		bY[0] = inY[2] ;
		
		aX[1] = inX[1] ;
		aY[1] = inY[1] ;
		bX[1] = inX[0] ;
		bY[1] = inY[0] ;
		
		aX[2] = inX[0] ;
		aY[2] = inY[0] ;
		bX[2] = inX[2] ;
		bY[2] = inY[2] ;
	
	end else if ( inY[0] >= inY[2] && inY[2] >= inY[1] ) begin
	
		aX[0] = inX[1] ;
		aY[0] = inY[1] ;
		bX[0] = inX[0] ;
		bY[0] = inY[0] ;
		
		aX[1] = inX[1] ;
		aY[1] = inY[1] ;
		bX[1] = inX[2] ;
		bY[1] = inY[2] ;
		
		aX[2] = inX[2] ;
		aY[2] = inY[2] ;
		bX[2] = inX[0] ;
		bY[2] = inY[0] ;
	
	end else if ( inY[2] >= inY[1] && inY[1] >= inY[0] ) begin
	
		aX[0] = inX[0] ;
		aY[0] = inY[0] ;
		bX[0] = inX[2] ;
		bY[0] = inY[2] ;
		
		aX[1] = inX[0] ;
		aY[1] = inY[0] ;
		bX[1] = inX[1] ;
		bY[1] = inY[1] ;
		
		aX[2] = inX[1] ;
		aY[2] = inY[1] ;
		bX[2] = inX[2] ;
		bY[2] = inY[2] ;
	
	end else if ( inY[1] >= inY[0] && inY[0] >= inY[2] ) begin
	
		aX[0] = inX[2] ;
		aY[0] = inY[2] ;
		bX[0] = inX[1] ;
		bY[0] = inY[1] ;
		
		aX[1] = inX[2] ;
		aY[1] = inY[2] ;
		bX[1] = inX[0] ;
		bY[1] = inY[0] ;
		
		aX[2] = inX[0] ;
		aY[2] = inY[0] ;
		bX[2] = inX[1] ;
		bY[2] = inY[1] ;
	
	end

end


endmodule
