library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity NeuralLayer is
    generic (
        INPUT_WIDTH : integer := 16;
        WEIGHT_WIDTH : integer := 16;
        NUM_INPUTS : integer := 8;
        NUM_NEURONS : integer := 4;
        OUTPUT_WIDTH : integer := 32
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        inputs : in std_logic_vector(NUM_INPUTS*INPUT_WIDTH-1 downto 0);
        weights : in std_logic_vector(NUM_NEURONS*NUM_INPUTS*WEIGHT_WIDTH-1 downto 0);
        biases : in std_logic_vector(NUM_NEURONS*WEIGHT_WIDTH-1 downto 0);
        outputs : out std_logic_vector(NUM_NEURONS*OUTPUT_WIDTH-1 downto 0)
    );
end NeuralLayer;

architecture Behavioral of NeuralLayer is
    component Neuron is
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
    end component;
begin
    gen_neurons: for i in 0 to NUM_NEURONS-1 generate
        neuron_inst: Neuron
            generic map (
                INPUT_WIDTH => INPUT_WIDTH,
                WEIGHT_WIDTH => WEIGHT_WIDTH,
                NUM_INPUTS => NUM_INPUTS,
                OUTPUT_WIDTH => OUTPUT_WIDTH
            )
            port map (
                clk => clk,
                rst => rst,
                inputs => inputs,
                weights => weights((i+1)*NUM_INPUTS*WEIGHT_WIDTH-1 downto i*NUM_INPUTS*WEIGHT_WIDTH),
                bias => biases((i+1)*WEIGHT_WIDTH-1 downto i*WEIGHT_WIDTH),
                output => outputs((i+1)*OUTPUT_WIDTH-1 downto i*OUTPUT_WIDTH)
            );
    end generate gen_neurons;
end Behavioral;