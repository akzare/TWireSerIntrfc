/***********************************************************************
  $FILENAME    : full_test.svh

  $TITLE       : Upper layer test module

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This class inherits from twire_base_test and
                 is used as the upper layer entry point into the FIFO
                 verification system. It should be called at the top
                 module.

************************************************************************/


class full_test extends twire_base_test;
  `uvm_component_utils(full_test);
   
  runall_sequence runall_seq;


  // =================================================================
  // C O N S T R U C T O R
  function new (string name, uvm_component parent);
    super.new(name,parent);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   run_phase   M E T H O D
  task run_phase(uvm_phase phase);
    runall_seq = new("runall_seq");
    phase.raise_objection(this);
    runall_seq.start(null);
    phase.drop_objection(this);
  endtask : run_phase


endclass

