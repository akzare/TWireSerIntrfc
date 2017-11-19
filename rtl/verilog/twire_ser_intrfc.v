/***********************************************************************
  $FILENAME    : twire_ser_intrfc.v

  $TITLE       : Master implementation of Two-Wire Serial Register Interface

  $DATE        : 15 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : The two-wire serial interface bus provides read/write 
                 access to control and status registers within a typical sensor 
                 chip.
                 The interface protocol utilizes a master and slave model. A master 
                 is in charge of controlling slave devices (i.e. sensors).

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)
                  (C) 2009 - Universitaet Potsdam (http://www.uni-potsdam.de/cs/)
                  (C) 2012 - Leibniz-Institut fuer Agrartechnik Potsdam-Bornim e.V.
                  https://www.atb-potsdam.de/de/institut/fachabteilungen/technik-im-pflanzenbau

************************************************************************/


//`include "sclk_gen.v"
//`include "ser2par_gen.v"

module TWireSerIntrfc #(
  parameter I2CCLK = 100, // Desired output serial clock rate (kHz)
  parameter SYSCLK = 100, // Input system clock rate (MHz)
  parameter [7:0] SLAVE_RD_ADDR = 8'h21, // The sensor device slave address (READ)
  parameter [7:0] SLAVE_WR_ADDR = 8'h20  // The sensor device slave address (WRITE)
)
(
  input         clk,       // Input system clock
  input         async_rst, // ASync input reset (low active)
  input         sync_rst,  // Sync input reset (high active)
  input         rw,        // Determines the type of desired operation: read/write -> 1/0
  input         valid_in,  // Indicates the validity of reg_addr and data_in signal. Assertion of
                           // a rising edge pulse on this signal forces the master controller
                           // to start a new transaction.
  input  [15:0] reg_addr,  // The target register address.
  input  [15:0] data_in,   // Input data which must be written into the specified register.
  output        valid_out, // A rising edge on this signal indicates the validity of
                           // the read data on data_out.
  output [15:0] data_out,  // The output of read transaction on the specified register
  output        busy,      // Indicates master FSM is in current progress 
                           // to accomplish the recent read/write transaction
  output        error,     // Presents an error condition during read/write transactions

  // Sensor interface
  // Data is transferred between the master and the slave on a bidirectional signal (SDATA).
  input         SDA_I,  // Data direction from sensor to master
  output        SDA_O,  // Data direction from master to sensor
  output        SDA_T,  // Tri-state buffer control
  output        SCL     // The master generates a clock (SCLK) that is an input 
                        // to the sensor and is used to synchronize transfers.
);

  // ==============================================================================
  // I N T E R N A L   C O N S T A N T S

  // Main state machine 
  // states definition
  parameter [23:0]
    WAIT_VALID           = 24'h000001,
    INIT_WRITE_START     = 24'h000002, 
    SEND_WRITE_START     = 24'h000004,
    SEND_WRITE_ADDR      = 24'h000008,
    RECV_WRITE_ADDR_ACK  = 24'h000010,
    SEND_HI_REG_ADDR     = 24'h000020,
    RECV_HI_REG_ADDR_ACK = 24'h000040,
    SEND_LO_REG_ADDR     = 24'h000080,
    RECV_LO_REG_ADDR_ACK = 24'h000100,
    SEND_HI_DATA         = 24'h000200,
    RECV_HI_DATA_ACK     = 24'h000400,
    SEND_LO_DATA         = 24'h000800,
    RECV_LO_DATA_ACK     = 24'h001000,
    STOP                 = 24'h002000,
    I2C_ERROR            = 24'h004000,
    INIT_READ_START      = 24'h008000,
    SEND_READ_START      = 24'h010000,
    SEND_READ_ADDR       = 24'h020000,
    RECV_READ_ADDR_ACK   = 24'h040000,
    RECV_HI_DATA         = 24'h080000,
    SEND_HI_DATA_ACK     = 24'h100000,
    RECV_LO_DATA         = 24'h200000,
    SEND_LO_DATA_NACK    = 24'h400000;


	
  // ==============================================================================
  // I N T E R N A L   S I G N A L S

  reg  [23:0] i2c_state = WAIT_VALID;      // FSM state register
  reg  [23:0] i2c_prev_state = WAIT_VALID; // FSM state register (one cycle delayed)
  reg  [23:0] i2c_next_state;


  reg         bit_cntr_rst = 1'b1;  // Bit counter reset
  reg  [2:0]  bit_cntr     = 8'h07; // Bit counter register


  wire        ticktock;          // Tick/Tock pulse
  reg         sclk_sync = 1'b0;  // Sync serial clock generator
  	
  wire        dbl_sclk;          // Double rated clock refer to sclk
  wire        dbl_sclk_d;        // Double rated clock delayed one system clock cycle
  wire        sclk;              // Generated serial clock
  reg         sclk_en = 1'b0;    // Signal to enable the serial clock generator
  reg         sdata = 1'b1;      // Generated internal serial data to be routed to output
  reg         tdata = 1'b1;      // Generated internal tri-state buffer control to be 
                                 // routed to output


  reg         ser2par_en = 1'b0;      // Signal to enable serial to parallel generator
  reg         ser2par_en_sync = 1'b0; // Sync version of the above signal


  wire        i2c_valid_out;
  reg         i2c_valid_out_d = 1'b0;
  reg         validout = 1'b0;
  reg  [1:0]  valid;
  reg         i2c_valid_in = 1'b0;
  reg         i2c_failed = 1'b0;


  reg         busy0 = 1'b0;     // Keeps output busy as far as FSM is progressing
  reg         busy1 = 1'b0;     // Rises output busy as soon as valid_is is high

  reg         sda_i_d = 1'b1;   // One cycle delayed SDA_I


  // ==============================================================================
  // S E R I A L   C L O C K   G E N E R A T O R
  sclk_gen #(
    I2CCLK,
    SYSCLK
  )
  u_sclk_gen
  (
    .clk       (clk),
    .async_rst (async_rst),
    .sync_rst  (sync_rst),
    .sclk_en   (sclk_en),
    .sclk_sync (sclk_sync),
    .dbl_sclk  (dbl_sclk),
    .dbl_sclk_d(dbl_sclk_d),
    .sclk      (sclk),
    .ticktock  (ticktock)
  );


  // ==============================================================================
  // S E R I A L   T O   P A R A L L E L   C O N V E R T E R
  ser2par_gen u_ser2par_gen
  (
    .clk       (clk),
    .dbl_sclk  (dbl_sclk),
    .dbl_sclk_d(dbl_sclk_d),
    .async_rst (async_rst),
    .sync_rst  (sync_rst),
    .ser2par_en(ser2par_en_sync),
    .ser_in    (SDA_I),
    .valid     (i2c_valid_out),
    .par_out   (data_out)		
  );


  // ==============================================================================
  // I N P U T / O U T P U T   V A L I D   S I G N A L S   H A N D L E R
  always @(posedge clk or negedge async_rst)
  begin : IN_OUT_VALID_HANDLER
    if (!async_rst) begin
      i2c_valid_out_d <= 1'b0;
      validout     <= 1'b0;
      i2c_valid_in <= 1'b0;
      sclk_sync    <= 1'b0;
    end else if (sync_rst) begin
      i2c_valid_out_d <= 1'b0;
      validout     <= 1'b0;
      i2c_valid_in <= 1'b0;
      sclk_sync    <= 1'b0;
    end else begin

      // =============================================
      // S E R I A L   T O   P A R A L L E L   E  N
      if (ser2par_en && sclk) begin
        ser2par_en_sync <= 1'b1;
      end else begin
        ser2par_en_sync <= 1'b0;
      end

      sclk_sync <= 1'b0;

      // =============================================
      // V A L I D   I N
      // The following logic detects the valid_in input and makes an internal
      // with longer durarion enough for triggering the FSM. The input valid_in 
      // input can be as short as only one clk cycle.
      valid = {valid_in,i2c_valid_in};
      case(valid)
        2'b00 : 
        begin
          i2c_valid_in <= 1'b0;
        end

        2'b01 : 
        begin
          if (ticktock == 1'b1) begin
            i2c_valid_in <= 1'b0;
          end else begin
            i2c_valid_in <= 1'b1;
          end
        end

        2'b10 :
        begin
          i2c_valid_in <= 1'b1;
          sclk_sync <= 1'b1;
        end

        default : 
        begin
          i2c_valid_in <= i2c_valid_in;
        end
      endcase

      // =============================================
      // V A L I D   O U T
      // Asster validout for only one clk cycle
      if (i2c_valid_out == 1'b1) begin
        if (i2c_valid_out_d == 1'b0) begin
          validout <= 1'b1;
        end else begin
          validout <= 1'b0;
        end
        i2c_valid_out_d <= 1'b1;
      end else begin
        validout <= 1'b0;
        i2c_valid_out_d <= 1'b0;
      end

    end
  end // End Of IN_OUT_VALID_HANDLER


  // ==============================================================================
  // S E R I A L   B I T   C O U N T E R   H A N D L E R
  always @(posedge clk or negedge async_rst)
  begin : SER_BIT_CNTR_HANDLER
    if (!async_rst) begin
      bit_cntr    <= 8'h07;
    end else if (sync_rst) begin
      bit_cntr    <= 8'h07;
    end else begin
      // Sync to the falling edge of dbl_sclk
      if (dbl_sclk == 1'b0 && dbl_sclk_d == 1'b1) begin
        if (bit_cntr_rst == 1'b1) begin
          bit_cntr <= 8'h07;
        end else if ((i2c_state == i2c_prev_state) && (sclk == 1'b0)) begin
          if (bit_cntr == 8'h00) begin
            bit_cntr <= 8'h07;
          end else begin
            bit_cntr <= bit_cntr-1;
          end
        end

      end
    end
  end // End Of SER_BIT_CNTR_HANDLER



  // ==============================================================================
  // S Y N C   F A I L U R E   S I G N A L   G E N E R A T O R
  always @(posedge clk or negedge async_rst)
  begin : SYNC_FAILURE_GEN
    if (!async_rst) begin
      i2c_failed <= 1'b0;
    end else if (sync_rst) begin
      i2c_failed <= 1'b0;
    end else begin
      // Sync to the falling edge of dbl_sclk
      if (dbl_sclk == 1'b0 && dbl_sclk_d == 1'b1) begin

        case(i2c_state)
          WAIT_VALID : 
          begin
            i2c_failed <= i2c_failed;
          end

          I2C_ERROR : 
          begin
            i2c_failed <= 1'b1;
          end

          default : 
          begin
            i2c_failed <= 1'b0;
          end
        endcase
      end
    end
  end // End Of SYNC_FAILURE_GEN



  // ==============================================================================
  // I 2 C   B U S Y   S I G N A L   G E N E R A T O R 
  always @(posedge clk or negedge async_rst)
  begin : BUSY_GEN
    if (!async_rst) begin
      busy1 <= 1'b0;
    end else if (sync_rst) begin
      busy1 <= 1'b0;
    end else begin
      if (i2c_state == WAIT_VALID) begin
        if (valid_in == 1'b1) begin
          busy1 <= 1'b1;
        end else begin
          busy1 <= busy1;
        end
      end else begin
        busy1 <= 1'b0;
      end
    end
  end // End Of BUSY_GEN



  // ==============================================================================
  // I 2 C   M I A N   F S M   S E Q
  always @(posedge clk or negedge async_rst)
  begin : MAIN_FSM
    if (!async_rst) begin
      i2c_state  <= WAIT_VALID;
      i2c_prev_state <= WAIT_VALID;
    end else if (sync_rst) begin
      i2c_state  <= WAIT_VALID;
      i2c_prev_state <= WAIT_VALID;
    end else begin
      // State machine goes one step ahead based on the falling edge of dbl_sclk
      if (dbl_sclk == 1'b0 && dbl_sclk_d == 1'b1) begin
        i2c_prev_state <= i2c_state;
        i2c_state      <= i2c_next_state;
	
         // One cycle delayed serial data output
         sda_i_d <= SDA_I;
      end
    end
  end // End Of MAIN_FSM



  // ==============================================================================
  // I 2 C   M I A N   F S M   C O M B 
  always @(i2c_state or i2c_valid_in or sclk or bit_cntr or SDA_I or sda_i_d or rw)
  begin : FSM_COMBO
    case(i2c_state)
      WAIT_VALID : 
      begin
        if (i2c_valid_in == 1'b1) begin
          i2c_next_state = INIT_WRITE_START;
        end else begin
          i2c_next_state = WAIT_VALID;
        end
      end
               
      INIT_WRITE_START : 
      begin
        i2c_next_state = SEND_WRITE_START;
      end

      SEND_WRITE_START :
      begin
        i2c_next_state = SEND_WRITE_ADDR;
      end

      SEND_WRITE_ADDR :
      begin
        if (bit_cntr == 8'h00 && sclk == 1'b0) begin
          i2c_next_state = RECV_WRITE_ADDR_ACK;
        end else begin
          i2c_next_state = SEND_WRITE_ADDR;
        end
      end
		  
      RECV_WRITE_ADDR_ACK :
      begin
        if (sclk == 1'b0) begin
          if (sda_i_d == 1'b0) begin
            i2c_next_state = SEND_HI_REG_ADDR;
          end else begin
            i2c_next_state = I2C_ERROR;
          end 
        end else begin
          i2c_next_state = RECV_WRITE_ADDR_ACK;
        end 
      end

      SEND_HI_REG_ADDR :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 )	begin
          i2c_next_state = RECV_HI_REG_ADDR_ACK;
        end else begin
          i2c_next_state = SEND_HI_REG_ADDR;
        end 
      end
		  
      RECV_HI_REG_ADDR_ACK :
      begin
        if ( sclk == 1'b0 ) begin
          if ( sda_i_d == 1'b0 ) begin
            i2c_next_state = SEND_LO_REG_ADDR;
          end else begin
            i2c_next_state = I2C_ERROR;
          end 
        end else begin
          i2c_next_state = RECV_HI_REG_ADDR_ACK;
        end 
      end

      SEND_LO_REG_ADDR :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 ) begin
          i2c_next_state = RECV_LO_REG_ADDR_ACK;
        end else begin
          i2c_next_state = SEND_LO_REG_ADDR;
        end 
      end
		  
      RECV_LO_REG_ADDR_ACK :
      begin
        if ( sclk == 1'b0 ) begin
          if ( sda_i_d == 1'b0 ) begin
            if ( rw == 1'b1 ) begin
              i2c_next_state = INIT_READ_START;
            end else begin
              i2c_next_state = SEND_HI_DATA;
            end 
          end else begin
            i2c_next_state = I2C_ERROR;
          end 
        end else begin
          i2c_next_state = RECV_LO_REG_ADDR_ACK;
        end 
      end

      SEND_HI_DATA :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 ) begin
          i2c_next_state = RECV_HI_DATA_ACK;
        end else begin
          i2c_next_state = SEND_HI_DATA;
        end 
      end
		  
      RECV_HI_DATA_ACK :
      begin
        if ( sclk == 1'b0 ) begin
          if ( sda_i_d == 1'b0 ) begin
            i2c_next_state = SEND_LO_DATA;
          end else begin
            i2c_next_state = I2C_ERROR;
          end 
        end else begin
          i2c_next_state = RECV_HI_DATA_ACK;
        end 
      end

      SEND_LO_DATA :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 ) begin
          i2c_next_state = RECV_LO_DATA_ACK;
        end else begin
          i2c_next_state = SEND_LO_DATA;
        end 
      end
		  
      RECV_LO_DATA_ACK :
      begin
        if ( sclk == 1'b0 ) begin
          if ( sda_i_d == 1'b0 ) begin
            i2c_next_state = STOP;
          end else begin
            i2c_next_state = I2C_ERROR;
          end 
        end else begin
          i2c_next_state = RECV_LO_DATA_ACK;
        end 
      end

      INIT_READ_START :
      begin
        i2c_next_state = SEND_READ_START;
      end
		  
      SEND_READ_START :
      begin
        i2c_next_state = SEND_READ_ADDR;
      end

      SEND_READ_ADDR :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 ) begin
          i2c_next_state = RECV_READ_ADDR_ACK;
        end else begin
          i2c_next_state = SEND_READ_ADDR;
        end 
      end
		  
      RECV_READ_ADDR_ACK :
      begin
        if ( sclk == 1'b0 ) begin
          if ( sda_i_d == 1'b0 ) begin
            i2c_next_state = RECV_HI_DATA;
          end else begin
            i2c_next_state = I2C_ERROR;
          end 
        end else begin
          i2c_next_state = RECV_READ_ADDR_ACK;
        end 
      end

      RECV_HI_DATA :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 ) begin
          i2c_next_state = SEND_HI_DATA_ACK;
        end else begin
          i2c_next_state = RECV_HI_DATA;
        end 
      end
		  
      SEND_HI_DATA_ACK :
      begin
        if ( sclk == 1'b0 ) begin
          i2c_next_state = RECV_LO_DATA;
        end else begin
          i2c_next_state = SEND_HI_DATA_ACK;
        end 
      end

      RECV_LO_DATA :
      begin
        if ( bit_cntr == 8'h00 && sclk == 1'b0 ) begin
          i2c_next_state = SEND_LO_DATA_NACK;
        end else begin
          i2c_next_state = RECV_LO_DATA;
        end 
      end
		  
      SEND_LO_DATA_NACK :
      begin
        if ( sclk == 1'b0 ) begin
          i2c_next_state = STOP;
        end else begin
          i2c_next_state = SEND_LO_DATA_NACK;
        end 
      end

      STOP :
      begin
        i2c_next_state = WAIT_VALID;
      end

      I2C_ERROR :
      begin
        i2c_next_state = WAIT_VALID;
      end
		
      default : 
      begin
        i2c_next_state = WAIT_VALID;
      end
    endcase		  
  end // End Of FSM_COMBO


  // ==============================================================================
  // I 2 C   M I A N   F S M   O U T P U T
  always @ (i2c_state or bit_cntr)
  begin : FSM_OUTPUT
    case(i2c_state)
      WAIT_VALID : 
      begin
        busy0         <= 1'b0;
        sdata         <= 1'b1;
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1;
        sclk_en       <= 1'b0;
        ser2par_en    <= 1'b0;
      end

      INIT_WRITE_START : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      SEND_WRITE_START : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b0; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      SEND_WRITE_ADDR : 
      begin
        busy0         <= 1'b1;
        sdata         <= SLAVE_WR_ADDR[bit_cntr]; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      RECV_WRITE_ADDR_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      SEND_HI_REG_ADDR : 
      begin
        busy0         <= 1'b1;
        sdata         <= reg_addr[bit_cntr+8]; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
       end

      RECV_HI_REG_ADDR_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      SEND_LO_REG_ADDR : 
      begin
        busy0         <= 1'b1;
        sdata         <= reg_addr[bit_cntr]; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      RECV_LO_REG_ADDR_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      SEND_HI_DATA : 
      begin
        busy0         <=  1'b1;
        sdata         <=  data_in[bit_cntr+8]; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      RECV_HI_DATA_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      SEND_LO_DATA : 
      begin
        busy0         <= 1'b1;
        sdata         <= data_in[bit_cntr]; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      RECV_LO_DATA_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
      
      INIT_READ_START : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      SEND_READ_START : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b0; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      SEND_READ_ADDR : 
      begin
        busy0         <= 1'b1;
        sdata         <= SLAVE_RD_ADDR[bit_cntr]; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end
	  
      RECV_READ_ADDR_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      RECV_HI_DATA : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b1;
      end

      SEND_HI_DATA_ACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b0; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      RECV_LO_DATA : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b0; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b1;
      end

      SEND_LO_DATA_NACK : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b1; 
        ser2par_en    <= 1'b0;
      end

      STOP : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b0; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b0; 
        ser2par_en    <= 1'b0;
      end

      I2C_ERROR : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b0; 
        tdata         <= 1'b0;
        bit_cntr_rst  <= 1'b1; 
        sclk_en       <= 1'b0; 
        ser2par_en    <= 1'b0;
      end

      default : 
      begin
        busy0         <= 1'b1;
        sdata         <= 1'b1; 
        tdata         <= 1'b1;
        bit_cntr_rst  <= 1'b1;
        sclk_en       <= 1'b0;
        ser2par_en    <= 1'b0;
      end
    endcase
  end // End Of FSM_OUTPUT


  // ==============================================================================
  // C O M B
  assign valid_out = validout;
  assign error = i2c_failed;
  assign busy  = busy0 | busy1;
  assign SCL   = sclk;
  assign SDA_O = sdata;
  assign SDA_T = tdata; 

endmodule
