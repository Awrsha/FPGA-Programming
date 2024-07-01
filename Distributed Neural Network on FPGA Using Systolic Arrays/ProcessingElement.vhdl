library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ProcessingElement is
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
end ProcessingElement;

architecture Behavioral of ProcessingElement is
    signal weight_reg : signed(DATA_WIDTH-1 downto 0);
    signal activation_reg : signed(DATA_WIDTH-1 downto 0);
    signal product : signed(2*DATA_WIDTH-1 downto 0);
    signal sum_reg : signed(2*DATA_WIDTH-1 downto 0);
begin
    process(clk, rst)
    begin
        if rst = '1' then
            weight_reg <= (others => '0');
            activation_reg <= (others => '0');
            sum_reg <= (others => '0');
        elsif rising_edge(clk) then
            weight_reg <= weight_in;
            activation_reg <= activation_in;
            product <= weight_reg * activation_reg;
            sum_reg <= sum_in + product;
        end if;
    end process;

    weight_out <= weight_reg;
    activation_out <= activation_reg;
    sum_out <= sum_reg;
end Behavioral;