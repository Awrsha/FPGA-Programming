library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity GeneticAlgorithm is
    generic (
        POPULATION_SIZE : integer := 100;
        CHROMOSOME_LENGTH : integer := 32;
        MUTATION_RATE : integer := 5  -- 5% mutation rate
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        fitness_in : in std_logic_vector(POPULATION_SIZE*32-1 downto 0);
        population_out : out std_logic_vector(POPULATION_SIZE*CHROMOSOME_LENGTH-1 downto 0);
        done : out std_logic
    );
end GeneticAlgorithm;

architecture Behavioral of GeneticAlgorithm is
    type population_array is array (0 to POPULATION_SIZE-1) of std_logic_vector(CHROMOSOME_LENGTH-1 downto 0);
    signal population : population_array;
    signal fitness : std_logic_vector(POPULATION_SIZE*32-1 downto 0);
    
    function selection(fitness : std_logic_vector) return integer is
        variable total_fitness : unsigned(31 downto 0) := (others => '0');
        variable random_value : unsigned(31 downto 0);
        variable cumulative_fitness : unsigned(31 downto 0) := (others => '0');
    begin
        for i in 0 to POPULATION_SIZE-1 loop
            total_fitness := total_fitness + unsigned(fitness(i*32+31 downto i*32));
        end loop;
        
        random_value := (total_fitness - 1) and x"FFFFFFFF";  -- Simple PRNG
        
        for i in 0 to POPULATION_SIZE-1 loop
            cumulative_fitness := cumulative_fitness + unsigned(fitness(i*32+31 downto i*32));
            if cumulative_fitness > random_value then
                return i;
            end if;
        end loop;
        
        return POPULATION_SIZE-1;
    end function;
    
    function crossover(parent1, parent2 : std_logic_vector) return std_logic_vector is
        variable child : std_logic_vector(CHROMOSOME_LENGTH-1 downto 0);
        variable crossover_point : integer;
    begin
        crossover_point := to_integer(unsigned(parent1(7 downto 0)));  -- Simple PRNG
        child := parent1(CHROMOSOME_LENGTH-1 downto crossover_point) & parent2(crossover_point-1 downto 0);
        return child;
    end function;
    
    function mutate(chromosome : std_logic_vector) return std_logic_vector is
        variable mutated : std_logic_vector(CHROMOSOME_LENGTH-1 downto 0) := chromosome;
    begin
        for i in 0 to CHROMOSOME_LENGTH-1 loop
            if to_integer(unsigned(chromosome(7 downto 0))) mod 100 < MUTATION_RATE then
                mutated(i) := not mutated(i);
            end if;
        end loop;
        return mutated;
    end function;
    
begin
    process(clk, rst)
        variable parent1_index, parent2_index : integer;
        variable child : std_logic_vector(CHROMOSOME_LENGTH-1 downto 0);
    begin
        if rst = '1' then
            for i in 0 to POPULATION_SIZE-1 loop
                population(i) <= std_logic_vector(to_unsigned(i, CHROMOSOME_LENGTH));  -- Initialize population
            end loop
            done <= '0';
        elsif rising_edge(clk) then
            fitness <= fitness_in;
            
            for i in 0 to POPULATION_SIZE-1 loop
                parent1_index := selection(fitness);
                parent2_index := selection(fitness);
                child := crossover(population(parent1_index), population(parent2_index));
                child := mutate(child);
                population(i) <= child;
            end loop;
            
            done <= '1';
        end if;
    end process;
    
    gen_output: for i in 0 to POPULATION_SIZE-1 generate
        population_out((i+1)*CHROMOSOME_LENGTH-1 downto i*CHROMOSOME_LENGTH) <= population(i);
    end generate gen_output;
end Behavioral;