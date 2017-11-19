/***********************************************************************
  $FILENAME    : top.svh

  $TITLE       : Top hierarchy module

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This module defines the top hierarchy module of the system.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


module top;
  import twire_pkg::*;


  // =================================================================
  // I N S T A T I A T E   D U T
  TWireSerIntrfc #(
    I2CCLK,
    SYSCLK
  ) 
  DUT
  (
    .clk(bfm.clk),
    .async_rst(bfm.async_rst),
    .sync_rst(bfm.sync_rst),
    .rw(bfm.rw),
    .valid_in(bfm.valid_in),
    .reg_addr(bfm.reg_addr),
    .data_in(bfm.data_in),
    .valid_out(bfm.valid_out),
    .data_out(bfm.data_out),
    .busy(bfm.busy),
    .error(bfm.error),
    .SDA_I(bfm.SDA_I),
    .SDA_O(bfm.SDA_O),
    .SDA_T(bfm.SDA_T),
    .SCL(bfm.SCL)
  );


  // =================================================================
  // I N S T A T I A T E   B F M
  twire_bfm bfm();


  // =================================================================
  // I N S T A T I A T E   T E S T B E N C H
  tb testbench_h;

  
  // =================================================================
  // M A I N   P R O C E S S
  initial begin
    testbench_h = new(bfm);
    testbench_h.execute();
  end


  // =================================================================
  // D U M P   N E T S   A N D   R E G I S T E R S   I N T O   F I L E
  initial begin
    $dumpfile("twire.vcd");
    $dumpvars();
  end

endmodule : top
