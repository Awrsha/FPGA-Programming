library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Neuron is
    generic (
        INPUT_WIDTH : integer := 16;
        WEIGHT_WIDTH : integer := 16;
        NUM_INPUTS : integer := 8;
        OUTPUT_WIDTH : integer := 32
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        inputs : in std_logic_vector(NUM_INPUTS*INPUT_WIDTH-1 downto 0);
        weights : in std_logic_vector(NUM_INPUTS*WEIGHT_WIDTH-1 downto 0);
        bias : in std_logic_vector(WEIGHT_WIDTH-1 downto 0);
        output : out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
    );
end Neuron;

architecture Behavioral of Neuron is
    signal sum : signed(OUTPUT_WIDTH-1 downto 0);
begin
    process(clk, rst)
        variable temp_sum : signed(OUTPUT_WIDTH-1 downto 0);
    begin
        if rst = '1' then
            sum <= (others => '0');
        elsif rising_edge(clk) then
            temp_sum := (others => '0');
            for i in 0 to NUM_INPUTS-1 loop
                temp_sum := temp_sum + signed(inputs((i+1)*INPUT_WIDTH-1 downto i*INPUT_WIDTH)) * 
                            signed(weights((i+1)*WEIGHT_WIDTH-1 downto i*WEIGHT_WIDTH));
            end loop;
            sum <= temp_sum + signed(bias);
        end if;
    end process;

    output <= std_logic_vector(sum) when sum > 0 else (others => '0');
end Behavioral;