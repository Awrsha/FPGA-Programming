-- Top Level Entity for Multi-FPGA Matrix Multiplication
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity matrix_mult_top is
    generic (
        NUM_FPGAS : integer := 4;
        MATRIX_SIZE : integer := 1024;
        DATA_WIDTH : integer := 32;
        PRECISION : integer := 16
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        start : in std_logic;
        done : out std_logic;
        
        -- Input matrix data ports
        matrix_a_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        matrix_b_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        matrix_addr : in std_logic_vector(31 downto 0);
        matrix_wr_en : in std_logic;
        
        -- Output matrix data ports
        result_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
        result_addr : in std_logic_vector(31 downto 0);
        result_valid : out std_logic;
        
        -- Inter-FPGA communication ports
        aurora_tx_data : out std_logic_vector(63 downto 0);
        aurora_tx_valid : out std_logic;
        aurora_tx_ready : in std_logic;
        aurora_rx_data : in std_logic_vector(63 downto 0);
        aurora_rx_valid : in std_logic
    );
end matrix_mult_top;

architecture rtl of matrix_mult_top is

    -- Component declarations
    component processing_element
        port (
            clk : in std_logic;
            rst : in std_logic;
            a_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
            b_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
            acc_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
            valid_in : in std_logic;
            result_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
            valid_out : out std_logic
        );
    end component;
    
    component block_ram
        port (
            clk : in std_logic;
            addr : in std_logic_vector(31 downto 0);
            data_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
            wr_en : in std_logic;
            data_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    component aurora_wrapper
        port (
            clk : in std_logic;
            rst : in std_logic;
            tx_data : in std_logic_vector(63 downto 0);
            tx_valid : in std_logic;
            tx_ready : out std_logic;
            rx_data : out std_logic_vector(63 downto 0);
            rx_valid : out std_logic
        );
    end component;

    -- Type definitions for arrays
    type matrix_array is array (0 to MATRIX_SIZE-1, 0 to MATRIX_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type pe_array is array (0 to MATRIX_SIZE/NUM_FPGAS-1, 0 to MATRIX_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Internal signals
    signal matrix_a : matrix_array;
    signal matrix_b : matrix_array;
    signal matrix_c : matrix_array;
    
    signal pe_array_a : pe_array;
    signal pe_array_b : pe_array;
    signal pe_array_c : pe_array;
    
    signal pe_valid_in : std_logic_vector(MATRIX_SIZE/NUM_FPGAS-1 downto 0);
    signal pe_valid_out : std_logic_vector(MATRIX_SIZE/NUM_FPGAS-1 downto 0);
    
    signal state : integer range 0 to 3;
    signal sub_matrix_done : std_logic;
    signal fpga_id : integer range 0 to NUM_FPGAS-1;
    
    -- Control signals
    signal load_matrices : std_logic;
    signal compute_start : std_logic;
    signal compute_done : std_logic;
    signal transfer_data : std_logic;
    
begin

    -- Generate processing elements
    PE_GEN: for i in 0 to MATRIX_SIZE/NUM_FPGAS-1 generate
        PE_ROW: for j in 0 to MATRIX_SIZE-1 generate
            PE_INST: processing_element
                port map (
                    clk => clk,
                    rst => rst,
                    a_in => pe_array_a(i,j),
                    b_in => pe_array_b(i,j),
                    acc_in => pe_array_c(i,j),
                    valid_in => pe_valid_in(i),
                    result_out => matrix_c(i,j),
                    valid_out => pe_valid_out(i)
                );
        end generate;
    end generate;
    
    -- Memory blocks for matrix storage
    MATRIX_A_MEM: block_ram
        port map (
            clk => clk,
            addr => matrix_addr,
            data_in => matrix_a_in,
            wr_en => matrix_wr_en and load_matrices,
            data_out => open
        );
        
    MATRIX_B_MEM: block_ram
        port map (
            clk => clk,
            addr => matrix_addr,
            data_in => matrix_b_in,
            wr_en => matrix_wr_en and load_matrices,
            data_out => open
        );
        
    -- Aurora interface for inter-FPGA communication
    AURORA: aurora_wrapper
        port map (
            clk => clk,
            rst => rst,
            tx_data => aurora_tx_data,
            tx_valid => aurora_tx_valid,
            tx_ready => aurora_tx_ready,
            rx_data => aurora_rx_data,
            rx_valid => aurora_rx_valid
        );

    -- Main control process
    process(clk, rst)
    begin
        if rst = '1' then
            state <= 0;
            load_matrices <= '0';
            compute_start <= '0';
            compute_done <= '0';
            transfer_data <= '0';
            done <= '0';
            
        elsif rising_edge(clk) then
            case state is
                -- Idle state
                when 0 =>
                    if start = '1' then
                        load_matrices <= '1';
                        state <= 1;
                    end if;
                
                -- Load matrices
                when 1 =>
                    if matrix_wr_en = '0' then
                        load_matrices <= '0';
                        compute_start <= '1';
                        state <= 2;
                    end if;
                
                -- Compute
                when 2 =>
                    if compute_done = '1' then
                        compute_start <= '0';
                        transfer_data <= '1';
                        state <= 3;
                    end if;
                
                -- Transfer results
                when 3 =>
                    if sub_matrix_done = '1' then
                        transfer_data <= '0';
                        done <= '1';
                        state <= 0;
                    end if;
            end case;
        end if;
    end process;

    -- Matrix multiplication process
    process(clk)
        variable row, col, k : integer;
        variable temp_sum : signed(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if compute_start = '1' then
                -- Systolic array computation
                for row in 0 to MATRIX_SIZE/NUM_FPGAS-1 loop
                    for col in 0 to MATRIX_SIZE-1 loop
                        temp_sum := (others => '0');
                        for k in 0 to MATRIX_SIZE-1 loop
                            temp_sum := temp_sum + signed(matrix_a(row,k)) * signed(matrix_b(k,col));
                        end loop;
                        matrix_c(row,col) <= std_logic_vector(temp_sum);
                    end loop;
                end loop;
                compute_done <= '1';
            end if;
        end if;
    end process;

    -- Data transfer process
    process(clk)
        variable transfer_count : integer;
    begin
        if rising_edge(clk) then
            if transfer_data = '1' then
                if aurora_tx_ready = '1' then
                    -- Pack result data
                    aurora_tx_data <= matrix_c(transfer_count/MATRIX_SIZE, transfer_count mod MATRIX_SIZE) & 
                                    matrix_c(transfer_count/MATRIX_SIZE, (transfer_count+1) mod MATRIX_SIZE);
                    aurora_tx_valid <= '1';
                    
                    if transfer_count = MATRIX_SIZE*MATRIX_SIZE/NUM_FPGAS-1 then
                        sub_matrix_done <= '1';
                    else
                        transfer_count := transfer_count + 2;
                    end if;
                end if;
            else
                aurora_tx_valid <= '0';
                transfer_count := 0;
            end if;
        end if;
    end process;

    -- Result output process
    process(clk)
    begin
        if rising_edge(clk) then
            if transfer_data = '1' then
                result_data <= matrix_c(to_integer(unsigned(result_addr(31 downto 16))),
                                     to_integer(unsigned(result_addr(15 downto 0))));
                result_valid <= '1';
            else
                result_valid <= '0';
            end if;
        end if;
    end process;

end rtl;

-- Processing Element Implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity processing_element is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        a_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        b_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        acc_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_in : in std_logic;
        result_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_out : out std_logic
    );
end processing_element;

architecture rtl of processing_element is
    signal mult_result : signed(DATA_WIDTH*2-1 downto 0);
    signal acc_reg : signed(DATA_WIDTH-1 downto 0);
    signal valid_reg : std_logic;
begin
    process(clk, rst)
    begin
        if rst = '1' then
            acc_reg <= (others => '0');
            valid_reg <= '0';
            
        elsif rising_edge(clk) then
            if valid_in = '1' then
                -- Multiply-accumulate operation
                mult_result <= signed(a_in) * signed(b_in);
                acc_reg <= signed(acc_in) + mult_result(DATA_WIDTH-1 downto 0);
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;

    result_out <= std_logic_vector(acc_reg);
    valid_out <= valid_reg;
end rtl;

-- Block RAM Implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity block_ram is
    generic (
        DATA_WIDTH : integer := 32;
        ADDR_WIDTH : integer := 32;
        RAM_DEPTH : integer := 1024
    );
    port (
        clk : in std_logic;
        addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        data_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
        wr_en : in std_logic;
        data_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end block_ram;

architecture rtl of block_ram is
    type ram_type is array (0 to RAM_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_type;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                ram(to_integer(unsigned(addr))) <= data_in;
            end if;
            data_out <= ram(to_integer(unsigned(addr)));
        end if;
    end process;
end rtl;

-- Aurora Interface Wrapper
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity aurora_wrapper is
    port (
        clk : in std_logic;
        rst : in std_logic;
        tx_data : in std_logic_vector(63 downto 0);
        tx_valid : in std_logic;
        tx_ready : out std_logic;
        rx_data : out std_logic_vector(63 downto 0);
        rx_valid : out std_logic
    );
end aurora_wrapper;

architecture rtl of aurora_wrapper is
    -- Aurora IP core component declaration would go here
    -- This is a simplified wrapper - actual implementation would
    -- interface with vendor-specific Aurora IP core
begin
    process(clk, rst)
    begin
        if rst = '1' then
            tx_ready <= '0';
            rx_valid <= '0';
            rx_data <= (others => '0');
            
        elsif rising_edge(clk) then
            -- Simplified Aurora interface logic
            tx_ready <= '1';
            
            if tx_valid = '1' then
                -- Handle transmission
                tx_ready <= '0';
            end if;
            
            -- Handle reception
            if rx_valid = '0' then
                rx_valid <= '1';
                rx_data <= tx_data; -- Loopback for simulation
            else
                rx_valid <= '0';
            end if;
        end if;
    end process;
end rtl;