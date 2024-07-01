library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TFLiteMicro is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        input_data : in sequence_buffer_type;
        output_valid : out STD_LOGIC;
        output_data : out STD_LOGIC_VECTOR(2 downto 0)
    );
end TFLiteMicro;

architecture Behavioral of TFLiteMicro is
    type state_type is (IDLE, PROCESSING, OUTPUT);
    signal state : state_type := IDLE;
    
    signal process_counter : integer range 0 to 1000 := 0;
    constant PROCESS_TIME : integer := 500;
    
begin
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            process_counter <= 0;
            output_valid <= '0';
            output_data <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if input_data'event then
                        state <= PROCESSING;
                        process_counter <= 0;
                    end if;
                
                when PROCESSING =>
                    if process_counter < PROCESS_TIME then
                        process_counter <= process_counter + 1;
                    else
                        state <= OUTPUT;
                        output_data <= "101";
                    end if;
                
                when OUTPUT =>
                    output_valid <= '1';
                    state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;