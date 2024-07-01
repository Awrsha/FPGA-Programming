library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SystolicArray is
    generic (
        DATA_WIDTH : integer := 16;
        ARRAY_SIZE : integer := 4
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        weights_in : in signed(ARRAY_SIZE*DATA_WIDTH-1 downto 0);
        activations_in : in signed(ARRAY_SIZE*DATA_WIDTH-1 downto 0);
        results_out : out signed(ARRAY_SIZE*(2*DATA_WIDTH)-1 downto 0)
    );
end SystolicArray;

architecture Behavioral of SystolicArray is
    component ProcessingElement is
        generic (
            DATA_WIDTH : integer := 16
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            weight_in : in signed(DATA_WIDTH-1 downto 0);
            activation_in : in signed(DATA_WIDTH-1 downto 0);
            sum_in : in signed(2*DATA_WIDTH-1 downto 0);
            weight_out : out signed(DATA_WIDTH-1 downto 0);
            activation_out : out signed(DATA_WIDTH-1 downto 0);
            sum_out : out signed(2*DATA_WIDTH-1 downto 0)
        );
    end component;

    type weight_array is array (0 to ARRAY_SIZE-1, 0 to ARRAY_SIZE-1) of signed(DATA_WIDTH-1 downto 0);
    type activation_array is array (0 to ARRAY_SIZE-1, 0 to ARRAY_SIZE-1) of signed(DATA_WIDTH-1 downto 0);
    type sum_array is array (0 to ARRAY_SIZE-1, 0 to ARRAY_SIZE-1) of signed(2*DATA_WIDTH-1 downto 0);

    signal weight_grid : weight_array;
    signal activation_grid : activation_array;
    signal sum_grid : sum_array;

begin
    gen_row: for i in 0 to ARRAY_SIZE-1 generate
        gen_col: for j in 0 to ARRAY_SIZE-1 generate
            pe: ProcessingElement
                generic map (
                    DATA_WIDTH => DATA_WIDTH
                )
                port map (
                    clk => clk,
                    rst => rst,
                    weight_in => weight_grid(i, j),
                    activation_in => activation_grid(i, j),
                    sum_in => sum_grid(i, j),
                    weight_out => weight_grid(i, j+1),
                    activation_out => activation_grid(i+1, j),
                    sum_out => sum_grid(i+1, j+1)
                );
        end generate gen_col;
    end generate gen_row;

    process(clk, rst)
    begin
        if rst = '1' then
            for i in 0 to ARRAY_SIZE-1 loop
                weight_grid(i, 0) <= (others => '0');
                activation_grid(0, i) <= (others => '0');
            end loop;
        elsif rising_edge(clk) then
            for i in 0 to ARRAY_SIZE-1 loop
                weight_grid(i, 0) <= weights_in((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH);
                activation_grid(0, i) <= activations_in((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH);
            end loop;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            for i in 0 to ARRAY_SIZE-1 loop
                results_out((i+1)*(2*DATA_WIDTH)-1 downto i*(2*DATA_WIDTH)) <= sum_grid(ARRAY_SIZE-1, i);
            end loop;
        end if;
    end process;

end Behavioral;