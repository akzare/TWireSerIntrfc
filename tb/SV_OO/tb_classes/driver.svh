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


class driver;

  // =================================================================
  // B F M   I N S T A N C E
  virtual twire_bfm bfm;

  
  // =================================================================
  // S C O R E B O A R D   I N S T A N C E
  scoreboard scoreboard_h;

  
  // =================================================================
  // I N T E R N A L   S I G N A L S

  // Number of transaction
  integer no_trans_cmds;

  integer wr_timeout;
  
  // ==========================================
  // S T I M U L I   S I G N A L S
  operation_t opr;
  bit [15:0]  reg_addr;
  bit [15:0]  data_in;
  bit [15:0]  data_out;
  
  // ==========================================
  // M O N I T O R   S I G N A L S
  operation_t cap_opr = wr_op;
  bit [7:0]  cap_SLAVE_WR_ADDR;
  bit [7:0]  cap_SLAVE_RD_ADDR;
  bit [15:0] cap_reg_addr;
  bit [15:0] cap_data_in;
  bit [15:0] rep_data_out;

  // ==========================================
  // M O N I T O R   E V E N T
  event monitor_event;
  

  
  // =================================================================
  // C O N S T R U C T O R
  function new (virtual twire_bfm b);
    bfm          = b;
    scoreboard_h = new();

    no_trans_cmds = 2;

    opr      = wr_op;
    reg_addr = 0;
    data_in  = 0;
    
    cap_opr           = wr_op;
    cap_SLAVE_WR_ADDR = 0;
    cap_SLAVE_RD_ADDR = 0;
    cap_reg_addr      = 0;
    cap_data_in       = 0;
    rep_data_out      = 0;
    
  endfunction : new


  // =================================================================
  // W R I T E   T R A N S A C T I O N
  task wrTrans();
  begin
     opr      = wr_op;
     reg_addr = $random();
     data_in  = $random();
     wr_timeout = 0;
     @ (posedge bfm.clk);
     bfm.rw       = 0;
     bfm.valid_in = 1;
     bfm.reg_addr = reg_addr;
     bfm.data_in  = data_in;
     $write("%dns : driver::wrTrans Writing address %x / data %x\n", $time, reg_addr, data_in);
     @ (posedge bfm.clk);
     bfm.valid_in = 0;
     while (bfm.busy == 0) begin
       @ (posedge bfm.clk);
   	   wr_timeout++;
   	   if (wr_timeout > 100) begin
         $error("%dns : wrTrans Warning : busy is 0 for more then 100 clocks\n", $time);
         repeat(20) @(posedge bfm.clk);
        $stop;
       end
     end
     wr_timeout = 0;

     while (bfm.busy == 1) begin
       @ (posedge bfm.clk);
   	   wr_timeout++;
       if (wr_timeout > 10000) begin
   	     $error("%dns : wrTrans Warning : busy is 1 for more then 10000 clocks\n", $time);
         repeat(20) @(posedge bfm.clk);
         $stop;
   	   end
     end
     wr_timeout = 0;
       
     $write("%dns : wrTrans Waiting for event monitor_event\n", $time);
     @ (monitor_event);

     bfm.reg_addr = 0;
     bfm.data_in  = 0;
     
     scoreboard_h.stimAdd(opr, reg_addr, data_in);
     scoreboard_h.monAdd(cap_opr, cap_SLAVE_WR_ADDR, cap_SLAVE_RD_ADDR, cap_reg_addr, cap_data_in);
  end
  endtask : wrTrans

  
  // =================================================================
  // R E A D   T R A N S A C T I O N
  task rdTrans();
  begin    
    opr          = rd_op;
    reg_addr     = $random();
    rep_data_out = $random();
    wr_timeout = 0;
    @ (posedge bfm.clk);
    bfm.rw       = 1;
    bfm.valid_in = 1;
    bfm.reg_addr = reg_addr;
    $write("%dns : driver::rdTrans Reading address %x\n", $time, bfm.reg_addr);
    @ (posedge bfm.clk);
    bfm.valid_in = 0;
    while (bfm.busy == 0) begin
      @ (posedge bfm.clk);
      wr_timeout++;
      if (wr_timeout > 100) begin
        $error("%dns : rdTrans Warning : busy is 0 for more then 100 clocks\n", $time);
        repeat(20) @(posedge bfm.clk);
   	    $stop;
      end
    end
    wr_timeout = 0;

    while (bfm.valid_out == 0) begin
      @ (posedge bfm.clk);
      wr_timeout++;
      if (wr_timeout > 10000) begin
        $error("%dns : rdTrans Warning : valid_out has not been reached for more then 10000 clocks\n", $time);
        repeat(20) @(posedge bfm.clk);
        $stop;
      end
    end
    wr_timeout = 0;
    data_out = bfm.data_out;
    
    $write("%dns : rdTrans Waiting for event monitor_event\n", $time);
    @ (monitor_event);

    bfm.reg_addr = 0;

    scoreboard_h.stimAdd(opr, reg_addr, data_out);
    scoreboard_h.monAdd(cap_opr, cap_SLAVE_WR_ADDR, cap_SLAVE_RD_ADDR, cap_reg_addr, rep_data_out);
    
  end
  endtask : rdTrans

  
  // =================================================================
  // T R A N S A C T I O N   M O N I T O R   A N D   R E P L Y   H A N D L E R
  task monitorHandler();
  begin
  	bit prev_sda_o = 0;
  	while (1) begin
      @ (negedge bfm.SCL);
      bfm.SDA_I = 1;

      // =====================================================
      // S E E K I N G   T H E   S T A R T   O F   F R A M E
      while (bfm.SDA_O == 1'b1) begin
        @ (negedge bfm.SCL); 
      end
      $write("%dns : driver::monitorHandler Info : Found start of frame(addr)...\n", $time);
      if (bfm.SDA_T == 1) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 1 during start of frame(addr) transmission!\n", $time);
      end
     
      // =====================================================
      // C A P T U R I N G   S L A V E   W R I T E   A D D R E S S   ( 8 - B I T )
      for (integer i = 7; i >= 0; i--)  begin
        @ (posedge bfm.SCL);
        if (bfm.SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during slave addr write field transmission!\n", $time);
        end
        cap_SLAVE_WR_ADDR[i] = bfm.SDA_O;
      end
      $write("%dns : driver::monitorHandler Info : cap_SLAVE_WR_ADDR %x\n", $time, cap_SLAVE_WR_ADDR);

      // =====================================================
      // R E P L Y   B Y   A C K 
      @ (negedge bfm.SCL);
      repeat(27) @(posedge bfm.clk);
      if (bfm.SDA_T == 1'b0) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 0 during slave addr write Ack field response!\n", $time);
      end
      $write("%dns : driver::monitorHandler Info : Sent ACK to slave addr write\n", $time);
      bfm.SDA_I = 1'b0;      
      @ (negedge bfm.SCL);
      repeat(22) @(posedge bfm.clk);
      bfm.SDA_I = 1'b1;
     
      // =====================================================
      // C A P T U R I N G   R E G I S T E R   A D D R E S S   H I G H   ( 8 - B I T )
      for (integer i = 15; i >= 8; i--)  begin
        @ (posedge bfm.SCL);
        if (bfm.SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during reg addr high field transmission!\n", $time);
        end
        cap_reg_addr[i] = bfm.SDA_O;
      end
     
      // =====================================================
      // R E P L Y   B Y   A C K  
      @ (negedge bfm.SCL);
      repeat(27) @(posedge bfm.clk);
      if (bfm.SDA_T == 1'b0) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 0 during reg addr high Ack field response!\n", $time);
      end
      $write("%dns : driver::monitorHandler Info : Sent ACK to reg addr high\n", $time);
      bfm.SDA_I = 1'b0;      
      @ (negedge bfm.SCL);
      repeat(22) @(posedge bfm.clk);
      bfm.SDA_I = 1'b1;
     
      // =====================================================
      // C A P T U R I N G   R E G I S T E R   A D D R E S S   L O W   ( 8 - B I T )
      for (integer i = 7; i >= 0; i--)  begin
        @ (posedge bfm.SCL);
        if (bfm.SDA_T == 1) begin
          $error("%dns : driver::monitorHandler Error : SDA_T is 1 during reg addr low field transmission!\n", $time);
        end
        cap_reg_addr[i] = bfm.SDA_O;
      end
     
      // =====================================================
      // R E P L Y   B Y   A C K 
      @ (negedge bfm.SCL);
      repeat(27) @(posedge bfm.clk);
      if (bfm.SDA_T == 1'b0) begin
        $error("%dns : driver::monitorHandler Error : SDA_T is 0 during reg addr low Ack field response!\n", $time);
      end
      $write("%dns : driver::monitorHandler Info : Sent ACK to reg addr low\n", $time);
      bfm.SDA_I = 1'b0;      
      @ (negedge bfm.SCL);
      repeat(22) @(posedge bfm.clk);
      bfm.SDA_I = 1'b1;

      $write("%dns : driver::monitorHandler Info : cap_reg_addr %x\n", $time, cap_reg_addr);

      @ (posedge bfm.SCL);
      prev_sda_o = bfm.SDA_O;
      @ (negedge bfm.SCL);

      // =========================================================================
      // H A N D L I N G   W R I T E   O P E R A T I O N
      if (bfm.SDA_O == prev_sda_o) begin 
        cap_opr = wr_op;
        $write("%dns : driver::monitorHandler Info : write operation.\n", $time);      
        cap_data_in[15] = bfm.SDA_O;

        // =====================================================
        // C A P T U R I N G   L O W   D A T A  ( 8 - B I T )
        for (integer i = 14; i >= 8; i--)  begin
          @ (posedge bfm.SCL);
          if (bfm.SDA_T == 1) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 1 during data high write field transmission!\n", $time);
          end
          cap_data_in[i] = bfm.SDA_O;
        end

        // =====================================================
        // R E P L Y   B Y   A C K 
  		@ (negedge bfm.SCL);
  		repeat(27) @(posedge bfm.clk);
  		if (bfm.SDA_T == 1'b0) begin
  		  $error("%dns : driver::monitorHandler Error : SDA_T is 0 during data high write Ack field response!\n", $time);
  		end
  		$write("%dns : driver::monitorHandler Info : Sent ACK to data high write\n", $time);
  		bfm.SDA_I = 1'b0;      
  		@ (negedge bfm.SCL);
  		repeat(22) @(posedge bfm.clk);
  		bfm.SDA_I = 1'b1;

  		// =====================================================
  		// C A P T U R I N G   L O W   D A T A  ( 8 - B I T )
  		for (integer i = 7; i >= 0; i--)  begin
  		  @ (posedge bfm.SCL);
  		  if (bfm.SDA_T == 1) begin
            $error("%dns : driver::monitorHandler Error : SDA_T is 1 during data low write field transmission!\n", $time);
  	      end
  	      cap_data_in[i] = bfm.SDA_O;
  		end

  		// =====================================================
  		// R E P L Y   B Y   A C K
  		@ (negedge bfm.SCL);
  		repeat(27) @(posedge bfm.clk);
  		if (bfm.SDA_T == 1'b0) begin
  	      $error("%dns : driver::monitorHandler Error : SDA_T is 0 during data low write Ack field response!\n", $time);
  		end
  		$write("%dns : driver::monitorHandler Info : Sent ACK to data low write\n", $time);
  		bfm.SDA_I = 1'b0;      
  		@ (negedge bfm.SCL);
  		repeat(22) @(posedge bfm.clk);
  		bfm.SDA_I = 1'b1;

  		$write("%dns : driver::monitorHandler Info : cap_data_in %x\n", $time, cap_data_in);
    
  		// =====================================================
  		// C H E C K I N G   S T O P   C M D
  		@ (posedge bfm.SCL);
  		if (bfm.SDA_T == 1'b1) begin
  	      $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending stop!\n", $time);
  		end
  		if (bfm.SDA_O == 1'b1) begin
  	      $error("%dns : driver::monitorHandler Error : SDA_O is 1 during sending stop!\n", $time);
  		end
  		@ (posedge bfm.SDA_O);
  		if (bfm.SDA_T == 1'b0) begin
  	      $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending stop!\n", $time);
  		end
  		$write("%dns : driver::monitorHandler Info : Received stop command.\n", $time);
      
  		repeat(200) @(posedge bfm.clk);      

      
  		// =========================================================================
  		// H A N D L I N G   R E A D   O P E R A T I O N
  		end else begin
          cap_opr = rd_op;
  		  // Reached start of frame
  		  $write("%dns : driver::monitorHandler Info : Found start of frame(read)...\n", $time);
  		  if (bfm.SDA_T == 1) begin
  			$error("%dns : driver::monitorHandler Error : SDA_T is 1 during start of frame(read) transmission!\n", $time);
  		  end
  		  $write("%dns : driver::monitorHandler Info : read operation.\n", $time);      

  		  // =====================================================
  		  // C A P T U R I N G   S L A V E   R E A D   A D D R E S S  ( 8 - B I T )
  		  for (integer i = 7; i >= 0; i--)  begin
  			@ (posedge bfm.SCL);
  			if (bfm.SDA_T == 1) begin
  			  $error("%dns : driver::monitorHandler Error : SDA_T is 1 during slave addr read field transmission!\n", $time);
  			end
  			cap_SLAVE_RD_ADDR[i] = bfm.SDA_O;
  		  end
  		  $write("%dns : driver::monitorHandler Info : cap_SLAVE_RD_ADDR %x\n", $time, cap_SLAVE_RD_ADDR);

  	      // =====================================================
  	      // R E P L Y   T O   A C K 
  	      @ (negedge bfm.SCL);
  	      repeat(27) @(posedge bfm.clk);
  	      if (bfm.SDA_T == 1'b0) begin
  		    $error("%dns : driver::monitorHandler Error : SDA_T is 0 during slave addr read Ack field response!\n", $time);
  	      end
  		  $write("%dns : driver::monitorHandler Info : Sent ACK to slave addr read\n", $time);
  		  bfm.SDA_I = 1'b0;      
  		  @ (negedge bfm.SCL);
  		  repeat(22) @(posedge bfm.clk);
  		  bfm.SDA_I = 1'b1;

  	      // =====================================================
  	      // S E N D I N G   H I G H   D A T A  ( 8 - B I T )
  	      $write("%dns : driver::monitorHandler Info : rep_data_out %x\n", $time, rep_data_out);
  	      for (integer i = 15; i >= 8; i--)  begin
  		    bfm.SDA_I = rep_data_out[i];
  	        if (bfm.SDA_T == 0) begin
  		      $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending high data(read)!\n", $time);
  			end
  			@ (negedge bfm.SCL);
  			repeat(23) @(posedge bfm.clk);
  		  end
  		  bfm.SDA_I = 1'b1;
    
  		  // =====================================================
  		  // C H E C K I N G   A C K 
  		  @ (posedge bfm.SCL);
  	      if (bfm.SDA_T == 1'b1) begin
  	        $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending ack for high data read!\n", $time);
  	      end
  	      if (bfm.SDA_O == 1'b1) begin
  	        $error("%dns : driver::monitorHandler Error : SDA_O is 1 during sending ack for high data read!\n", $time);
  	      end
  	      $write("%dns : driver::monitorHandler Info : Received ACK for high data read\n", $time);

  	      @ (negedge bfm.SCL);
  	      repeat(27) @(posedge bfm.clk);

  	      // =====================================================
  	      // S E N D I N G   L O W   D A T A  ( 8 - B I T )
  	      for (integer i = 7; i >= 0; i--)  begin
  	        bfm.SDA_I = rep_data_out[i];
  	        if (bfm.SDA_T == 0) begin
  	          $error("%dns : driver::monitorHandler Error : SDA_T is 0 during sending low data(read)!\n", $time);
  	        end
  	        @ (negedge bfm.SCL);
  	        repeat(23) @(posedge bfm.clk);
  	      end
  	      bfm.SDA_I = 1'b1;
    
  	      // =====================================================
  	      // C H E C K I N G   N A C K
  	      @ (posedge bfm.SCL);
  	      if (bfm.SDA_T == 1'b1) begin
  	        $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending ack for low data read!\n", $time);
  	      end
  	      if (bfm.SDA_O == 1'b0) begin
  	        $error("%dns : driver::monitorHandler Error : SDA_O is 0 during sending ack for low data read!\n", $time);
  	      end
  	      $write("%dns : driver::monitorHandler Info : Received NACK for low data read\n", $time);

  	      // =====================================================
  	      // C H E C K I N G   S T O P   C M D 
  	      @ (negedge bfm.SCL);
  	      @ (posedge bfm.SCL);
  	      if (bfm.SDA_T == 1'b1) begin
  	        $error("%dns : driver::monitorHandler Error : SDA_T is 1 during sending stop!\n", $time);
  	      end
  	      if (bfm.SDA_O == 1'b1) begin
  	        $error("%dns : driver::monitorHandler Error : SDA_O is 1 during sending stop!\n", $time);
  	      end
  	      @ (posedge bfm.SDA_O);
  	      if (bfm.SDA_T == 1'b0) begin
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

  
  // =================================================================
  // R A N D O M   O P R   G E N  
  protected function operation_t get_opr();
    bit rand_opr = $random;
    if (rand_opr == 1'b0)
      return wr_op;
    else
      return rd_op;
  endfunction : get_opr


  // =================================================================
  // M A I N   T E S T   T H R E A D  
  task testScheduler();
  begin
  	for (integer i = 0; i < no_trans_cmds; i++) begin
  	  opr = get_opr;
  	  if (opr == 1) begin
  	  	// ======================================================
  	  	// W R I T E   T R A N S A C T I O N
        wrTrans();
      end else begin  
      	// ======================================================
      	// R E A D    T R A N S A C T I O N
        rdTrans();
      end
      // ======================================================
      // C O M P A R E   R E S U L T S
      scoreboard_h.resCompare();
    end
  end
  endtask : testScheduler


  // =================================================================
  // M A I N   T E S T   P R O C E S S  
  task execute();
  begin
  	// ======================================================
  	// R E S E T   P H A S E
    bfm.reset_DUT();

    // ======================================================
    // S T A R T I N G   M O N I T O R
    $write("%dns : driver::Starting monitorHandler...\n", $time);
    fork
      monitorHandler();
    join_none

    // ======================================================
    // S T A R T I N G   T E S T   S C H E D U L E R
    $write("%dns : driver::Starting testScheduler...\n", $time);
    fork
      testScheduler();
    join

    // ======================================================
    // E N D I N G   T H E   S I M U L A T I O N
    repeat(500) @(posedge bfm.clk);
    $write("%dns : driver::Terminating simulations\n", $time);
    $stop;
  end
  endtask : execute


endclass : driver
