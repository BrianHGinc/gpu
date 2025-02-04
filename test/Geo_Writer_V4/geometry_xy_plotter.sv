/*
 *      GEOFF MODULE
 *  (geometry_xy_plotter)
 *
 *       v 0.1.019
 *
 */

module geometry_xy_plotter (
    input wire clk,               // System clock
    input wire reset,             // Force reset
    input wire fifo_cmd_ready,    // 16-bit Data Command Ready signal
    input wire [15:0] fifo_cmd_in,// 16-bit Data Command bus
    input wire draw_busy,         // HIGH when pixel writer is busy, so geometry plotter will pause before sending any new pixels
    
    output wire load_cmd,         // HIGH when ready to receive next cmd_data[15:0] input
    output wire draw_cmd_rdy,     // Pulsed HIGH when data on draw_cmd[15:0] is ready to send to the pixel writer module
    output wire [35:0] draw_cmd,  // Bits [35:32] hold AUX function number 0-15:
    //  AUX=0  : Do nothing
    //  AUX=1  : Write pixel,                             : 31:24 color         : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=2  : Write pixel with color 0 mask,           : 31:24 color         : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=3  : Write from read pixel,                   : 31:24 ignored       : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=4  : Write from read pixel with color 0 mask, : 31:24 ignored       : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=6  : Read source pixel,                       : 31:24 ignored       : 23:12 Y coordinates : 11:0 X coordinates
    //  AUX=7  : Set Truecolor pixel color                : 31:24 8 bit alpha blend mix value : bits 23:0 hold RGB 24 bit color
    //                                                      Use function Aux3/4 to draw this color, only works if the destination is set to 16 bit true-color mode

    //  AUX=10 ; Resets the Write Pixel collision counter           : 31:24 sets transparent masked out color : bits 23:0 in true color mode, this holds RGB 24 bit mask color, in 8 bit mode, this allows for 3 additional transparent colors
    //  AUX=11 ; Resets the Write from read pixel collision counter : 31:24 sets transparent masked out color : bits 23:0 in true color mode, this holds RGB 24 bit mask color, in 8 bit mode, this allows for 3 additional transparent colors

    //  AUX=12 : Set destination raster width in bytes    : 15:0 holds destination raster image width in #bytes so the proper memory address can be calculated from the X&Y coordinates
    //  AUX=13 : Set source raster width in bytes,        : 15:0 holds source raster image width in #bytes so the proper memory address can be calculated from the X&Y coordinates
    //  AUX=14 : Set destination mem address,             : 31:24 bitplane mode : 23:0 hold destination base memory addres for write pixel
    //  AUX=15 : Set source mem address,                  : 31:24 bitplane mode : 23:0 hold the source base memory address for read source pixel
    output wire fifo_cmd_busy     // HIGH when FIFO is full/nearly full
);

parameter int FIFO_MARGIN         = 32 ; // The number of extra commands the fifo has room after the 'fifo_cmd_busy' goes high

logic [3:0] CMD_OUT_NOP           = 0  ;
logic [3:0] CMD_OUT_PXWRI         = 1  ;
logic [3:0] CMD_OUT_PXWRI_M       = 2  ;
logic [3:0] CMD_OUT_PXPASTE       = 3  ;
logic [3:0] CMD_OUT_PXPASTE_M     = 4  ;

logic [3:0] CMD_OUT_PXCOPY        = 6  ;
logic [3:0] CMD_OUT_SETARGB       = 7  ;

logic [3:0] CMD_OUT_RST_PXWRI_M   = 10 ;
logic [3:0] CMD_OUT_RST_PXPASTE_M = 11 ;
logic [3:0] CMD_OUT_DSTRWDTH      = 12 ;
logic [3:0] CMD_OUT_SRCRWDTH      = 13 ;
logic [3:0] CMD_OUT_DSTMADDR      = 14 ;
logic [3:0] CMD_OUT_SRCMADDR      = 15 ;

logic [7:0]  command_in     ;
logic [11:0] command_data12 ;
logic [7:0]  command_data8  ;

logic [11:0] x[3:0] ; // 2-dimensional 12-bit register for x0-x3
logic [11:0] y[3:0] ; // 2-dimensional 12-bit register for y0-y3
logic [11:0] max_x  ; // this reg will be both in this module and the memory pixel writer
logic [11:0] max_y  ; // this reg will be both in this module and the memory pixel writer

logic [3:0]  draw_cmd_func        ;
logic [7:0]  draw_cmd_data_color  ;
logic [11:0] draw_cmd_data_word_Y ;
logic [11:0] draw_cmd_data_word_X ;
logic        draw_cmd_tx = 1'b0   ;

//************************************************
// geometry sequencer controls
//************************************************
logic [3:0] geo_shape       ; // 0 through 7 will draw their assigned shape, 8 through 15 will have different copy algorithms
logic       geo_fill        ; // The geometric shape should be filled when set high
logic       geo_mask        ; // If high, when drawing, the colors set in the 'collision counter' will not be drawn.
logic       geo_paste       ; // If high, when drawing a geometric object, CMD_OUT_PXPASTE/_M will be used instead of CMD_OUT_PXWRI/_M for true color 16bit pixels
logic       geo_run = 1'b0  ; // High when a geometric shape is being drawn
logic [7:0] geo_color       ; // 8 bit pen drawing color

