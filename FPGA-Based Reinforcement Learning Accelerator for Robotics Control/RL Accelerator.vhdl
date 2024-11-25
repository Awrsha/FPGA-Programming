-- Top-level entity for RL Accelerator
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rl_accelerator is
    generic (
        STATE_WIDTH : integer := 32;
        ACTION_WIDTH : integer := 16;
        Q_WIDTH : integer := 32;
        MEMORY_DEPTH : integer := 1024;
        LEARNING_RATE_WIDTH : integer := 16
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        -- State and action inputs
        state_in : in std_logic_vector(STATE_WIDTH-1 downto 0);
        action_in : in std_logic_vector(ACTION_WIDTH-1 downto 0);
        reward_in : in std_logic_vector(Q_WIDTH-1 downto 0);
        -- Control signals
        start_learning : in std_logic;
        done_learning : out std_logic;
        -- Q-value output
        q_value_out : out std_logic_vector(Q_WIDTH-1 downto 0);
        best_action_out : out std_logic_vector(ACTION_WIDTH-1 downto 0)
    );
end rl_accelerator;

architecture behavioral of rl_accelerator is
    -- Q-table memory component
    component q_table_memory is
        port (
            clk : in std_logic;
            write_en : in std_logic;
            addr_read : in std_logic_vector(STATE_WIDTH+ACTION_WIDTH-1 downto 0);
            addr_write : in std_logic_vector(STATE_WIDTH+ACTION_WIDTH-1 downto 0);
            data_in : in std_logic_vector(Q_WIDTH-1 downto 0);
            data_out : out std_logic_vector(Q_WIDTH-1 downto 0)
        );
    end component;
    
    -- Neural network component for function approximation
    component neural_network is
        port (
            clk : in std_logic;
            rst : in std_logic;
            state_in : in std_logic_vector(STATE_WIDTH-1 downto 0);
            action_in : in std_logic_vector(ACTION_WIDTH-1 downto 0);
            q_value_out : out std_logic_vector(Q_WIDTH-1 downto 0)
        );
    end component;
    
    -- Experience replay buffer
    component replay_buffer is
        port (
            clk : in std_logic;
            rst : in std_logic;
            write_en : in std_logic;
            state_in : in std_logic_vector(STATE_WIDTH-1 downto 0);
            action_in : in std_logic_vector(ACTION_WIDTH-1 downto 0);
            reward_in : in std_logic_vector(Q_WIDTH-1 downto 0);
            next_state_in : in std_logic_vector(STATE_WIDTH-1 downto 0);
            sample_valid : out std_logic;
            sample_state : out std_logic_vector(STATE_WIDTH-1 downto 0);
            sample_action : out std_logic_vector(ACTION_WIDTH-1 downto 0);
            sample_reward : out std_logic_vector(Q_WIDTH-1 downto 0);
            sample_next_state : out std_logic_vector(STATE_WIDTH-1 downto 0)
        );
    end component;

    -- Internal signals
    signal q_table_write_en : std_logic;
    signal q_table_addr_read : std_logic_vector(STATE_WIDTH+ACTION_WIDTH-1 downto 0);
    signal q_table_addr_write : std_logic_vector(STATE_WIDTH+ACTION_WIDTH-1 downto 0);
    signal q_table_data_in : std_logic_vector(Q_WIDTH-1 downto 0);
    signal q_table_data_out : std_logic_vector(Q_WIDTH-1 downto 0);
    
    signal nn_q_value : std_logic_vector(Q_WIDTH-1 downto 0);
    
    signal replay_write_en : std_logic;
    signal replay_sample_valid : std_logic;
    signal replay_sample_state : std_logic_vector(STATE_WIDTH-1 downto 0);
    signal replay_sample_action : std_logic_vector(ACTION_WIDTH-1 downto 0);
    signal replay_sample_reward : std_logic_vector(Q_WIDTH-1 downto 0);
    signal replay_sample_next_state : std_logic_vector(STATE_WIDTH-1 downto 0);
    
    -- State machine signals
    type state_type is (IDLE, LEARNING, UPDATE_Q, FIND_BEST_ACTION);
    signal current_state, next_state : state_type;
    
    -- Learning parameters
    signal gamma : std_logic_vector(LEARNING_RATE_WIDTH-1 downto 0);
    signal alpha : std_logic_vector(LEARNING_RATE_WIDTH-1 downto 0);
    
