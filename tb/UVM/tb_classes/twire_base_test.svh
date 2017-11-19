/***********************************************************************
  $FILENAME    : twire_base_test.svh

  $TITLE       : User-defined UVM base class tests fro async FIFO

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : twire_base_test class inherits from uvm_test and
                 is used as a base class for other test class for the
                 DUT verification.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class twire_base_test extends uvm_test;

  env       env_h;
  sequencer sequencer_h;

   
  // =================================================================
  // C O N S T R U C T O R
  function new (string name, uvm_component parent);
    super.new(name,parent);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   build_phase   M E T H O D
  function void build_phase(uvm_phase phase);
    env_h = env::type_id::create("env_h", this);
  endfunction : build_phase


  // =================================================================
  // O V E R R I D E S   U V M   end_of_elaboration_phase   M E T H O D
  function void end_of_elaboration_phase(uvm_phase phase);
    sequencer_h = env_h.sequencer_h;
  endfunction : end_of_elaboration_phase


endclass

