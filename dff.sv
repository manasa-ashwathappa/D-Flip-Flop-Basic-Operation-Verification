// D Flip-Flop with synchronous reset
module dff (dff_if dif);

  // Capture input on rising edge of clock
  always_ff @(posedge dif.clk) begin
    if (dif.rst)
      dif.dout <= 1'b0;     // Reset output on clock edge
    else
      dif.dout <= dif.din;  // Transfer input to output
  end

endmodule


// Interface for D Flip-Flop signals
interface dff_if;
  logic clk;
  logic rst;
  logic din;
  logic dout;
endinterface
