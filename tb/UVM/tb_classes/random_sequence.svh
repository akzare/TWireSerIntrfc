/***********************************************************************
  $FILENAME    : random_sequence.svh

  $TITLE       : Random sequence generator for FIFO verification

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This class utilises an instance of the sequence_item 
                 to serialize random values into FIFO.

************************************************************************/


class random_sequence extends uvm_sequence #(sequence_item);
  `uvm_object_utils(random_sequence);

  
  // =================================================================
  // U V M   S E Q U E N C E   I T E M   F O R   S T I M U L I
  sequence_item stimuli;


  // =================================================================
  // C O N S T R U C T O R
  function new(string name = "random_sequence");
    super.new(name);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   b o d y   M E T H O D
  // This method initiates pushing a sequence of stimulus continously 
  // into DUT. The number of the iterations is determined 
  // by the TEST_NUM_ITER parameter.
  //
  integer i = 0;
  task body();
    repeat (TEST_NUM_ITER) begin : random_loop
      $display("%dns : random_sequence::iter# %2d", $time, i);
      stimuli = sequence_item::type_id::create("stimuli");
      start_item(stimuli);
      assert(stimuli.randomize());
      finish_item(stimuli);
      i++;
    end : random_loop
  endtask : body


endclass : random_sequence

