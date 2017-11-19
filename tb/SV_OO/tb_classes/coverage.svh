/***********************************************************************
  $FILENAME    : coverage.svh

  $TITLE       : Coverage class implementation

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : The coverage class provides all the necessary methods
                 in order to perform the functional coverage.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class coverage;

  // =================================================================
  // B F M   I N S T A N C E
  virtual twire_bfm bfm;

  // =================================================================
  // I N T E R N A L   S I G N A L S
  bit        rw;
  bit        busy;
  bit [15:0] reg_addr;
  bit [15:0] data_in;
  bit [15:0] data_out;
  bit [1:0]  rw_seq;


  // =================================================================
  // C O V E R A G E   G R O U P   D E F I N I T I O N

  // ====================================================
  // O P E R A T I O N   C O V E R A G E
  covergroup op_cov;

  	// =======================================
  	// R E A D   W R I T E   S E Q U E N C E S
    coverpoint rw_seq {
      bins write = (2'b00 => 2'b01); // write -> busy
      bins read  = (2'b10 => 2'b11); // read  -> busy

      bins read_write[] = (2'b10 => 2'b11 => 2'b00 => 2'b01); // read -> busy -> write -> busy
      bins write_read[] = (2'b00 => 2'b01 => 2'b10 => 2'b11); // write -> busy -> read -> busy

      bins readwriteread   = (2'b10 => 2'b11 => 2'b00 => 2'b01 => 2'b10 => 2'b11);
      bins writereadwrite  = (2'b00 => 2'b01 => 2'b10 => 2'b11 => 2'b00 => 2'b01);
    }

  endgroup


  // ====================================================
  // R E A D   O P E R A T I O N
  covergroup read_ops;

    reg_addr_leg: coverpoint reg_addr {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

    data_in_leg: coverpoint data_in {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

  endgroup


  // ====================================================
  // W R I T E   O P E R A T I O N
  covergroup write_ops;

    reg_addr_leg: coverpoint reg_addr {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

    data_out_leg: coverpoint data_out {
      bins zeros = {'h0000};
      bins others= {['h0001:'hFFFE]};
      bins ones  = {'hFFFF};
    }

  endgroup


  // =================================================================
  // C O N S T R U C T O R
  function new (virtual twire_bfm b);
    op_cov    = new();
    read_ops  = new();
    write_ops = new();
    bfm = b;
  endfunction : new


  // =================================================================
  // R A E A D / W R I T E   C O V E R A G E    S A M P L I N G
  task rw_sampling();
    forever begin : sampling_block
      @(posedge bfm.clk);
      busy   = bfm.busy;
      rw     = bfm.rw;
      rw_seq = {rw,busy};
      op_cov.sample();
    end : sampling_block
  endtask : rw_sampling


  // =================================================================
  // R A E A D   C O V E R A G E    S A M P L I N G
  task read_sampling();
    forever begin : sampling_block
      @(posedge bfm.valid_out iff bfm.rw);
      reg_addr = bfm.reg_addr;
      data_out = bfm.data_out;
      read_ops.sample();
    end : sampling_block
  endtask : read_sampling


  // =================================================================
  // W R I T E   C O V E R A G E    S A M P L I N G
  task write_sampling();
    forever begin : sampling_block
      @(posedge bfm.valid_in iff !bfm.rw);
      reg_addr = bfm.reg_addr;
      data_in  = bfm.data_in;
      write_ops.sample();
    end : sampling_block
  endtask : write_sampling


  // =================================================================
  // M A I N   P R O C E S S
  task execute();
    fork
      rw_sampling();
      read_sampling();
      write_sampling();
    join_none
  endtask : execute


endclass : coverage
