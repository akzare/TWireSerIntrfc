/***********************************************************************
  $FILENAME    : driver.svh

  $TITLE       : Driver class implementation

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : The driver class provides all the necessary methods
                 to transmit, receive, and monitor data to/from DUT.
                 This module defines the high level tester module
                 which schedules the entire test scenario.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class driver extends uvm_driver #(sequence_item);
  `uvm_component_utils(driver)


  // =================================================================
  // B F M   I N S T A N C E
  virtual twire_bfm bfm;


  // =================================================================
  // C O N S T R U C T O R
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   build_phase   M E T H O D
  // The testbench component hierarchy is constructed by this method.
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db #(virtual twire_bfm)::get(null, "*", "bfm", bfm))
      `uvm_fatal("DRIVER", "driver::Failed to get BFM")
  endfunction : build_phase


  // =================================================================
  // O V E R R I D E S   U V M   run_phase   M E T H O D
  // This method runs in parallel across all the processes.
  // It is used for the stimulus generation and checking activities of the Testbench.
  task run_phase(uvm_phase phase);

    sequence_item rDwR;

    // ================================================
    // R E S E T   D U T
    bfm.reset_DUT();

    // ================================================
    // L U N C H   R E A D / W R I T E   T R A N S A C T I O N S
    forever begin : cmd_loop
      seq_item_port.get_next_item(rDwR);
      if (rDwR.stim_op == wr_op) begin
        bfm.wrTrans(rDwR.stim_reg_addr, rDwR.stim_data_in);
        $display("%dns : driver::wrTrans  stim_reg_addr %4h  stim_data_in %4h", $time, rDwR.stim_reg_addr, rDwR.stim_data_in);
      end else begin
        bfm.rdTrans(rDwR.stim_reg_addr, rDwR.stim_data_out);
        $display("%dns : driver::rdTrans  stim_reg_addr %4h  stim_data_out %4h", $time, rDwR.stim_reg_addr, rDwR.stim_data_out);
      end
      seq_item_port.item_done();
    end : cmd_loop

  endtask : run_phase


endclass : driver

