-- Top-Level Entity
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity autonomous_vision_system is
    Port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        -- Camera Interface
        cam_data : in STD_LOGIC_VECTOR(7 downto 0);
        cam_href : in STD_LOGIC;
        cam_vsync : in STD_LOGIC;
        cam_pclk : in STD_LOGIC;
        -- Object Detection Output
        object_detected : out STD_LOGIC;
        object_x : out STD_LOGIC_VECTOR(9 downto 0);
        object_y : out STD_LOGIC_VECTOR(9 downto 0);
        object_width : out STD_LOGIC_VECTOR(9 downto 0);
        object_height : out STD_LOGIC_VECTOR(9 downto 0);
        object_class : out STD_LOGIC_VECTOR(3 downto 0)
    );
end autonomous_vision_system;

architecture Behavioral of autonomous_vision_system is

    -- Image Processing Components
    component image_capture
        Port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            cam_data : in STD_LOGIC_VECTOR(7 downto 0);
            cam_href : in STD_LOGIC;
            cam_vsync : in STD_LOGIC;
            cam_pclk : in STD_LOGIC;
            pixel_data : out STD_LOGIC_VECTOR(23 downto 0);
            pixel_valid : out STD_LOGIC;
            frame_start : out STD_LOGIC;
            frame_end : out STD_LOGIC
        );
    end component;

    component image_preprocessor
        Port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            pixel_data : in STD_LOGIC_VECTOR(23 downto 0);
            pixel_valid : in STD_LOGIC;
            processed_data : out STD_LOGIC_VECTOR(7 downto 0);
            processed_valid : out STD_LOGIC
        );
    end component;

    component neural_network
        Port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            input_data : in STD_LOGIC_VECTOR(7 downto 0);
            input_valid : in STD_LOGIC;
            detection_valid : out STD_LOGIC;
            detection_x : out STD_LOGIC_VECTOR(9 downto 0);
            detection_y : out STD_LOGIC_VECTOR(9 downto 0);
            detection_width : out STD_LOGIC_VECTOR(9 downto 0);
            detection_height : out STD_LOGIC_VECTOR(9 downto 0);
            detection_class : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

    -- Internal Signals
    signal pixel_data : STD_LOGIC_VECTOR(23 downto 0);
    signal pixel_valid : STD_LOGIC;
    signal frame_start : STD_LOGIC;
    signal frame_end : STD_LOGIC;
    signal processed_data : STD_LOGIC_VECTOR(7 downto 0);
    signal processed_valid : STD_LOGIC;
    signal detection_valid : STD_LOGIC;
    signal detection_x : STD_LOGIC_VECTOR(9 downto 0);
    signal detection_y : STD_LOGIC_VECTOR(9 downto 0);
    signal detection_width : STD_LOGIC_VECTOR(9 downto 0);
    signal detection_height : STD_LOGIC_VECTOR(9 downto 0);
    signal detection_class : STD_LOGIC_VECTOR(3 downto 0);

begin

    -- Image Capture Instance
    img_capture: image_capture
    port map (
        clk => clk,
        rst => rst,
        cam_data => cam_data,
        cam_href => cam_href,
        cam_vsync => cam_vsync,
        cam_pclk => cam_pclk,
        pixel_data => pixel_data,
        pixel_valid => pixel_valid,
        frame_start => frame_start,
        frame_end => frame_end
    );

    -- Image Preprocessor Instance
    img_preprocess: image_preprocessor
    port map (
        clk => clk,
        rst => rst,
        pixel_data => pixel_data,
        pixel_valid => pixel_valid,
        processed_data => processed_data,
        processed_valid => processed_valid
    );

    -- Neural Network Instance
    nn_core: neural_network
    port map (
        clk => clk,
        rst => rst,
        input_data => processed_data,
        input_valid => processed_valid,
        detection_valid => detection_valid,
        detection_x => detection_x,
        detection_y => detection_y,
        detection_width => detection_width,
        detection_height => detection_height,
        detection_class => detection_class
    );

    -- Output Assignment
    object_detected <= detection_valid;
    object_x <= detection_x;
    object_y <= detection_y;
    object_width <= detection_width;
    object_height <= detection_height;
    object_class <= detection_class;

