#include <iostream>
#include <string>
#include <atomic>
#include <thread>
#include <cctype>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <pigpio.h>

static constexpr int GPIO_OE = 17;
static constexpr int GPIO_ZC = 27;
static constexpr unsigned RET_MIN = 1000;
static constexpr unsigned RET_MAX = 7500;

static std::atomic<int>  velocidad{0};
static std::atomic<bool> bomba_on{false};
static int fd = -1;

static void pca_init()
{
    fd = open("/dev/i2c-1", O_RDWR);
    ioctl(fd, I2C_SLAVE, 0x40);
    uint8_t s[2] = {0x00, 0x10}; write(fd, s, 2); usleep(500);
    uint8_t w[2] = {0x00, 0x20}; write(fd, w, 2); usleep(500);
    uint8_t f[5] = {0x06, 0x00, 0x10, 0x00, 0x00}; write(fd, f, 5);  // canal 0
    printf("[PCA9685] Canal 0 FULL ON\n");
}

static void hilo_fase()
{
    int prev = 0;
    while (true) {
        int curr = gpioRead(GPIO_ZC);
        if (curr == 1 && prev == 0) {
            if (bomba_on.load() && velocidad.load() > 0) {
                unsigned v   = (unsigned)velocidad.load();
                unsigned ret = RET_MAX - (RET_MAX - RET_MIN) * v / 100u;
                gpioDelay(ret);
                gpioWrite(GPIO_OE, 0);
                gpioDelay(500);
                gpioWrite(GPIO_OE, 1);
            }
        }
        prev = curr;
        gpioDelay(10);
    }
}

static void procesar(const std::string& cmd)
{
    if (cmd == "ON") {
        bomba_on = true;
        if (velocidad == 0) velocidad = 50;
        printf("Bomba ON al %d%%\n", velocidad.load());
    } else if (cmd == "OFF") {
        bomba_on = false;
        gpioWrite(GPIO_OE, 1);
        printf("Bomba OFF\n");
    } else if (cmd == "ESTADO") {
        printf("Bomba:%s  Nivel:%d%%\n", bomba_on.load() ? "ON" : "OFF", velocidad.load());
    } else {
        try {
            int v = std::stoi(cmd);
            if (v >= 0 && v <= 100) {
                if (!bomba_on) {
                    printf("Manda ON primero\n");
                } else {
                    velocidad = v;
                    if (v == 0) gpioWrite(GPIO_OE, 1);
                    printf("Nivel: %d%%\n", v);
                }
            } else {
                printf("Rango 0-100\n");
            }
        } catch (...) {
            printf("Comandos: ON  OFF  ESTADO  0-100\n");
        }
    }
}

int main()
{
    if (gpioInitialise() < 0) {
        fprintf(stderr, "Error: pigpio fallo\n");
        return 1;
    }
    gpioSetMode(GPIO_OE, PI_OUTPUT);
    gpioWrite(GPIO_OE, 1);
    gpioSetMode(GPIO_ZC, PI_INPUT);
    gpioSetPullUpDown(GPIO_ZC, PI_PUD_UP);

    pca_init();
    std::thread(hilo_fase).detach();

    printf("Dimmer listo. GPIO%d=ZC  GPIO%d=OE\n", GPIO_ZC, GPIO_OE);
    printf("Comandos: ON  OFF  ESTADO  0-100\n\n");

    std::string l;
    while (std::getline(std::cin, l)) {
        while (!l.empty() && (l.back() == 13 || l.back() == ' '))
            l.pop_back();
        for (auto& c : l)
            c = toupper((unsigned char)c);
        if (!l.empty())
            procesar(l);
    }

    gpioWrite(GPIO_OE, 1);
    if (fd >= 0) close(fd);
    gpioTerminate();
}
