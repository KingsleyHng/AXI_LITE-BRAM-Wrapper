module bram_single_port #(
    parameter ADDR_WIDTH = 10, // 2^10 = 1024 locations
    parameter DATA_WIDTH = 32  // 32-bit data width
) (
    input wire clk,
    input wire we,              // Write enable (1 = write, 0 = read)
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] din,  // Data input (for writing)
    output reg [DATA_WIDTH-1:0] dout  // Data output (for reading)
);

    // BRAM memory array
    reg [DATA_WIDTH-1:0] bram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (we)
            bram[addr] <= din;  // Write operation
        else
            dout <= bram[addr];  // Read operation
    end

endmodule