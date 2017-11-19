/***********************************************************************
  $FILENAME    : scoreboard.svh

  $TITLE       : Scoreboard class implementation

  $DATE        : 15 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : The scoreboard class provides all the necessary methods
                 to compare actual results from the DUT to expected results.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class scoreboard;

  // ===================================================================
  // M A I L B O X   D E F
  mailbox stim_opr;
  mailbox stim_reg_addr;
  mailbox stim_data;

  mailbox mon_opr;
  mailbox mon_slave_wr_addr;
  mailbox mon_slave_rd_addr;
  mailbox mon_reg_addr;
  mailbox mon_data;
  

  // ==============================================================================
  // C O N S T R U C T O R
  function new ();
  	stim_opr      = new();
    stim_reg_addr = new();
    stim_data     = new();

    mon_opr           = new();
    mon_slave_wr_addr = new();
    mon_slave_rd_addr = new();
    mon_reg_addr      = new();
    mon_data          = new();
  endfunction : new


  // ==============================================================================
  // A D D   S T I M U L I   T O   M A I L B O X
  task stimAdd(operation_t opr, bit [15:0] reg_addr, bit [15:0] data);
  begin
  	stim_opr.put(opr);
    stim_reg_addr.put(reg_addr);
    stim_data.put(data);
    
    if (opr == wr_op) begin
      $write("%dns : scoreboard::stimAdd WR Added reg_addr %x / data_in %x\n", $time, reg_addr, data);
    end else begin
      $write("%dns : scoreboard::stimAdd RD Added reg_addr %x / data_out %x\n", $time, reg_addr, data);
    end
  end
  endtask : stimAdd


  // ==============================================================================
  // A D D   M O N I T O R   T O   M A I L B O X
  task monAdd(operation_t opr, bit [7:0] slave_wr_addr, bit [7:0] slave_rd_addr, bit [15:0] reg_addr, bit [15:0] data);
  begin
  	mon_opr.put(opr);
    mon_slave_wr_addr.put(slave_wr_addr);
    mon_slave_rd_addr.put(slave_rd_addr);
    mon_reg_addr.put(reg_addr);
    mon_data.put(data);
    
    if (opr == wr_op) begin
      $write("%dns : scoreboard::monAdd WR Added slave_wr_addr %x / slave_wr_addr %x / data_in %x\n", $time, slave_wr_addr, reg_addr, data);
    end else begin
      $write("%dns : scoreboard::monAdd RD Added slave_wr_addr %x / slave_rd_addr %x / reg_addr %x / data_out %x\n", $time, slave_wr_addr, slave_rd_addr, reg_addr, data);
    end
  end
  endtask


  // ==============================================================================
  // C O M P A R E   R E S U L T S
  task resCompare();
  begin
  	operation_t opr = wr_op;
  	bit [15:0]  reg_addr = 0;
  	bit [15:0]  data = 0;

  	operation_t cap_opr = wr_op;
  	bit [7:0]   cap_SLAVE_WR_ADDR = 0;
  	bit [7:0]   cap_SLAVE_RD_ADDR = 0;
  	bit [15:0]  cap_reg_addr = 0;
  	bit [15:0]  cap_data = 0;

  	stim_opr.get(opr);
    stim_reg_addr.get(reg_addr);
    stim_data.get(data);

    mon_opr.get(cap_opr);
    mon_slave_wr_addr.get(cap_SLAVE_WR_ADDR);
    mon_slave_rd_addr.get(cap_SLAVE_RD_ADDR);
    mon_reg_addr.get(cap_reg_addr);
    mon_data.get(cap_data);

    // =====================================================
    // W R   S C O R E B O A R D
    if (opr == wr_op) begin
      $display("%dns : scoreboard: opr:WR Expected = %h, Got = %h", $time, opr, cap_opr);
      assert(cap_SLAVE_WR_ADDR === SLAVE_WR_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, opr, cap_opr);

      $display("%dns : scoreboard: SLAVE_WR_ADDR: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);
      assert(cap_SLAVE_WR_ADDR === SLAVE_WR_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);

      $display("%dns : scoreboard: reg_addr: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);
      assert(cap_reg_addr === reg_addr) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);

      $display("%dns : scoreboard: data_in: Expected = %h, Got = %h", $time, data, cap_data);
      assert(cap_data === data) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, data, cap_data);

    // =====================================================
    // R D   S C O R E B O A R D
    end else begin
      $display("%dns : scoreboard: opr:RD Expected = %h, Got = %h", $time, opr, cap_opr);
      assert(cap_SLAVE_WR_ADDR === SLAVE_WR_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, opr, cap_opr);

   	  $display("%dns : scoreboard: SLAVE_WR_ADDR: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);
      assert(cap_SLAVE_WR_ADDR === SLAVE_WR_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);

      $display("%dns : scoreboard: SLAVE_RD_ADDR: Expected = %h, Got = %h", $time, SLAVE_RD_ADDR, cap_SLAVE_RD_ADDR);
      assert(cap_SLAVE_RD_ADDR === SLAVE_RD_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, SLAVE_RD_ADDR, cap_SLAVE_RD_ADDR);

      $display("%dns : scoreboard: reg_addr: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);
      assert(cap_reg_addr === reg_addr) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);

      $display("%dns : scoreboard: data_out: Expected = %h, Got = %h", $time, data, cap_data);
      assert(cap_data === data) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, data, cap_data);
    end

  end
  endtask : resCompare


endclass : scoreboard
