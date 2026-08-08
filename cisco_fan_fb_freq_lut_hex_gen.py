CLK_FREQ = 50_000_000
RPM_MAX = 15_000
PPR = 2
DUTY_RATIO_WIDTH = 8
FREQ_DIVIDE_WIDTH = 26
RPM_WIDTH = 14
OUTPUT_FILE = "rtl/cisco_fan_fb_freq_lut.hex"

def calculate_rpm(duty_ratio):
    if duty_ratio == 0:
        return 0

    ratio_max = (1 << DUTY_RATIO_WIDTH) - 1
    return (RPM_MAX * duty_ratio + ratio_max // 2) // ratio_max

def calculate_freq_divide(rpm):
    if rpm == 0:
        return 1

    numerator = CLK_FREQ * 60
    denominator = rpm * PPR
    freq_divide = (numerator + denominator // 2) // denominator
    max_freq_divide = (1 << FREQ_DIVIDE_WIDTH) - 1

    if freq_divide > max_freq_divide:
        freq_divide = max_freq_divide

    return freq_divide

def main():
    lut_depth = 1 << DUTY_RATIO_WIDTH
    lut_data_width = RPM_WIDTH + FREQ_DIVIDE_WIDTH
    hex_width = (lut_data_width + 3) // 4

    with open(OUTPUT_FILE, "w", newline="\n") as f:
        for duty_ratio in range(lut_depth):
            rpm = calculate_rpm(duty_ratio)
            freq_divide = calculate_freq_divide(rpm)
            lut_data = (rpm << FREQ_DIVIDE_WIDTH) | freq_divide
            f.write(f"{lut_data:0{hex_width}X}\n")
            print(f"duty_ratio = {duty_ratio:3d}, rpm = {rpm:5d}, freq_divide = {freq_divide:8d}, data = {lut_data:0{hex_width}X}")

if __name__ == "__main__":
    main()