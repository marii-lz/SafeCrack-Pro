// Controle da FSM do SafeCrack Pro.
// Os quatro dígitos são ajustados pelos botões da placa.
// btn[0]: confirma e avança
// btn[1]: aumenta o dígito
// btn[2]: diminui o dígito
// rstn: reset assíncrono
module safecrackpro_fsm #(
    parameter int         CLK_FREQ_HZ = 50_000_000,
    parameter int         GREEN_SECS  = 5,
    parameter int         RED_SECS    = 3,
    parameter logic [3:0] PASS_D0     = 4'd1,
    parameter logic [3:0] PASS_D1     = 4'd2,
    parameter logic [3:0] PASS_D2     = 4'd3,
    parameter logic [3:0] PASS_D3     = 4'd4
) (
    input  logic            clk,
    input  logic            rstn,
    input  logic [2:0]      btn,
    output logic [3:0][3:0] digits,
    output logic [1:0]      current_position_idx,
    output logic [17:0]     led_red,
    output logic [8:0]      led_green
);

    // Estados da máquina (codificação one-hot).
    typedef enum logic [7:0] {
        START               = 8'b0000_0001,  // estado inicial (pós-reset / pós-LEDs)
        CURRENT_POSITION    = 8'b0000_0010,  // aguardando botão
        INC_POSITION        = 8'b0000_0100,  // KEY[1]: confirma dígito, avança posição
        INC_DIGIT           = 8'b0000_1000,  // KEY[2]: dígito + 1
        DEC_DIGIT           = 8'b0001_0000,  // KEY[3]: dígito - 1
        CHECK_PASSWORD      = 8'b0010_0000,  // compara dígitos com a senha
        WAIT_RED_LED_TIME   = 8'b0100_0000,  // LEDs vermelhos por RED_SECS
        WAIT_GREEN_LED_TIME = 8'b1000_0000   // LEDs verdes por GREEN_SECS
    } state_t;

    state_t state, next_state;

    // Gera um pulso quando um botão é pressionado.
    logic [2:0] btn_pos, btn_prev, btn_edge;

    always_comb begin
        btn_pos  = ~btn;
        btn_edge = btn_pos & ~btn_prev;
    end

    // Contador usado para controlar o tempo dos LEDs.
    localparam int GREEN_CYCLES = GREEN_SECS * CLK_FREQ_HZ;
    localparam int RED_CYCLES   = RED_SECS   * CLK_FREQ_HZ;
    localparam int CNT_W        = $clog2(GREEN_CYCLES > RED_CYCLES ? GREEN_CYCLES : RED_CYCLES);

    logic [CNT_W-1:0] led_time_cnt, next_led_time_cnt;

    // Valores que serão atualizados no próximo ciclo de clock.
    logic [3:0][3:0] next_digits;
    logic [1:0]      next_position_idx;

    // Atualiza os registradores na borda do clock.
    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state                <= START;
            btn_prev             <= 3'b000;
            digits               <= '0;
            current_position_idx <= 2'd0;
            led_time_cnt         <= '0;
        end else begin
            state                <= next_state;
            btn_prev             <= btn_pos;
            digits               <= next_digits;
            current_position_idx <= next_position_idx;
            led_time_cnt         <= next_led_time_cnt;
        end
    end

    // Define o próximo estado e os próximos valores dos registradores.
    always_comb begin
        // Mantém os valores atuais quando não há alteração.
        next_state        = state;
        next_digits       = digits;
        next_position_idx = current_position_idx;
        next_led_time_cnt = led_time_cnt;

        unique case (state)
            START: next_state = CURRENT_POSITION;

            CURRENT_POSITION: begin
                // Considera apenas um botão pressionado por vez.
                case (btn_edge)
                    3'b001:  next_state = INC_POSITION;
                    3'b010:  next_state = INC_DIGIT;
                    3'b100:  next_state = DEC_DIGIT;
                    default: next_state = CURRENT_POSITION;
                endcase
            end

            INC_DIGIT: begin
                next_digits[current_position_idx] =
                    (digits[current_position_idx] == 4'd9) ? 4'd0
                                                           : digits[current_position_idx] + 4'd1;
                next_state = CURRENT_POSITION;
            end

            DEC_DIGIT: begin
                next_digits[current_position_idx] =
                    (digits[current_position_idx] == 4'd0) ? 4'd9
                                                           : digits[current_position_idx] - 4'd1;
                next_state = CURRENT_POSITION;
            end

            INC_POSITION: begin
                if (current_position_idx == 2'd3) begin
                    next_state = CHECK_PASSWORD;
                end else begin
                    next_position_idx = current_position_idx + 2'd1;
                    next_state        = CURRENT_POSITION;
                end
            end

            CHECK_PASSWORD: begin
                if (digits == {PASS_D3, PASS_D2, PASS_D1, PASS_D0}) begin
                    next_led_time_cnt = CNT_W'(GREEN_CYCLES - 1);
                    next_state        = WAIT_GREEN_LED_TIME;
                end else begin
                    next_led_time_cnt = CNT_W'(RED_CYCLES - 1);
                    next_state        = WAIT_RED_LED_TIME;
                end
            end

            WAIT_RED_LED_TIME, WAIT_GREEN_LED_TIME: begin
                if (led_time_cnt == '0) begin
                    // Ao terminar, zera os dígitos e volta à primeira posição.
                    next_digits       = '0;
                    next_position_idx = 2'd0;
                    next_state        = START;
                end else begin
                    next_led_time_cnt = led_time_cnt - 1'b1;
                end
            end

            default: next_state = START;
        endcase
    end

    // Acende os LEDs de acordo com o estado atual.
    always_comb begin
        led_red   = (state == WAIT_RED_LED_TIME)   ? '1 : '0;
        led_green = (state == WAIT_GREEN_LED_TIME) ? '1 : '0;
    end

endmodule
