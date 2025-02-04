module geometry_processor (

	// inputs
	input logic clk,                    // System clock
    input logic reset,                  // Force reset
    input logic fifo_cmd_ready,         // 16-bit Data Command Ready signal    - connects to the 'strobe' on the selected high.low Z80 bus output port
    input logic [15:0] fifo_cmd_in,     // 16-bit Data Command bus             - connects to the 16-bit output port on the Z80 bus

	// data_mux_geo inputs
    input logic [15:0] rd_data_in,      // input from data_out_geo[15:0]
    input logic rd_data_rdy_a,          // input from geo_rd_rdy_a
    input logic rd_data_rdy_b,          // input from geo_rd_rdy_b
    input logic ram_mux_busy,           // input from geo_port_full
    
    // data_mux_geo outputs
    output logic rd_req_a,              // output to geo_rd_req_a on data_mux_geo
    output logic rd_req_b,              // output to geo_rd_req_b on data_mux_geo
    output logic wr_ena,                // output to geo_wr_ena   on data_mux_geo
    output logic [19:0] ram_addr,       // output to address_geo  on data_mux_geo
    output logic [15:0] ram_wr_data,    // output to data_in_geo  on data_mux_geo
    
    // collision saturation counter outputs
    output logic [7:0]  collision_rd,   // output to 1st read port on Z80_bridge_v2
    output logic [7:0]  collision_wr    // output to 2nd read port on Z80_bridge_v2
    
);

// wire interconnects for the sub-modules
logic draw_busy        ;  
logic [35:0] draw_cmd  ;
logic draw_cmd_rdy     ;
logic fifo_cmd_busy    ;
logic [39:0] pixel_cmd ;
logic pixel_cmd_rdy    ;

geometry_xy_plotter geoff (

	// inputs
	.clk            ( clk            ),
	.reset          ( reset          ),
	.fifo_cmd_ready ( fifo_cmd_ready ),
	.fifo_cmd_in    ( fifo_cmd_in    ),
	.draw_busy      ( draw_busy      ),
	//outputs
	.draw_cmd_rdy   ( draw_cmd_rdy   ),
	.draw_cmd       ( draw_cmd       ),
	.fifo_cmd_busy  ( fifo_cmd_busy  )
	
);

