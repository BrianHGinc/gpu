module geometry_xy_plotter (
    input wire clk,              // System clock
    input wire reset,            // Force reset
    input wire fifo_cmd_ready,   // 16-bit Data Command Ready signal
    input wire [15:0] fifo_cmd_in,// 16-bit Data Command bus
    input wire draw_busy,        // HIGH when pixel writer is busy, so geometry plotter will pause before sending any new pixels
    
    output wire load_cmd,        // HIGH when ready to receive next cmd_data[15:0] input
    output wire draw_cmd_rdy,    // Pulsed HIGH when data on draw_cmd[15:0] is ready to send to the pixel writer module
    output wire [35:0] draw_cmd, // Bits [35:32] hold AUX function number 0-15:
    output wire fifo_cmd_busy    // HIGH when FIFO is full/nearly full
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
/*
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
*/

logic [3:0] CMD_OUT_NOP           = 0;
logic [3:0] CMD_OUT_PXWRI         = 1;
logic [3:0] CMD_OUT_PXWRI_M       = 2;
logic [3:0] CMD_OUT_PXPASTE       = 3;
logic [3:0] CMD_OUT_PXPASTE_M     = 4;

logic [3:0] CMD_OUT_PXCOPY        = 6;
logic [3:0] CMD_OUT_SETARGB       = 7;

logic [3:0] CMD_OUT_RST_PXWRI_M   = 10;
logic [3:0] CMD_OUT_RST_PXPASTE_M = 11;
logic [3:0] CMD_OUT_DSTRWDTH      = 12;
logic [3:0] CMD_OUT_SRCRWDTH      = 13;
logic [3:0] CMD_OUT_DSTMADDR      = 14;
logic [3:0] CMD_OUT_SRCMADDR      = 15;

wire [7:0]  command_in;
wire [11:0] command_data12;
wire [7:0]  command_data8;

assign command_in     [7:0] = cmd_data[15:8];
assign command_data12[11:0] = cmd_data[11:0];
assign command_data8  [7:0] = cmd_data[7:0];

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
// Assign output port wires to internal registers
//************************************************
assign draw_cmd[35:32] = draw_cmd_func[3:0];
assign draw_cmd[31:24] = draw_cmd_data_color[7:0];
assign draw_cmd[23:12] = draw_cmd_data_word_Y[11:0];
assign draw_cmd[11:0]  = draw_cmd_data_word_X[11:0];
assign draw_cmd_rdy    = draw_cmd_tx;

//************************************************
// geometry sequencer controls
//************************************************
reg [3:0]    geo_shape;            // 0 through 7 will draw their assigned shape, 8 through 15 will have different copy algorithms
reg          geo_fill;             // The geometric shape should be filled when set high
reg          geo_mask;             // If high, when drawing, the colors set in the 'collision counter' will not be drawn.
reg          geo_paste;            // If high, when drawing a geometric object, CMD_OUT_PXPASTE/_M will be used instead of CMD_OUT_PXWRI/_M for true color 16bit pixels
reg          geo_run   = 1'b0;     // High when a geometric shape is being drawn
reg [7:0]    geo_color;            // 8 bit pen drawing color
assign       load_cmd = ~geo_run;  // assigns the load_cmd output.  When the geometry unit is not drawing, the load_cmd goes high to load the next command.

//************************************************
// geometry counters
//************************************************
reg signed [11:0]   geo_x;
reg signed [11:0]   geo_y;
reg signed [11:0]   geo_xdir;
reg signed [11:0]   geo_ydir;
reg        [3:0]    geo_sub_func1; // auxiliary sequence counter
reg        [3:0]    geo_sub_func2; // auxiliary sequence counter
reg signed [11:0]   dx;
reg signed [11:0]   dy;
reg signed [11:0]   errd;

logic [15:0] cmd_data;
logic        fifo_cmd_rdy_n;
scfifo  scfifo_component (
    .sclr        (reset),                    // reset input
    .clock       (clk),                    // system clock
    .wrreq       (fifo_cmd_ready),           // connect this to the 'strobe' on the selected high.low Z80 bus output port.
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
