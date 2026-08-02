module lcd_reset_command_rom #(
        parameter ADDR_WIDTH = 4,
        parameter DATA_WIDTH = 8,
        parameter DELAY_MS_WIDTH = 4
    )(
        input logic[ADDR_WIDTH - 1:0] addr,
        output logic phy_rs,
        output logic[DATA_WIDTH - 1:0] phy_db,
        output logic need_delay,
        output logic[DELAY_MS_WIDTH - 1:0] delay_ms,
        output logic last_command
    );

    always_comb begin
        phy_rs = 1'b0;
        phy_db = '0;
        need_delay = 1'b0;
        delay_ms = '0;
        last_command = 1'b1;

        case(addr)
            ADDR_WIDTH'('d0): begin//soft reset
                phy_rs = 1'b0;
                phy_db = 'b1110_0010;
                need_delay = 1'b1;
                delay_ms = 'd10;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d1): begin//enable built-in booster
                phy_rs = 1'b0;
                phy_db = 'b0010_1100;
                need_delay = 1'b1;
                delay_ms = 'd10;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d2): begin//enable built-in regulator
                phy_rs = 1'b0;
                phy_db = 'b0010_1110;
                need_delay = 1'b1;
                delay_ms = 'd10;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d3): begin//enable built-in follower
                phy_rs = 1'b0;
                phy_db = 'b0010_1111;
                need_delay = 1'b1;
                delay_ms = 'd10;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d4): begin//set regulation ratio 4
                phy_rs = 1'b0;
                phy_db = 'b0010_0100;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d5): begin//set ev 0x28 - 1
                phy_rs = 1'b0;
                phy_db = 'b1000_0001;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d6): begin//set ev 0x28 - 2
                phy_rs = 1'b0;
                phy_db = 'b0010_1000;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d7): begin//set bias 1/9
                phy_rs = 1'b0;
                phy_db = 'b1010_0010;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d8): begin//disable inverse display
                phy_rs = 1'b0;
                phy_db = 'b1010_0110;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d9): begin//set seg direction normal
                phy_rs = 1'b0;
                phy_db = 'b1010_0000;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d10): begin//set com direction reverse
                phy_rs = 1'b0;
                phy_db = 'b1100_1000;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d11): begin//set init line 0
                phy_rs = 1'b0;
                phy_db = 'b0100_0000;
                last_command = 1'b0;
            end

            ADDR_WIDTH'('d12): begin//enable display
                phy_rs = 1'b0;
                phy_db = 'b10101111;
                last_command = 1'b1;
            end
        endcase
    end
endmodule