//************************************************
logic [15:0] cmd_data       ;
logic        fifo_cmd_rdy_n ;

scfifo  scfifo_component (
    .sclr        (reset),                                     // reset input
    .clock       (clk),                                       // system clock
    .wrreq       (fifo_cmd_ready),                            // connect this to the 'strobe' on the selected high.low Z80 bus output port
    .data        (fifo_cmd_in),                               // connect this to the 16 bit output port on the Z80 bus
    .almost_full (fifo_cmd_busy),                             // send to a selected bit on the Z80 status read port

    .empty       (fifo_cmd_rdy_n),                            // when LOW, the FIFO has commands for the geometry unit to process
    .rdreq       (load_cmd && !draw_busy && !fifo_cmd_rdy_n), // connect to the listed inputs
    .q           (cmd_data[15:0]),                            // to geometry_xy_plotter cmd_data input
    .full        ()                                           // optional, unused
);

defparam
    scfifo_component.add_ram_output_register = "ON",
    scfifo_component.almost_full_value       = (512 - FIFO_MARGIN),
    scfifo_component.intended_device_family  = "Cyclone IV",
    scfifo_component.lpm_hint                = "RAM_BLOCK_TYPE=M9K",
    scfifo_component.lpm_numwords            = 512,
    scfifo_component.lpm_showahead           = "ON",
    scfifo_component.lpm_type                = "scfifo",
    scfifo_component.lpm_width               = 16,
    scfifo_component.lpm_widthu              = 9,
    scfifo_component.overflow_checking       = "ON",
    scfifo_component.underflow_checking      = "ON",
    scfifo_component.use_eab                 = "ON";

logic line_gen_starter    ; // goes HIGH to start linegen#1
logic linegen_1_run       ; // HIGH to make linegen run
logic linegen_2_run       ; // HIGH to make linegen run
logic linegen_3_run       ; // HIGH to make linegen run
logic line_1_done         ; // HIGH when linegen is finished
logic line_2_done         ; // HIGH when linegen is finished
logic line_3_done         ; // HIGH when linegen is finished
logic pass_thru_1_a       ; // HIGH to pass-through aX/aY values to output
logic pass_thru_1_b       ; // HIGH to pass-through bX/bY values to output
logic pass_thru_2_a       ; // HIGH to pass-through aX/aY values to output
logic pass_thru_2_b       ; // HIGH to pass-through bX/bY values to output
logic pass_thru_3_a       ; // HIGH to pass-through aX/aY values to output
logic pass_thru_3_b       ; // HIGH to pass-through bX/bY values to output
logic y_stop_en_1         ;
logic y_stop_en_2         ;
logic y_stop_en_3         ;
logic y_stopped_1         ; // HIGH when linegen has Y-stopped
logic y_stopped_2         ; // HIGH when linegen has Y-stopped
logic y_stopped_3         ; // HIGH when linegen has Y-stopped
logic last_y_stopped_1    ; // value of y_stopped on last clock
logic last_y_stopped_2    ; // value of y_stopped on last clock
logic last_y_stopped_3    ; // value of y_stopped on last clock
logic line_1_dat_rdy      ; // HIGH when valid pixel data is ready
logic line_2_dat_rdy      ; // HIGH when valid pixel data is ready
logic line_3_dat_rdy      ; // HIGH when valid pixel data is ready
logic line_gen_1_running  ; // HIGH when linegen is running
logic line_gen_2_running  ; // HIGH when linegen is running
logic line_gen_3_running  ; // HIGH when linegen is running
logic [11:0] gen_1_x      ; // X-coordinate output
logic [11:0] gen_1_y      ; // Y-coordinate output
logic [11:0] gen_2_x      ; // X-coordinate output
logic [11:0] gen_2_y      ; // Y-coordinate output
logic [11:0] gen_3_x      ; // X-coordinate output
logic [11:0] gen_3_y      ; // Y-coordinate output
logic last_1_dat_rdy      ; // value of line_#_dat_rdy on last clock
logic last_2_dat_rdy      ; // value of line_#_dat_rdy on last clock
logic last_line_3_done    ; // value of line_#_dat_rdy on last clock
logic lineIndex_1         ;
logic lineIndex_2         ;
logic lineIndex_3         ;
logic [11:0] x_sort[3:0]  ;
logic [11:0] y_sort[3:0]  ;

logic [1:0] lgen_1ax      ; // starting coordinate selector for linegen_1
logic [1:0] lgen_2ax      ; // starting coordinate selector for linegen_2
logic [1:0] lgen_1bx      ; // ending coordinate selector for linegen_1
logic [1:0] lgen_2bx      ; // ending coordinate selector for linegen_2
logic [1:0] lgen_1ay      ; // starting coordinate selector for linegen_1
logic [1:0] lgen_2ay      ; // starting coordinate selector for linegen_2
logic [1:0] lgen_1by      ; // ending coordinate selector for linegen_1
logic [1:0] lgen_2by      ; // ending coordinate selector for linegen_2

logic [2:0] lg1_seq       ; // Sequence counter for geometric shapes with multiple lines
logic [2:0] lg2_seq       ; // Sequence counter for geometric shapes with multiple lines
logic [2:0] lg1_seq_end   ; // Sequence counter for geometric shapes with multiple lines
logic [2:0] lg2_seq_end   ; // Sequence counter for geometric shapes with multiple lines
logic [2:0] lg1_nseq      ; // Sequence counter for geometric shapes with multiple lines
logic [2:0] lg2_nseq      ; // Sequence counter for geometric shapes with multiple lines

