`timescale 1ns / 1ps
`include "BRAM.v"

module axi_bram_wrapper_tb();

    // Parameters
    localparam C_S_AXI_DATA_WIDTH = 32;
    localparam C_S_AXI_ADDR_WIDTH = 10;
    localparam BRAM_DEPTH = 1024;
    localparam CLK_PERIOD = 10; // 100MHz clock
    localparam NUM_TRANSACTIONS = 10; // Number of random transactions to perform

    // Signals
    logic s_axi_aclk;
    logic s_axi_aresetn;
    
    // Write Address Channel
    logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [2:0] s_axi_awprot;
    logic s_axi_awvalid;
    logic s_axi_awready;
    
    // Write Data Channel
    logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    logic s_axi_wvalid;
    logic s_axi_wready;
    
    // Write Response Channel
    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready;
    
    // Read Address Channel
    logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic [2:0] s_axi_arprot;
    logic s_axi_arvalid;
    logic s_axi_arready;
    
    // Read Data Channel
    logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready;

    // Memory array to store written data for verification
    logic [C_S_AXI_DATA_WIDTH-1:0] test_memory[BRAM_DEPTH];

    // Instantiate DUT
    axi_bram_wrapper #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .BRAM_DEPTH(BRAM_DEPTH)
    ) dut (.*);

    // Clock generation
    initial begin
        s_axi_aclk = 0;
        forever #(CLK_PERIOD/2) s_axi_aclk = ~s_axi_aclk;
    end

    // Task for AXI write transaction
    task automatic axi_write(
        input [C_S_AXI_ADDR_WIDTH-1:0] addr,
        input [C_S_AXI_DATA_WIDTH-1:0] data
    );
        // Initialize write signals
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid <= 1'b0;
        s_axi_bready <= 1'b0;
        
        // Write Address Phase
        @(posedge s_axi_aclk);
        s_axi_awaddr <= addr;
        s_axi_awprot <= 3'b000;
        s_axi_wvalid <= 1'b1;      
        s_axi_awvalid <= 1'b1;
        s_axi_wdata <= data; 
        s_axi_wstrb <= 4'b1111;
        
        // Wait for AWREADY
        wait(s_axi_awready && s_axi_wready);
        @(posedge s_axi_aclk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid <= 1'b0;

        // Write Response Phase
        s_axi_bready <= 1'b1;
        wait(s_axi_bvalid);
        @(posedge s_axi_aclk);
        s_axi_bready <= 1'b0;
        
        // Store written data for verification
        test_memory[addr[C_S_AXI_ADDR_WIDTH-1:2]] = data;
        
        // Add some delay between transactions
        repeat(2) @(posedge s_axi_aclk);
    endtask

    // Task for AXI read transaction
    task automatic axi_read(
        input [C_S_AXI_ADDR_WIDTH-1:0] addr,
        input [C_S_AXI_DATA_WIDTH-1:0] expected_data
    );
        // Initialize read signals
        s_axi_arvalid <= 1'b0;
        s_axi_rready <= 1'b0;

        // Read Address Phase
        @(posedge s_axi_aclk);
        s_axi_araddr <= addr;
        s_axi_arprot <= 3'b000;
        s_axi_arvalid <= 1'b1;
      
        wait(s_axi_arready);
        s_axi_rready <= 1'b1;
      
        wait(~s_axi_arready);
        s_axi_arvalid <= 1'b0;   
      
        if (s_axi_rdata === expected_data) begin
            $display("PASS: Addr=0x%h, Read data=0x%h matches expected data", 
                    addr, s_axi_rdata);
        end else begin
            $display("FAIL: Addr=0x%h, Read data=0x%h does not match expected=0x%h", 
                    addr, s_axi_rdata, expected_data);
        end
      
        wait(~s_axi_rvalid);
        s_axi_rready <= 1'b0;
        
        repeat(2) @(posedge s_axi_aclk);
    endtask

    // Function to generate random word-aligned address
    function [C_S_AXI_ADDR_WIDTH-1:0] get_random_addr();
        logic [C_S_AXI_ADDR_WIDTH-1:0] rand_addr;
        rand_addr = $urandom % (BRAM_DEPTH-1);
        // Word align the address (multiply by 4)
        return {rand_addr[C_S_AXI_ADDR_WIDTH-1:2], 2'b00};
    endfunction

    // Test stimulus
    initial begin
        // Initialize signals
        s_axi_aresetn = 0;
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        s_axi_awaddr = 0;
        s_axi_wdata = 0;
        s_axi_araddr = 0;

        // Reset sequence
        repeat(5) @(posedge s_axi_aclk);
        s_axi_aresetn = 1;
        repeat(5) @(posedge s_axi_aclk);

        // Random Write-Read Test Cases
        $display("\nStarting Random Write-Read Test Cases");
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            logic [C_S_AXI_ADDR_WIDTH-1:0] rand_addr;
            logic [C_S_AXI_DATA_WIDTH-1:0] rand_data;
            
            // Generate random address and data
            rand_addr = get_random_addr();
            rand_data = $urandom;
            
            $display("\nTest Case %0d: Write-Read at address 0x%h with data 0x%h", 
                    i, rand_addr, rand_data);
            
            // Perform write operation
            axi_write(rand_addr, rand_data);
            repeat(5) @(posedge s_axi_aclk);
            
            // Perform read operation
            axi_read(rand_addr, rand_data);
            repeat(5) @(posedge s_axi_aclk);
        end

        // Additional verification: Read back all written locations
        $display("\nVerifying all written locations...");
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            logic [C_S_AXI_ADDR_WIDTH-1:0] addr;
            addr = i << 2; // Word-aligned address
            if (test_memory[i] != 0) begin // Only verify locations that were written
                axi_read(addr, test_memory[i]);
            end
        end

        #100;
        $display("\nAll test cases completed");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

    // Optional: Waveform dump
    initial begin
        $dumpfile("axi_bram_wrapper_tb.vcd");
        $dumpvars(0, axi_bram_wrapper_tb);
    end

endmodule 