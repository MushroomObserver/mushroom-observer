#include <stdio.h>
#include <stdlib.h>
#include <string.h>

unsigned char codes[256][4] = {
    "\xE2\x82\xAC\x00",
    "\xC2\x81\x00\x00",
    "\xE2\x80\x9A\x00",
    "\xC6\x92\x00\x00",
    "\xE2\x80\x9E\x00",
    "\xE2\x80\xA6\x00",
    "\xE2\x80\xA0\x00",
    "\xE2\x80\xA1\x00",
    "\xCB\x86\x00\x00",
    "\xE2\x80\xB0\x00",
    "\xC5\xA0\x00\x00",
    "\xE2\x80\xB9\x00",
    "\xC5\x92\x00\x00",
    "\xC2\x8D\x00\x00",
    "\xC5\xBD\x00\x00",
    "\xC2\x8F\x00\x00",
    "\xC2\x90\x00\x00",
    "\xE2\x80\x98\x00",
    "\xE2\x80\x99\x00",
    "\xE2\x80\x9C\x00",
    "\xE2\x80\x9D\x00",
    "\xE2\x80\xA2\x00",
    "\xE2\x80\x93\x00",
    "\xE2\x80\x94\x00",
    "\xCB\x9C\x00\x00",
    "\xE2\x84\xA2\x00",
    "\xC5\xA1\x00\x00",
    "\xE2\x80\xBA\x00",
    "\xC5\x93\x00\x00",
    "\xC2\x9D\x00\x00",
    "\xC5\xBE\x00\x00",
    "\xC5\xB8\x00\x00",
    "\xC2\xA0\x00\x00",
    "\xC2\xA1\x00\x00",
    "\xC2\xA2\x00\x00",
    "\xC2\xA3\x00\x00",
    "\xC2\xA4\x00\x00",
    "\xC2\xA5\x00\x00",
    "\xC2\xA6\x00\x00",
    "\xC2\xA7\x00\x00",
    "\xC2\xA8\x00\x00",
    "\xC2\xA9\x00\x00",
    "\xC2\xAA\x00\x00",
    "\xC2\xAB\x00\x00",
    "\xC2\xAC\x00\x00",
    "\xC2\xAD\x00\x00",
    "\xC2\xAE\x00\x00",
    "\xC2\xAF\x00\x00",
    "\xC2\xB0\x00\x00",
    "\xC2\xB1\x00\x00",
    "\xC2\xB2\x00\x00",
    "\xC2\xB3\x00\x00",
    "\xC2\xB4\x00\x00",
    "\xC2\xB5\x00\x00",
    "\xC2\xB6\x00\x00",
    "\xC2\xB7\x00\x00",
    "\xC2\xB8\x00\x00",
    "\xC2\xB9\x00\x00",
    "\xC2\xBA\x00\x00",
    "\xC2\xBB\x00\x00",
    "\xC2\xBC\x00\x00",
    "\xC2\xBD\x00\x00",
    "\xC2\xBE\x00\x00",
    "\xC2\xBF\x00\x00",
    "\xC3\x80\x00\x00",
    "\xC3\x81\x00\x00",
    "\xC3\x82\x00\x00",
    "\xC3\x83\x00\x00",
    "\xC3\x84\x00\x00",
    "\xC3\x85\x00\x00",
    "\xC3\x86\x00\x00",
    "\xC3\x87\x00\x00",
    "\xC3\x88\x00\x00",
    "\xC3\x89\x00\x00",
    "\xC3\x8A\x00\x00",
    "\xC3\x8B\x00\x00",
    "\xC3\x8C\x00\x00",
    "\xC3\x8D\x00\x00",
    "\xC3\x8E\x00\x00",
    "\xC3\x8F\x00\x00",
    "\xC3\x90\x00\x00",
    "\xC3\x91\x00\x00",
    "\xC3\x92\x00\x00",
    "\xC3\x93\x00\x00",
    "\xC3\x94\x00\x00",
    "\xC3\x95\x00\x00",
    "\xC3\x96\x00\x00",
    "\xC3\x97\x00\x00",
    "\xC3\x98\x00\x00",
    "\xC3\x99\x00\x00",
    "\xC3\x9A\x00\x00",
    "\xC3\x9B\x00\x00",
    "\xC3\x9C\x00\x00",
    "\xC3\x9D\x00\x00",
    "\xC3\x9E\x00\x00",
    "\xC3\x9F\x00\x00",
    "\xC3\xA0\x00\x00",
    "\xC3\xA1\x00\x00",
    "\xC3\xA2\x00\x00",
    "\xC3\xA3\x00\x00",
    "\xC3\xA4\x00\x00",
    "\xC3\xA5\x00\x00",
    "\xC3\xA6\x00\x00",
    "\xC3\xA7\x00\x00",
    "\xC3\xA8\x00\x00",
    "\xC3\xA9\x00\x00",
    "\xC3\xAA\x00\x00",
    "\xC3\xAB\x00\x00",
    "\xC3\xAC\x00\x00",
    "\xC3\xAD\x00\x00",
    "\xC3\xAE\x00\x00",
    "\xC3\xAF\x00\x00",
    "\xC3\xB0\x00\x00",
    "\xC3\xB1\x00\x00",
    "\xC3\xB2\x00\x00",
    "\xC3\xB3\x00\x00",
    "\xC3\xB4\x00\x00",
    "\xC3\xB5\x00\x00",
    "\xC3\xB6\x00\x00",
    "\xC3\xB7\x00\x00",
    "\xC3\xB8\x00\x00",
    "\xC3\xB9\x00\x00",
    "\xC3\xBA\x00\x00",
    "\xC3\xBB\x00\x00",
    "\xC3\xBC\x00\x00",
    "\xC3\xBD\x00\x00",
    "\xC3\xBE\x00\x00",
    "\xC3\xBF\x00\x00"
};

