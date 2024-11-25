module dma_controller (
    input wire clk,
    input wire rst_n,
    input wire start_transfer,
    input wire [31:0] src_addr,
    input wire [31:0] dst_addr,
    input wire [31:0] transfer_size,
    output reg transfer_done,
    
    // AXI interface signals
    output reg [31:0] m_axi_awaddr,
    output reg [7:0] m_axi_awlen,
    output reg m_axi_awvalid,
    input wire m_axi_awready,
    
    output reg [31:0] m_axi_wdata,
    output reg m_axi_wlast,
    output reg m_axi_wvalid,
    input wire m_axi_wready,
    
    input wire m_axi_bvalid,
    output reg m_axi_bready,
    
    output reg [31:0] m_axi_araddr,
    output reg [7:0] m_axi_arlen,
    output reg m_axi_arvalid,
    input wire m_axi_arready,
    
    input wire [31:0] m_axi_rdata,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output reg m_axi_rready
);

    // Parameters
    parameter IDLE = 2'd0;
    parameter READ = 2'd1;
    parameter WRITE = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [31:0] transfer_count;
    reg [31:0] buffer [0:255];
    reg [7:0] buffer_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            transfer_count <= 0;
            buffer_count <= 0;
            transfer_done <= 0;
            
            m_axi_awvalid <= 0;
            m_axi_wvalid <= 0;
            m_axi_bready <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (start_transfer) begin
                        state <= READ;
                        m_axi_araddr <= src_addr;
                        m_axi_arlen <= 8'd255;
                        m_axi_arvalid <= 1;
                        m_axi_rready <= 1;
                    end
                end
                
                READ: begin
                    if (m_axi_rvalid) begin
                        buffer[buffer_count] <= m_axi_rdata;
                        buffer_count <= buffer_count + 1;
                        
                        if (m_axi_rlast) begin
                            state <= WRITE;
                            m_axi_awaddr <= dst_addr;
                            m_axi_awlen <= buffer_count;
                            m_axi_awvalid <= 1;
                            buffer_count <= 0;
                        end
                    end
                end
                
                WRITE: begin
                    if (m_axi_awready && m_axi_awvalid) begin
                        m_axi_awvalid <= 0;
                        m_axi_wvalid <= 1;
                        m_axi_wdata <= buffer[buffer_count];
                        
                        if (buffer_count == m_axi_awlen) begin
                            m_axi_wlast <= 1;
                            state <= IDLE;
                            transfer_done <= 1;
                        end
                        else begin
                            buffer_count <= buffer_count + 1;
                        end
                    end
                end
            endcase
        end
    end
    
endmodule