/***********************************************************************
  $FILENAME    : twire_ser_intrfc_tb.sv

  $TITLE       : Conventional testbech for Two-Wire Serial Register Interface

  $DATE        : 19 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This Systemverilog testbench is used to test the single read/write
                 transaction on the Two-Wire Serial Register Interface.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


`timescale 1ns / 100ps

module TWireSerIntrfc_tb;

  // ===============================================================
  // I N T E R N A L   C O N S T A N T S
	
  // I2C clock rate (kHz)
  parameter I2CCLK = 400;
  // System clock rate (MHz)
  parameter SYSCLK = 100;
  // Sensor slave read address
  parameter [7:0] SLAVE_RD_ADDR = 8'h21;
  // Sensor slave write address
  parameter [7:0] SLAVE_WR_ADDR = 8'h20;

 
  // ===============================================================
  // I N T E R N A L   S I G N A L S

  // ==========================================
  // D U T   S I G N A L S
  
  reg         clk = 1'b0;
  reg         sync_rst = 1'b0;
  reg         async_rst = 1'b1;
  reg         rw = 1'b0;
  reg         valid_in = 1'b0;
  reg  [15:0] reg_addr = 16'h0000;
  reg  [15:0] data_in = 16'h0000;
  wire        valid_out;
  wire [15:0] data_out;
  wire        busy;
  wire        error;
  reg         SDA_I = 1'b1;
  wire        SDA_O;
  wire        SDA_T;
  wire        SCL;


  // ==========================================
  // M O N I T O R   S I G N A L S
  
  bit        cap_opr = 0;
  bit [7:0]  cap_SLAVE_WR_ADDR = 0;
  bit [7:0]  cap_SLAVE_RD_ADDR = 0;
  bit [15:0] cap_reg_addr = 0;
  bit [15:0] cap_data_in = 0;
  bit [15:0] rep_data_out = 0;

  event monitor_event;

  integer wr_timeout = 0;

  
  // ===============================================================
  // I N S T A N T I A T E   T H E   D U T 
  TWireSerIntrfc #(
    I2CCLK,
    SYSCLK,
    SLAVE_RD_ADDR,
    SLAVE_WR_ADDR
  ) 
  DUT
  (
   .clk(clk),
   .async_rst(async_rst),
   .sync_rst(sync_rst),
   .rw(rw),
   .valid_in(valid_in),
   .reg_addr(reg_addr),
   .data_in(data_in),
   .valid_out(valid_out),
   .data_out(data_out),
   .busy(busy),
   .error(error),
   .SDA_I(SDA_I),
   .SDA_O(SDA_O),
   .SDA_T(SDA_T),
   .SCL(SCL)
  );

  
  // ===============================================================
  // M A I N   T E S T   P R O C E S S  
  initial begin
	
    // ======================================================
    // R E S E T   P H A S E
    repeat(1) @(posedge clk);
    async_rst = 1'b0;
    repeat(20) @(posedge clk);
    #2
    async_rst = 1'b1;
    repeat(35) @(posedge clk);

    
    // ======================================================
    // S T A R T I N G   monitorHandler  A S   P A R A L L E L   T H R E A D
    fork 
      monitorHandler();
    join_none

    
    // ======================================================
    // W R I T E   T R A N S A C T I O N
    @ (posedge clk);
    rw       = 0;
    valid_in = 1;
    reg_addr = $random();
    data_in  = $random();
    $write("%dns : driver::wrTrans Writing address %x / data %x\n", $time, reg_addr, data_in);
    @ (posedge clk);
    valid_in = 0;
    while (busy == 0) begin
      @ (posedge clk);
      wr_timeout++;
      if (wr_timeout > 100) begin
        $error("%dns : wrTrans Warning : busy is 0 for more then 100 clocks\n", $time);
        repeat(20) @(posedge clk);
        $stop;
      end
    end
    wr_timeout = 0;

    while (busy == 1) begin
      @ (posedge clk);
      wr_timeout++;
      if (wr_timeout > 10000) begin
        $error("%dns : wrTrans Warning : busy is 1 for more then 10000 clocks\n", $time);
        repeat(20) @(posedge clk);
        $stop;
      end
    end
    wr_timeout = 0;

    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::wrTrans Waiting for event monitor_event\n", $time);
    @ (monitor_event);

    // ======================================================
    // W R   S C O R E B O A R D

    $display("%dns : scoreboard: OPR: Expected = 0, Got = %h", $time, cap_opr);
    assert(cap_opr === 0) else $error("%dns : scoreboard::Checking failed: Expected = 0, Got = %h", $time, cap_opr);

    $display("%dns : scoreboard: SLAVE_WR_ADDR: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);
    assert(cap_SLAVE_WR_ADDR === SLAVE_WR_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);

    $display("%dns : scoreboard: reg_addr: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);
    assert(cap_reg_addr === reg_addr) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);

    $display("%dns : scoreboard: data_in: Expected = %h, Got = %h", $time, data_in, cap_data_in);
    assert(cap_data_in === data_in) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, data_in, cap_data_in);

    reg_addr = 0;
    data_in  = 0;



    
    // ======================================================
    // R E A D   T R A N S A C T I O N
    @ (posedge clk);
    rw       = 1;
    valid_in = 1;
    reg_addr = $random();
    $write("%dns : driver::rdTrans Reading address %x\n", $time, reg_addr);
    @ (posedge clk);
    valid_in = 0;
    while (busy == 0) begin
      @ (posedge clk);
      wr_timeout++;
      if (wr_timeout > 100) begin
        $error("%dns : rdTrans Warning : busy is 0 for more then 100 clocks\n", $time);
        repeat(20) @(posedge clk);
        $stop;
      end
    end
    wr_timeout = 0;

    while (valid_out == 0) begin
      @ (posedge clk);
      wr_timeout++;
      if (wr_timeout > 10000) begin
        $error("%dns : rdTrans Warning : valid_out has not been reached for more then 10000 clocks\n", $time);
        repeat(20) @(posedge clk);
        $stop;
      end
    end
    wr_timeout = 0;
    
    // ======================================================
    // W A I T I N G   F O R   M O N I T O R
    $write("%dns : driver::rdTrans Waiting for event monitor_event\n", $time);
    @ (monitor_event);

    // ======================================================
    // R D   S C O R E B O A R D
    $display("%dns : scoreboard: OPR: Expected = 1, Got = %h", $time, cap_opr);
    assert(cap_opr === 1) else $error("%dns : scoreboard::Checking failed: Expected = 1, Got = %h", $time, cap_opr);

    $display("%dns : scoreboard: SLAVE_WR_ADDR: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);
    assert(cap_SLAVE_WR_ADDR === SLAVE_WR_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, SLAVE_WR_ADDR, cap_SLAVE_WR_ADDR);

    $display("%dns : scoreboard: SLAVE_RD_ADDR: Expected = %h, Got = %h", $time, SLAVE_RD_ADDR, cap_SLAVE_RD_ADDR);
    assert(cap_SLAVE_RD_ADDR === SLAVE_RD_ADDR) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, SLAVE_RD_ADDR, cap_SLAVE_RD_ADDR);

    $display("%dns : scoreboard: reg_addr: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);
    assert(cap_reg_addr === reg_addr) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, reg_addr, cap_reg_addr);

    $display("%dns : scoreboard: data_out: Expected = %h, Got = %h", $time, data_out, rep_data_out);
    assert(rep_data_out === data_out) else $error("%dns : scoreboard::Checking failed: Expected = %h, Got = %h", $time, data_out, rep_data_out);
    
    reg_addr = 0;


    // ======================================================
    // E N D I N G   T H E   S I M U L A T I O N
    repeat(500) @(posedge clk);
    $write("%dns : Terminating simulations\n", $time);
    $stop;

  end


  
  // ===============================================================
  // T R A N S A C T I O N   M O N I T O R   A N D   R E P L Y   H A N D L E R
  task monitorHandler();
  begin
    bit prev_sda_o = 0;
    while (1) begin
      @ (negedge SCL);
      SDA_I = 1;
      // =====================================================
      // S E E K I N G   T H E   S T A R T   O F   F R A M E
      while (SDA_O == 1'b1) begin
        @ (negedge SCL); 
      end
      $write("%dns : driver::monitorHandler Info : Found start of i2c frame(addr)...\n", $time);
      if (SDA_T == 1) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 1 during start of frame(addr) transmission!\n", $time);
      end
      
      // =====================================================
      // C A P T U R I N G   S L A V E   W R I T E   A D D R E S S   ( 8 - B I T )
      for (integer i = 7; i >= 0; i--)  begin
        @ (posedge SCL);
        if (SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during slave addr write field transmission!\n", $time);
        end
        cap_SLAVE_WR_ADDR[i] = SDA_O;
      end
      $write("%dns : driver::monitorHandler Info : cap_SLAVE_WR_ADDR %x\n", $time, cap_SLAVE_WR_ADDR);

      // =====================================================
      // R E P L Y   B Y   A C K 
      @ (negedge SCL);
      repeat(27) @(posedge clk);
      if (SDA_T == 1'b0) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 0 during slave addr write Ack field response!\n", $time);
      end
      $write("%dns : driver::monitorHandler Info : Sent ACK to slave addr write\n", $time);
      SDA_I = 1'b0;      
      @ (negedge SCL);
      repeat(22) @(posedge clk);
      SDA_I = 1'b1;
      
      // =====================================================
      // C A P T U R I N G   R E G I S T E R   A D D R E S S   H I G H   ( 8 - B I T )
      for (integer i = 15; i >= 8; i--)  begin
        @ (posedge SCL);
        if (SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during reg addr high field transmission!\n", $time);
        end
        cap_reg_addr[i] = SDA_O;
      end
      
      // =====================================================
      // R E P L Y   B Y   A C K  
      @ (negedge SCL);
      repeat(27) @(posedge clk);
      if (SDA_T == 1'b0) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 0 during reg addr high Ack field response!\n", $time);
      end
      $write("%dns : driver::monitorHandler Info : Sent ACK to reg addr high\n", $time);
      SDA_I = 1'b0;      
      @ (negedge SCL);
      repeat(22) @(posedge clk);
      SDA_I = 1'b1;
      
      // =====================================================
      // C A P T U R I N G   R E G I S T E R   A D D R E S S   L O W   ( 8 - B I T )
      for (integer i = 7; i >= 0; i--)  begin
        @ (posedge SCL);
        if (SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during reg addr low field transmission!\n", $time);
        end
        cap_reg_addr[i] = SDA_O;
      end
      
      // =====================================================
      // R E P L Y   B Y   A C K 
      @ (negedge SCL);
      repeat(27) @(posedge clk);
      if (SDA_T == 1'b0) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 0 during reg addr low Ack field response!\n", $time);
      end
      $write("%dns : driver::monitorHandler Info : Sent ACK to reg addr low\n", $time);
      SDA_I = 1'b0;      
      @ (negedge SCL);
      repeat(22) @(posedge clk);
      SDA_I = 1'b1;

      $write("%dns : driver::monitorHandler Info : cap_reg_addr %x\n", $time, cap_reg_addr);

      @ (posedge SCL);
      prev_sda_o = SDA_O;
      @ (negedge SCL);

      // =========================================================================
      // H A N D L I N G   W R I T E   O P E R A T I O N
      if (SDA_O == prev_sda_o) begin 
        cap_opr = 0;
        $write("%dns : driver::monitorHandler Info : write operation.\n", $time);    
        cap_data_in[15] = SDA_O;

        // =====================================================
        // C A P T U R I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 14; i >= 8; i--)  begin
          @ (posedge SCL);
          if (SDA_T == 1) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 1 during data high write field transmission!\n", $time);
          end
          cap_data_in[i] = SDA_O;
        end

        // =====================================================
        // R E P L Y   B Y   A C K 
        @ (negedge SCL);
        repeat(27) @(posedge clk);
        if (SDA_T == 1'b0) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 0 during data high write Ack field response!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Sent ACK to data high write\n", $time);
        SDA_I = 1'b0;      
        @ (negedge SCL);
        repeat(22) @(posedge clk);
        SDA_I = 1'b1;

        // =====================================================
        // C A P T U R I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 7; i >= 0; i--)  begin
          @ (posedge SCL);
          if (SDA_T == 1) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 1 during data low write field transmission!\n", $time);
          end
          cap_data_in[i] = SDA_O;
        end

        // =====================================================
        // R E P L Y   B Y   A C K
        @ (negedge SCL);
        repeat(27) @(posedge clk);
        if (SDA_T == 1'b0) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 0 during data low write Ack field response!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Sent ACK to data low write\n", $time);
        SDA_I = 1'b0;      
        @ (negedge SCL);
        repeat(22) @(posedge clk);
        SDA_I = 1'b1;

        $write("%dns : driver::monitorHandler Info : cap_data_in %x\n", $time, cap_data_in);
      
        // =====================================================
        // C H E C K I N G   S T O P   C M D
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending stop!\n", $time);
        end
        if (SDA_O == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_O is 1 during sending stop!\n", $time);
        end
        @ (posedge SDA_O);
        if (SDA_T == 1'b0) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending stop!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Received stop command.\n", $time);
        
        repeat(200) @(posedge clk);      

        
      // =========================================================================
      // H A N D L I N G   R E A D   O P E R A T I O N
      end else begin
        cap_opr = 1;
        // Reached start of frame
        $write("%dns : driver::monitorHandler Info : Found start of i2c frame(read)...\n", $time);
        if (SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during start of frame(read) transmission!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : read operation.\n", $time);      

        // =====================================================
        // C A P T U R I N G   S L A V E   R E A D   A D D R E S S  ( 8 - B I T )
        for (integer i = 7; i >= 0; i--)  begin
          @ (posedge SCL);
          if (SDA_T == 1) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 1 during slave addr read field transmission!\n", $time);
          end
          cap_SLAVE_RD_ADDR[i] = SDA_O;
        end
        $write("%dns : driver::monitorHandler Info : cap_SLAVE_RD_ADDR %x\n", $time, cap_SLAVE_RD_ADDR);

        // =====================================================
        // R E P L Y   T O   A C K 
        @ (negedge SCL);
        repeat(27) @(posedge clk);
        if (SDA_T == 1'b0) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 0 during slave addr read Ack field response!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Sent ACK to slave addr read\n", $time);
        SDA_I = 1'b0;      
        @ (negedge SCL);
        repeat(22) @(posedge clk);
        SDA_I = 1'b1;

        // =====================================================
        // S E N D I N G   H I G H   D A T A  ( 8 - B I T )
        rep_data_out = $random();
        $write("%dns : driver::monitorHandler Info : rep_data_out %x\n", $time, rep_data_out);
        for (integer i = 15; i >= 8; i--)  begin
          SDA_I = rep_data_out[i];
          if (SDA_T == 0) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending high data(read)!\n", $time);
          end
          @ (negedge SCL);
          repeat(23) @(posedge clk);
        end
        SDA_I = 1'b1;
      
        // =====================================================
        // C H E C K I N G   A C K 
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending ack for high data read!\n", $time);
        end
        if (SDA_O == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_O is 1 during sending ack for high data read!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Received ACK for high data read\n", $time);

        @ (negedge SCL);
        repeat(27) @(posedge clk);

        // =====================================================
        // S E N D I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 7; i >= 0; i--)  begin
          SDA_I = rep_data_out[i];
          if (SDA_T == 0) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending low data(read)!\n", $time);
          end
          @ (negedge SCL);
          repeat(23) @(posedge clk);
        end
        SDA_I = 1'b1;
      
        // =====================================================
        // C H E C K I N G   N A C K
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending ack for low data read!\n", $time);
        end
        if (SDA_O == 1'b0) begin
          $error("%dns : driver::monitorHandler Error : SDA_O is 0 during sending ack for low data read!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Received NACK for low data read\n", $time);

        // =====================================================
        // C H E C K I N G   S T O P   C M D 
        @ (negedge SCL);
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending stop!\n", $time);
        end
        if (SDA_O == 1'b1) begin
          $error("%dns : driver::monitorHandler Error : SDA_O is 1 during sending stop!\n", $time);
        end
        @ (posedge SDA_O);
        if (SDA_T == 1'b0) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending stop!\n", $time);
        end
        $write("%dns : driver::monitorHandler Info : Received stop command.\n", $time);
      end
      
      // =====================================================
      // T R I G G E R I N G   E V E N T
      $write("%dns : driver::monitorHandler Info : Triggering event monitor_event\n", $time);
      -> monitor_event;
    end
  end
  endtask : monitorHandler


  // ===============================================================
  // C L O C K   G E N E R A T O R
  always #10ns clk = ~clk;

  
  // ===============================================================
  // Dump the changes in the values of nets and registers in twire.vcd
  initial begin
    $dumpfile("twire.vcd");
    $dumpvars();
  end

endmodule
