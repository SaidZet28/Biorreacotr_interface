"""
Test actuador canal 0 — PWM directo sin OE toggle.
OE fijo en LOW (salidas siempre habilitadas).
PCA9685 corre a 60 Hz, duty cycle controla la potencia.
Ejecutar con: sudo python3 test_pca9685_ch0.py
"""
import pigpio, smbus2, time, sys

PCA_ADDR = 0x40
PIN_OE   = 17

bus = smbus2.SMBus(1)

def pca_init():
    bus.write_byte_data(PCA_ADDR, 0x00, 0x10)
    bus.write_byte_data(PCA_ADDR, 0xFE, 50)    # 120 Hz
    bus.write_byte_data(PCA_ADDR, 0x00, 0x20)
    time.sleep(0.001)
    bus.write_byte_data(PCA_ADDR, 0x00, 0xA0)

def set_duty(pct):
    val = int(max(0.0, min(100.0, pct)) / 100.0 * 4095)
    bus.write_i2c_block_data(PCA_ADDR, 0x06, [0, 0, val & 0xFF, val >> 8])

pi = pigpio.pi()
if not pi.connected:
    print("Error: sudo pigpiod primero"); bus.close(); sys.exit(1)

pi.set_mode(PIN_OE, pigpio.OUTPUT)
pi.write(PIN_OE, 0)   # OE fijo en LOW — salidas siempre habilitadas

pca_init()
set_duty(0)
print("Listo\n")

try:
    for pct in [25, 50, 75, 100, 75, 50, 25, 0]:
        set_duty(pct)
        print(f"{pct}% — 3 s")
        time.sleep(3)
finally:
    set_duty(0)
    pi.write(PIN_OE, 1)
    pi.stop()
    bus.close()
    print("Apagado OK")
