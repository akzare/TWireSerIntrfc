/***********************************************************************
  $FILENAME    : stimuli_monitor.svh

  $TITLE       : DUT input data flow monitor

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This class monitors the input data flow into DUT and 
                 transmits its acquired data towards scoreboard and 
                 coverage modules.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class stimuli_monitor extends uvm_component;
  `uvm_component_utils(stimuli_monitor);

  // Bus Functional Model interface
  virtual twire_bfm bfm;
  // Broadcasts the monitored write data to FIFO value to corresponding 
  // subscribers (scoreboard and coverage).
  uvm_analysis_port #(sequence_item) ap;


  //
  // Class constructor method
  //
  function new (string name, uvm_component parent);
    super.new(name,parent);
  endfunction


  //
  // Overrides UVM build_phase method
  // This method is called top-down by the UVM "root".
  // The build_phase is where the Testbench is constructed, 
  // connected and configured.
  //
  function void build_phase(uvm_phase phase);

    if(!uvm_config_db #(virtual twire_bfm)::get(null, "*", "bfm", bfm))
      `uvm_fatal("DRIVER", "stimuli_monitor::Failed to get BFM")

    ap  = new("ap",this);
  endfunction : build_phase


  //
  // Overrides UVM connect_phase method
  // The connect phase is used to make TLM connections between 
  // components or to assign handles to testbench resources.
  //
  function void connect_phase(uvm_phase phase);
    bfm.stimuli_monitor_h = this;
  endfunction : connect_phase


  //
  // Transmits DUT's wdata to coverage and scoreboard
  //
  function void write_to_monitor(operation_t op, bit [15:0] reg_addr, bit [15:0] data);

    // push sequence into FIFO
    sequence_item rDwR;
    rDwR = new("rDwR");
    if (op == wr_op) begin
      `uvm_info ("INPUT FLOW MONITOR", $sformatf("stimuli_monitor::MONITOR: WR  reg_addr: %4h  data_in: %4h",
                reg_addr, data), UVM_HIGH);
      rDwR.stim_op       = op;
      rDwR.stim_reg_addr = reg_addr;
      rDwR.stim_data_in  = data;
    end else begin
      `uvm_info ("INPUT FLOW MONITOR", $sformatf("stimuli_monitor::MONITOR: RD  reg_addr: %4h  data_out: %4h",
                reg_addr, data), UVM_HIGH);
      rDwR.stim_op       = op;
      rDwR.stim_reg_addr = reg_addr;
      rDwR.stim_data_out = data;
    end
    ap.write(rDwR);
  endfunction : write_to_monitor


endclass : stimuli_monitor

