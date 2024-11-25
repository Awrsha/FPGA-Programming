library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity YOLO_Face_Pipeline is
    Port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        pixel_in : in STD_LOGIC_VECTOR(23 downto 0);
        pixel_valid : in STD_LOGIC;
        frame_start : in STD_LOGIC;
        face_detected : out STD_LOGIC;
        face_x : out STD_LOGIC_VECTOR(10 downto 0);
        face_y : out STD_LOGIC_VECTOR(10 downto 0);
        face_width : out STD_LOGIC_VECTOR(10 downto 0);
        face_height : out STD_LOGIC_VECTOR(10 downto 0);
        face_confidence : out STD_LOGIC_VECTOR(7 downto 0);
        face_id : out STD_LOGIC_VECTOR(7 downto 0)
    );
end YOLO_Face_Pipeline;

architecture Behavioral of YOLO_Face_Pipeline is

    type state_type is (IDLE, PREPROCESS, CONV1, POOL1, CONV2, POOL2, CONV3, 
                       POOL3, CONV4, POOL4, CONV5, POOL5, FC1, FC2, DETECT);
    signal state : state_type;
    
    type feature_map_type is array (0 to 415) of signed(15 downto 0);
    signal feature_maps : feature_map_type;
    
    type weight_array is array (0 to 4095) of signed(7 downto 0);
    signal conv_weights : weight_array;
    
    type bias_array is array (0 to 63) of signed(15 downto 0);
    signal conv_biases : bias_array;
    
    signal conv_result : signed(31 downto 0);
    signal pool_result : signed(15 downto 0);
    
    type anchor_box_type is array (0 to 4) of unsigned(15 downto 0);
    signal anchor_boxes : anchor_box_type;
    
    signal process_count : unsigned(15 downto 0);
    signal pixel_count : unsigned(20 downto 0);
    
    signal temp_x, temp_y : unsigned(10 downto 0);
    signal temp_w, temp_h : unsigned(10 downto 0);
    signal temp_conf : unsigned(7 downto 0);
    signal temp_class : unsigned(7 downto 0);
    
begin

    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            process_count <= (others => '0');
            pixel_count <= (others => '0');
            face_detected <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if frame_start = '1' then
                        state <= PREPROCESS;
                        pixel_count <= (others => '0');
                    end if;
                    
                when PREPROCESS =>
                    if pixel_valid = '1' then
                        feature_maps(to_integer(pixel_count)) <= 
                            signed(resize(unsigned(pixel_in), 16));
                        pixel_count <= pixel_count + 1;
                        
                        if pixel_count = 416*416-1 then
                            state <= CONV1;
                            process_count <= (others => '0');
                        end if;
                    end if;
                    
                when CONV1 =>
                    conv_result <= (others => '0');
                    for i in 0 to 8 loop
                        for j in 0 to 8 loop
                            conv_result <= conv_result + 
                                feature_maps(to_integer(process_count + i + j*416)) * 
                                conv_weights(i + j*9);
                        end loop;
                    end loop;
                    
                    feature_maps(to_integer(process_count)) <= 
                        resize(conv_result + conv_biases(0), 16);
                    
                    process_count <= process_count + 1;
                    if process_count = 414*414-1 then
                        state <= POOL1;
                        process_count <= (others => '0');
                    end if;
                    
                when POOL1 =>
                    pool_result <= feature_maps(to_integer(process_count));
                    if feature_maps(to_integer(process_count + 1)) > pool_result then
                        pool_result <= feature_maps(to_integer(process_count + 1));
                    end if;
                    if feature_maps(to_integer(process_count + 416)) > pool_result then
                        pool_result <= feature_maps(to_integer(process_count + 416));
                    end if;
                    if feature_maps(to_integer(process_count + 417)) > pool_result then
                        pool_result <= feature_maps(to_integer(process_count + 417));
                    end if;
                    
                    feature_maps(to_integer(process_count/4)) <= pool_result;
                    process_count <= process_count + 4;
                    
                    if process_count = 207*207*4-1 then
                        state <= CONV2;
                        process_count <= (others => '0');
                    end if;
                    
                when CONV2 =>
                    state <= POOL2;
                    
                when POOL2 =>
                    state <= CONV3;
                    
                when CONV3 =>
                    state <= POOL3;
                    
                when POOL3 =>
                    state <= CONV4;
                    
                when CONV4 =>
                    state <= POOL4;
                    
                when POOL4 =>
                    state <= CONV5;
                    
                when CONV5 =>
                    state <= POOL5;
                    
                when POOL5 =>
                    state <= FC1;
                    
                when FC1 =>
                    state <= FC2;
                    
                when FC2 =>
                    state <= DETECT;
                    
                when DETECT =>
                    if conv_result > 16384 then
                        face_detected <= '1';
                        face_x <= std_logic_vector(temp_x);
                        face_y <= std_logic_vector(temp_y);
                        face_width <= std_logic_vector(temp_w);
                        face_height <= std_logic_vector(temp_h);
                        face_confidence <= std_logic_vector(temp_conf);
                        face_id <= std_logic_vector(temp_class);
                    else
                        face_detected <= '0';
                    end if;
                    state <= IDLE;
                    
            end case;
        end if;
    end process;

    anchor_boxes <= (
        0 => to_unsigned(32, 16),
        1 => to_unsigned(64, 16),
        2 => to_unsigned(128, 16),
        3 => to_unsigned(256, 16),
        4 => to_unsigned(512, 16)
    );

end Behavioral;