begin
    -- Q-table memory instantiation
    q_table : q_table_memory
    port map (
        clk => clk,
        write_en => q_table_write_en,
        addr_read => q_table_addr_read,
        addr_write => q_table_addr_write,
        data_in => q_table_data_in,
        data_out => q_table_data_out
    );
    
    -- Neural network instantiation
    nn : neural_network
    port map (
        clk => clk,
        rst => rst,
        state_in => state_in,
        action_in => action_in,
        q_value_out => nn_q_value
    );
    
    -- Experience replay buffer instantiation
    replay : replay_buffer
    port map (
        clk => clk,
        rst => rst,
        write_en => replay_write_en,
        state_in => state_in,
        action_in => action_in,
        reward_in => reward_in,
        next_state_in => state_in, -- Assuming next state is current state for simplicity
        sample_valid => replay_sample_valid,
        sample_state => replay_sample_state,
        sample_action => replay_sample_action,
        sample_reward => replay_sample_reward,
        sample_next_state => replay_sample_next_state
    );
    
    -- State machine process
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;
    
    -- Next state logic
    process(current_state, start_learning, replay_sample_valid)
    begin
        case current_state is
            when IDLE =>
                if start_learning = '1' then
                    next_state <= LEARNING;
                else
                    next_state <= IDLE;
                end if;
                
            when LEARNING =>
                if replay_sample_valid = '1' then
                    next_state <= UPDATE_Q;
                else
                    next_state <= LEARNING;
                end if;
                
            when UPDATE_Q =>
                next_state <= FIND_BEST_ACTION;
                
            when FIND_BEST_ACTION =>
                next_state <= IDLE;
                
            when others =>
                next_state <= IDLE;
        end case;
    end process;
    
    -- Q-learning update process
    process(clk)
        variable max_q : signed(Q_WIDTH-1 downto 0);
        variable target_q : signed(Q_WIDTH-1 downto 0);
        variable current_q : signed(Q_WIDTH-1 downto 0);
        variable td_error : signed(Q_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            case current_state is
                when LEARNING =>
                    -- Sample from replay buffer and prepare for Q-update
                    replay_write_en <= '1';
                    
                when UPDATE_Q =>
                    -- Calculate TD error and update Q-value
                    current_q := signed(q_table_data_out);
                    max_q := signed(nn_q_value);
                    target_q := signed(replay_sample_reward) + signed(gamma) * max_q;
                    td_error := target_q - current_q;
                    
                    -- Update Q-table
                    q_table_write_en <= '1';
                    q_table_data_in <= std_logic_vector(current_q + signed(alpha) * td_error);
                    q_table_addr_write <= replay_sample_state & replay_sample_action;
                    
                when FIND_BEST_ACTION =>
                    -- Find best action for current state
                    q_table_write_en <= '0';
                    -- Implementation of action selection logic
                    -- This could be epsilon-greedy or other policy
                    best_action_out <= action_in; -- Simplified for now
                    
                when others =>
                    q_table_write_en <= '0';
                    replay_write_en <= '0';
            end case;
        end if;
    end process;
    
    -- Output assignments
    q_value_out <= q_table_data_out;
    done_learning <= '1' when current_state = IDLE else '0';

end behavioral;

-- Q-table memory implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity q_table_memory is
    port (
        clk : in std_logic;
        write_en : in std_logic;
        addr_read : in std_logic_vector(47 downto 0);
        addr_write : in std_logic_vector(47 downto 0);
        data_in : in std_logic_vector(31 downto 0);
        data_out : out std_logic_vector(31 downto 0)
    );
end q_table_memory;

architecture behavioral of q_table_memory is
    type memory_array is array (0 to 1023) of std_logic_vector(31 downto 0);
    signal memory : memory_array := (others => (others => '0'));
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if write_en = '1' then
                memory(to_integer(unsigned(addr_write))) <= data_in;
            end if;
            data_out <= memory(to_integer(unsigned(addr_read)));
        end if;
    end process;
end behavioral;

-- Neural network implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity neural_network is
    port (
        clk : in std_logic;
        rst : in std_logic;
        state_in : in std_logic_vector(31 downto 0);
        action_in : in std_logic_vector(15 downto 0);
        q_value_out : out std_logic_vector(31 downto 0)
    );
end neural_network;

architecture behavioral of neural_network is
    -- Neural network parameters
    type weight_array is array (0 to 63) of signed(15 downto 0);
    signal weights_layer1 : weight_array;
    signal weights_layer2 : weight_array;
    
    -- Layer signals
    signal layer1_outputs : std_logic_vector(63 downto 0);
    signal layer2_outputs : std_logic_vector(31 downto 0);
    
begin
    -- Neural network forward pass
    process(clk, rst)
        variable temp_sum : signed(31 downto 0);
    begin
        if rst = '1' then
            -- Initialize weights
            for i in 0 to 63 loop
                weights_layer1(i) <= (others => '0');
                weights_layer2(i) <= (others => '0');
            end loop
        elsif rising_edge(clk) then
            -- Layer 1 computation
            for i in 0 to 63 loop
                temp_sum := (others => '0');
                for j in 0 to 31 loop
                    temp_sum := temp_sum + signed(state_in(j)) * weights_layer1(i);
                end loop
                -- ReLU activation
                if temp_sum > 0 then
                    layer1_outputs(i) <= '1';
                else
                    layer1_outputs(i) <= '0';
                end if;
            end loop
            
            -- Layer 2 computation
            temp_sum := (others => '0');
            for i in 0 to 63 loop
                if layer1_outputs(i) = '1' then
                    temp_sum := temp_sum + weights_layer2(i);
                end if;
            end loop
            
            q_value_out <= std_logic_vector(temp_sum);
        end if;
    end process;
end behavioral;

-- Experience replay buffer implementation
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity replay_buffer is
    port (
        clk : in std_logic;
        rst : in std_logic;
        write_en : in std_logic;
        state_in : in std_logic_vector(31 downto 0);
        action_in : in std_logic_vector(15 downto 0);
        reward_in : in std_logic_vector(31 downto 0);
        next_state_in : in std_logic_vector(31 downto 0);
        sample_valid : out std_logic;
        sample_state : out std_logic_vector(31 downto 0);
        sample_action : out std_logic_vector(15 downto 0);
        sample_reward : out std_logic_vector(31 downto 0);
        sample_next_state : out std_logic_vector(31 downto 0)
    );
end replay_buffer;

architecture behavioral of replay_buffer is
    -- Buffer parameters
    constant BUFFER_SIZE : integer := 1024;
    
    type state_memory is array (0 to BUFFER_SIZE-1) of std_logic_vector(31 downto 0);
    type action_memory is array (0 to BUFFER_SIZE-1) of std_logic_vector(15 downto 0);
    type reward_memory is array (0 to BUFFER_SIZE-1) of std_logic_vector(31 downto 0);
    
    signal states : state_memory;
    signal actions : action_memory;
    signal rewards : reward_memory;
    signal next_states : state_memory;
    
    signal write_ptr : unsigned(9 downto 0);
    signal read_ptr : unsigned(9 downto 0);
    signal buffer_full : std_logic;
    
begin
    process(clk, rst)
    begin
        if rst = '1' then
            write_ptr <= (others => '0');
            read_ptr <= (others => '0');
            buffer_full <= '0';
            sample_valid <= '0';
        elsif rising_edge(clk) then
            if write_en = '1' then
                -- Write new experience to buffer
                states(to_integer(write_ptr)) <= state_in;
                actions(to_integer(write_ptr)) <= action_in;
                rewards(to_integer(write_ptr)) <= reward_in;
                next_states(to_integer(write_ptr)) <= next_state_in;
                
                write_ptr <= write_ptr + 1;
                if write_ptr = BUFFER_SIZE-1 then
                    buffer_full <= '1';
                end if;
            end if;
            
            -- Random sampling
            if buffer_full = '1' then
                read_ptr <= unsigned(state_in(9 downto 0)); -- Use state as random seed
                sample_valid <= '1';
                sample_state <= states(to_integer(read_ptr));
                sample_action <= actions(to_integer(read_ptr));
                sample_reward <= rewards(to_integer(read_ptr));
                sample_next_state <= next_states(to_integer(read_ptr));
            else
                sample_valid <= '0';
            end if;
        end if;
    end process;
end behavioral;