// This lookup table specifies the number of sequence cycles each linegen needs to run before completing the final shape
logic [2:0] LUT_LG_CMD_SEQ_SIZE[0:31] = '{ // Linegen 1, Linegen 2 sequence size
    0,0,   // Shape  0 = NOTHING
    1,0,   // Shape  1 = Pixel
    1,0,   // Shape  2 = Line
    1,2,   // Shape  3 = Triangle
    4,0,   // Shape  4 = Box
    4,0,   // Shape  5 = Quadrilateral
    0,0,   // Shape  6 = Ellipse
    0,0,   // Shape  7 = Bezier Curve
    0,0,   // Shape f0 = NOTHING
    0,0,   // Shape f1 = Pixel
    0,0,   // Shape f2 = Line
    1,2,   // Shape f3 = Triangle Filled
    1,1,   // Shape f4 = Box Filled
    1,1,   // Shape f5 = Quadrilateral Filled
    0,0,   // Shape f6 = Ellipse Filled
    0,0    // Shape f7 = Bezier Curve Filled
};

// These are the lookup tables to select which X/Y source for A,B
// The order is stage 0A,0B, 1A,1B, 2A,2B, 3A,3B, 4A,4B, 5A,5B, 6A,6B, 7A,7B 
 logic [1:0] LUT_LG1_SEL_XY[0:511] = '{ 
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  0 = NOTHING
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  1 = Pixel
    0,0,1,1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  2 = Line
    0,0,2,2, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  3 = Triangle
    0,0,1,0, 1,0,1,1, 1,1,0,1, 0,1,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  4 = Box
    0,0,1,1, 1,1,2,2, 2,2,3,3, 3,3,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  5 = Quadrilateral
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  6 = Ellipse
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  7 = Bezier Curve
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f0 = NOTHING
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f1 = Pixel
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f2 = Line
    0,0,2,2, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f3 = Triangle Filled
    0,0,0,1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f4 = Box Filled
    0,0,3,3, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f5 = Quadrilateral Filled
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f6 = Ellipse Filled
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0    // Shape f7 = Bezier Curve Filled
 };
 logic [1:0] LUT_LG2_SEL_XY[0:511] = '{ 
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  0 = NOTHING
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  1 = Pixel
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  2 = Line
    0,0,1,1, 1,1,2,2, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  3 = Triangle
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  4 = Box
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  5 = Quadrilateral
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  6 = Ellipse
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape  7 = Bezier Curve
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f0 = NOTHING
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f1 = Pixel
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f2 = Line
    0,0,1,1, 1,1,2,2, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f3 = Triangle Filled
    1,0,1,1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f4 = Box Filled
    1,1,2,2, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f5 = Quadrilateral Filled
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,   // Shape f6 = Ellipse Filled
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0    // Shape f7 = Bezier Curve Filled
};

