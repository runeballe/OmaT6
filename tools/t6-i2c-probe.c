// Probe the MCT Trigger 6 vendor I2C requests (0x81 read, 0x02 write) to find
// the encoding, using only reads of the monitor's EDID (I2C 0x50), which has a
// known 8-byte header. Read-only: sends no I2C writes.
//
// Build: cc -O2 -o t6-i2c-probe t6-i2c-probe.c -lusb-1.0
// Run:   sudo ./t6-i2c-probe
#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <string.h>

#define VENDOR_REQ_I2C_READ 0x81
#define VENDOR_REQ_GET_EDID 0x80

static const unsigned char EDID_HDR[8] = {0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00};

static void dump(const char *label, const unsigned char *b, int n) {
    printf("%-44s", label);
    for (int i = 0; i < n && i < 16; i++) printf(" %02x", b[i]);
    printf("\n");
}

int main(void) {
    libusb_context *ctx;
    if (libusb_init(&ctx)) return 1;
    libusb_device_handle *h = NULL;
    for (unsigned pid = 0x5600; pid <= 0x57ff && !h; pid++)
        h = libusb_open_device_with_vid_pid(ctx, 0x0711, pid);
    if (!h) { fprintf(stderr, "No MCT T6 device found (or no permission: run with sudo)\n"); return 1; }

    unsigned char buf[64];
    int r;

    // Reference: the documented EDID request.
    memset(buf, 0, sizeof buf);
    r = libusb_control_transfer(h, 0xc0, VENDOR_REQ_GET_EDID, 0, 0, buf, 16, 1000);
    printf("reference GET_EDID (0x80) ret=%d\n", r);
    if (r > 0) dump("  edid:", buf, r);

    // Candidate encodings for I2C_READ: wValue = 7-bit or 8-bit address, wIndex = bus/set 0..3.
    const unsigned addrs[] = {0x50, 0xA0, 0xA1, 0x5000, 0xA000};
    for (unsigned a = 0; a < sizeof addrs / sizeof *addrs; a++) {
        for (unsigned idx = 0; idx < 4; idx++) {
            memset(buf, 0xEE, sizeof buf);
            r = libusb_control_transfer(h, 0xc0, VENDOR_REQ_I2C_READ, addrs[a], idx, buf, 16, 1000);
            char label[64];
            snprintf(label, sizeof label, "I2C_READ wValue=0x%04x wIndex=%u ret=%d", addrs[a], idx, r);
            if (r > 0) {
                dump(label, buf, r);
                if (r >= 8 && !memcmp(buf, EDID_HDR, 8)) printf("    ^^^ EDID header: this encoding works\n");
            } else {
                printf("%s (%s)\n", label, libusb_error_name(r));
            }
        }
    }
    libusb_close(h);
    libusb_exit(ctx);
    return 0;
}