end Behavioral;

-- Image Capture Module
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity image_capture is
    Port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        cam_data : in STD_LOGIC_VECTOR(7 downto 0);
        cam_href : in STD_LOGIC;
        cam_vsync : in STD_LOGIC;
        cam_pclk : in STD_LOGIC;
        pixel_data : out STD_LOGIC_VECTOR(23 downto 0);
        pixel_valid : out STD_LOGIC;
        frame_start : out STD_LOGIC;
        frame_end : out STD_LOGIC
    );
end image_capture;

architecture Behavioral of image_capture is
    
    type state_type is (IDLE, CAPTURE_Y, CAPTURE_CB, CAPTURE_CR);
    signal state : state_type;
    signal pixel_count : unsigned(1 downto 0);
    signal rgb_buffer : STD_LOGIC_VECTOR(23 downto 0);
    
begin
    
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            pixel_count <= (others => '0');
            pixel_valid <= '0';
            frame_start <= '0';
            frame_end <= '0';
            rgb_buffer <= (others => '0');
            
        elsif rising_edge(clk) then
            frame_start <= '0';
            frame_end <= '0';
            pixel_valid <= '0';
            
            if cam_vsync = '1' then
                state <= IDLE;
                pixel_count <= (others => '0');
                frame_end <= '1';
                
            elsif cam_href = '1' and cam_pclk = '1' then
                case state is
                    when IDLE =>
                        state <= CAPTURE_Y;
                        frame_start <= '1';
                        
                    when CAPTURE_Y =>
                        rgb_buffer(23 downto 16) <= cam_data;
                        state <= CAPTURE_CB;
                        
                    when CAPTURE_CB =>
                        rgb_buffer(15 downto 8) <= cam_data;
                        state <= CAPTURE_CR;
                        
                    when CAPTURE_CR =>
                        rgb_buffer(7 downto 0) <= cam_data;
                        pixel_valid <= '1';
                        pixel_data <= rgb_buffer;
                        state <= CAPTURE_Y;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;

-- Image Preprocessor Module
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity image_preprocessor is
    Port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        pixel_data : in STD_LOGIC_VECTOR(23 downto 0);
        pixel_valid : in STD_LOGIC;
        processed_data : out STD_LOGIC_VECTOR(7 downto 0);
        processed_valid : out STD_LOGIC
    );
end image_preprocessor;

architecture Behavioral of image_preprocessor is

    -- Grayscale conversion coefficients
    constant R_COEFF : unsigned(7 downto 0) := to_unsigned(77, 8);  -- 0.299
    constant G_COEFF : unsigned(7 downto 0) := to_unsigned(150, 8); -- 0.587
    constant B_COEFF : unsigned(7 downto 0) := to_unsigned(29, 8);  -- 0.114
    
    signal r_pixel : unsigned(7 downto 0);
    signal g_pixel : unsigned(7 downto 0);
    signal b_pixel : unsigned(7 downto 0);
    signal gray_pixel : unsigned(15 downto 0);
    
begin

    process(clk, rst)
    begin
        if rst = '1' then
            processed_data <= (others => '0');
            processed_valid <= '0';
            gray_pixel <= (others => '0');
            
        elsif rising_edge(clk) then
            processed_valid <= '0';
            
            if pixel_valid = '1' then
                -- Extract RGB components
                r_pixel <= unsigned(pixel_data(23 downto 16));
                g_pixel <= unsigned(pixel_data(15 downto 8));
                b_pixel <= unsigned(pixel_data(7 downto 0));
                
                -- Convert to grayscale
                gray_pixel <= (r_pixel * R_COEFF + g_pixel * G_COEFF + b_pixel * B_COEFF) / 256;
                processed_data <= std_logic_vector(gray_pixel(7 downto 0));
                processed_valid <= '1';
            end if;
        end if;
    end process;