int validate_utf(unsigned char *str) {
    if (str[0] < 0x80)
        return(1);
    if ((str[0] & 0xE0) == 0xC0 &&
        (str[1] & 0xC0) == 0x80)
        return(2);
    if ((str[0] & 0xF0) == 0xE0 &&
        (str[1] & 0xC0) == 0x80 &&
        (str[2] & 0xC0) == 0x80)
        return(3);
    if ((str[0] & 0xF8) == 0xF0 &&
        (str[1] & 0xC0) == 0x80 &&
        (str[2] & 0xC0) == 0x80 &&
        (str[3] & 0xC0) == 0x80)
        return(4);
    return(0);
}

unsigned char out_buf[10];
int out_len = 0;

void print(unsigned char c) {
    int i, j;
    out_buf[out_len++] = c;
    out_buf[out_len] = 0;
    for (i=0; i<out_len-4; ) {
        if (j = validate_utf(out_buf + i)) {
            fwrite(out_buf+i, 1, j, stdout);
            i += j;
        } else {
            i++;
        }
    }
    memcpy(out_buf, out_buf+i, out_len-i);
    out_len -= i;
}

void flush() {
    int i, j;
    out_buf[out_len] = 0;
    for (i=0; i<out_len; ) {
        if (j = validate_utf(out_buf + i)) {
            fwrite(out_buf+i, 1, j, stdout);
            i += j;
        } else {
            i++;
        }
    }
    out_len = 0;
}

int main(int argc, char **argv) {
    unsigned char buf[1004];
    int  len = fread(buf, 1, 1000, stdin);
    int  i = 0;
    int  j, k;
    int  eof = 0;
    buf[len] = 0;
    while (1) {
        if (i > len - 4) {
            memcpy(buf, buf+i, len-i);
            len -= i;
            len += fread(buf+len, 1, 1000-len, stdin);
            buf[len] = 0;
            if (!len) break;
            i = 0;
        }
        if (buf[i] < 128) {
            while (i < len && buf[i] < 128)
                print(buf[i++]);
        } else if (j = validate_utf(buf+i)) {
            for (k=0; k<128; k++) {
                if (buf[i+0] == codes[k][0] &&
                    buf[i+1] == codes[k][1] &&
                    (buf[i+2] == codes[k][2] || codes[k][2] == 0))
                    break;
            }
            if (k < 128) {
                print(k + 128);
                i += j;
            } else {
                while (j--)
                    print(buf[i++]);
            }
        } else {
            i++;
        }
    }
    flush();
    exit(0);
}

