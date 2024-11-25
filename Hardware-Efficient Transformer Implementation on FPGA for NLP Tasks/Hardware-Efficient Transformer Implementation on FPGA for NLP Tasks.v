// Hardware-Efficient Transformer Implementation on FPGA for NLP Tasks

// Top-level module
module transformer_nlp (
    input wire clk,
    input wire rst_n,
    input wire [7:0] input_data,
    input wire input_valid,
    output reg [7:0] output_data,
    output reg output_valid
);

// Parameters
parameter HIDDEN_SIZE = 512;
parameter NUM_HEADS = 8;
parameter HEAD_SIZE = HIDDEN_SIZE/NUM_HEADS;
parameter MAX_SEQ_LEN = 128;
parameter VOCAB_SIZE = 32000;

// Memory interfaces
reg [15:0] weight_addr;
reg weight_rd_en;
wire [15:0] weight_data;

reg [15:0] embedding_addr; 
reg embedding_rd_en;
wire [15:0] embedding_data;

// Control signals
reg [3:0] state;
reg [6:0] seq_pos;
reg [3:0] layer_num;

// Attention mechanism registers
reg [15:0] q_buffer [0:HEAD_SIZE-1];
reg [15:0] k_buffer [0:HEAD_SIZE-1];
reg [15:0] v_buffer [0:HEAD_SIZE-1];
reg [31:0] score_buffer [0:MAX_SEQ_LEN-1];

// Processing elements
reg [15:0] pe_input [0:15];
wire [15:0] pe_output [0:15];

// Processing element array
genvar i;
generate
    for (i=0; i<16; i=i+1) begin: pe_array
        processing_element pe_inst (
            .clk(clk),
            .rst_n(rst_n),
            .input_data(pe_input[i]),
            .output_data(pe_output[i])
        );
    end
endgenerate

