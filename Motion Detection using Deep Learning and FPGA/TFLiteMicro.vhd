library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ArtificialVisionSensor is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        pixel_data : in STD_LOGIC_VECTOR(23 downto 0);
        pixel_valid : in STD_LOGIC;
        frame_start : in STD_LOGIC;
        frame_end : in STD_LOGIC;
        motion_detected : out STD_LOGIC;
        motion_type : out STD_LOGIC_VECTOR(2 downto 0)
    );
end ArtificialVisionSensor;

architecture Behavioral of ArtificialVisionSensor is
    constant IMAGE_WIDTH : integer := 160;
    constant IMAGE_HEIGHT : integer := 120;
    constant SEQUENCE_LENGTH : integer := 20;
    
    type frame_buffer_type is array (0 to IMAGE_HEIGHT-1, 0 to IMAGE_WIDTH-1) of STD_LOGIC_VECTOR(23 downto 0);
    type sequence_buffer_type is array (0 to SEQUENCE_LENGTH-1) of frame_buffer_type;
    
    signal frame_buffer : frame_buffer_type;
    signal sequence_buffer : sequence_buffer_type;
    signal frame_count : integer range 0 to SEQUENCE_LENGTH-1 := 0;
    signal pixel_count : integer range 0 to IMAGE_WIDTH*IMAGE_HEIGHT-1 := 0;
    
    component TFLiteMicro is
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            input_data : in sequence_buffer_type;
            output_valid : out STD_LOGIC;
            output_data : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;
    
    signal tflite_input : sequence_buffer_type;
    signal tflite_output_valid : STD_LOGIC;
    signal tflite_output : STD_LOGIC_VECTOR(2 downto 0);

begin
    process(clk, reset)
    begin
        if reset = '1' then
            frame_count <= 0;
            pixel_count <= 0;
        elsif rising_edge(clk) then
            if frame_start = '1' then
                frame_count <= (frame_count + 1) mod SEQUENCE_LENGTH;
                pixel_count <= 0;
            elsif pixel_valid = '1' then
                frame_buffer(pixel_count / IMAGE_WIDTH, pixel_count mod IMAGE_WIDTH) <= pixel_data;
                pixel_count <= pixel_count + 1;
            elsif frame_end = '1' then
                sequence_buffer(frame_count) <= frame_buffer;
                if frame_count = SEQUENCE_LENGTH - 1 then
                    tflite_input <= sequence_buffer;
                end if;
            end if;
        end if;
    end process;

    TFLite_Inst: TFLiteMicro
    port map (
        clk => clk,
        reset => reset,
        input_data => tflite_input,
        output_valid => tflite_output_valid,
        output_data => tflite_output
    );

    process(tflite_output_valid, tflite_output)
    begin
        if tflite_output_valid = '1' then
            motion_detected <= '1';
            motion_type <= tflite_output;
        else
            motion_detected <= '0';
            motion_type <= (others => '0');
        end if;
    end process;

end Behavioral;