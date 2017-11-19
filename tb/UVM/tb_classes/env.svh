/***********************************************************************
  $FILENAME    : env.svh

  $TITLE       : Comprises a complete UVM environment

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This UVM environment consist of the entire testbench.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class env extends uvm_env;
  `uvm_component_utils(env);

  sequencer       sequencer_h;
  coverage        coverage_h;
  scoreboard      scoreboard_h;
  driver          driver_h;
  stimuli_monitor stimuli_monitor_h;
  twire_monitor   twire_monitor_h;


  // =================================================================
  // C O N S T R U C T O R
  function new (string name, uvm_component parent);
    super.new(name,parent);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   build_phase   M E T H O D
  // The testbench component hierarchy is constructed by this method.
  function void build_phase(uvm_phase phase);
    // stimulus objects
    sequencer_h  = new("sequencer_h", this);
    driver_h     = driver::type_id::create("driver_h", this);
    // monitors objects
    stimuli_monitor_h = stimuli_monitor::type_id::create("stimuli_monitor_h", this);
    twire_monitor_h  = twire_monitor::type_id::create("twire_monitor", this);
    // analysis objects
    coverage_h   = coverage::type_id::create ("coverage_h", this);
    scoreboard_h = scoreboard::type_id::create("scoreboard", this);
  endfunction : build_phase


  // =================================================================
  // O V E R R I D E S   U V M   connect_phase   M E T H O D
  function void connect_phase(uvm_phase phase);
    // Inter-class communication: Source: Driver -> Destination: Sequencer
    driver_h.seq_item_port.connect(sequencer_h.seq_item_export);

    // Inter-class communication: Source: stimuli Monitor -> Destination: Coverage
    stimuli_monitor_h.ap.connect(coverage_h.analysis_export);
    // Inter-class communication: Source: stimuli Monitor -> Destination: Scoreboard
    stimuli_monitor_h.ap.connect(scoreboard_h.stimuli_f.analysis_export);
    // Inter-class communication: Source: stimuli Monitor -> Destination: Scoreboard
    twire_monitor_h.ap.connect(scoreboard_h.analysis_export);
  endfunction : connect_phase


endclass : env