end Behavioral;

-- Neural Network Module
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity neural_network is
    Port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        input_data : in STD_LOGIC_VECTOR(7 downto 0);
        input_valid : in STD_LOGIC;
        detection_valid : out STD_LOGIC;
        detection_x : out STD_LOGIC_VECTOR(9 downto 0);
        detection_y : out STD_LOGIC_VECTOR(9 downto 0);
        detection_width : out STD_LOGIC_VECTOR(9 downto 0);
        detection_height : out STD_LOGIC_VECTOR(9 downto 0);
        detection_class : out STD_LOGIC_VECTOR(3 downto 0)
    );
end neural_network;

architecture Behavioral of neural_network is

    -- Neural Network Parameters
    constant INPUT_SIZE : integer := 784;  -- 28x28 input
    constant HIDDEN_SIZE : integer := 128;
    constant OUTPUT_SIZE : integer := 10;
    
    type weight_array is array (0 to HIDDEN_SIZE-1) of signed(7 downto 0);
    type bias_array is array (0 to HIDDEN_SIZE-1) of signed(7 downto 0);
    
    -- Network weights and biases (pre-trained values would be loaded here)
    signal hidden_weights : weight_array;
    signal hidden_biases : bias_array;
    signal output_weights : weight_array;
    signal output_biases : bias_array;
    
    -- Processing signals
    signal input_buffer : STD_LOGIC_VECTOR(INPUT_SIZE-1 downto 0);
    signal input_count : unsigned(9 downto 0);
    signal processing_state : unsigned(1 downto 0);
    signal hidden_layer : signed(15 downto 0);
    signal output_layer : signed(15 downto 0);
    
begin

    process(clk, rst)
    begin
        if rst = '1' then
            detection_valid <= '0';
            detection_x <= (others => '0');
            detection_y <= (others => '0');
            detection_width <= (others => '0');
            detection_height <= (others => '0');
            detection_class <= (others => '0');
            input_count <= (others => '0');
            processing_state <= (others => '0');
            
        elsif rising_edge(clk) then
            detection_valid <= '0';
            
            case processing_state is
                when "00" => -- Input Collection
                    if input_valid = '1' then
                        input_buffer(to_integer(input_count)) <= input_data(0);
                        input_count <= input_count + 1;
                        
                        if input_count = INPUT_SIZE-1 then
                            processing_state <= "01";
                            input_count <= (others => '0');
                        end if;
                    end if;
                    
                when "01" => -- Hidden Layer Processing
                    if input_count < HIDDEN_SIZE then
                        -- Compute hidden layer neuron output
                        hidden_layer <= hidden_weights(to_integer(input_count)) * 
                                      signed('0' & input_buffer(to_integer(input_count))) +
                                      hidden_biases(to_integer(input_count));
                        input_count <= input_count + 1;
                    else
                        processing_state <= "10";
                        input_count <= (others => '0');
                    end if;
                    
                when "10" => -- Output Layer Processing
                    if input_count < OUTPUT_SIZE then
                        -- Compute output layer neuron output
                        output_layer <= output_weights(to_integer(input_count)) * 
                                      hidden_layer +
                                      output_biases(to_integer(input_count));
                        input_count <= input_count + 1;
                    else
                        -- Generate detection outputs
                        detection_valid <= '1';
                        detection_x <= std_logic_vector(to_unsigned(100, 10)); -- Example values
                        detection_y <= std_logic_vector(to_unsigned(100, 10));
                        detection_width <= std_logic_vector(to_unsigned(50, 10));
                        detection_height <= std_logic_vector(to_unsigned(50, 10));
                        detection_class <= std_logic_vector(to_unsigned(1, 4));
                        
                        processing_state <= "00";
                        input_count <= (others => '0');
                    end if;
                    
                when others =>
                    processing_state <= "00";
            end case;
        end if;
    end process;

end Behavioral;