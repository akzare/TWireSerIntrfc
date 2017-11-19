/***********************************************************************
  $FILENAME    : twire_bfm.svh

  $TITLE       : Bus Functional Model (BFM) interface definition

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This module defines DUT's BFM interface which includes 
                 the Master Two-Wire Serial Register Interface (DUT).

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


interface twire_bfm;
  import twire_pkg::*;

  // =================================================================
  // D U T   I N T E R C A E

  bit          clk;       // Input system clock
  bit          async_rst; // ASync input reset (low active)
  bit          sync_rst;  // Sync input reset (high active)
  bit          rw;        // Determines the type of desired operation: read/write -> 1/0
  bit          valid_in;  // Indicates the validity of reg_addr and data_in signal. Assertion of
                          // a rising edge pulse on this signal forces the master controller
                          // to start a new transaction.
  logic [15:0] reg_addr;  // The target register address.
  logic [15:0] data_in;   // Input data which must be written into the specified register.
  wire         valid_out; // A rising edge on this signal indicates the validity of
                          // the read data on data_out.
  wire  [15:0] data_out;  // The output of read transaction on the specified register
  wire         busy;      // Indicates master FSM is in current progress 
                          // to accomplish the recent read/write transaction
  wire         error;     // Presents an error condition during read/write transactions

  // Sensor interface
  // Data is transferred between the master and the slave on a bidirectional signal (SDATA).  
  bit          SDA_I;     // Data direction from sensor to master
  wire         SDA_O;     // Data direction from master to sensor
  wire         SDA_T;     // Tri-state buffer control
  wire         SCL;       // The master generates a clock (SCLK) that is an input


  // =================================================================
  // C L O C K   G E N E R A T O R
  initial begin
    clk = 1'b0;

    fork
      forever #10ns clk = ~clk; // System clock
    join
  end


  // =================================================================
  // R E S E T   T H E   D U T   I N T E R F A C E
  task reset_DUT();
  begin
    $write("%dns : bfm::Asserting reset on Two-Wire Serial Register Interface module.\n", $time);

    rw        = 1'b0;
    valid_in  = 1'b0;
    reg_addr  = 16'h0000;
    data_in   = 16'h0000;
    SDA_I     = 1'b0;
    
    repeat(1) @(posedge clk);
    async_rst = 1'b0;
    repeat(20) @(posedge clk);
    #2
    async_rst = 1'b1;
    repeat(35) @(posedge clk);
    
    $write("%dns : bfm::Done asserting reset on Two-Wire Serial Register Interface module.\n", $time);
  end
  endtask : reset_DUT


endinterface : twire_bfm
