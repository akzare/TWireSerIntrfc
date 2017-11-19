/***********************************************************************
  $FILENAME    : sclk_gen.v

  $TITLE       : Serial clock generator

  $DATE        : 15 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : Generates serial clock for data transmission on two wires

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module sclk_gen #(
  parameter I2CCLK = 100, // Desired output serial clock rate (kHz)
  parameter SYSCLK = 100  // Input system clock rate (MHz)
)
(
  input	 clk,         // Input system clock
  input	 async_rst,   // ASync input reset (low active)
  input	 sync_rst,    // Sync input reset (high active)
  input	 sclk_en,     // Serial clock generator enable
  input	 sclk_sync,   // Sync tick=tock at the beginning of each new transaction
  output dbl_sclk,    // Double rate serial clock output 
  output dbl_sclk_d,  // One cycle delayed double rate serial clock output
  output sclk,        // Serial clock output
  output ticktock     // Generates a pulse when tick==tock
);


  // ==============================================================================
  // I N T E R N A L   C O N S T A N T S

  // Pre-scale constant for calculation of the required timing parameters in order to
  // generate the desired serial clock rate.
  parameter PRESCALE = (((SYSCLK*1000000)/(5*I2CCLK*1000))-1);


  // state machine
  // states
  parameter [1:0]
    STATE_CLK_HIGH = 2'b01,
    STATE_CLK_LOW  = 2'b10;


  // ==============================================================================
  // I N T E R N A L   S I G N A L S

  wire [15:0] prescaleval = PRESCALE[15:0]; // Pre-scale signal to generate double 
                                            // rate serial clock
  reg  [15:0] tick = 16'h0001;     // Tick counter to generate double serial clock rate 
  reg  [15:0] tock = 16'h0001;     // Tock counter to generate double serial clock rate 


  reg [1:0]   sclk_state = STATE_CLK_HIGH; // FSM state register

  reg         sclk_i = 1'b0;       // Internal generated serial clock signal
  reg         sclk_en_i = 1'b0;    // Internal sync enable signal
  reg         dbl_sclk_i = 1'b1;   // Internal double rate serial clock output 
  reg         dbl_sclk_d_i = 1'b1; // Internal one cycle delayed double rate serial clock output
  reg         ticktock_i = 1'b0;   // Generates a pulse when tick==tock

  
  // ==============================================================================
  // D O U B L E   R A T E   S E R I A L   C L O C K   G E N E R A T O R
  always @(posedge clk or negedge async_rst)
  begin : DSCLK_GEN
  	if (!async_rst) begin
  		tick       <= 16'h0001;
  		tock       <= 16'h0001;
  		ticktock_i <= 1'b0;
  		dbl_sclk_i   <= 1'b1;
  		dbl_sclk_d_i <= 1'b1;
  	end else if (sync_rst) begin
  		tick       <= 16'h0001;
  		tock       <= 16'h0001;
  		ticktock_i <= 1'b0;
  		dbl_sclk_i   <= 1'b1;
  		dbl_sclk_d_i <= 1'b1;
  	end else begin
  		// double serial clock generator
  		if (tick == prescaleval) begin
  			tick <= 16'h0001;
  			dbl_sclk_i <= ~dbl_sclk_i;
  		end else if (tick == (prescaleval/2)) begin
  			tick <= tick+1;
  			dbl_sclk_i <= ~dbl_sclk_i;
  		end else begin
  			tick <= tick+1;
  			dbl_sclk_i <= dbl_sclk_i;		
  		end
  		
  		// One cycle delayed clock
  		dbl_sclk_d_i <= dbl_sclk_i;
  		
  		// ticktock pulse generator 
  		ticktock_i <= 1'b0;
        if (tick == tock) begin
  	      ticktock_i <= 1'b1;
        end
        
        if (sclk_sync == 1'b1) begin
          tock = tick;
        end
  		
  	end
  end


  // ==============================================================================
  // S E R I A L   C L O C K   G E N E R A T O R
  always @(posedge clk or negedge async_rst)
  begin : SCLK_GEN
    if (!async_rst) begin
      sclk_state <= STATE_CLK_HIGH;
      sclk_en_i  <= 1'b0;
      sclk_i     <= 1'b0;
    end else if (sync_rst) begin
      sclk_state <= STATE_CLK_HIGH;
      sclk_en_i  <= 1'b0;
      sclk_i     <= 1'b0;
    end else begin
      // Go ahead on the rising edge of dbl_sclk
      if (dbl_sclk_i == 1'b1 && dbl_sclk_d_i == 1'b0) begin

        sclk_en_i <= sclk_en;

        case (sclk_state)

          STATE_CLK_HIGH :
          begin
            if (sclk_en_i == 1'b1) begin
              sclk_state <= STATE_CLK_LOW;
              sclk_i     <= 1'b0;
            end else begin
              sclk_state <= STATE_CLK_HIGH;
              sclk_i     <= 1'b1;
            end
          end

          STATE_CLK_LOW :
          begin
            sclk_state <= STATE_CLK_HIGH;
            sclk_i     <= 1'b1;
          end

          default :
          begin
            sclk_state <= STATE_CLK_HIGH;
          end
        endcase
      end
    end
  end

  
  // ==============================================================================
  assign sclk       = sclk_i;
  assign dbl_sclk   = dbl_sclk_i;
  assign dbl_sclk_d = dbl_sclk_d_i;
  assign ticktock   = ticktock_i;

endmodule
