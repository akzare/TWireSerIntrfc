/***********************************************************************
  $FILENAME    : tb.svh

  $TITLE       : Testbench module

  $DATE        : 15 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This module defines the high level tester module
                 which schedules the entire test scenario.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class tb;

  // =================================================================
  // B F M   I N S T A N C E
  virtual twire_bfm bfm;

  // =================================================================
  // D R I V E R   I N S T A N C E
  driver   driver_h;

  // =================================================================
  // C O V E R A G E   I N S T A N C E
  coverage coverage_h;


  // =================================================================
  // C O N S T R U C T O R
  function new (virtual twire_bfm b);
    bfm = b;
  endfunction : new


  // =================================================================
  // M A I N   T E S T   P R O C E S S  
  task execute();
    coverage_h = new(bfm);
    driver_h   = new(bfm);

    fork
      coverage_h.execute();
      driver_h.execute();
    join_none
  endtask : execute

endclass : tb
