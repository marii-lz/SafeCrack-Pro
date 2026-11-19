// Top-level do SafeCrack Pro (DE2-115).
// Liga a FSM aos displays de 7 segmentos e aos LEDs da placa:
//   HEX3..HEX0 mostram os quatro dígitos e HEX4 mostra a posição ativa (1 a 4).
// Os botões são ativos em nível baixo; o tratamento fica dentro da FSM.
module safecrackpro_top (
    input  logic        clk,
    input  logic        rstn,      // KEY[0]: reset
    input  logic [2:0]  btn,       // btn[0]=KEY[1] confirma, btn[1]=KEY[2] incrementa, btn[2]=KEY[3] decrementa
    output logic [6:0]  seg_pos1,  // HEX3: 1º dígito da senha (digits[0])
    output logic [6:0]  seg_pos2,  // HEX2: 2º dígito da senha (digits[1])
    output logic [6:0]  seg_pos3,  // HEX1: 3º dígito da senha (digits[2])
    output logic [6:0]  seg_pos4,  // HEX0: 4º dígito da senha (digits[3])
    output logic [6:0]  seg_cur_pos,     // HEX4: dígito ativo (1 a 4)
    output logic [17:0] led_red,     // 18 LEDs vermelhos (senha errada)
    output logic [8:0]  led_green    // 9 LEDs verdes (senha correta)
);

    logic [3:0][3:0] digits;    // digits[0] = 1º dígito ... digits[3] = 4º dígito
    logic [1:0]      position;  // dígito ativo, de 0 a 3

    // FSM: guarda dígitos e posição, confere a senha e controla os LEDs
    safecrackpro_fsm fsm_inst (
        .clk                  (clk),
        .rstn                 (rstn),
        .btn                  (btn),
        .digits               (digits),
        .current_position_idx (position),
        .led_red              (led_red),
        .led_green            (led_green)
    );

    // Um decodificador de 7 segmentos para cada display
    bcd_to_7segment_anodo dec_pos1 (
        .bcd (digits[0]),
        .seg (seg_pos1)
    );

    bcd_to_7segment_anodo dec_pos2 (
        .bcd (digits[1]),
        .seg (seg_pos2)
    );

    bcd_to_7segment_anodo dec_pos3 (
        .bcd (digits[2]),
        .seg (seg_pos3)
    );

    bcd_to_7segment_anodo dec_pos4 (
        .bcd (digits[3]),
        .seg (seg_pos4)
    );

    // position vai de 0 a 3; somamos 1 para exibir o dígito ativo como 1 a 4
    bcd_to_7segment_anodo dec_cur_pos (
        .bcd ({2'b00, position} + 4'd1),
        .seg (seg_cur_pos)
    );

endmodule
