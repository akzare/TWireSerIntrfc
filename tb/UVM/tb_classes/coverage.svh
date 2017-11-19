/***********************************************************************
  $FILENAME    : coverage.svh

  $TITLE       : Coverage class implementation

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : The coverage class provides all the necessary methods
                 in order to perform the functional coverage.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/



class coverage extends uvm_subscriber #(sequence_item);
  `uvm_component_utils(coverage)

  // =================================================================
  // I N T E R N A L   S I G N A L S

  operation_t stim_op;
  bit [15:0]  stim_reg_addr;
  bit [15:0]  stim_data_in;
  bit [15:0]  stim_data_out;


  // =================================================================
  // C O V E R A G E   G R O U P   D E F I N I T I O N

  // ====================================================
  // O P E R A T I O N   C O V E R A G E
  covergroup op_cov;

  	// =======================================
  	// R E A D   W R I T E   O P E R A T I O N S
    coverpoint stim_op {
      bins write = {wr_op}; // write
      bins read  = {rd_op}; // read 

      bins read_write[] = (rd_op => wr_op); // read -> write
      bins write_read[] = (wr_op => rd_op); // write -> read

      bins readwriteread   = (rd_op => wr_op => rd_op);
      bins writereadwrite  = (wr_op => rd_op => wr_op);
    }

  endgroup


  // ====================================================
  // R E A D   O P E R A T I O N
  covergroup read_ops;

    reg_addr_leg: coverpoint stim_reg_addr {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

    data_in_leg: coverpoint stim_data_in {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

  endgroup


  // ====================================================
  // W R I T E   O P E R A T I O N
  covergroup write_ops;

    reg_addr_leg: coverpoint stim_reg_addr {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

    data_out_leg: coverpoint stim_data_out {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

  endgroup


  // =================================================================
  // C O N S T R U C T O R
  function new (string name, uvm_component parent);
    super.new(name, parent);
    op_cov    = new();
    read_ops  = new();
    write_ops = new();
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   write   M E T H O D
  // write method: Receives date from stimuli_monitor
  function void write(sequence_item t);
    stim_op       = t.stim_op;
    stim_reg_addr = t.stim_reg_addr;
    stim_data_in  = t.stim_data_in;
    stim_data_out = t.stim_data_out;

    op_cov.sample();

    if (stim_op == wr_op)
      write_ops.sample();
    else
      read_ops.sample();

  endfunction : write

endclass : coverage

