/***********************************************************************
  $FILENAME    : scoreboard.svh

  $TITLE       : Scoreboard class implementation

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : The scoreboard class provides all the necessary methods
                 to compare actual results from the DUT to expected results.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class scoreboard extends uvm_subscriber #(twire_transaction);
  `uvm_component_utils(scoreboard);

  // storage of transactions between driver and scoreboard processes
  uvm_tlm_analysis_fifo #(sequence_item) stimuli_f;

   
  // =================================================================
  // C O N S T R U C T O R
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   build_phase   M E T H O D
  function void build_phase(uvm_phase phase);
    stimuli_f = new ("stimuli_f", this);
  endfunction : build_phase


  // =================================================================
  // Generates an twire_transaction for the expected data
  function twire_transaction expected_twire(sequence_item stimuli);
    twire_transaction expected;
      
    expected = new("expected");

    expected.cap_opr           = stimuli.stim_op;
    expected.cap_reg_addr      = stimuli.stim_reg_addr;
    expected.cap_data_in       = stimuli.stim_data_in;
    expected.rep_data_out      = stimuli.stim_data_out;
    expected.cap_SLAVE_WR_ADDR = SLAVE_WR_ADDR;
    expected.cap_SLAVE_RD_ADDR = SLAVE_RD_ADDR;

    return expected;

   endfunction : expected_twire
   

  // =================================================================
  // O V E R R I D E S   U V M   write   M E T H O D
  // write method: 
  //    Receives stimuli from stimuli_monitor (sequence_item cmd)
  //    Receives results from twire_monitor (twire_transaction t)
  // This method compares the output results from DUT and 
  // the previously inserted stimuli into DUT.
  //
  virtual function void write(twire_transaction t);
    string data_str;

    sequence_item stimuli;
    twire_transaction expected;

    if (!stimuli_f.try_get(stimuli))
      $fatal(1, "scoreboard::Missing stimuli in self checker");

    expected = expected_twire(stimuli);

//    $display("%dns : scoreboard::Checking rdata: expected stim_op = %h, cap_opr = %h", $time, stimuli.stim_op, t.cap_opr);
//    assert(t.cap_opr === stimuli.stim_op) else $error("%dns : scoreboard::Checking failed: expected stim_op = %h, cap_opr = %h", $time, stimuli.stim_op, t.cap_opr);
      
    data_str = {                     stimuli.convert2string(), 
                  " ==>  Actual "  , t.convert2string(), 
                  "/expected "     , expected.convert2string()};

    if (!expected.compare(t))
      `uvm_error("SCOREBOARD SELF CHECKER", {"FAIL: ", data_str})
    else
      `uvm_info ("SCOREBOARD SELF CHECKER", {"PASS: ", data_str}, UVM_LOW)

  endfunction : write


endclass : scoreboard

