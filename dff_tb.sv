//=================== Transaction =====================
class dff_transaction;
  rand bit din;
       bit dout;

  // Copy constructor
  function dff_transaction clone();
    clone = new();
    clone.din  = this.din;
    clone.dout = this.dout;
  endfunction

  function void display(input string tag);
    $display("[%0t] [%0s]: DIN=%0b DOUT=%0b", $time, tag, din, dout);
  endfunction
endclass


//=================== Generator =======================
class dff_generator;
  dff_transaction trans;
  mailbox #(dff_transaction) drv_mbx;
  mailbox #(dff_transaction) ref_mbx;

  int count;
  event done, sync_evt;

  function new(mailbox #(dff_transaction) drv_mbx,
               mailbox #(dff_transaction) ref_mbx);
    this.drv_mbx = drv_mbx;
    this.ref_mbx = ref_mbx;
    trans = new();
  endfunction

  task run();
    repeat (count) begin
      assert(trans.randomize) else $error("[GEN] Randomization failed");
      drv_mbx.put(trans);
      ref_mbx.put(trans);
      trans.display("GEN");
      @(sync_evt);
    end
    ->done;
  endtask
endclass


//=================== Driver ==========================
class dff_driver;
  virtual dff_if dif;
  mailbox #(dff_transaction) drv_mbx;
  dff_transaction trans;

  function new(mailbox #(dff_transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction

  task apply_reset();
    dif.rst <= 1'b1;
    repeat (4) @(posedge dif.clk);
    dif.rst <= 1'b0;
    $display("[%0t] [DRV] Reset Deasserted", $time);
  endtask

  task run();
    forever begin
      drv_mbx.get(trans);
      dif.din <= trans.din;
      @(posedge dif.clk);
      trans.display("DRV");
    end
  endtask
endclass


//=================== Monitor =========================
class dff_monitor;
  virtual dff_if dif;
  mailbox #(dff_transaction) mon_mbx;

  function new(mailbox #(dff_transaction) mon_mbx);
    this.mon_mbx = mon_mbx;
  endfunction

  task run();
    dff_transaction trans;
    forever begin
      @(posedge dif.clk);
      trans = new();
      trans.din  = dif.din;
      trans.dout = dif.dout;
      mon_mbx.put(trans);
      trans.display("MON");
    end
  endtask
endclass


//=================== Scoreboard ======================
class dff_scoreboard;
  mailbox #(dff_transaction) mon_mbx;
  mailbox #(dff_transaction) ref_mbx;
  dff_transaction mon_trans, ref_trans;
  event sync_evt;

  function new(mailbox #(dff_transaction) mon_mbx,
               mailbox #(dff_transaction) ref_mbx);
    this.mon_mbx = mon_mbx;
    this.ref_mbx = ref_mbx;
  endfunction

  task run();
    forever begin
      mon_mbx.get(mon_trans);
      ref_mbx.get(ref_trans);
      if (mon_trans.dout === ref_trans.din)
        $display("[%0t] [SCO] PASS: Output matched expected value", $time);
      else
        $display("[%0t] [SCO] FAIL: Output mismatch", $time);
      ->sync_evt;
    end
  endtask
endclass


//=================== Environment =====================
class dff_env;
  dff_generator gen;
  dff_driver drv;
  dff_monitor mon;
  dff_scoreboard sco;

  mailbox #(dff_transaction) drv_mbx, mon_mbx, ref_mbx;
  event sync_evt;
  virtual dff_if dif;

  function new(virtual dff_if dif);
    this.dif = dif;

    drv_mbx = new();
    mon_mbx = new();
    ref_mbx = new();

    gen = new(drv_mbx, ref_mbx);
    drv = new(drv_mbx);
    mon = new(mon_mbx);
    sco = new(mon_mbx, ref_mbx);

    drv.dif = this.dif;
    mon.dif = this.dif;

    gen.sync_evt = sync_evt;
    sco.sync_evt = sync_evt;
  endfunction

  task run();
    drv.apply_reset();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
    wait(gen.done.triggered);
    $display("[%0t] [ENV] Simulation completed successfully", $time);
    $finish;
  endtask
endclass


//=================== Testbench =======================
module tb;
  
  dff_if dif();
  
  dff dut(dif);


  // Clock Generation
  initial begin
    dif.clk <= 0;
  end
  
  always #10 dif.clk = ~dif.clk;
  
  dff_env env;
  
  // Environment Setup
  initial begin
    env = new(dif);
    env.gen.count = 20;
    env.run();
  end

  // Dumpfile setup
  initial begin
    $dumpfile("dff.vcd");
    $dumpvars;
  end
endmodule
