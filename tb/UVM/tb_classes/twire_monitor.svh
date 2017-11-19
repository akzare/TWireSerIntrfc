/***********************************************************************
  $FILENAME    : twire_monitor.svh

  $TITLE       : FIFO output data flow monitor

  $DATE        : 12 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This class monitors the output data flow out of FIFO and 
                 transmits its acquired data towards scoreboard module.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class twire_monitor extends uvm_component;
  `uvm_component_utils(twire_monitor);

  // Bus Functional Model interface
  virtual twire_bfm bfm;
  // Broadcasts the monitored read data from FIFO value to corresponding 
  // subscribers (scoreboard).
  uvm_analysis_port #(twire_transaction) ap;


  //
  // Class constructor method
  //
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new


  //
  // Overrides UVM build_phase method
  // This method is called top-down by the UVM "root".
  // The build_phase is where the Testbench is constructed, 
  // connected and configured.
  //
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db #(virtual twire_bfm)::get(null, "*","bfm", bfm))
      `uvm_fatal("DRIVER", "twire_monitor::Failed to get BFM");
    ap  = new("ap", this);
  endfunction : build_phase


  //
  // Overrides UVM connect_phase method
  //
  function void connect_phase(uvm_phase phase);
    bfm.twire_monitor_h = this;
  endfunction : connect_phase


  //
  // Transmits FIFO's rdata to scoreboard
  //
  function void write_to_monitor(operation_t cap_opr, bit [7:0] cap_SLAVE_WR_ADDR, bit [7:0] cap_SLAVE_RD_ADDR, bit [15:0] cap_reg_addr, bit [15:0] cap_data_in, bit [15:0] rep_data_out);

    twire_transaction twire_t;
    twire_t = new("twire_t");
    twire_t.cap_opr           = cap_opr;
    twire_t.cap_SLAVE_WR_ADDR = cap_SLAVE_WR_ADDR;
    twire_t.cap_SLAVE_RD_ADDR = cap_SLAVE_RD_ADDR;
    twire_t.cap_reg_addr      = cap_reg_addr;
    twire_t.cap_data_in       = cap_data_in;
    twire_t.rep_data_out      = rep_data_out;
    ap.write(twire_t);
  endfunction : write_to_monitor


endclass : twire_monitor

