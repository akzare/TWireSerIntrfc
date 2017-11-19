/***********************************************************************
  $FILENAME    : sequence_item.svh

  $TITLE       : UVM sequence_item generator for input data flow to DUT

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : Defines some operations to generate some random sequence 
                 of data for supplying to the input of DUT.

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class sequence_item extends uvm_sequence_item;
  `uvm_object_utils(sequence_item);


  // =================================================================
  // C O N S T R U C T O R
  function new(string name = "");
    super.new(name);
  endfunction : new


  // Randomized stimuli
  rand operation_t stim_op;
  rand bit [15:0]  stim_reg_addr;
  rand bit [15:0]  stim_data_in;
  rand bit [15:0]  stim_data_out;


  constraint addrdata { stim_reg_addr dist {16'h0000:=1, [16'h0001 : 16'hFFFE]:=1, 16'hFFFF:=1};
                        stim_data_in  dist {16'h0000:=1, [16'h0001 : 16'hFFFE]:=1, 16'hFFFF:=1};
                        stim_data_out dist {16'h0000:=1, [16'h0001 : 16'hFFFE]:=1, 16'hFFFF:=1};
                      } 

  constraint op_con {stim_op dist {wr_op := 1, rd_op := 1};}

   
  // =================================================================
  // O V E R R I D E S   U V M   do_compare   M E T H O D
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    sequence_item tested;
    bit           same;
      
    if (rhs==null) `uvm_fatal(get_type_name(), 
                               "sequence_item::Tried to do comparison to a null pointer");
      
    if (!$cast(tested, rhs))
      same = 0;
    else
      if (stim_op == wr_op)
        same = super.do_compare(rhs, comparer) && 
                               (tested.stim_op       == stim_op) &&
                               (tested.stim_reg_addr == stim_reg_addr) &&
                               (tested.stim_data_in  == stim_data_in);
      else
        same = super.do_compare(rhs, comparer) && 
                               (tested.stim_op       == stim_op) &&
                               (tested.stim_reg_addr == stim_reg_addr) &&
                               (tested.stim_data_out == stim_data_out);
    return same;
  endfunction : do_compare


  // =================================================================
  // O V E R R I D E S   U V M   do_copy   M E T H O D
  function void do_copy(uvm_object rhs);
    sequence_item RHS;
    assert(rhs != null) else
        $fatal(1, "sequence_item::Tried to copy null transaction");
    super.do_copy(rhs);
    assert($cast(RHS, rhs)) else
        $fatal(1, "sequence_item::Failed cast in do_copy");
    stim_op       = RHS.stim_op;
    stim_reg_addr = RHS.stim_reg_addr;
    stim_data_in  = RHS.stim_data_in;
    stim_data_out = RHS.stim_data_out;
  endfunction : do_copy


  // =================================================================
  // O V E R R I D E S   U V M   convert2string   M E T H O D
  function string convert2string();
    string s;
    if (stim_op == wr_op)
      s = $sformatf("WR stim_reg_addr: %4h  stim_data_in: %4h", stim_reg_addr, stim_data_in);
    else
      s = $sformatf("RD stim_reg_addr: %4h  stim_data_out: %4h", stim_reg_addr, stim_data_out);
    return s;
  endfunction : convert2string

endclass : sequence_item