pixel_address_generator paget (

    // inputs
    .clk           ( clk           ),
    .reset         ( reset         ),
    .draw_cmd_rdy  ( draw_cmd_rdy  ),
    .draw_cmd      ( draw_cmd      ),
    .draw_busy     ( draw_busy     ),
    // outputs
    .pixel_cmd_rdy ( pixel_cmd_rdy ),
    .pixel_cmd     ( pixel_cmd     )

);

 geo_pixel_writer pixie (

    // inputs
    .clk              ( clk           ),
    .reset            ( reset         ),
    .cmd_rdy          ( pixel_cmd_rdy ),
    .cmd_in           ( pixel_cmd     ),
    .rd_data_in       ( rd_data_in    ),
    .rd_data_rdy_a    ( rd_data_rdy_a ),
    .rd_data_rdy_b    ( rd_data_rdy_b ),
    .ram_mux_busy     ( ram_mux_busy  ),
    .collision_rd_rst ( 1'b0          ),
    .collision_wr_rst ( 1'b0          ),
    
    // outputs
    .draw_busy        ( draw_busy     ),
    .rd_req_a         ( rd_req_a      ),
    .rd_req_b         ( rd_req_b      ),
    .wr_ena           ( wr_ena        ),
    .ram_addr         ( ram_addr      ),
    .ram_wr_data      ( ram_wr_data   ),
    .collision_rd     ( collision_rd  ),
    .collision_wr     ( collision_wr  )

);

endmodule



/*********************************************************
 *
 * GEOMETRY XY PLOTTER
 *
 *********************************************************/
module geometry_xy_plotter (

    input logic clk,              // System clock
    input logic reset,            // Force reset
    input logic fifo_cmd_ready,   // 16-bit Data Command Ready signal
    input logic [15:0] fifo_cmd_in,// 16-bit Data Command bus
    input logic draw_busy,        // HIGH when pixel writer FIFO is full - connects to zero_latency_fifo full flag
    
    //output logic load_cmd,        // HIGH when ready to receive next cmd_data[15:0] input
    output logic draw_cmd_rdy,    // Pulsed HIGH when data on draw_cmd[15:0] is ready to send to the pixel writer module
    output logic [35:0] draw_cmd, // Bits [35:32] hold AUX function number 0-15:
    output logic fifo_cmd_busy    // HIGH when FIFO is full/nearly full
    //  AUX=0  : Do nothing
    //  AUX=1  : Write pixel,                             : 31:24 color         : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=2  : Write pixel with color 0 mask,           : 31:24 color         : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=3  : Write from read pixel,                   : 31:24 ignored       : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=4  : Write from read pixel with color 0 mask, : 31:24 ignored       : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=6  : Read source pixel,                       : 31:24 ignored       : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=7  : Set Truecolor pixel color                : 31:24 8 bit alpha blend mix value : bits 23:0 hold RGB 24 bit color
    //                                                    Use function Aux3/4 to draw this color, only works if the destination is set to 16 bit true-color mode

    //  AUX=10 ; Resets the Write Pixel collision counter           : 31:24 sets transparent masked out color : bits 23:0 in true color mode, this holds RGB 24 bit mask color, in 8 bit mode, this allows for 3 additional transparent colors
    //  AUX=11 ; Resets the Write from read pixel collision counter : 31:24 sets transparent masked out color : bits 23:0 in true color mode, this holds RGB 24 bit mask color, in 8 bit mode, this allows for 3 additional transparent colors

    //  AUX=12 : Set destination raster width in bytes    : 15:0 holds destination raster image width in #bytes so the proper memory address can be calculated from the X&Y coordinates
    //  AUX=13 : Set source raster width in bytes,        : 15:0 holds source raster image width in #bytes so the proper memory address can be calculated from the X&Y coordinates
    //  AUX=14 : Set destination mem address,             : 31:24 bitplane mode : 23:0 hold destination base memory addres for write pixel
    //  AUX=15 : Set source mem address,                  : 31:24 bitplane mode : 23:0 hold the source base memory address for read source pixel
    
);

localparam CMD_OUT_NOP           = 0;
localparam CMD_OUT_PXWRI         = 1;
localparam CMD_OUT_PXWRI_M       = 2;
localparam CMD_OUT_PXPASTE       = 3;
localparam CMD_OUT_PXPASTE_M     = 4;

localparam CMD_OUT_PXCOPY        = 6;
localparam CMD_OUT_SETARGB       = 7;

localparam CMD_OUT_RST_PXWRI_M   = 10;
localparam CMD_OUT_RST_PXPASTE_M = 11;
localparam CMD_OUT_DSTRWDTH      = 12;
localparam CMD_OUT_SRCRWDTH      = 13;
localparam CMD_OUT_DSTMADDR      = 14;
localparam CMD_OUT_SRCMADDR      = 15;

reg [11:0] x[3:0];         // 2-dimensional 12-bit register for x0-x3
reg [11:0] y[3:0];         // 2-dimensional 12-bit register for y0-y3
reg [11:0] max_x;          // this reg will be both in this module and the memory pixel writer
reg [11:0] max_y;          // this reg will be both in this module and the memory pixel writer

reg [3:0]  draw_cmd_func;
reg [7:0]  draw_cmd_data_color;
reg [11:0] draw_cmd_data_word_Y;
reg [11:0] draw_cmd_data_word_X;
reg        draw_cmd_tx = 1'b0;

//************************************************
// geometry sequencer controls
//************************************************
reg [3:0]    geo_shape;            // 0 through 7 will draw their assigned shape, 8 through 15 will have different copy algorithms
reg          geo_fill;             // The geometric shape should be filled when set high
reg          geo_mask;             // If high, when drawing, the colors set in the 'collision counter' will not be drawn.
reg          geo_paste;            // If high, when drawing a geometric object, CMD_OUT_PXPASTE/_M will be used instead of CMD_OUT_PXWRI/_M for true color 16bit pixels
reg          geo_run   = 1'b0;     // High when a geometric shape is being drawn
reg [7:0]    geo_color;            // 8 bit pen drawing color

//************************************************
// geometry counters
//************************************************
reg signed [11:0]   geo_x    ;
reg signed [11:0]   geo_y    ;
reg signed [11:0]   geo_xdir ;
reg signed [11:0]   geo_ydir ;
reg        [3:0]    geo_sub_func1 ; // auxiliary sequence counter
reg        [3:0]    geo_sub_func2 ; // auxiliary sequence counter
reg signed [11:0]   dx   ;
reg signed [11:0]   dy   ;
reg signed [11:0]   errd ;

logic [15:0] cmd_data ;
logic        fifo_cmd_rdy_n ;
logic        load_cmd ;  // internal wire for FIFO

scfifo  scfifo_component (
    .sclr        (reset),                  // reset input
    .clock       (clk),                    // system clock
    .wrreq       (fifo_cmd_ready),         // connect this to the 'strobe' on the selected high.low Z80 bus output port.
    .data        (fifo_cmd_in),            // connect this to the 16 bit output port on the Z80 bus.
    .almost_full (fifo_cmd_busy),          // send to a selected bit on the Z80 status read port

    .empty       (fifo_cmd_rdy_n),         // remember, when low, the FIFO has commands for the geometry unit to process
    .rdreq       (load_cmd && !draw_busy && !fifo_cmd_rdy_n), // connect to the listed inputs.
    .q           (cmd_data[15:0]),         // to geometry_xy_plotter cmd_data input.
    .full        ()                        // optional, unused
);

defparam
    scfifo_component.add_ram_output_register = "ON",
    scfifo_component.almost_full_value = 510,
    scfifo_component.intended_device_family = "Cyclone III",
    scfifo_component.lpm_hint = "RAM_BLOCK_TYPE=M9K",
    scfifo_component.lpm_numwords = 512,
    scfifo_component.lpm_showahead = "ON",
    scfifo_component.lpm_type = "scfifo",
    scfifo_component.lpm_width = 16,
    scfifo_component.lpm_widthu = 9,
    scfifo_component.overflow_checking = "ON",
    scfifo_component.underflow_checking = "ON",
    scfifo_component.use_eab = "ON";

logic [7:0]  command_in;
logic [11:0] command_data12;
logic [7:0]  command_data8;

always_comb begin

	command_in     [7:0] = cmd_data[15:8];
	command_data12[11:0] = cmd_data[11:0];
	command_data8  [7:0] = cmd_data[7:0];

	//************************************************
	// Assign output port wires to internal registers
	//************************************************
	draw_cmd[35:32] = draw_cmd_func[3:0];
	draw_cmd[31:24] = draw_cmd_data_color[7:0];
	draw_cmd[23:12] = draw_cmd_data_word_Y[11:0];
	draw_cmd[11:0]  = draw_cmd_data_word_X[11:0];
	draw_cmd_rdy    = draw_cmd_tx;

	load_cmd        = ~geo_run;  // assigns the load_cmd output.  When the geometry unit is not drawing, the load_cmd goes high to load the next command.
	
end

always @(posedge clk or posedge reset) begin

    if (reset) begin    // reset to defaults
        
        // reset coordinate registers
        for ( integer i = 0; i < 4; i++ ) begin
            x[i]  <= { 12'b0 };
            y[i]  <= { 12'b0 };
        end
        max_x     <= 12'b0;
        max_y     <= 12'b0;

        // reset draw command registers
        draw_cmd_func        <= 4'b0;
        draw_cmd_data_color  <= 8'b0;
        draw_cmd_data_word_Y <= 12'b0;
        draw_cmd_data_word_X <= 12'b0;
        draw_cmd_tx          <= 1'b0;

        // reset geometry sequencer controls
        geo_shape     <= 4'b0;
        geo_fill      <= 1'b0;
        geo_mask      <= 1'b0;
        geo_paste     <= 1'b0;
        geo_run       <= 1'b0;
        geo_color     <= 8'b0;
        
        // reset geometry counters
        geo_x         <= 12'b0;
        geo_y         <= 12'b0;
        geo_xdir      <= 12'b0;
        geo_ydir      <= 12'b0;
        geo_sub_func1 <= 4'b0;
        geo_sub_func2 <= 4'b0;
        dx            <= 12'b0;
        dy            <= 12'b0;
        errd          <= 12'b0;

    end else begin
    
        if ( !fifo_cmd_rdy_n && ~geo_run && !draw_busy ) begin  // when the fifo_cmd_rdy_n input is LOW and the geometry unit geo_run is not running, execute the following command input

            casez (command_in)
                8'b10?????? : x[command_in[5:4]] <= command_data12;
                8'b11?????? : y[command_in[5:4]] <= command_data12;

                8'b011111?? : begin // set 24-bit destination screen memory pointer for plotting
                    draw_cmd_func        <= CMD_OUT_DSTMADDR[3:0];   // sets the output function
                    draw_cmd_data_color  <= command_data8;           // set screen_mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[command_in[1:0]];      // sets the upper 12 bits of the destination address
                    draw_cmd_data_word_X <= x[command_in[1:0]];      // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1;                    // transmits the command
                end

                8'b011110?? : begin // set 24-bit source screen memory pointer for blitter copy
                    draw_cmd_func        <= CMD_OUT_SRCMADDR[3:0];   // sets the output function
                    draw_cmd_data_color  <= command_data8;           // set screen_mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[command_in[1:0]];      // sets the upper 12 bits of the destination address
                    draw_cmd_data_word_X <= x[command_in[1:0]];      // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1;                    // transmits the command
                end
                    
                        
                8'd119 : begin  //Ignore for now
                    //destmem <= x[11:0][0] * 4096 + y[11:0][0];  // set both source & destination pointers for blitter copy
                    //srcmem  <= x[11:0][1] * 4096 + y[11:0][1];
                end
                8'd118 : begin //Ignore for now
                    //destmem <= x[11:0][1] * 4096 + y[11:0][1];  // set both source & destination pointers for blitter copy
                    //srcmem  <= x[11:0][0] * 4096 + y[11:0][0];
                end
                8'd117 : begin //Ignore for now
                    //destmem <= x[11:0][2] * 4096 + y[11:0][2];  // set both source & destination pointers for blitter copy
                    //srcmem  <= x[11:0][3] * 4096 + y[11:0][3];
                end
                8'd116 : begin //Ignore for now
                    //destmem <= x[11:0][3] * 4096 + y[11:0][3];  // set both source & destination pointers for blitter copy
                    //srcmem  <= x[11:0][2] * 4096 + y[11:0][2];
                end
                        
                8'd115 : begin  // set the number of bytes per horizontal line in the destination raster
                    draw_cmd_func        <= CMD_OUT_DSTRWDTH[3:0];   // sets the output function
                    draw_cmd_data_color  <= command_data8;           // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[2];                    // null
                    draw_cmd_data_word_X <= x[2];                    // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1;                    // transmits the command
                end
                    
                8'd114 : begin  // set the number of bytes per horizontal line in the source raster
                    draw_cmd_func        <= CMD_OUT_SRCRWDTH[3:0];   // sets the output function
                    draw_cmd_data_color  <= command_data8;           // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[2];                    // sets the lower 12 bits of the destination address
                    draw_cmd_data_word_X <= x[2];                    // null
                    draw_cmd_tx          <= 1'b1;                    // transmits the command
                end
                    
                8'd113 : begin  // set the number of bytes per horizontal line in the destination raster
                    draw_cmd_func        <= CMD_OUT_DSTRWDTH[3:0];   // sets the output function
                    draw_cmd_data_color  <= command_data8;           // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[3];                    // null
                    draw_cmd_data_word_X <= x[3];                    // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1;                    // transmits the command
                end
                    
                8'd112 : begin  // set the number of bytes per horizontal line in the source raster
                    draw_cmd_func        <= CMD_OUT_SRCRWDTH[3:0];   // sets the output function
                    draw_cmd_data_color  <= command_data8;           // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[3];                    // sets the lower 12 bits of the destination address
                    draw_cmd_data_word_X <= x[3];                    // null
                    draw_cmd_tx          <= 1'b1;                    // transmits the command
                end

                    
                8'd95  : begin
                    max_x <= x[0];    // set max width & height of screen to x0/y0
                    max_y <= y[0];
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                8'd94  : begin
                    max_x <= x[1];    // set max width & height of screen to x1/y1
                    max_y <= y[1];
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                8'd93  : begin
                    max_x <= x[2];    // set max width & height of screen to x2/y2
                    max_y <= y[2];
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                8'd92 : begin
                    max_x <= x[3];    // set max width & height of screen to x3/y3
                    max_y <= y[3];
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                        
                8'd91 : begin               // clear the pixel collision counter and sets all 3 transparent mask colors to 1 8-bit color in the source function data
                    draw_cmd_func        <= CMD_OUT_RST_PXWRI_M[3:0];                   // sets the output funtion
                    draw_cmd_data_color  <= command_data8;                              // sets the mask color
                    draw_cmd_data_word_Y <= { command_data8[7:0], command_data8[7:4] }; // sets mask color #2 and 1/2 or #3
                    draw_cmd_data_word_X <= { command_data8[3:0], command_data8[7:4] }; // sets mask color 1/2 or #3 and #4
                    draw_cmd_tx          <= 1'b1;                                       // transmits the command
                end
                8'd90 : begin               // clear the blitter copy pixel collision counter
                    draw_cmd_func        <= CMD_OUT_RST_PXPASTE_M[3:0];                 // sets the output funtion
                    draw_cmd_data_color  <= command_data8;                              // sets the mask color
                    draw_cmd_data_word_Y <= { command_data8[7:0], command_data8[7:4] }; // sets mask color #2 and 1/2 or #3
                    draw_cmd_data_word_X <= { command_data8[3:0], command_data8[7:4] }; // sets mask color 1/2 or #3 and #4
                    draw_cmd_tx          <= 1'b1;                                       // transmits the command
                end

                8'b000????? : begin // this range of commands all begin drawing a shape.
                                    // drawing commands begin here.  Keep the convention that:
                                    // extend_cmd[3] = fill enable
                                    // extend_cmd[4] = use the color in the copy/paste buffer.  This one is for drawing in true color mode.
                                    // extend_cmd[5] = mask enable - when drawing, the mask colours will not be plotted as they are transparent

                    geo_shape[3]         <= 1'b0;               // geo shapes 0 through 7, geo shapes 8 through 15 are for copy & paste.
                    geo_shape[2:0]       <= command_in[2:0];    // Set which one of shapes 0 through 7 should be drawn.  Shape 0 turns means nothing is being drawn
                    geo_fill             <= command_in[3];      // Fill enable bit
                    geo_paste            <= command_in[4];      // used for drawing in true color 16 bit mode
                    geo_mask             <= 1'b0;               // Mask disables when drawing raw geometry shapes
                    geo_run              <= 1'b1;               // a flag which signifies that a geometric shap drawing engine will begin drawing
                    geo_color            <= command_data8;      // set the 8bit pen color.
                    
                    geo_sub_func1        <= 4'b0;               // for geometric engines which have multiple phases, reset the phase counter
                    geo_sub_func2        <= 4'b0;               // for geometric engines which have 2 dimensional multiple phases, reset the phase counter
                    
                    // Initialize the geometry unit starting coordinates and direction so it can begin plotting immediately
                    geo_x                <= x[0];               // initialize the beginning pixel location
                    geo_y                <= y[0];               // initialize the beginning pixel location
                    if ( x[1] < x[0] ) geo_xdir <= 12'd0-12'd1; // set the direction of the counter (negative x in this case)
                    else if ( x[1] == x[0]) geo_xdir <= 12'd0;  // neutral x direction
                    else               geo_xdir <= 12'd1;       // positive x direction
                    if ( y[1] < y[0] ) geo_ydir <= 12'd0-12'd1; // negative y direction
                    else if ( y[1] == y[0]) geo_ydir <= 12'd0;  // neutral y direction
                    else               geo_ydir <= 12'd1;       // positive y direction
                    
                    dx <= (x[1]>x[0]) ? (x[1]-x[0]) : (x[0]-x[1]); // get absolute size of delta-x
                    dy <= (y[0]>y[1]) ? (y[1]-y[0]) : (y[0]-y[1]); // get absolute size of delta-y
                end

                default : begin
                    draw_cmd_tx <= 1'b0;    // stop transmit output command function
                    geo_shape   <= 4'b0;    // turn off the drawing shape
                end
                
            endcase
            
        end else if ( geo_run && !draw_busy ) begin

            case (geo_shape)    // run a selected geometric drawing engine

                4'd1 : begin    // draw line from (x[0],y[0]) to (x[1],y[1])
                
                    case (geo_sub_func1)    // during the draw line, we have multiple sub-functions to call 1 at a time
                
                        4'd0 : begin
                        
                               errd            <= dx + dy;
                               geo_sub_func1   <= 4'd1;                 // set line sub-function to plot line.
                               
                        end // geo_sub_func1 = 0 - setup for plot line
                
                        4'd1 : begin
                        
                            draw_cmd_func        <= CMD_OUT_PXWRI[3:0]; // Set up command to pixel plotter to write a pixel,
                            draw_cmd_data_color  <= geo_color;          // ... in geo_colour,
                            draw_cmd_data_word_Y <= geo_y ;             // ... at Y-coordinate,
                            draw_cmd_data_word_X <= geo_x ;             // ... and X-coordinate.

                            if ( ( geo_x >= 0 && geo_x <= max_x ) && (geo_y>=0 && geo_y<=max_y) )
								draw_cmd_tx  	 <= 1'b1; 				// send command if geo_X&Y are within valid drawing area
                            else
								draw_cmd_tx  	 <= 1'b0; 				// otherwise turn off draw command
                            
                            if ( geo_x == x[1] && geo_y == y[1] ) geo_shape <= 4'd0;   // last pixel - step to last sub_func1 stage, allowing time for this pixel to be written
                                                                                       // On the next clock, end the drawing-line function
                                
                            // increment x,y position
                            if ((errd << 1) > dy) begin
                                geo_x   <= geo_x + geo_xdir;
                                               
                                if (((errd<<1)+dy) < dx) begin
                                    geo_y   <= geo_y + geo_ydir;
                                    errd    <= errd + dx + dy;
                                end else errd    <= errd + dy;
                                
                            end else if ((errd << 1) < dx) begin
                                errd    <= errd + dx;
                                geo_y   <= geo_y + geo_ydir;                           
                            end
                        
                        end // geo_sub_func1 = 1 - plot line
                        
                    endcase // sub functions of draw line
                
                end // geo_shape - draw line
                
                4'd2 : begin    // draw a filled rectangle

                    if ( geo_y != (y[1] + geo_ydir) ) begin             // Check for bottom (or top, depending on sign of geo_ydir) of rectangle reached
                        if ( geo_x != (x[1] + geo_xdir) ) begin         // Check for right (or left, depending on sign of geo_xdir) of rectangle reached
                            draw_cmd_func        <= CMD_OUT_PXWRI[3:0]; // Set up command to pixel plotter to write a pixel,
                            draw_cmd_data_color  <= geo_color;          // ... in geo_colour,
                            draw_cmd_data_word_Y <= geo_y ;             // ... at Y-coordinate,
                            draw_cmd_data_word_X <= geo_x ;             // ... and X-coordinate.
                            if ( (geo_x >= 0 && geo_x <= max_x) && (geo_y >= 0 && geo_y <= max_y) )
								draw_cmd_tx  <= 1'b1; // send command if geo_X&Y are within valid drawing area
                            else
								draw_cmd_tx  <= 1'b0; // otherwise turn off draw command
                            
                            // Now increment (or decrement according to geo_xdir) geo_x to the next pixel.
                            // If geo_fill is HIGH, step to next X-position to fill the rectangle.
                            // If geo_x is at the end edge, step past it.
                            // If geo_y is at start or end (top or bottom edge), step to next X-position to draw the horizontal line.
                            if (geo_fill || geo_x == x[1] || geo_y == y[0] || geo_y == y[1] )   geo_x <= geo_x + geo_xdir;
                            // Otherwise, jump to end X-position to draw other edge for non-filled rectangle.
                            else                                                                geo_x <= x[1];

                        end else begin  // geo_x has passed vertical edge
                            draw_cmd_tx         <= 1'b0;                // do not send a draw cmd this cycle
                            geo_x               <= x[0];                // reset X to start X-position
                            geo_y               <= geo_y + geo_ydir;    // increment (or decrement) Y-position for next line
                        end
                    end else begin      // geo_y has passed horizontal edge
                            geo_run             <= 1'b0;                // stop geometry engine - shape completed
                            draw_cmd_tx         <= 1'b0;                // do not send a draw cmd this cycle
                    end
                    
                end // draw a filled rectangle

                default : begin
                
                    geo_run         <= 1'b0; // no valid drawing engine selected, so stop the geo_run flag.
                    draw_cmd_tx     <= 1'b0;
                    
                end

            endcase   // run a selected geometric drawing engine
                
        end else   draw_cmd_tx <= 1'b0;    // stop transmit output command function//  end of (geo_run) flag
    
    end // reset

end //always @(posedge clk)

endmodule


/*********************************************************
 *
 * PIXEL ADDRESS GENERATOR
 *
 *********************************************************/
 module pixel_address_generator (

    // inputs
    input logic        clk,              // System clock
    input logic        reset,            // Force reset
    
    input logic        draw_cmd_rdy,     // Pulsed HIGH when data on draw_cmd[15:0] is valid
    input logic[35:0]  draw_cmd,         // Bits [35:32] hold AUX function number 0-15:
    input logic        draw_busy,        // HIGH when pixel writer is busy

    // outputs
    output logic       pixel_cmd_rdy,
    output logic[39:0] pixel_cmd
// pixel_cmd format:
// 3     3 3             2 2     2 2     2 1                                     0
// 9     6 5             8 7     4 3     0 9                                     0
// |     | |             | |     | |     | |                                     |
// 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
// |-CMD-| |----COLOUR---| |WIDTH| |-BIT-| |-----------MEMORY ADDRESS------------|
//
// WIDTH is bits per pixel (screen mode)
//
// BIT is the bit in the addressed word that is the target of the RD/WR operation
//
    
);

// 3     3 3             2 2               1     1 1     0 0             0
// 5     2 1             4 3               5     2 1     8 7             0
// |     | |             | |               |     | |     | |             |
// 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
// |AUX01| |----COLOUR---| |-----Y COORDINATE----| |-----X COORDINATE----|
// |AUX02| |----COLOUR---| |-----Y COORDINATE----| |-----X COORDINATE----|
// |AUX03|                 |-----Y COORDINATE----| |-----X COORDINATE----|
// |AUX04|                 |-----Y COORDINATE----| |-----X COORDINATE----|
// ...
// |AUX06|                 |-----Y COORDINATE----| |-----X COORDINATE----|  READ
// |AUX07| |-ALPHA BLEND-| |-------------24-bit RGB COLOUR---------------|
// ...
// |AUX10| |-TRANSP MASK-| |RGB 24-bit MASK COLOUR OR 3 ADD TRANS COLOURS|
// |AUX11| |-TRANSP MASK-| |RGB 24-bit MASK COLOUR OR 3 ADD TRANS COLOURS|
// |AUX12| |BITPLANE MODE|                 |---DEST RASTER IMAGE WIDTH---|
// |AUX13| |BITPLANE MODE|                 |--SOURCE RASTER IMAGE WIDTH--|
// |AUX14|                 |-------DESTINATION BASE MEMORY ADDRESS-------|
// |AUX15|                 |----------SOURCE BASE MEMORY ADDRESS---------|
//

localparam int LUT_bits_to_shift[16] = '{ 4,3,3,2,2,2,2,1,1,1,1,1,1,1,1,0 };  // shift bits/pixel-1  0=1 bit, 1=2bit, 3=4bit, 7=8bit, 15-16bit.

localparam CMD_IN_NOP           = 0;
localparam CMD_IN_PXWRI         = 1;
localparam CMD_IN_PXWRI_M       = 2;
localparam CMD_IN_PXPASTE       = 3;
localparam CMD_IN_PXPASTE_M     = 4;

localparam CMD_IN_PXCOPY        = 6;
localparam CMD_IN_SETARGB       = 7;

localparam CMD_IN_RST_PXWRI_M   = 10;
localparam CMD_IN_RST_PXPASTE_M = 11;
localparam CMD_IN_DSTRWDTH      = 12;
localparam CMD_IN_SRCRWDTH      = 13;
localparam CMD_IN_DSTMADDR      = 14;
localparam CMD_IN_SRCMADDR      = 15;

// CMD_OUT:
localparam CMD_OUT_NOP           = 0;
localparam CMD_OUT_PXWRI         = 1;
localparam CMD_OUT_PXWRI_M       = 2;
localparam CMD_OUT_PXPASTE       = 3;
localparam CMD_OUT_PXPASTE_M     = 4;
localparam CMD_OUT_PXCOPY        = 6;
localparam CMD_OUT_SETARGB       = 7;
localparam CMD_OUT_RST_PXWRI_M   = 10;
localparam CMD_OUT_RST_PXPASTE_M = 11;

logic[23:0] dest_base_address_offset ;
logic[23:0] srce_base_address_offset ;
logic[3:0]  dest_target_bit ;
logic[3:0]  srce_target_bit ;
logic[3:0]  aux_cmd_in ;
logic[7:0]  bit_mode ;
logic[11:0] x ;
logic[11:0] y ;

// internal registers
logic[3:0]  dest_bits_per_pixel = 4'b0  ; // how many bits make up one pixel (1-16) - screen mode
logic[3:0]  srce_bits_per_pixel = 4'b0  ; // how many bits make up one pixel (1-16) - screen mode
//
logic[15:0] dest_rast_width     = 16'b0 ; // number of bits in a horizontal raster line
logic[15:0] srce_rast_width     = 16'b0 ; // number of bits in a horizontal raster line
//
logic[23:0] dest_base_address   = 24'b0 ; // points to first byte in the graphics display memory
logic[23:0] srce_base_address   = 24'b0 ; // points to first byte in the graphics display memory

logic[19:0] dest_address   = 20'b0 ; // points to first byte in the graphics display memory
logic[19:0] srce_address   = 20'b0 ; // points to first byte in the graphics display memory

// Logic registers for STAGE CLOCK #2
logic       s2_draw_cmd_rdy;
logic[3:0]  s2_aux_cmd_in;
logic[35:0] s2_draw_cmd;

always_comb begin

    aux_cmd_in[3:0] = draw_cmd[35:32] ;
    bit_mode[7:0]   = draw_cmd[31:24] ;   // number of bits per pixel - needs to be sourced from elsewhere (MAGGIE#?)
    y[11:0]         = draw_cmd[23:12] ;
    x[11:0]         = draw_cmd[11:0]  ;
    
    
    dest_target_bit[3:0]     = dest_base_address_offset[3:0] ;
    srce_target_bit[3:0]     = srce_base_address_offset[3:0] ;
    
    dest_address = dest_base_address[19:0] + ((dest_base_address_offset[19:0] << 1) >> LUT_bits_to_shift[dest_bits_per_pixel[3:0]]);
    srce_address = srce_base_address[19:0] + ((srce_base_address_offset[19:0] << 1) >> LUT_bits_to_shift[srce_bits_per_pixel[3:0]]);
    
end // always_comb

always_ff @(posedge clk or posedge reset) begin

    if (reset) begin

        dest_bits_per_pixel <= 4'b0 ;
        srce_bits_per_pixel <= 4'b0 ;
        dest_rast_width     <= 16'b0;
        srce_rast_width     <= 16'b0;
        dest_base_address   <= 24'b0;
        srce_base_address   <= 24'b0;
        pixel_cmd[39:0]     <= 40'b0;
        
    end else begin
  
		if (!draw_busy) begin
			s2_draw_cmd_rdy <= draw_cmd_rdy;
			s2_aux_cmd_in   <= aux_cmd_in;
			s2_draw_cmd     <= draw_cmd;
				
			if ( draw_cmd_rdy ) begin

				dest_base_address_offset <=  y * dest_rast_width[15:0]  + x ; // This calculation will only be ready for the S2 - second stage clock cycle.
				srce_base_address_offset <=  y * srce_rast_width[15:0]  + x ; // This calculation will only be ready for the S2 - second stage clock cycle.

				case (aux_cmd_in) //  These functions will happen on the first stage clock cycle
								  // no output functions are to take place
					
					CMD_IN_DSTRWDTH : begin
						dest_rast_width[15:0]    <= draw_cmd[15:0] ;    // set destination raster image width
						dest_bits_per_pixel[3:0] <= bit_mode[3:0] ;     // set screen mode (bits per pixel)
					end
					
					CMD_IN_SRCRWDTH : begin
						srce_rast_width[15:0]    <= draw_cmd[15:0] ;    // set source raster image width
						srce_bits_per_pixel[3:0] <= bit_mode[3:0] ;     // set screen mode (bits per pixel)
					end
				
					CMD_IN_DSTMADDR : begin
						dest_base_address[23:0]  <= draw_cmd[23:0] ;    // set destination base memory address
					end
					
					CMD_IN_SRCMADDR : begin
						srce_base_address[23:0]  <= draw_cmd[23:0] ;    // set source base memory address (even addresses only?)
					end                
				endcase

			end // if ( draw_cmd_rdy ) 

			if ( s2_draw_cmd_rdy ) begin
				case (s2_aux_cmd_in) //  These functions will happen on the second stage clock cycle
			
					CMD_IN_PXWRI : begin   // write pixel with colour, x & y
						pixel_cmd[0]     <= 1'b0 ;                       // generate address for the pixel
						pixel_cmd[19:1]  <= dest_address[19:1] ;         // generate address for the pixel
						pixel_cmd[23:20] <= dest_target_bit[3:0] ;       // which bit to edit in the addressed byte
						pixel_cmd[27:24] <= dest_bits_per_pixel[3:0] ;   // set bits per pixel for current screen mode
						pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;          // include colour information
						pixel_cmd[39:36] <= CMD_OUT_PXWRI[3:0] ;         // COLOUR, WRITE, NO TRANSPARENCY, NO R/M/W
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					CMD_IN_PXWRI_M : begin   // write pixel with colour, x & y
						pixel_cmd[0]     <= 1'b0 ;                       // generate address for the pixel
						pixel_cmd[19:1]  <= dest_address[19:1] ;         // generate address for the pixel
						pixel_cmd[23:20] <= dest_target_bit[3:0] ;       // which bit to edit in the addressed byte
						pixel_cmd[27:24] <= dest_bits_per_pixel[3:0] ;   // set bits per pixel for current screen mode
						pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;            // include colour information
						pixel_cmd[39:36] <= CMD_OUT_PXWRI_M[3:0] ;       // COLOUR, WRITE, MASK SET, NO R/M/W
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					CMD_IN_PXPASTE : begin   // write pixel with colour, x & y
						pixel_cmd[0]     <= 1'b0 ;                       // generate address for the pixel
						pixel_cmd[19:1]  <= dest_address[19:1] ;         // generate address for the pixel
						pixel_cmd[23:20] <= dest_target_bit[3:0] ;       // which bit to edit in the addressed byte
						pixel_cmd[27:24] <= dest_bits_per_pixel[3:0] ;   // set bits per pixel for current screen mode
						pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;            // include colour information
						pixel_cmd[39:36] <= CMD_OUT_PXPASTE[3:0] ;       // COLOUR, WRITE, NO TRANSPARENCY, NO R/M/W
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					CMD_IN_PXPASTE_M : begin   // write pixel with colour, x & y
						pixel_cmd[0]     <= 1'b0 ;                      // generate address for the pixel
						pixel_cmd[19:1]  <= dest_address[19:1] ;        // generate address for the pixel
						pixel_cmd[23:20] <= dest_target_bit[3:0] ;      // which bit to edit in the addressed byte
						pixel_cmd[27:24] <= dest_bits_per_pixel[3:0] ;  // set bits per pixel for current screen mode
						pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;           // include colour information
						pixel_cmd[39:36] <= CMD_OUT_PXPASTE_M[3:0] ;    // COLOUR, WRITE, MASK SET, NO R/M/W
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					CMD_IN_PXCOPY : begin   // read pixel with x & y
						pixel_cmd[0]     <= 1'b0 ;                       // generate address for the pixel
						pixel_cmd[19:1]  <= srce_address[19:1] ;         // generate address for the pixel
						pixel_cmd[23:20] <= srce_target_bit[3:0] ;       // which bit to read from the addressed byte
						pixel_cmd[27:24] <= srce_bits_per_pixel[3:0] ;   // set bits per pixel for current screen mode
						pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;         // transparent color value used for read pixel collision counter
						pixel_cmd[39:36] <= CMD_OUT_PXCOPY[3:0] ;        // NO COLOUR, READ, NO TRANS, NO R/M/W
						pixel_cmd_rdy    <= 1'b1 ;
					end

					CMD_IN_SETARGB       : begin
						pixel_cmd[31:0]  <= s2_draw_cmd[31:0] ;    // pass through first 32-bits of input to output ( Alpha Blend and 24-bit RGB colour data)
						pixel_cmd[39:36] <= CMD_OUT_SETARGB[3:0] ;   // pass through command only
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					CMD_IN_RST_PXWRI_M   : begin
						pixel_cmd[31:0]  <= s2_draw_cmd[31:0] ;          // pass through first 32-bits of input to output ( Alpha Blend and 24-bit RGB colour data)
						pixel_cmd[39:36] <= CMD_OUT_RST_PXWRI_M[3:0] ;   // pass through command only
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					CMD_IN_RST_PXPASTE_M : begin
						pixel_cmd[31:0]  <= s2_draw_cmd[31:0] ;           // pass through first 32-bits of input to output ( Alpha Blend and 24-bit RGB colour data)
						pixel_cmd[39:36] <= CMD_OUT_RST_PXPASTE_M[3:0] ;  // pass through command only
						pixel_cmd_rdy    <= 1'b1 ;
					end
					
					default : pixel_cmd_rdy      <= 1'b0 ;              // NOP - reset pixel_cmd_rdy for one-clock operation
					
				endcase

			end else pixel_cmd_rdy      <= 1'b0 ; //if ( s2_draw_cmd_rdy )

		end // if !draw_busy
  
	end // if !reset

end // always_ff @ posedge clk or reset

endmodule


/*********************************************************
 *
 * PIXEL WRITER
 *
 *********************************************************/
 module geo_pixel_writer (

// **** INPUTS ****

    input logic clk,
    input logic reset,
    
    // fifo inputs
    input logic cmd_rdy,                // input to fifo_not_empty
    input logic [39:0] cmd_in,          // input to fifo_data_in
    
    // data_mux_geo inputs
    input logic [15:0] rd_data_in,      // input from data_out_geo[15:0]
    input logic rd_data_rdy_a,          // input from geo_rd_rdy_a
    input logic rd_data_rdy_b,          // input from geo_rd_rdy_b
    input logic ram_mux_busy,           // input from geo_port_full
    
    // collision saturation counter inputs
    input logic collision_rd_rst,       // input from associated read port's read strobe
    input logic collision_wr_rst,       // input from associated read port's read strobe
    
// **** OUTPUTS ****

    // fifo outputs
    output logic draw_busy,             // fifo_full output
    
    // data_mux_geo outputs
    output logic rd_req_a,              // output to geo_rd_req_a on data_mux_geo
    output logic rd_req_b,              // output to geo_rd_req_b on data_mux_geo
    output logic wr_ena,                // output to geo_wr_ena   on data_mux_geo
    output logic [19:0] ram_addr,       // output to address_geo  on data_mux_geo
    output logic [15:0] ram_wr_data,    // output to data_in_geo  on data_mux_geo
    
    // collision saturation counter outputs
    output logic [7:0]  collision_rd,   // output to 1st read port on Z80_bridge_v2
    output logic [7:0]  collision_wr,   // output to 2nd read port on Z80_bridge_v2
    
    output logic [15:0] PX_COPY_COLOUR

);

localparam int LUT_shift [256] = '{
15,14,13,12,11,10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,  // Shift values for bpp=0, target=0 through 15.
14,12,10, 8, 6, 4, 2, 0,14,12,10, 8, 6, 4, 2, 0,  // Shift values for bpp=1, target=0 through 15.
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=2, invalid bitplane mode, no shift
12, 8, 4, 0,12, 8, 4, 0,12, 8, 4, 0,12, 8, 4, 0,  // Shift values for bpp=3, target=0 through 15.
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=4, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=5, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=6, invalid bitplane mode, no shift
 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0,  // Shift values for bpp=7, target=0 through 15.
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=8, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=9, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=10, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=11, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=12, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=13, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // Shift values for bpp=14, invalid bitplane mode, no shift
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0   // Shift values for bpp=15, target=0 through 15.
};
localparam int LUT_mask  [16]  = '{ 1,3,3,15,15,15,15,255,255,255,255,255,255,255,255,65535 };  // mask result bits after shift pixel-1  0=1 bit, 1=2bit, 3=4bit, 7=8bit, 15-16bit.

localparam CMD_IN_NOP              = 0  ;
localparam CMD_IN_PXWRI            = 1  ;
localparam CMD_IN_PXWRI_M          = 2  ;
localparam CMD_IN_PXPASTE          = 3  ;
localparam CMD_IN_PXPASTE_M        = 4  ;
localparam CMD_IN_PXCOPY           = 6  ;
localparam CMD_IN_SETARGB          = 7  ;
localparam CMD_IN_RST_PXWRI_M      = 10 ;
localparam CMD_IN_RST_PXPASTE_M    = 11 ;

parameter bit ZERO_LATENCY         = 1  ; // When set to 1 this will make the read&write commands immediate instead of a clock cycle later
parameter bit overflow_protection  = 1  ; // Prevents internal write position and writing if the fifo is full past the 1 extra reserve word
parameter bit underflow_protection = 1  ; // Prevents internal position position increment if the fifo is empty
parameter bit size7_fifo           = 0  ; // sets fifo into 7 word mode.

FIFO_3word_0_latency input_cmd_fifo_1 (  // Zero Latency Command buffer
    .clk              ( clk                  ), // CLK input
    .reset            ( reset                ), // Reset FIFO

    .shift_in         ( cmd_rdy              ), // Load data into the FIFO
    .shift_out        ( exec_cmd             ), // Shift data out of the FIFO
    .data_in          ( cmd_in[39:0]         ), // Data input from PAGET

    .fifo_not_empty   ( pixel_cmd_rdy        ), // High when there is data available for the pixel writer
    .fifo_full        ( draw_busy            ), // High when the FIFO is full - used to tell GEOFF and PAGET to halt until there is room in the FIFO again
    .data_out         ( pixel_cmd_data[39:0] )  // FIFO data output to pixel writer
);

defparam
    input_cmd_fifo_1.bits                 = 40,                   // The number of bits containing the command
    input_cmd_fifo_1.zero_latency         = ZERO_LATENCY,
    input_cmd_fifo_1.overflow_protection  = overflow_protection,  // Prevents internal write position and writing if the fifo is full past the 1 extra reserve word
    input_cmd_fifo_1.underflow_protection = underflow_protection, // Prevents internal position position increment if the fifo is empty
    input_cmd_fifo_1.size7_ena            = size7_fifo;           // Set to 0 for 3 words

// FIFO->pixel_writer internal command bus
logic        pixel_cmd_rdy  ;  // HIGH when data is in FIFO for pixel writer
logic [39:0] pixel_cmd_data ;  // internal command data bus
logic        exec_cmd       ;  // HIGH to pick up next command from FIFO
//
// collision saturation counters
logic [7:0]  wr_px_collision_counter ;
logic [7:0]  rd_px_collision_counter ;
//
// pixel_cmd breakouts
logic [7:0]  colour    ;  // colour data
logic [3:0]  pixel_cmd ;  // specifies action to perform
logic [3:0]  bpp       ;  // bits per pixel for the addressed word
logic [3:0]  target    ;  // the byte, nybble, crumb or bit we're trying to read/modify
//
// cache registers
logic        rc_valid      ;
logic [19:0] rc_addr       ;  // last RD address
logic [15:0] rcd           ;  // last RD data from RAM
logic [15:0] rd_pix_c_miss ;  // decoded pixel byte for write cache miss
logic [15:0] rd_pix_c_hit  ;  // decoded pixel byte for write cache hit
logic [7:0]  rc_colour     ;  // last RD colour data
logic [3:0]  rc_bpp        ;  // last RD bpp setting
logic [3:0]  rc_target     ;  // last RD target value
//
//
logic        wc_valid      ;
logic [19:0] wc_addr       ;  // last WR address
logic [15:0] wcd           ;  // last WR data from RAM
logic [15:0] wr_pix_c_miss ;  // decoded pixel byte for write cache miss
logic [15:0] wr_pix_c_hit  ;  // decoded pixel byte for write cache hit
logic [7:0]  wc_colour     ;  // last WR colour data
logic [3:0]  wc_bpp        ;  // last WR bpp setting
logic [3:0]  wc_target     ;  // last WR target value
//
// general logic
logic rd_addr_valid  ;  // HIGH when new address matches cached address
logic wr_addr_valid  ;  // HIGH when new address matches cached address
logic stop_fifo_read ;  // HIGH to stop drawing commands from FIFO
//
logic collision_rd_inc ;
logic collision_wr_inc ;
//
logic rd_wait_a      ;  // HIGH whilst waiting for a_channel RD op to complete
logic rd_wait_b      ;  // HIGH whilst waiting for b_channel RD op to complete
//
logic rd_cache_hit   ;
logic wr_cache_hit   ;
//
logic write_pixel    ; // high when any write pixel command takes place.
logic copy_pixel     ; // high when any write pixel command takes place.
logic wr_ena_ladr    ; // When writing a pixel, this selects whether to use the current command address or the latched write address.

always_comb begin

    // break the pixel_cmd_data down into clear sub-components:
    pixel_cmd[3:0] = pixel_cmd_data[39:36] ;  // command code
    colour[7:0]    = pixel_cmd_data[35:28] ;  // colour data
    bpp[3:0]       = pixel_cmd_data[27:24] ;  // bits per pixel (width)
    target[3:0]    = pixel_cmd_data[23:20] ;  // target bit (sub-word)
    
    ram_addr[19:0] = wr_ena_ladr ? wc_addr[19:0] : pixel_cmd_data[19:0] ;  // select the R/W address.

    write_pixel    = (pixel_cmd[3:0] == CMD_IN_PXWRI) || (pixel_cmd[3:0] == CMD_IN_PXWRI_M) || (pixel_cmd[3:0] == CMD_IN_PXPASTE) || (pixel_cmd[3:0] == CMD_IN_PXPASTE_M) ;
    copy_pixel     = (pixel_cmd[3:0] == CMD_IN_PXCOPY) ;
    
    // logic
    exec_cmd       = ( !(rd_wait_a || rd_wait_b) && pixel_cmd_rdy && !(!wr_cache_hit && wr_ena) ) ;
    rd_addr_valid  = ( pixel_cmd_data[19:0] == rc_addr ) ;
    wr_addr_valid  = ( pixel_cmd_data[19:0] == wc_addr ) ;
    rd_cache_hit   = rd_addr_valid && rc_valid ;
    wr_cache_hit   = wr_addr_valid && wc_valid ;
 
    rd_req_a       = exec_cmd && copy_pixel  && !rd_cache_hit && !reset ;
    rd_req_b       = exec_cmd && write_pixel && !wr_cache_hit && !reset ;

    wr_pix_c_miss  = rd_data_in & (16'hFFFF ^ (LUT_mask[wc_bpp] << LUT_shift[{wc_bpp,wc_target}])) | ( (wc_colour & LUT_mask[wc_bpp]) << LUT_shift[{wc_bpp,wc_target}] ) ; // Separate out the PX_COPY_COLOUR
    wr_pix_c_hit   = wcd        & (16'hFFFF ^ (LUT_mask[bpp   ] << LUT_shift[{bpp   ,target   }])) | ( (colour    & LUT_mask[bpp   ]) << LUT_shift[{bpp   ,target   }] ) ; // Separate out the PX_COPY_COLOUR

    rd_pix_c_miss  = ( rd_data_in >> LUT_shift[{rc_bpp,rc_target}]) & LUT_mask[rc_bpp] ; // Separate out the PX_COPY_COLOUR
    rd_pix_c_hit   = ( rcd        >> LUT_shift[{bpp   ,target   }]) & LUT_mask[bpp   ] ; // Separate out the PX_COPY_COLOUR

end

always_ff @( posedge clk ) begin

    if ( reset ) begin
    
        // reset the collision counters
        rd_px_collision_counter <= 8'b0 ;
        wr_px_collision_counter <= 8'b0 ;
        // reset the cache registers
        rc_addr     <= 20'b0 ;
        rc_colour   <= 8'b0  ;
        rc_bpp      <= 4'b0  ;
        rc_target   <= 4'b0  ;
        //
        wc_addr     <= 20'b0 ;
        wc_colour   <= 8'b0  ;
        wc_bpp      <= 4'b0  ;
        wc_target   <= 4'b0  ;
        //
        rc_valid    <= 1'b0  ;
        wc_valid    <= 1'b0  ;
        //
        rd_wait_a   <= 1'b0  ;
        rd_wait_b   <= 1'b0  ;
        //
        wr_ena_ladr <= 1'b0  ; // end write sequence.
        wr_ena      <= 1'b0  ; // end write sequence.
        
    end else begin // if reset

        if ( collision_rd_rst ) rd_px_collision_counter <= 8'b0 ;   // reset the COPY/READ PIXEL COLLISION counter
        if ( collision_wr_rst ) wr_px_collision_counter <= 8'b0 ;   // reset the WRITE PIXEL COLLISION counter

        if (rd_data_rdy_b) begin   // If a ram read was returned
        
             rd_wait_b    <= 1'b0          ; // Turn off the wait
             wc_valid     <= 1'b1          ; // Make the cache valid
             ram_wr_data  <= wr_pix_c_miss ; 
             wcd          <= wr_pix_c_miss ;
             wr_ena_ladr  <= 1'b1          ; // initiate a write using the latched address.
             wr_ena       <= 1'b1          ; // initiate a write using the latched address.

        end else if (!wr_cache_hit && exec_cmd && write_pixel ) begin  // If there is a read command with a cache miss,
        
             rd_wait_b    <= 1'b1          ; // hold everything while we wait for new data from RAM
             wc_addr      <= ram_addr      ; // cache new address
             wc_valid     <= 1'b0          ; // clear cache valid flag in case it wasn't already cleared 
             wc_colour    <= colour        ; // colour data
             wc_bpp       <= bpp           ; // bits per pixel (width)
             wc_target    <= target        ; // target bit (sub-word)
             wr_ena_ladr  <= 1'b0          ; // end write sequence.
             wr_ena       <= 1'b0          ; // end write sequence.

        end else if (exec_cmd && write_pixel && wr_cache_hit)  begin
        
             ram_wr_data  <= wr_pix_c_hit  ; 
             wcd          <= wr_pix_c_hit  ;

             wr_ena_ladr  <= 1'b1          ; // initiate a write using the immediate address.
             wr_ena       <= 1'b1          ; // initiate a write using the immediate address.
             
        end else begin
        
             wr_ena_ladr  <= 1'b0          ; // end write sequence.
             wr_ena       <= 1'b0          ; // end write sequence.
             
        end

        if (wr_ena && (wc_addr==rc_addr)) begin     // A written pixel has the same address as the read cache
        
             rcd            <= ram_wr_data ; // so, we should copy the new writen pixel data into the read cache

        end else if (rd_data_rdy_a) begin   // If a ram read request was returned
        
             rd_wait_a      <= 1'b0             ; // Turn off the wait
             rc_valid       <= 1'b1             ; // Make the cache valid
             rcd            <= rd_data_in[15:0] ; // store a copy of the returned read data.
             PX_COPY_COLOUR <= rd_pix_c_miss    ;

        end else if (!rd_cache_hit && exec_cmd && copy_pixel) begin  // If there is a read command with a cache miss,
        
             rc_addr        <= ram_addr ; // cache new address
             rd_wait_a      <= 1'b1     ; // hold everything while we wait for new data from RAM
             rc_valid       <= 1'b0     ; // clear cache valid flag in case it wasn't already cleared 
             rc_colour      <= colour   ; // colour data
             rc_bpp         <= bpp      ; // bits per pixel (width)
             rc_target      <= target   ; // target bit (sub-word)

        end else if (exec_cmd && copy_pixel && rd_cache_hit) begin
        
             PX_COPY_COLOUR     <= rd_pix_c_hit ;
             
        end

    end // else reset

end

endmodule
