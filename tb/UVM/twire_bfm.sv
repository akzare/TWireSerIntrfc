/***********************************************************************
  $FILENAME    : twire_bfm.svh

  $TITLE       : Bus Functional Model (BFM) interface definition

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This module defines DUT's BFM interface which includes 
                 the Master Two-Wire Serial Register Interface (DUT).

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


interface twire_bfm;
  import twire_pkg::*;

  // =================================================================
  // D U T   I N T E R C A E

  bit          clk;       // Input system clock
  bit          async_rst; // ASync input reset (low active)
  bit          sync_rst;  // Sync input reset (high active)
  bit          rw;        // Determines the type of desired operation: read/write -> 1/0
  bit          valid_in;  // Indicates the validity of reg_addr and data_in signal. Assertion of
                          // a rising edge pulse on this signal forces the master controller
                          // to start a new transaction.
  logic [15:0] reg_addr;  // The target register address.
  logic [15:0] data_in;   // Input data which must be written into the specified register.
  wire         valid_out; // A rising edge on this signal indicates the validity of
                          // the read data on data_out.
  wire  [15:0] data_out;  // The output of read transaction on the specified register
  wire         busy;      // Indicates master FSM is in current progress 
                          // to accomplish the recent read/write transaction
  wire         error;     // Presents an error condition during read/write transactions

  // Sensor interface
  // Data is transferred between the master and the slave on a bidirectional signal (SDATA).  
  bit          SDA_I;     // Data direction from sensor to master
  wire         SDA_O;     // Data direction from master to sensor
  wire         SDA_T;     // Tri-state buffer control
  wire         SCL;       // The master generates a clock (SCLK) that is an input


  // ==========================================
  // M O N I T O R   S I G N A L S
  
  bit [7:0]  cap_SLAVE_WR_ADDR = 0;
  bit [7:0]  cap_SLAVE_RD_ADDR = 0;
  bit [15:0] cap_reg_addr = 0;
  bit [15:0] cap_data_in = 0;
  bit [15:0] rep_data_out = 0;

  event monitor_event;

  stimuli_monitor stimuli_monitor_h;
  
  twire_monitor twire_monitor_h;


  // =================================================================
  // C L O C K   G E N E R A T O R
  initial begin
    clk = 1'b0;

    fork
      forever #10ns clk = ~clk; // System clock
    join
  end


  // =================================================================
  // R E S E T   T H E   D U T   I N T E R F A C E
  task reset_DUT();
  begin
    $write("%dns : bfm::Asserting reset on Two-Wire Serial Register Interface module.\n", $time);

    rw        = 1'b0;
    valid_in  = 1'b0;
    reg_addr  = 16'h0000;
    data_in   = 16'h0000;
    SDA_I     = 1'b0;
    
    repeat(1) @(posedge clk);
    async_rst = 1'b0;
    repeat(20) @(posedge clk);
    #2
    async_rst = 1'b1;
    repeat(35) @(posedge clk);
    
    $write("%dns : bfm::Done asserting reset on Two-Wire Serial Register Interface module.\n", $time);
  end
  endtask : reset_DUT


  // =================================================================
  // W R I T E   T R A N S A C T I O N
  task wrTrans(input bit [15:0] stim_reg_addr, input bit [15:0] stim_data_in);
  begin
    integer wr_timeout = 0;
    @ (posedge clk);
    rw       = 0;
    valid_in = 1;
    reg_addr = stim_reg_addr;
    data_in  = stim_data_in;
    $write("%dns : driver::wrTrans Writing address %x / data %x\n", $time, stim_reg_addr, stim_data_in);
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

    if (stimuli_monitor_h != null)
      stimuli_monitor_h.write_to_monitor(wr_op, stim_reg_addr, stim_data_in);
       
    $write("%dns : wrTrans Waiting for event monitor_event\n", $time);
    @ (monitor_event);

    reg_addr = 0;
    data_in  = 0;

  end
  endtask : wrTrans


  // =================================================================
  // R E A D   T R A N S A C T I O N
  task rdTrans(input bit [15:0] stim_reg_addr, input bit [15:0] stim_data_out);
  begin
    integer rd_timeout = 0;
    rep_data_out = stim_data_out;
    @ (posedge clk);
    rw       = 1;
    valid_in = 1;
    reg_addr = stim_reg_addr;
    $write("%dns : driver::rdTrans Reading address %x / data %x\n", $time, stim_reg_addr, stim_data_out);
    @ (posedge clk);
    valid_in = 0;
    while (busy == 0) begin
      @ (posedge clk);
      rd_timeout++;
      if (rd_timeout > 100) begin
        $error("%dns : rdTrans Warning : busy is 0 for more then 100 clocks\n", $time);
        repeat(20) @(posedge clk);
   	    $stop;
      end
    end
    rd_timeout = 0;

    while (valid_out == 0) begin
      @ (posedge clk);
      rd_timeout++;
      if (rd_timeout > 10000) begin
        $error("%dns : rdTrans Warning : valid_out has not been reached for more then 10000 clocks\n", $time);
        repeat(20) @(posedge clk);
        $stop;
      end
    end
    rd_timeout = 0;

    if (stimuli_monitor_h != null)
      stimuli_monitor_h.write_to_monitor(rd_op, reg_addr, data_out);
    
    $write("%dns : rdTrans Waiting for event monitor_event\n", $time);
    @ (monitor_event);

    reg_addr = 0;
  end
  endtask : rdTrans


  // ==============================================================================
  // T R A N S A C T I O N   M O N I T O R   A N D   R E P L Y   H A N D L E R
  initial begin : slave_thread
    bit  prev_sda_o = 0;
    operation_t  cap_opr = wr_op;
    while (1) begin
      @ (negedge SCL);
      SDA_I = 1;
      // =====================================================
      // S E E K I N G   T H E   S T A R T   O F   F R A M E
      while (SDA_O == 1'b1) begin
        @ (negedge SCL); 
      end
      $write("%dns : bfm::slave_thread Info : Found start of frame(addr)...\n", $time);
      if (SDA_T == 1) begin
        $error("%dns : bfm::slave_thread Error : SDA_T is 1 during start of frame(addr) transmission!\n", $time);
      end
      
      // =====================================================
      // C A P T U R I N G   S L A V E   W R I T E   A D D R E S S   ( 8 - B I T )
      for (integer i = 7; i >= 0; i--)  begin
        @ (posedge SCL);
        if (SDA_T == 1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during slave addr write field transmission!\n", $time);
        end
        cap_SLAVE_WR_ADDR[i] = SDA_O;
      end
      $write("%dns : bfm::slave_thread Info : cap_SLAVE_WR_ADDR %x\n", $time, cap_SLAVE_WR_ADDR);

      // =====================================================
      // R E P L Y   B Y   A C K 
      @ (negedge SCL);
      repeat(27) @(posedge clk);
      if (SDA_T == 1'b0) begin
        $error("%dns : bfm::slave_thread Error : SDA_T is 0 during slave addr write Ack field response!\n", $time);
      end
      $write("%dns : bfm::slave_thread Info : Sent ACK to slave addr write\n", $time);
      SDA_I = 1'b0;      
      @ (negedge SCL);
      repeat(22) @(posedge clk);
      SDA_I = 1'b1;
      
      // =====================================================
      // C A P T U R I N G   R E G I S T E R   A D D R E S S   H I G H   ( 8 - B I T )
      for (integer i = 15; i >= 8; i--)  begin
        @ (posedge SCL);
        if (SDA_T == 1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during reg addr high field transmission!\n", $time);
        end
        cap_reg_addr[i] = SDA_O;
      end
      
      // =====================================================
      // R E P L Y   B Y   A C K  
      @ (negedge SCL);
      repeat(27) @(posedge clk);
      if (SDA_T == 1'b0) begin
        $error("%dns : bfm::slave_thread Error : SDA_T is 0 during reg addr high Ack field response!\n", $time);
      end
      $write("%dns : bfm::slave_thread Info : Sent ACK to reg addr high\n", $time);
      SDA_I = 1'b0;      
      @ (negedge SCL);
      repeat(22) @(posedge clk);
      SDA_I = 1'b1;
      
      // =====================================================
      // C A P T U R I N G   R E G I S T E R   A D D R E S S   L O W   ( 8 - B I T )
      for (integer i = 7; i >= 0; i--)  begin
        @ (posedge SCL);
        if (SDA_T == 1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during reg addr low field transmission!\n", $time);
        end
        cap_reg_addr[i] = SDA_O;
      end
      
      // =====================================================
      // R E P L Y   B Y   A C K 
      @ (negedge SCL);
      repeat(27) @(posedge clk);
      if (SDA_T == 1'b0) begin
        $error("%dns : bfm::slave_thread Error : SDA_T is 0 during reg addr low Ack field response!\n", $time);
      end
      $write("%dns : bfm::slave_thread Info : Sent ACK to reg addr low\n", $time);
      SDA_I = 1'b0;      
      @ (negedge SCL);
      repeat(22) @(posedge clk);
      SDA_I = 1'b1;

      $write("%dns : bfm::slave_thread Info : cap_reg_addr %x\n", $time, cap_reg_addr);

      @ (posedge SCL);
      prev_sda_o = SDA_O;
      @ (negedge SCL);

      // =========================================================================
      // H A N D L I N G   W R I T E   O P E R A T I O N
      if (SDA_O == prev_sda_o) begin 
        $write("%dns : bfm::slave_thread Info : write operation.\n", $time);
        cap_opr = wr_op; 
        cap_data_in[15] = SDA_O;

        // =====================================================
        // C A P T U R I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 14; i >= 8; i--)  begin
          @ (posedge SCL);
          if (SDA_T == 1) begin
            $error("%dns : bfm::slave_thread Error : SDA_T is 1 during data high write field transmission!\n", $time);
          end
          cap_data_in[i] = SDA_O;
        end

        // =====================================================
        // R E P L Y   B Y   A C K 
        @ (negedge SCL);
        repeat(27) @(posedge clk);
        if (SDA_T == 1'b0) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 0 during data high write Ack field response!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Sent ACK to data high write\n", $time);
        SDA_I = 1'b0;      
        @ (negedge SCL);
        repeat(22) @(posedge clk);
        SDA_I = 1'b1;

        // =====================================================
        // C A P T U R I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 7; i >= 0; i--)  begin
          @ (posedge SCL);
          if (SDA_T == 1) begin
            $error("%dns : bfm::slave_thread Error : SDA_T is 1 during data low write field transmission!\n", $time);
          end
          cap_data_in[i] = SDA_O;
        end

        // =====================================================
        // R E P L Y   B Y   A C K
        @ (negedge SCL);
        repeat(27) @(posedge clk);
        if (SDA_T == 1'b0) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 0 during data low write Ack field response!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Sent ACK to data low write\n", $time);
        SDA_I = 1'b0;      
        @ (negedge SCL);
        repeat(22) @(posedge clk);
        SDA_I = 1'b1;

        $write("%dns : bfm::slave_thread Info : cap_data_in %x\n", $time, cap_data_in);
      
        // =====================================================
        // C H E C K I N G   S T O P   C M D
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during sending stop!\n", $time);
        end
        if (SDA_O == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_O is 1 during sending stop!\n", $time);
        end
        @ (posedge SDA_O);
        if (SDA_T == 1'b0) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 0 during sending stop!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Received stop command.\n", $time);
        
        repeat(200) @(posedge clk);      

        
      // =========================================================================
      // H A N D L I N G   R E A D   O P E R A T I O N
      end else begin
        cap_opr = rd_op; 
        // Reached start of frame
        $write("%dns : bfm::slave_thread Info : Found start of frame(read)...\n", $time);
        if (SDA_T == 1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during start of frame(read) transmission!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : read operation.\n", $time);      

        // =====================================================
        // C A P T U R I N G   S L A V E   R E A D   A D D R E S S  ( 8 - B I T )
        for (integer i = 7; i >= 0; i--)  begin
          @ (posedge SCL);
          if (SDA_T == 1) begin
            $error("%dns : bfm::slave_thread Error : SDA_T is 1 during slave addr read field transmission!\n", $time);
          end
          cap_SLAVE_RD_ADDR[i] = SDA_O;
        end
        $write("%dns : bfm::slave_thread Info : cap_SLAVE_RD_ADDR %x\n", $time, cap_SLAVE_RD_ADDR);

        // =====================================================
        // R E P L Y   T O   A C K 
        @ (negedge SCL);
        repeat(27) @(posedge clk);
        if (SDA_T == 1'b0) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 0 during slave addr read Ack field response!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Sent ACK to slave addr read\n", $time);
        SDA_I = 1'b0;      
        @ (negedge SCL);
        repeat(22) @(posedge clk);
        SDA_I = 1'b1;

        // =====================================================
        // S E N D I N G   H I G H   D A T A  ( 8 - B I T )
        $write("%dns : bfm::slave_thread Info : rep_data_out %x\n", $time, rep_data_out);
        for (integer i = 15; i >= 8; i--)  begin
          SDA_I = rep_data_out[i];
          if (SDA_T == 0) begin
            $error("%dns : bfm::slave_thread Error : SDA_T is 0 during sending high data(read)!\n", $time);
          end
          @ (negedge SCL);
          repeat(23) @(posedge clk);
        end
        SDA_I = 1'b1;
      
        // =====================================================
        // C H E C K I N G   A C K 
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during sending ack for high data read!\n", $time);
        end
        if (SDA_O == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_O is 1 during sending ack for high data read!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Received ACK for high data read\n", $time);

        @ (negedge SCL);
        repeat(27) @(posedge clk);

        // =====================================================
        // S E N D I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 7; i >= 0; i--)  begin
          SDA_I = rep_data_out[i];
          if (SDA_T == 0) begin
            $error("%dns : bfm::slave_thread Error : SDA_T is 0 during sending low data(read)!\n", $time);
          end
          @ (negedge SCL);
          repeat(23) @(posedge clk);
        end
        SDA_I = 1'b1;
      
        // =====================================================
        // C H E C K I N G   N A C K
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during sending ack for low data read!\n", $time);
        end
        if (SDA_O == 1'b0) begin
          $error("%dns : bfm::slave_thread Error : SDA_O is 0 during sending ack for low data read!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Received NACK for low data read\n", $time);

        // =====================================================
        // C H E C K I N G   S T O P   C M D 
        @ (negedge SCL);
        @ (posedge SCL);
        if (SDA_T == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 1 during sending stop!\n", $time);
        end
        if (SDA_O == 1'b1) begin
          $error("%dns : bfm::slave_thread Error : SDA_O is 1 during sending stop!\n", $time);
        end
        @ (posedge SDA_O);
        if (SDA_T == 1'b0) begin
          $error("%dns : bfm::slave_thread Error : SDA_T is 0 during sending stop!\n", $time);
        end
        $write("%dns : bfm::slave_thread Info : Received stop command.\n", $time);
      end

      if (twire_monitor_h != null)
        twire_monitor_h.write_to_monitor(cap_opr, cap_SLAVE_WR_ADDR, cap_SLAVE_RD_ADDR, cap_reg_addr, cap_data_in, rep_data_out);
      $display("%dns : bfm::write2outmonitor cap_opr = %h  cap_SLAVE_WR_ADDR = %h  cap_SLAVE_RD_ADDR = %h  cap_reg_addr = %h  cap_data_in = %h  rep_data_out = %h", $time, cap_opr, cap_SLAVE_WR_ADDR, cap_SLAVE_RD_ADDR, cap_reg_addr, cap_data_in, rep_data_out);

      // =====================================================
      // T R I G G E R I N G   E V E N T
      $write("%dns : bfm::slave_thread Info : Triggering event monitor_event\n", $time);
      -> monitor_event;
    end
  end : slave_thread

 
endinterface : twire_bfm