// State machine parameters  
localparam IDLE = 4'd0;
localparam LOAD_EMBED = 4'd1;
localparam CALC_QKV = 4'd2;
localparam CALC_SCORES = 4'd3;
localparam APPLY_ATTENTION = 4'd4;
localparam FFN = 4'd5;
localparam LAYER_NORM = 4'd6;
localparam OUTPUT = 4'd7;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        seq_pos <= 0;
        layer_num <= 0;
        output_valid <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                if (input_valid) begin
                    state <= LOAD_EMBED;
                    seq_pos <= 0;
                    layer_num <= 0;
                end
            end

            LOAD_EMBED: begin
                embedding_addr <= input_data;
                embedding_rd_en <= 1;
                state <= CALC_QKV;
            end

            CALC_QKV: begin
                // Load Q,K,V weights
                weight_addr <= layer_num * HIDDEN_SIZE * 3 + seq_pos;
                weight_rd_en <= 1;
                
                // Calculate Q,K,V vectors
                for (int j=0; j<HEAD_SIZE; j=j+1) begin
                    q_buffer[j] <= embedding_data * weight_data[j*16 +: 16];
                    k_buffer[j] <= embedding_data * weight_data[(HEAD_SIZE+j)*16 +: 16];
                    v_buffer[j] <= embedding_data * weight_data[(2*HEAD_SIZE+j)*16 +: 16];
                end

                if (seq_pos == MAX_SEQ_LEN-1)
                    state <= CALC_SCORES;
                else
                    seq_pos <= seq_pos + 1;
            end

            CALC_SCORES: begin
                // Calculate attention scores
                for (int j=0; j<MAX_SEQ_LEN; j=j+1) begin
                    score_buffer[j] <= 0;
                    for (int k=0; k<HEAD_SIZE; k=k+1) begin
                        score_buffer[j] <= score_buffer[j] + q_buffer[k] * k_buffer[k];
                    end
                    score_buffer[j] <= score_buffer[j] / $sqrt(HEAD_SIZE);
                end
                state <= APPLY_ATTENTION;
            end

            APPLY_ATTENTION: begin
                // Apply softmax and attention
                reg [31:0] max_score = 0;
                reg [31:0] sum_exp = 0;
                
                // Find max for numerical stability
                for (int j=0; j<MAX_SEQ_LEN; j=j+1) begin
                    if (score_buffer[j] > max_score)
                        max_score = score_buffer[j];
                end
                
                // Calculate softmax denominators
                for (int j=0; j<MAX_SEQ_LEN; j=j+1) begin
                    sum_exp = sum_exp + $exp(score_buffer[j] - max_score);
                end

                // Apply attention
                for (int j=0; j<HEAD_SIZE; j=j+1) begin
                    pe_input[j] <= 0;
                    for (int k=0; k<MAX_SEQ_LEN; k=k+1) begin
                        pe_input[j] <= pe_input[j] + 
                            ($exp(score_buffer[k] - max_score) * v_buffer[j]) / sum_exp;
                    end
                end

                state <= FFN;
            end

            FFN: begin
                // Feed-forward network
                for (int j=0; j<16; j=j+1) begin
                    pe_input[j] <= pe_output[j];
                end
                
                state <= LAYER_NORM;
            end

            LAYER_NORM: begin
                // Layer normalization
                reg [31:0] mean = 0;
                reg [31:0] variance = 0;
                
                for (int j=0; j<HEAD_SIZE; j=j+1) begin
                    mean = mean + pe_output[j];
                end
                mean = mean / HEAD_SIZE;
                
                for (int j=0; j<HEAD_SIZE; j=j+1) begin
                    variance = variance + (pe_output[j] - mean) * (pe_output[j] - mean);
                end
                variance = variance / HEAD_SIZE;
                
                for (int j=0; j<HEAD_SIZE; j=j+1) begin
                    pe_input[j] <= (pe_output[j] - mean) / $sqrt(variance + 0.00001);
                end

                if (layer_num == NUM_HEADS-1)
                    state <= OUTPUT;
                else begin
                    layer_num <= layer_num + 1;
                    state <= CALC_QKV;
                end
            end

            OUTPUT: begin
                output_data <= pe_output[0][7:0];
                output_valid <= 1;
                state <= IDLE;
            end

        endcase
    end
end

endmodule

// Processing Element module
module processing_element (
    input wire clk,
    input wire rst_n,
    input wire [15:0] input_data,
    output reg [15:0] output_data
);

reg [15:0] accumulator;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        accumulator <= 0;
        output_data <= 0;
    end
    else begin
        accumulator <= accumulator + input_data;
        output_data <= accumulator;
    end
end

endmodule

// Memory module for weights
module weight_memory (
    input wire clk,
    input wire [15:0] addr,
    input wire rd_en,
    output reg [15:0] data
);

reg [15:0] mem [0:32768-1];

always @(posedge clk) begin
    if (rd_en)
        data <= mem[addr];
end

endmodule

// Memory module for embeddings
module embedding_memory (
    input wire clk,
    input wire [15:0] addr,
    input wire rd_en, 
    output reg [15:0] data
);

reg [15:0] mem [0:32768-1];

always @(posedge clk) begin
    if (rd_en)
        data <= mem[addr];
end

endmodule

// Testbench
module transformer_nlp_tb;

reg clk;
reg rst_n;
reg [7:0] input_data;
reg input_valid;
wire [7:0] output_data;
wire output_valid;

transformer_nlp dut (
    .clk(clk),
    .rst_n(rst_n),
    .input_data(input_data),
    .input_valid(input_valid),
    .output_data(output_data),
    .output_valid(output_valid)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    input_valid = 0;
    input_data = 0;
    
    #100;
    rst_n = 1;
    
    #20;
    input_valid = 1;
    input_data = 8'hAA;
    
    #10;
    input_valid = 0;
    
    #1000;
    $finish;
end

initial begin
    $dumpfile("transformer_nlp.vcd");
    $dumpvars(0, transformer_nlp_tb);
end

endmodule