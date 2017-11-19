/***********************************************************************
  $FILENAME    : twire_transaction.svh

  $TITLE       : User defined transaction class on FIFO output data flow

  $DATE        : 18 Nov 2017

  $VERSION     : 1.0.0

  $DESCRIPTION : This class provides the transaction recording support
                 on the output data flow of the FIFO

  $AUTHOR     : Armin Zare Zadeh (ali.a.zarezadeh @ gmail.com)

************************************************************************/


class twire_transaction extends uvm_transaction;

  // Read data value out of DUT
  bit        cap_opr;
  bit [7:0]  cap_SLAVE_WR_ADDR;
  bit [7:0]  cap_SLAVE_RD_ADDR;
  bit [15:0] cap_reg_addr;
  bit [15:0] cap_data_in;
  bit [15:0] rep_data_out;


  // =================================================================
  // C O N S T R U C T O R
  function new(string name = "");
    super.new(name);
  endfunction : new


  // =================================================================
  // O V E R R I D E S   U V M   do_copy   M E T H O D
  // This method is used to copy all the properties of a twire_transaction
  // object. 
  //
  function void do_copy(uvm_object rhs);
    twire_transaction copied_transaction_h;
    assert(rhs != null) else
        $fatal(1, "twire_transaction::Tried to copy null transaction");
    super.do_copy(rhs);
    assert($cast(copied_transaction_h,rhs)) else
        $fatal(1, "twire_transaction::Faied cast in do_copy");
    cap_opr           = copied_transaction_h.cap_opr;
    cap_SLAVE_WR_ADDR = copied_transaction_h.cap_SLAVE_WR_ADDR;
    cap_SLAVE_RD_ADDR = copied_transaction_h.cap_SLAVE_RD_ADDR;
    cap_reg_addr      = copied_transaction_h.cap_reg_addr;
    cap_data_in       = copied_transaction_h.cap_data_in;
    rep_data_out      = copied_transaction_h.rep_data_out;
  endfunction : do_copy


  // =================================================================
  // O V E R R I D E S   U V M   convert2string   M E T H O D
  // This method is used to convert each property of the twire_transaction 
  // object into a string.
  function string convert2string();
    string s;
    if (cap_opr == wr_op)
      s = $sformatf("WR cap_SLAVE_WR_ADDR: %2h  cap_reg_addr: %4h  cap_data_in: %4h", cap_SLAVE_WR_ADDR, cap_reg_addr, cap_data_in);
    else
      s = $sformatf("RD cap_SLAVE_WR_ADDR: %2h  cap_SLAVE_RD_ADDR: %4h  cap_reg_addr: %4h  rep_data_out: %4h", cap_SLAVE_WR_ADDR, cap_SLAVE_RD_ADDR, cap_reg_addr, rep_data_out);
    return s;
  endfunction : convert2string


  // =================================================================
  // O V E R R I D E S   U V M   do_compare   M E T H O D
  // This method is used to compare each property of the twire_transaction object.
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    twire_transaction RHS;
    bit    same;
    assert(rhs != null) else
        $fatal(1, "twire_transaction::Tried to copare null transaction");

    same = super.do_compare(rhs, comparer);

    $cast(RHS, rhs);
    if (cap_opr == wr_op)
      same = (cap_opr == RHS.cap_opr) &&
             (cap_SLAVE_WR_ADDR == RHS.cap_SLAVE_WR_ADDR) &&  
             (cap_reg_addr == RHS.cap_reg_addr) &&  
             (cap_data_in == RHS.cap_data_in) &&  
             same;
    else
      same = (cap_opr == RHS.cap_opr) &&
             (cap_SLAVE_WR_ADDR == RHS.cap_SLAVE_WR_ADDR) &&  
             (cap_SLAVE_RD_ADDR == RHS.cap_SLAVE_RD_ADDR) &&  
             (cap_reg_addr == RHS.cap_reg_addr) &&  
             (rep_data_out == RHS.rep_data_out) &&  
             same;
    return same;
  endfunction : do_compare


endclass : twire_transaction

