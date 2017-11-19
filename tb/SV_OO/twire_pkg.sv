/***********************************************************************
  $FILENAME    : twire_pkg.svh

  $TITLE       : Package definition

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This package include some common code to be shared 
                 across multiple modules in the verification system. 

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


package twire_pkg;

  // I2C clock rate (kHz)
  parameter I2CCLK = 400;
  // System clock rate (MHz)
  parameter SYSCLK = 100;
  // Sensor slave read address
  parameter [7:0] SLAVE_RD_ADDR = 8'h21;
  // Sensor slave write address
  parameter [7:0] SLAVE_WR_ADDR = 8'h20;
  
  
  // Read/Write operations
  typedef enum bit {
    wr_op  = 1'b0,
    rd_op  = 1'b1
  } operation_t;
  
  
  `include "coverage.svh"
  `include "scoreboard.svh"
  `include "driver.svh"
  `include "tb.svh"

endpackage : twire_pkg
