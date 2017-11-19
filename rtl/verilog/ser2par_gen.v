/***********************************************************************
  $FILENAME    : ser2par_gen.v

  $TITLE       : Serial to parallel converter

  $DATE        : 15 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This module receives the serial bits from top module and
                 depending on the status of input enable puts bits together
                 to form the final parallel output.  

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


module ser2par_gen #(
  parameter width = 16
)
(
  input	        clk,       // Input system clock
  input         dbl_sclk,  // Double rate serial clock
  input         dbl_sclk_d,// One cycle delayed double rate serial clock
  input	        async_rst, // ASync input reset (low active)
  input	        sync_rst,  // Sync input reset (high active)
  input	        ser2par_en,// Enables conversion
  input	        ser_in,    // Serial data input
  output [15:0] par_out,   // Parallel data output
  output        valid      // Indicates the end of conversion process
);

  // ==============================================================================
  // I N T E R N A L   S I G N A L S

  reg [15:0] par_data = 16'h0000;
  reg [3:0]  bit_cntr = 4'b0000;
  reg        validout = 1'b0;


  // ==============================================================================
  // S E R I A L   T O   P A R A L L E L
  always @(posedge clk or negedge async_rst)
  begin
    if (!async_rst) begin
      par_data <= 16'h0000;
      bit_cntr <= 4'b0000;
      validout <= 1'b0;
    end else if (sync_rst) begin
      par_data <= 16'h0000;
      bit_cntr <= 4'b0000;
      validout <= 1'b0;
    end else begin
      // Go ahead on the falling edge of dbl_sclk
      if (dbl_sclk == 1'b0 && dbl_sclk_d == 1'b1) begin

        if(ser2par_en == 1'b1) begin

          par_data[15:1] <= par_data[14:0];
          par_data[0]    <= ser_in;

          if(bit_cntr == 4'b1111) begin
            bit_cntr <= 4'b0000;
            validout <= 1'b1;
          end else begin
            bit_cntr <= bit_cntr+1;
            validout <= 1'b0;
          end

        end
      end
    end
  end

  
  // ==============================================================================  
  assign valid   = validout;
  assign par_out = par_data;

endmodule