line_generator linegen_1 (
    // inputs
    .clk            ( clk                ), // 125 MHz pixel clock
    .reset          ( reset              ), // asynchronous reset
    .run            ( linegen_1_run      ), // HIGH during drawing
    .draw_busy      ( draw_busy          ), // draw_busy input from parent module
    .pass_thru_a    ( 1'b0               ), // set HIGH to pass through aX/aY coordinates
    .pass_thru_b    ( 1'b0               ), // set HIGH to pass through bX/bY coordinates
    .aX             ( x_sort[lgen_1ax]   ), // 12-bit X-coordinate for line start
    .aY             ( y_sort[lgen_1ay]   ), // 12-bit Y-coordinate for line start
    .bX             ( x_sort[lgen_1bx]   ), // 12-bit X-coordinate for line end
    .bY             ( y_sort[lgen_1by]   ), // 12-bit Y-coordinate for line end
    .ena_stop_y     ( y_stop_en_1        ), // set HIGH to make line generator stop at next Y increment
    .lineIndex      ( lineIndex_1        ), // start with ypos_stopped_int set
    // outputs
    .busy           ( line_gen_1_running ), // HIGH when line_generator is running
    .X_coord        ( gen_1_x            ), // 12-bit X-coordinate for current pixel
    .Y_coord        ( gen_1_y            ), // 12-bit Y-coordinate for current pixel
    .pixel_data_rdy ( line_1_dat_rdy     ), // HIGH when coordinate outputs are valid
    .ypos_stopped   ( y_stopped_1        ), // HIGH when stopped on Y-position
    .line_complete  ( line_1_done        )  // HIGH when line is completed
);

line_generator linegen_2 (
    // inputs
    .clk            ( clk                ), // 125 MHz pixel clock
    .reset          ( reset              ), // asynchronous reset
    .run            ( linegen_2_run      ), // HIGH during drawing
    .draw_busy      ( draw_busy          ), // draw_busy input from parent module
    .pass_thru_a    ( 1'b0               ), // set HIGH to pass through aX/aY coordinates
    .pass_thru_b    ( 1'b0               ), // set HIGH to pass through bX/bY coordinates
    .aX             ( x_sort[lgen_2ax]   ), // 12-bit X-coordinate for line start
    .aY             ( y_sort[lgen_2ay]   ), // 12-bit Y-coordinate for line start
    .bX             ( x_sort[lgen_2bx]   ), // 12-bit X-coordinate for line end
    .bY             ( y_sort[lgen_2by]   ), // 12-bit Y-coordinate for line end
    .ena_stop_y     ( y_stop_en_2        ), // set HIGH to make line generator stop at next Y increment
    .lineIndex      ( lineIndex_2        ), // start with ypos_stopped_int set
    // outputs
    .busy           ( line_gen_2_running ), // HIGH when line_generator is running
    .X_coord        ( gen_2_x            ), // 12-bit X-coordinate for current pixel
    .Y_coord        ( gen_2_y            ), // 12-bit Y-coordinate for current pixel
    .pixel_data_rdy ( line_2_dat_rdy     ), // HIGH when coordinate outputs are valid
    .ypos_stopped   ( y_stopped_2        ), // HIGH when stopped on Y-position
    .line_complete  ( line_2_done        )  // HIGH when line is completed
);

line_generator linegen_3 (
    // inputs
    .clk            ( clk                ), // 125 MHz pixel clock
    .reset          ( reset              ), // asynchronous reset
    .run            ( linegen_3_run      ), // HIGH during drawing
    .draw_busy      ( draw_busy          ), // draw_busy input from parent module
    .pass_thru_a    ( line_1_dat_rdy     ), // set HIGH to pass through aX/aY coordinates
    .pass_thru_b    ( line_2_dat_rdy     ), // set HIGH to pass through bX/bY coordinates
    .aX             ( gen_1_x            ), // 12-bit X-coordinate for line start
    .aY             ( gen_1_y            ), // 12-bit Y-coordinate for line start
    .bX             ( gen_2_x            ), // 12-bit X-coordinate for line end
    .bY             ( gen_2_y            ), // 12-bit Y-coordinate for line end
    .ena_stop_y     ( y_stop_en_3        ), // set HIGH to make line generator stop at next Y increment
    .lineIndex      ( lineIndex_3        ), // start with ypos_stopped_int not set
    // outputs
    .busy           ( line_gen_3_running ), // HIGH when line_generator is running
    .X_coord        ( gen_3_x            ), // 12-bit X-coordinate for current pixel
    .Y_coord        ( gen_3_y            ), // 12-bit Y-coordinate for current pixel
    .pixel_data_rdy ( line_3_dat_rdy     ), // HIGH when coordinate outputs are valid
    .ypos_stopped   ( y_stopped_3        ), // HIGH when stopped on Y-position
    .line_complete  ( line_3_done        )  // HIGH when line is completed
);

logic        new_cmd_rdy   ;
logic [15:0] cmd_data_pipe ; // cmd_data pipeline OUT from poly_sort into geo_xy_plotter

poly_sort sorter (
// inputs
    .clk           ( clk            ),
    .reset         ( reset          ),
    .enable        ( !draw_busy     ), // !pixel_writer busy input
    .cmd_rdy_in    ( fifo_cmd_rdy_n ),
    .cmd_pipe_in   ( cmd_data       ), // ** cmd_data pipeline input from FIFO
    .x_in          ( x              ), // values to sort
    .y_in          ( y              ), // values to sort
//outputs
    .cmd_rdy_out   ( new_cmd_rdy    ),
    .cmd_pipe_out  ( cmd_data_pipe  ), // ** cmd_data pipeline output
    .sorted_x      ( x_sort         ), // sorted value output
    .sorted_y      ( y_sort         ), // sorted value output
    .y_min         ( ),
    .y_max         ( ),
    .x_min         ( ),
    .x_max         ( ),
    .all_x_equal   ( ), // tells the linegens to skip a filled geometric shape and just draw 1 single line from y-min to y-max
    .all_y_equal   ( )  // tells the linegens to skip a filled geometric shape and just draw 1 single line from x-min to x-max
);

always_comb begin

    // Assign output port wires to internal registers
    draw_cmd[35:32]      = draw_cmd_func[3:0]         ;
    draw_cmd[31:24]      = draw_cmd_data_color[7:0]   ;
    draw_cmd[23:12]      = draw_cmd_data_word_Y[11:0] ;
    draw_cmd[11:0]       = draw_cmd_data_word_X[11:0] ;
    draw_cmd_rdy         = draw_cmd_tx && !draw_busy  ;

    // Break out cmd_data bus into logical words
    command_in     [7:0] = cmd_data_pipe[15:8]        ;
    command_data12[11:0] = cmd_data_pipe[11:0]        ;
    command_data8  [7:0] = cmd_data_pipe[7:0]         ;

    // Assign the load_cmd output - when the geometry unit is not drawing, the load_cmd goes high to load the next command
    load_cmd             = ~geo_run                   ;

    // If any of the linegens or blitter are working, geo_run needs to go immediately HIGH to stop loading new commands
    geo_run              = (lg1_seq!=lg1_seq_end) || (lg2_seq!=lg2_seq_end) || line_gen_3_running ;

    linegen_1_run        = line_gen_1_running  || (lg1_seq!=lg1_seq_end && !line_1_done)  ; // initiate linegen1 when linegen2 is not running
    linegen_2_run        = (line_gen_2_running || ( y_stopped_1 )) && !(line_2_done && (lg2_seq!=lg2_seq_end))       ; // initiate linegen2 after linegen1 has its first stop
    linegen_3_run        = (line_gen_3_running || ( y_stopped_2 )) && geo_fill ;         ; // not used at the moment

    lineIndex_1          = ( geo_shape[2:0] == 4 ) ; // set linegen initial y_stop delay according to shape type
    lineIndex_2          = ( geo_shape[2:0] == 4 ) ; // set linegen initial y_stop delay according to shape type
    lineIndex_3          = 0 ;
    
    // Starting and ending coordinate selection
    // Only release a stop once the opposite linegen goes from a non-y-stopped state to a y-stopped-state, or that linegen has completed a line
    if (geo_fill) y_stop_en_1  = !(line_3_done && !last_line_3_done) ; //( !(y_stopped_2 && !last_y_stopped_2) ) && (lg2_seq!=lg2_seq_end) || line_gen_3_running;
    else          y_stop_en_1  = ( !(y_stopped_2 && !last_y_stopped_2) ) && (lg2_seq!=lg2_seq_end) ;

    y_stop_en_2          = ( !(y_stopped_1 && !last_y_stopped_1) ) && (lg1_seq!=lg1_seq_end) ;
    y_stop_en_3          = 0 ;

    lg1_nseq             = lg1_seq + 1 ; // prepare an array with the next sequence number
    lg2_nseq             = lg2_seq + 1 ; // prepare an array with the next sequence number
    
end // always_comb

always_ff @(posedge clk or posedge reset) begin

    if (reset) begin    // reset to defaults
        
        // reset coordinate registers
        for ( integer i = 0; i < 4; i++ ) begin
            x[i] <= { 12'b0 } ;
            y[i] <= { 12'b0 } ;
        end
        
        max_x                <= 12'b0 ;
        max_y                <= 12'b0 ;
        
        // reset draw command registers
        draw_cmd_func        <= 4'b0  ;
        draw_cmd_data_color  <= 8'b0  ;
        draw_cmd_data_word_Y <= 12'b0 ;
        draw_cmd_data_word_X <= 12'b0 ;
        draw_cmd_tx          <= 1'b0  ;
        
        // reset geometry sequencer controls
        geo_shape            <= 4'b0  ;
        geo_fill             <= 1'b0  ;
        geo_mask             <= 1'b0  ;
        geo_paste            <= 1'b0  ;
        geo_color            <= 8'b0  ;
        
        line_gen_starter     <= 1'b0  ;

        lg1_seq     <=0  ; // Sequence counter for geometric shapes with multiple lines
        lg2_seq     <=0  ; // Sequence counter for geometric shapes with multiple lines
        lg1_seq_end <=0  ; // Sequence counter for geometric shapes with multiple lines
        lg2_seq_end <=0  ; // Sequence counter for geometric shapes with multiple lines
        
    end else if (!draw_busy) begin  // Everything must PAUSE if the incoming draw_busy signal from the pixel_writer is high
     
        // Keep the previous states of y_stopped_#
        last_y_stopped_1    <= y_stopped_1 ;
        last_y_stopped_2    <= y_stopped_2 ;
        last_y_stopped_3    <= y_stopped_3 ;
        last_line_3_done    <= line_3_done ;
        
        // Line generator running logic
        line_gen_starter    <= ( !new_cmd_rdy && !geo_run ) && ( command_in[7:5] == 3'd0 && command_in[3:0] != 4'd0 ) ; // for now, only the draw line command

//if (line_gen_starter) begin
                   // Depending on the selected draw command+fill bit, this sets the number of sequences to count down from for each linegen once each linegen finishes.
//                  lg1_seq <= LUT_LG_CMD_SEQ_SIZE[{command_in[3:0],1'b0}];
//                  lg2_seq <= LUT_LG_CMD_SEQ_SIZE[{command_in[3:0],1'b1}];
//          end else
        if ( geo_run ) begin // Decrement each line sequence counter once their line has completed.
            if (line_1_done && (lg1_seq!=lg1_seq_end)) begin 
                lg1_seq  <= lg1_nseq;
                lgen_1ax <= LUT_LG1_SEL_XY[{geo_shape[3:0],lg1_nseq,2'b00}] ;
                lgen_1ay <= LUT_LG1_SEL_XY[{geo_shape[3:0],lg1_nseq,2'b01}] ;
                lgen_1bx <= LUT_LG1_SEL_XY[{geo_shape[3:0],lg1_nseq,2'b10}] ;
                lgen_1by <= LUT_LG1_SEL_XY[{geo_shape[3:0],lg1_nseq,2'b11}] ;
            end
            if (line_2_done && (lg2_seq!=lg2_seq_end)) begin
                lg2_seq  <= lg2_nseq;
                lgen_2ax <= LUT_LG2_SEL_XY[{geo_shape[3:0],lg2_nseq,2'b00}] ;
                lgen_2ay <= LUT_LG2_SEL_XY[{geo_shape[3:0],lg2_nseq,2'b01}] ;
                lgen_2bx <= LUT_LG2_SEL_XY[{geo_shape[3:0],lg2_nseq,2'b10}] ;
                lgen_2by <= LUT_LG2_SEL_XY[{geo_shape[3:0],lg2_nseq,2'b11}] ;
            end
        end

                    
        // Pass through the pixel draw command and pixel_cmd_ready when the final line_gen or blitter has a ready pixel
        draw_cmd_func       <= CMD_OUT_PXWRI[3:0] ; // Set up command to pixel plotter to write a pixel,
        draw_cmd_data_color <= geo_color          ; // ... in geo_colour,

        if ( line_3_dat_rdy && ( gen_3_x >= 0 && gen_3_x <= max_x ) && ( gen_3_y >=0 && gen_3_y <= max_y ) ) begin
        
            // linegen#3 has valid pixel data ready
            draw_cmd_data_word_X <= gen_3_x ; // ... at X-coordinate
            draw_cmd_data_word_Y <= gen_3_y ; // ... and Y-coordinate
            draw_cmd_tx          <= 1'b1    ; // let PAGET know valid pixel data is incoming
            
        end
        else draw_cmd_tx <= 1'b0 ; // otherwise turn off draw command
     
        // This code interprets the incoming commands when the linegens and blitter are not generating pixels
        if ( !new_cmd_rdy && ~geo_run ) begin  // when the new_cmd_rdy input is LOW and the geometry unit geo_run is not running, execute the following command input
         
            casez (command_in)
             
                8'b10?????? : x[command_in[5:4]] <= command_data12 ;
                
                8'b11?????? : y[command_in[5:4]] <= command_data12 ;
                
                8'b011111?? : begin // set 24-bit destination screen memory pointer for plotting
                    draw_cmd_func        <= CMD_OUT_DSTMADDR[3:0]  ; // sets the output function
                    draw_cmd_data_color  <= command_data8          ; // set screen_mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[command_in[1:0]]     ; // sets the upper 12 bits of the destination address
                    draw_cmd_data_word_X <= x[command_in[1:0]]     ; // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1                   ; // transmits the command
                end
             
                8'b011110?? : begin // set 24-bit source screen memory pointer for blitter copy
                    draw_cmd_func        <= CMD_OUT_SRCMADDR[3:0]  ; // sets the output function
                    draw_cmd_data_color  <= command_data8          ; // set screen_mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[command_in[1:0]]     ; // sets the upper 12 bits of the destination address
                    draw_cmd_data_word_X <= x[command_in[1:0]]     ; // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1                   ; // transmits the command
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
                    draw_cmd_func        <= CMD_OUT_DSTRWDTH[3:0]  ; // sets the output function
                    draw_cmd_data_color  <= command_data8          ; // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[2]                   ; // null
                    draw_cmd_data_word_X <= x[2]                   ; // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1                   ; // transmits the command
                end
                
                8'd114 : begin  // set the number of bytes per horizontal line in the source raster
                    draw_cmd_func        <= CMD_OUT_SRCRWDTH[3:0]  ; // sets the output function
                    draw_cmd_data_color  <= command_data8          ; // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[2]                   ; // sets the lower 12 bits of the destination address
                    draw_cmd_data_word_X <= x[2]                   ; // null
                    draw_cmd_tx          <= 1'b1                   ; // transmits the command
                end
                    
                8'd113 : begin  // set the number of bytes per horizontal line in the destination raster
                    draw_cmd_func        <= CMD_OUT_DSTRWDTH[3:0]  ; // sets the output function
                    draw_cmd_data_color  <= command_data8          ; // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[3]                   ; // null
                    draw_cmd_data_word_X <= x[3]                   ; // sets the lower 12 bits of the destination address
                    draw_cmd_tx          <= 1'b1                   ; // transmits the command
                end
                    
                8'd112 : begin  // set the number of bytes per horizontal line in the source raster
                    draw_cmd_func        <= CMD_OUT_SRCRWDTH[3:0]  ; // sets the output function
                    draw_cmd_data_color  <= command_data8          ; // set bitplane mode (bits per pixel)
                    draw_cmd_data_word_Y <= y[3]                   ; // sets the lower 12 bits of the destination address
                    draw_cmd_data_word_X <= x[3]                   ; // null
                    draw_cmd_tx          <= 1'b1                   ; // transmits the command
                end

                8'd95  : begin
                    max_x <= x[0] ;    // set max width & height of screen to x0/y0
                    max_y <= y[0] ;
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                
                8'd94  : begin
                    max_x <= x[1] ;    // set max width & height of screen to x1/y1
                    max_y <= y[1] ;
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                
                8'd93  : begin
                    max_x <= x[2] ; // set max width & height of screen to x2/y2
                    max_y <= y[2] ;
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                
                8'd92 : begin
                    max_x <= x[3] ; // set max width & height of screen to x3/y3
                    max_y <= y[3] ;
                    //********************  no command to be set......draw_cmd_tx <= 1'b1;
                end
                        
                8'd91 : begin               // clear the pixel collision counter and sets all 3 transparent mask colors to 1 8-bit color in the source function data
                    draw_cmd_func        <= CMD_OUT_RST_PXWRI_M[3:0]                   ; // sets the output funtion
                    draw_cmd_data_color  <= command_data8                              ; // sets the mask color
                    draw_cmd_data_word_Y <= { command_data8[7:0], command_data8[7:4] } ; // sets mask color #2 and 1/2 or #3
                    draw_cmd_data_word_X <= { command_data8[3:0], command_data8[7:4] } ; // sets mask color 1/2 or #3 and #4
                    draw_cmd_tx          <= 1'b1                                       ; // transmits the command
                end
                
                8'd90 : begin               // clear the blitter copy pixel collision counter
                    draw_cmd_func        <= CMD_OUT_RST_PXPASTE_M[3:0]                 ; // sets the output funtion
                    draw_cmd_data_color  <= command_data8                              ; // sets the mask color
                    draw_cmd_data_word_Y <= { command_data8[7:0], command_data8[7:4] } ; // sets mask color #2 and 1/2 or #3
                    draw_cmd_data_word_X <= { command_data8[3:0], command_data8[7:4] } ; // sets mask color 1/2 or #3 and #4
                    draw_cmd_tx          <= 1'b1                                       ; // transmits the command
                end

                8'b000????? : begin // this range of commands all begin drawing a shape
                
                   // drawing commands begin here.  Keep the convention that:
                   // extend_cmd[3] = fill enable
                   // extend_cmd[4] = use the color in the copy/paste buffer.  This one is for drawing in true color mode.
                   // extend_cmd[5] = mask enable - when drawing, the mask colours will not be plotted as they are transparent
                    geo_shape[3]   <= 1'b0            ; // geo shapes 0 through 7, geo shapes 8 through 15 are for copy & paste.
                    geo_shape[2:0] <= command_in[2:0] ; // Set which one of shapes 0 through 7 should be drawn.  Shape 0 means nothing is being drawn
                    geo_fill       <= command_in[3]   ; // Fill enable bit
                    geo_paste      <= command_in[4]   ; // Used for drawing in true color 16 bit mode
                    geo_mask       <= 1'b0            ; // Mask disables when drawing raw geometry shapes
                    geo_color      <= command_data8   ; // set the 8-bit pen color

                    // Depending on the selected draw command+fill bit, this sets the number of sequences to count down from for each linegen once each linegen finishes.
                    lg1_seq_end    <= LUT_LG_CMD_SEQ_SIZE[ { command_in[3:0], 1'b0 } ] ;
                    lg2_seq_end    <= LUT_LG_CMD_SEQ_SIZE[ { command_in[3:0], 1'b1 } ] ;
                    lg1_seq        <= 0 ;
                    lg2_seq        <= 0 ;

                    lgen_1ax       <= LUT_LG1_SEL_XY[ { command_in[3:0], 5'b00000 } ]  ;
                    lgen_1ay       <= LUT_LG1_SEL_XY[ { command_in[3:0], 5'b00001 } ]  ;
                    lgen_1bx       <= LUT_LG1_SEL_XY[ { command_in[3:0], 5'b00010 } ]  ;
                    lgen_1by       <= LUT_LG1_SEL_XY[ { command_in[3:0], 5'b00011 } ]  ;
                    lgen_2ax       <= LUT_LG2_SEL_XY[ { command_in[3:0], 5'b00000 } ]  ;
                    lgen_2ay       <= LUT_LG2_SEL_XY[ { command_in[3:0], 5'b00001 } ]  ;
                    lgen_2bx       <= LUT_LG2_SEL_XY[ { command_in[3:0], 5'b00010 } ]  ;
                    lgen_2by       <= LUT_LG2_SEL_XY[ { command_in[3:0], 5'b00011 } ]  ;
                    
                 end

                default : begin
                
                    geo_shape   <= 4'b0 ; // turn off the drawing shape
                    
                end

            endcase
            
        end 
    
    end // !draw_busy

end //always @(posedge clk)

endmodule

/*
 * poly_sort module
 *
 * Outputs two arrays (X[1:0] and Y[1:0]) of four 12-bit
 * values sorted in ascending Y-position.
 */
module poly_sort (
// inputs
    input                clk            ,
    input                reset          ,
    input                enable         , // !pixel_writer busy input
    input                cmd_rdy_in     ,
    input         [15:0] cmd_pipe_in    ,
    input  signed [11:0] x_in [0:3]     , // values to sort
    input  signed [11:0] y_in [0:3]     , // values to sort
//outputs
    output               cmd_rdy_out    ,
    output        [15:0] cmd_pipe_out   ,
    output signed [11:0] sorted_x [0:3] , // sorted value output
    output signed [11:0] sorted_y [0:3] , // sorted value output
    output signed [11:0] y_min          ,
    output signed [11:0] y_max          ,
    output signed [11:0] x_min          ,
    output signed [11:0] x_max          ,
    output               all_x_equal    , // tells the linegens to skip a filled geometric shape and just draw 1 single line from y-min to y-max
    output               all_y_equal      // tells the linegens to skip a filled geometric shape and just draw 1 single line from x-min to x-max
);

logic        cmd_rdy_mid         ;
logic [15:0] cmd_pipe_mid        ;
logic signed [11:0] x_pipe [0:3] ;
logic signed [11:0] y_pipe [0:3] ;

always_ff @(posedge clk) begin

    if ( reset ) begin

        cmd_rdy_mid  <=  1'b0 ;
        cmd_pipe_mid <= 16'b0 ;
        cmd_rdy_out  <=  1'b0 ;
        cmd_pipe_out <= 16'b0 ;

    end // reset
    else
    if ( enable ) begin

        // cmd_pipe must be passed through
        cmd_rdy_mid  <= cmd_rdy_in   ;
        cmd_pipe_mid <= cmd_pipe_in  ;
        cmd_rdy_out  <= cmd_rdy_mid  ;
        cmd_pipe_out <= cmd_pipe_mid ;

        if ( cmd_pipe_in[10:8] != 3 && cmd_pipe_in[11:8] != 13 ) begin // if not triangle (filled or not), or filled quad - bypass

            for ( int i=0; i<=3 ; i++ ) begin
            
                sorted_x[i] <= x_in[i] ;
                sorted_y[i] <= y_in[i] ;
                
            end
            
        end // bypass
        else if ( cmd_rdy_in ) begin //if ( ~cmd_pipe_in[10] ) begin // triangle sorting - shape to be drawn is not a quad

            // pass-through x_in[3] & y_in[3] as we're only sorting the first 3 values (initially)
            x_pipe[3] <= x_in[3] ;
            y_pipe[3] <= y_in[3] ;

            if ( ( y_in[0] >=  y_in[1] ) && ( y_in[1] >= y_in[2] ) ) begin
            
                x_pipe[0] <= x_in[2] ;
                y_pipe[0] <= y_in[2] ;
                x_pipe[1] <= x_in[1] ;
                y_pipe[1] <= y_in[1] ;
                x_pipe[2] <= x_in[0] ;
                y_pipe[2] <= y_in[0] ;
                
            end else
            if ( ( y_in[1] >=  y_in[2] ) && ( y_in[2] >= y_in[0] ) ) begin
            
                x_pipe[0] <= x_in[0] ;
                y_pipe[0] <= y_in[0] ;
                x_pipe[1] <= x_in[2] ;
                y_pipe[1] <= y_in[2] ;
                x_pipe[2] <= x_in[1] ;
                y_pipe[2] <= y_in[1] ;
                
            end else
            if ( ( y_in[2] >=  y_in[0] ) && ( y_in[0] >= y_in[1] ) ) begin
            
                x_pipe[0] <= x_in[1] ;
                y_pipe[0] <= y_in[1] ;
                x_pipe[1] <= x_in[0] ;
                y_pipe[1] <= y_in[0] ;
                x_pipe[2] <= x_in[2] ;
                y_pipe[2] <= y_in[2] ;
                
            end else
            if ( ( y_in[0] >=  y_in[2] ) && ( y_in[2] >= y_in[1] ) ) begin
            
                x_pipe[0] <= x_in[1] ;
                y_pipe[0] <= y_in[1] ;
                x_pipe[1] <= x_in[2] ;
                y_pipe[1] <= y_in[2] ;
                x_pipe[2] <= x_in[0] ;
                y_pipe[2] <= y_in[0] ;
                
            end else
            if ( ( y_in[2] >=  y_in[1] ) && ( y_in[1] >= y_in[0] ) ) begin
            
                x_pipe[0] <= x_in[0] ;
                y_pipe[0] <= y_in[0] ;
                x_pipe[1] <= x_in[1] ;
                y_pipe[1] <= y_in[1] ;
                x_pipe[2] <= x_in[2] ;
                y_pipe[2] <= y_in[2] ;
                
            end else
            if ( ( y_in[1] >=  y_in[0] ) && ( y_in[0] >= y_in[2] ) ) begin
            
                x_pipe[0] <= x_in[2] ;
                y_pipe[0] <= y_in[2] ;
                x_pipe[1] <= x_in[0] ;
                y_pipe[1] <= y_in[0] ;
                x_pipe[2] <= x_in[1] ;
                y_pipe[2] <= y_in[1] ;
                
            end
            
        end
        else if ( cmd_rdy_mid ) begin
        
            if ( cmd_pipe_mid[10] ) begin // quad sorting
            
                if ( y_pipe[2] >= y_pipe[3] ) begin
            
                    sorted_x[0] <= x_pipe[0] ;
                    sorted_y[0] <= y_pipe[0] ;
                    sorted_x[1] <= x_pipe[0] ;
                    sorted_y[1] <= y_pipe[0] ;
                    
                    sorted_x[2] <= x_pipe[3] ;
                    sorted_y[2] <= y_pipe[3] ;
                    sorted_x[3] <= x_pipe[2] ;
                    sorted_y[3] <= y_pipe[2] ;
            
                end else
                if ( y_pipe[0] >= y_pipe[3] ) begin
                    
                    sorted_x[1] <= x_pipe[1] ;
                    sorted_y[1] <= y_pipe[1] ;
                    sorted_x[2] <= x_pipe[2] ;
                    sorted_y[2] <= y_pipe[2] ;
                    
                    sorted_x[0] <= x_pipe[3] ;
                    sorted_y[0] <= y_pipe[3] ;
                    sorted_x[3] <= x_pipe[0] ;
                    sorted_y[3] <= y_pipe[0] ;
            
                end
                
            end // quad sort
            else begin
        
                // triangle sort needs to output its values
                sorted_x[0] <= x_pipe[0] ;
                sorted_y[0] <= y_pipe[0] ;
                sorted_x[1] <= x_pipe[1] ;
                sorted_y[1] <= y_pipe[1] ;
                sorted_x[2] <= x_pipe[2] ;
                sorted_y[2] <= y_pipe[2] ;
                sorted_x[3] <= x_pipe[3] ;
                sorted_y[3] <= y_pipe[3] ;
        
            end
            
        end // quad sorting
        
    end // enable

end // always_ff

endmodule
