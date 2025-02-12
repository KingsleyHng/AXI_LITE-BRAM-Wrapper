`timescale 1 ns / 1 ps

module axi_bram_wrapper #(
    // Parameters
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 10,
    parameter integer BRAM_DEPTH = 1024
)(
    // AXI-Lite Interface
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,
    
    // Write Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire [2:0] s_axi_awprot,
    input wire  s_axi_awvalid,
    output wire s_axi_awready,
    
    // Write Data Channel
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input wire  s_axi_wvalid,
    output wire s_axi_wready,
    
    // Write Response Channel
    output wire [1:0] s_axi_bresp,
    output wire s_axi_bvalid,
    input wire  s_axi_bready,
    
    // Read Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire [2:0] s_axi_arprot,
    input wire  s_axi_arvalid,
    output wire s_axi_arready,
    
    // Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0] s_axi_rresp,
    output wire s_axi_rvalid,
    input wire  s_axi_rready
);

    // Local parameters
    localparam ADDR_LSB = $clog2(C_S_AXI_DATA_WIDTH/8);
    localparam BRAM_ADDR_WIDTH = $clog2(BRAM_DEPTH);

    // Internal signals for AXI interface
    reg axi_awready;
    reg axi_wready;
    reg axi_bvalid;
    reg axi_arready;
    reg axi_rvalid;
    reg [1:0] axi_bresp;
    reg [1:0] axi_rresp;
    
    // BRAM control signals
    wire bram_we;
    wire [BRAM_ADDR_WIDTH-1:0] bram_addr;
    reg [C_S_AXI_DATA_WIDTH-1:0] bram_din;
    wire [C_S_AXI_DATA_WIDTH-1:0] bram_dout;
    
    // Write control signals
    reg write_in_progress;
    reg [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
    
    // Read control signals
    reg read_in_progress;
    reg [C_S_AXI_ADDR_WIDTH-1:0] read_addr;

    // Instantiate the BRAM
    bram_single_port #(
        .ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) bram_inst (
        .clk(s_axi_aclk),
        .we(bram_we),
        .addr(bram_addr),
        .din(bram_din),
        .dout(bram_dout)
    );

    // Assign AXI interface outputs
    assign s_axi_awready = axi_awready;
    assign s_axi_wready = axi_wready;
    assign s_axi_bresp = axi_bresp;
    assign s_axi_bvalid = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata = bram_dout;
    assign s_axi_rresp = axi_rresp;
    assign s_axi_rvalid = axi_rvalid;

    // BRAM control signals
    assign bram_we = write_in_progress && s_axi_wvalid && axi_wready && s_axi_awvalid && axi_awready;
  
  always@(*) begin
    if(bram_we) begin
   	 for(int i =0; i<= (C_S_AXI_DATA_WIDTH/8)-1; i=i+1) begin
       if (s_axi_wstrb[i]) begin
         bram_din[(i*8) +: 8] = s_axi_wdata[(i*8) +: 8];
      end 
    end
   end
  end
  
    assign bram_addr = write_in_progress ? write_addr : read_addr;

    // Write address channel handling
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            axi_awready <= 1'b0;
            write_in_progress <= 1'b0;
            write_addr <= 0;
        end else begin
          if (~axi_awready && s_axi_awvalid  && s_axi_wvalid &&  ~write_in_progress) begin
                axi_awready <= 1'b1;
                write_in_progress <= 1'b1;
                write_addr <= s_axi_awaddr;
            end else begin
                axi_awready <= 1'b0;
                if (axi_bvalid && s_axi_bready) begin
                    write_in_progress <= 1'b0;
                end
            end
        end
    end

    // Write data channel handling
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            axi_wready <= 1'b0;
        end else begin
          if (~axi_wready && s_axi_wvalid &&  s_axi_awvalid && ~write_in_progress) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // Write response channel handling
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b0;
        end else begin
            if (write_in_progress && axi_wready && s_axi_wvalid && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b0; // OKAY response
            end else if (axi_bvalid && s_axi_bready) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // Read address channel handling
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            axi_arready <= 1'b0;
            read_in_progress <= 1'b0;
            read_addr <= 0;
        end else begin
            if (~axi_arready && s_axi_arvalid && ~read_in_progress) begin
                axi_arready <= 1'b1;
                read_in_progress <= 1'b1;
                read_addr <= s_axi_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // Read data channel handling
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            axi_rvalid <= 1'b0;
            axi_rresp <= 2'b0;
        end else begin
          if (axi_arready && read_in_progress && s_axi_arvalid &&  ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b0; // OKAY response
            end else if (axi_rvalid && s_axi_rready) begin
                axi_rvalid <= 1'b0;
                read_in_progress <= 1'b0;
            end
        end
    end

endmodule 