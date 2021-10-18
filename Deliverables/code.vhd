library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
--segnali interni
type state is (RESET, ASK_SIZE, GET_SIZE, ASK_VALUE, WAIT_MEMORY, COMPARE, EQUALIZE, WRITE, DONE);
signal current_state : state;
signal current_address : std_logic_vector (15 downto 0) := (others => '0');
signal max : std_logic_vector (7 downto 0) := (others => '0');
signal min : std_logic_vector (7 downto 0) := (others => '0');
signal max_set : std_logic := '0';
signal min_set : std_logic := '0';
signal shift : std_logic_vector(7 downto 0) := (others => '0');
signal cols : std_logic_vector(7 downto 0) := (others => '0');
signal rows : std_logic_vector(7 downto 0) := (others => '0');
signal eq_value : std_logic_vector(15 downto 0) := (others => '0');
signal cols_set : std_logic := '0';
signal rows_set : std_logic := '0';
signal shift_set : std_logic := '0';

begin
--unico processo
process(i_clk, i_rst)
begin
    --reset
	if(i_rst = '1') then
		current_state <= RESET;
	elsif(rising_edge(i_clk)) then
	   --gestione stati
		case current_state is
		
			when RESET =>
				current_address <= (others => '0');
				max <= (others => '0');
				min <= (others => '0');
				eq_value <= (others => '0');
				max_set <= '0';
				min_set <= '0';
				cols_set <= '0';
				rows_set <= '0';
				shift_set <= '0';
				o_done <= '0';
				shift <= (others => '0');
				cols <= (others => '0');
				rows <= (others => '0');
				o_en <= '0';
				o_we <= '0';
				if(i_start = '1') then
				    o_en <= '1';
					current_state <= ASK_SIZE; 
				end if;
				
			when ASK_SIZE =>
				o_we <= '0';
				o_address <= current_address;
				current_state <= WAIT_MEMORY;
				
			when WAIT_MEMORY =>
			    --se devo ancora trovare max e min vado a COMPARE, altrimenti EQUALIZE
			    if(rows_set = '0' or cols_set = '0') then
				    current_state <= GET_SIZE;
				--se devo ancora trovare max e min vado a COMPARE, altrimenti EQUALIZE
				elsif(min_set = '0' or max_set = '0') then
					current_state <= COMPARE;
				else
					current_state <= EQUALIZE;
				end if;
				
			when GET_SIZE =>
			    --se devo ancora richiedere il numero di colonne
				if(cols_set = '0') then
					cols <= i_data;
					cols_set <= '1';
					current_state <= ASK_SIZE;
				--se devo ancora richiedere il numero di colonne
				elsif(rows_set = '0') then
					rows <= i_data;
					rows_set <= '1';
					--se ho zero pixel vado direttamente a DONE
					if(i_data = "00000000" or cols = "00000000") then
					   current_state <= DONE;
					else
					   current_state <= ASK_VALUE;
					end if;
				end if;
				current_address <= std_logic_vector( unsigned(current_address) + 1 );
			
			when ASK_VALUE =>
				o_we <= '0';
				o_address <= current_address;
				current_state <= WAIT_MEMORY;
				
				--se ho appena finito il calcolo di min e max calcolo shift
				if(min_set = '1' and max_set = '1' and shift_set = '0') then
				    --calcolo shift mediante soglie
                    if(std_logic_vector(unsigned(max) - unsigned(min)) < "00000001") then
                       shift <= "00001000";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "00000011") then
                       shift <= "00000111";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "00000111") then
                       shift <= "00000110";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "00001111") then
                       shift <= "00000101";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "00011111") then
                       shift <= "00000100";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "00111111") then
                       shift <= "00000011";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "01111111") then
                       shift <= "00000010";
                    elsif(std_logic_vector(unsigned(max) - unsigned(min)) < "11111111") then
                       shift <= "00000001";
                    else
                       shift <= "00000000";
                    end if;
				    shift_set <= '1';
				end if;
				
			when COMPARE =>
				--primo valore che analizzo diventa massimo e minimo
				if(current_address = "0000000000000010") then
					max <= i_data;
					min <= i_data;
				--verifico se valore è nuovo massimo o minimo
				else
					if(i_data < min) then
						min <= i_data;
					end if;
					if(i_data > max) then
						max <= i_data;
					end if;
				end if;
				--se ultimo pixel immagine smetto ci cercare max e min e mi rimetto all'inizio dell'immagine per equalizzare
				if(current_address = std_logic_vector(unsigned(cols)*unsigned(rows) + 1)) then
				    min_set <= '1';
				    max_set <= '1';
				    current_address <= "0000000000000010";
				else
				    current_address <= std_logic_vector( unsigned(current_address) + 1 );
				end if;
				current_state <= ASK_VALUE;
			
			when EQUALIZE =>
			    --calcolo valore equalizzato
			    eq_value <= std_logic_vector(shift_left(unsigned(i_data) - unsigned(min) + "0000000000000000",TO_INTEGER(unsigned(shift))));
			    current_state <= WRITE;
			
			when WRITE =>
			    o_we <= '1';
			    --se valore equalizzato < 255 allora lo riporto in uscita, altrimenti riporto 255
			    if(unsigned(eq_value)< "0000000011111111") then
			        o_data <= eq_value(7 downto 0);
			    else
			        o_data <= "11111111";
			    end if;
			    o_address <= std_logic_vector(unsigned(current_address) + unsigned(cols) * unsigned(rows));
			    --se sono alla fine dell'immagine vado a DONE, altrimenti chiedo prossimo pixel per equalizzarlo
			    if(current_address = std_logic_vector(unsigned(cols)*unsigned(rows) + 1)) then
			        current_state <= DONE;
			    else
			        current_address <= std_logic_vector( unsigned(current_address) + 1 );
			        current_state <= ASK_VALUE;
			    end if;
			
			when DONE =>
			    --se start è ancora alto notifico fine computazione, altrimenti vado in RESET in attesa di nuovo START
			    if(i_start = '1') then
			        o_done <= '1';
                else
                    o_done <= '0';
                    current_state <= RESET;
                end if;
                o_en <= '0';
                
        end case;		
	end if;
end process;

end Behavioral;
