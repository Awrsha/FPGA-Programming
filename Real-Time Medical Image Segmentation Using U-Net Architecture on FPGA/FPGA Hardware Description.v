module conv2d_accelerator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] input_data,
    input wire [31:0] weight_data,
    output reg [31:0] output_data,
    output reg done
);

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter KERNEL_SIZE = 3;
    parameter IMG_SIZE = 256;
    
    // Registers
    reg [31:0] input_buffer [0:IMG_SIZE*IMG_SIZE-1];
    reg [31:0] weight_buffer [0:KERNEL_SIZE*KERNEL_SIZE-1];
    reg [31:0] output_buffer [0:IMG_SIZE*IMG_SIZE-1];
    
    // State machine
    reg [2:0] state;
    parameter IDLE = 3'd0;
    parameter LOAD = 3'd1;
    parameter COMPUTE = 3'd2;
    parameter STORE = 3'd3;
    
    // Counters
    reg [15:0] input_cnt;
    reg [3:0] weight_cnt;
    reg [15:0] compute_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_cnt <= 0;
            weight_cnt <= 0;
            compute_cnt <= 0;
            done <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (start)
                        state <= LOAD;
                end
                
                LOAD: begin
                    if (input_cnt < IMG_SIZE*IMG_SIZE) begin
                        input_buffer[input_cnt] <= input_data;
                        input_cnt <= input_cnt + 1;
                    end
                    else if (weight_cnt < KERNEL_SIZE*KERNEL_SIZE) begin
                        weight_buffer[weight_cnt] <= weight_data;
                        weight_cnt <= weight_cnt + 1;
                    end
                    else
                        state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (compute_cnt < IMG_SIZE*IMG_SIZE) begin
                        // Convolution computation
                        output_buffer[compute_cnt] <= convolve(
                            input_buffer,
                            weight_buffer,
                            compute_cnt
                        );
                        compute_cnt <= compute_cnt + 1;
                    end
                    else
                        state <= STORE;
                end
                
                STORE: begin
                    output_data <= output_buffer[compute_cnt];
                    if (compute_cnt == IMG_SIZE*IMG_SIZE-1) begin
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    function [31:0] convolve;
        input [31:0] in_buf [0:IMG_SIZE*IMG_SIZE-1];
        input [31:0] weight_buf [0:KERNEL_SIZE*KERNEL_SIZE-1];
        input [15:0] pos;
        
        reg [31:0] sum;
        integer i, j;
        begin
            sum = 0;
            for (i = 0; i < KERNEL_SIZE; i = i + 1)
                for (j = 0; j < KERNEL_SIZE; j = j + 1)
                    sum = sum + in_buf[pos + i*IMG_SIZE + j] * 
                          weight_buf[i*KERNEL_SIZE + j];
            convolve = sum;
        end
    endfunction
    
endmodule