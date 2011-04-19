/* Build with: gcc jpegresize.c -ljpeg -lm -O2 -o jpegresize
/*
/* runtime:  flags:
/* 2.8956
/* 2.1513    (ImageMagick's convert)
/* 1.3060    -O2                      <------ (i.e., probably makes no difference!)
/* 1.3120    -O2 -m64
/* 1.3122    -O2 -mmmx -msse -msse2
/* 1.3175    -O3
/* 1.3182    -O3 -mmmx -msse -msse2
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <jpeglib.h>

#define F_FLAT      1
#define F_LINEAR    2
#define F_HERMITE   3
#define F_CATROM    4
#define F_MITCHELL  5
#define F_KEYS      6
#define F_LANCZOS   7

#define M_SET_SIZE  1
#define M_MAX_SIZE  2
#define M_MIN_SIZE  3
#define M_SET_AREA  4
#define M_MAX_AREA  5
#define M_MIN_AREA  6

#define PI 3.14159265358979

#define USAGE "jpegresize [-flags] [-param <val>] <w>x<h> <input.jpg> <output.jpg>"

void  bad_usage(char*, char*);
char* remove_arg(char**, int*, int);
char* get_file(char**, int*);
void  get_size(char**, int*, int*, int*);
int   get_flag(char**, int*, char*, char*);
float get_value(char**, int*, char*, char*, float);
int   get_filter(char**, int*, char*, int, float, float);
int   default_quality(int, int);
float calc_factor(float);

int   filter;  /* filter type: 1=bilinear, 2=hermite, 3=bicubic, 4=lanczos */
float radius;  /* half-width of convolution kernel */
float sharp;   /* sharpen image? */
float arg1;    /* first argument to filter: meaning varies */
float arg2;    /* second argument to filter: meaning varies */
float c1, c2, c3, c4, c5, c6, c7, c8;  /* used by Keys-type filters */

/* --------------------------- */
/*  Main program.              */
/* --------------------------- */

int main(int argc, char **argv) {
    struct jpeg_decompress_struct dinfo;
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;

    char *file1;   /* input filename */
    char *file2;   /* output filename */
    FILE *fh1;     /* input file handle */
    FILE *fh2;     /* output file handle */
    float *data;   /* partially-convolved rows in 4-tuples: r, g, b, sum */
    float **ptrs;  /* pointers into input buffer, one for each scanline */
    JSAMPLE *line; /* input/output buffer */
    float *fx,*fy; /* convolution kernel cache */
    int mode;      /* resize mode (see M_SET_SIZE, etc.) */
    int quality;   /* jpeg quality: 0 to 100 */
    int len;       /* length of one line in data */
    int w1, h1, z1; /* size of input image */
    int w2, h2;    /* size of output image */
    int w3, h3;    /* size of convolution kernel */
    int xo, yo;    /* number of cols/rows to side of center of kernel */
    int y1, n1;    /* first row and number of rows loaded into input buffer */
    int yc;        /* last row loaded from input file */
    int x2, y2;    /* current location in output image */
    float xf, yf;  /* corresponding location in input image */
    float ax, ay;  /* constants needed for Lanczos kernel */
    float extra;   /* multiply kernel radius by this to get extra lobes */
    int kernel;    /* boolean: dump convolution kernel and abort? */
    int verbose;   /* boolean: verbose mode? */

    /* Temporary variables. */
    float *ptr1, *ptr2, *ptr3;
    JSAMPLE *ptr4;
    int x, y, i, j, k, c;
    float f, r, g, b, s, *accum;

    /* Print help message. */
    if (argc <= 1 || get_flag(argv, &argc, "-h", "--help")) {
        printf("\n");
        printf("USAGE\n");
        printf("    %s\n", USAGE);
        printf("\n");
        printf("OPTIONS\n");
        printf("    <w>x<h>             Width and height of output image, e.g., '200x200'.\n");
        printf("    <input.jpg>         Input image.  Must be 'normal' RGB color JPEG.\n");
        printf("    <output.jpg>        Output image.  Clobbers any existing file.\n");
        printf("\n");
        printf("    --set-size          Default mode: set to given size, ignoring aspect ratio.\n");
        printf("    --set-area          Keep aspect ratio, reducing/enlarging to area of given box.\n");
        printf("    --max-size          Keep aspect ratio, reducing to within given box.\n");
        printf("    --max-area          Keep aspect ratio, reducing to area of given box.\n");
        printf("    --min-size          Keep aspect ratio, enlarging to contain given box.\n");
        printf("    --min-area          Keep aspect ratio, enlarging to area of given box.\n");
        printf("\n");
        printf("    -q --quality <pct>  JPEG quality of output image; default depends on size.\n");
        printf("    -r --radius <n>     Radius of convolution kernel, > 0; default is 1.0.\n");
        printf("    -s --sharp <n>      Amount to sharpen output, >= 0; default is 0.2.\n");
        printf("\n");
        printf("    --flat              Average pixels within box of given radius.\n");
        printf("    --linear            Weight pixels within box linearly by closeness.\n");
        printf("    --hermite           Hermite cubic spline filter; similar to Gaussian.\n");
        printf("    --catrom [<M>]      Catmull-Rom cubic spline; default is M = 0.5 at R = 1.\n");
        printf("    --mitchell          Mitchell-Netravali filter (see Keys filter).\n");
        printf("    --keys [<B> <C>]    Keys family filters; default is B = C = 1/3 (Mitchell).\n");
        printf("    --lanczos [<N>]     Lanczos windowed sinc filter; default is N = 3 lobes.\n");
        printf("\n");
        printf("    -h --help           Print this message.\n");
        printf("    -v --verbose        Verbose / debug mode.\n");
        printf("    -k --kernel         Dump convolution kernel without processing image.\n");
        printf("\n");
        exit(1);
    }

    /* Get command line args. */
    get_size(argv, &argc, &w2, &h2);
    quality = get_value(argv, &argc, "-q", "--quality", default_quality(w2, h2));
    radius  = get_value(argv, &argc, "-r", "--radius", 1.0);
    sharp   = get_value(argv, &argc, "-s", "--sharp", 0.2);
    verbose = get_flag(argv, &argc, "-v", "--verbose");
    kernel  = get_flag(argv, &argc, "-k", "--kernel");

    /* Only allowed one mode flag. */
    mode = get_flag(argv, &argc, "--set-size", 0) ? M_SET_SIZE :
           get_flag(argv, &argc, "--max-size", 0) ? M_MAX_SIZE :
           get_flag(argv, &argc, "--min-size", 0) ? M_MIN_SIZE :
           get_flag(argv, &argc, "--set-area", 0) ? M_SET_AREA :
           get_flag(argv, &argc, "--max-area", 0) ? M_MAX_AREA :
           get_flag(argv, &argc, "--min-area", 0) ? M_MIN_AREA : M_SET_SIZE;

    /* Each filter type takes different arguments. */
    if (get_filter(argv, &argc, "--flat", 0, 0, 0)) {
        filter = F_FLAT;
        extra  = 1.0;
    } else if (get_filter(argv, &argc, "--linear", 0, 0, 0)) {
        filter = F_LINEAR;
        extra  = 1.0;
    } else if (get_filter(argv, &argc, "--hermite", 0, 0, 0)) {
        filter = F_HERMITE;
        extra  = 1.0;
    } else if (get_filter(argv, &argc, "--catrom",   1, 1.0, 0.0)) {
        filter = F_CATROM;
        extra  = 2.0;
    } else if (get_filter(argv, &argc, "--mitchell", 0, 0.0, 0.0)) {
        filter = F_KEYS;
        extra  = 2.0;
        arg1   = 1.0 / 3.0;
        arg2   = 1.0 / 3.0;
    } else if (get_filter(argv, &argc, "--keys",     2, 1.0/3.0, 1.0/3.0)) {
        filter = F_KEYS;
        extra  = 2.0;
    } else if (get_filter(argv, &argc, "--lanczos",  1, 3.0, 0.0)) {
        filter = F_LANCZOS;
        extra  = arg1;
    } else {
        filter = F_LANCZOS;
        arg1   = 3.0;
        extra  = arg1;
    }

    /* Get files last because they complain if there are any flags left. */
    file1 = get_file(argv, &argc);
    file2 = get_file(argv, &argc);
    if (argc > 1) bad_usage("unexpected argument: %s", argv[1]);

    /* Create and initialize decompress object. */
    dinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&dinfo);
    if ((fh1 = fopen(file1, "rb")) == NULL) {
        fprintf(stderr, "can't open %s for reading\n", file1);
        exit(1);
    }
    jpeg_stdio_src(&dinfo, fh1);

    /* Get dimensions and format of input image. */
    jpeg_read_header(&dinfo, TRUE);
    jpeg_start_decompress(&dinfo);
    w1 = dinfo.output_width;
    h1 = dinfo.output_height;
    z1 = dinfo.output_components;

    /* Choose output size. */
    if (mode == M_SET_SIZE) {
        /* leave as is */
    } else if (mode == M_MAX_SIZE) {
        if (w1 > w2 && h1 * w2 / w1 < h2) {
            h2 = h1 * w2 / w1 + 0.5;
        } else if (h1 > h2) {
            w2 = w1 * h2 / h1 + 0.5;
        } else {
            w2 = w1;
            h2 = h1;
        }
    } else if (mode == M_MIN_SIZE) {
        if (w1 < w2 && h1 * w2 / w1 > h2) {
            h2 = h1 * w2 / w1 + 0.5;
        } else if (h1 < h2) {
            w2 = w1 * h2 / h1 + 0.5;
        } else {
            w2 = w1;
            h2 = h1;
        }
    } else if (mode == M_SET_AREA) {
        double f = sqrt(((double)w2) * h2 / w1 / h1);
        w2 = w1 * f + 0.5;
        h2 = h1 * f + 0.5;
    } else if (mode == M_MAX_AREA) {
        if (w1 * h1 > w2 * h2) {
            double f = sqrt(((double)w2) * h2 / w1 / h1);
            w2 = w1 * f + 0.5;
            h2 = h1 * f + 0.5;
        } else {
            w2 = w1;
            h2 = h1;
        }
    } else if (mode == M_MIN_AREA) {
        if (w1 * h1 < w2 * h2) {
            double f = sqrt(((double)w2) * h2 / w1 / h1);
            w2 = w1 * f + 0.5;
            h2 = h1 * f + 0.5;
        } else {
            w2 = w1;
            h2 = h1;
        }
    } else {
        fprintf(stderr, "invalid mode: %d!", mode);
        exit(1);
    }

    if (verbose) {
        fprintf(stderr, "input:   %dx%d (%d) %s\n", w1, h1, z1, file1);
        fprintf(stderr, "output:  %dx%d (%d) %s\n", w2, h2, z1, file2);
        fprintf(stderr, "quality: %d\n", quality);
        fprintf(stderr, "radius:  %f\n", radius);
        fprintf(stderr, "sharp:   %f\n", sharp);
        if (filter == F_FLAT)    fprintf(stderr, "filter:  flat\n");
        if (filter == F_LINEAR)  fprintf(stderr, "filter:  bilinear\n");
        if (filter == F_HERMITE) fprintf(stderr, "filter:  hermite\n");
        if (filter == F_CATROM)  fprintf(stderr, "filter:  Catmull-Rom (M=%f)\n", arg1);
        if (filter == F_KEYS)    fprintf(stderr, "filter:  Keys-family (B=%f, C=%f)\n", arg1, arg2);
        if (filter == F_LANCZOS) fprintf(stderr, "filter:  Lanczos (N=%f)\n", arg1);
    }

    /* Calculate size of convolution kernel. */
    ax = w1 > w2 ? radius * w1 / w2 : radius;
    ay = h1 > h2 ? radius * h1 / h2 : radius;
    xo = (int)(ax * extra + 0.5);
    yo = (int)(ay * extra + 0.5);
    w3 = xo + xo + 1;
    h3 = yo + yo + 1;

    /* Pre-calculate coefficients for Keys-family filters. */
    if (filter == F_CATROM) {
        filter = F_KEYS;
        c1 = 2.0 - arg1;
        c2 = -3.0 + arg1;
        c3 = 0.0;
        c4 = 1.0;
        c5 = -arg1;
        c6 = 2.0 * arg1;
        c7 = -arg1;
        c8 = 0.0;
    } else if (filter == F_KEYS) {
        c1 = ( 12.0 + -9.0 * arg1 +  -6.0 * arg2) / 6.0;
        c2 = (-18.0 + 12.0 * arg1 +   6.0 * arg2) / 6.0;
        c3 = (  0.0 +  0.0 * arg1 +   0.0 * arg2) / 6.0;
        c4 = (  6.0 + -2.0 * arg1 +   0.0 * arg2) / 6.0;
        c5 = (  0.0 + -1.0 * arg1 +  -6.0 * arg2) / 6.0;
        c6 = (  0.0 +  3.0 * arg1 +  12.0 * arg2) / 6.0;
        c7 = (  0.0 + -3.0 * arg1 +  -6.0 * arg2) / 6.0;
        c8 = (  0.0 +  1.0 * arg1 +   0.0 * arg2) / 6.0;
    }

    if (verbose) {
        fprintf(stderr, "w1-h1:   %d %d\n", w1, h1);
        fprintf(stderr, "xo-yo:   %d %d\n", xo, yo);
        fprintf(stderr, "w3-h3:   %d %d\n", w3, h3);
        fprintf(stderr, "ax-ay:  %8.5f %8.5f\n", ax, ay);
        fprintf(stderr, "c1-4:   %8.5f %8.5f %8.5f %8.5f\n", c1, c2, c3, c4);
        fprintf(stderr, "c5-8:   %8.5f %8.5f %8.5f %8.5f\n", c5, c6, c7, c8);
    }

    /* Debug convolution kernel. */
    if (kernel) {
        f = -1;
        for (xf=0; xf<10.0; xf+=0.1) {
            s = calc_factor(xf);
            fprintf(stderr, "%5.2f %7.4f\n", xf, s);
            if (s == 0.0 && f == 0.0)
                break;
            f = s;
        }
        exit(0);
    }

    /* Allocate buffers. */
    len   = w2 * (z1 + 1);
    data  = (float*)malloc(h3 * len * sizeof(float));
    ptrs  = (float**)malloc(h3 * sizeof(float*));
    line  = (JSAMPLE*)malloc((w1 > w2 ? w1 : w2) * z1 * sizeof(JSAMPLE));
    fx    = (float*)malloc(w2 * w3 * sizeof(float));
    fy    = (float*)malloc(h2 * h3 * sizeof(float));
    accum = (float*)malloc(z1 * sizeof(float));

    /* Cache horizontal and vertical components of kernel. */
    for (x2=0, ptr3=fx; x2<w2; x2++) {
        xf = ((float)x2) * w1 / w2;
        for (i=0, x=(int)xf-xo; i<w3; i++, x++) {
            *ptr3++ = calc_factor(fabs(xf-x) / ax);
        }
    }
    for (y2=0, ptr3=fy; y2<h2; y2++) {
        yf = ((float)y2) * h1 / h2;
        for (i=0, y=(int)yf-yo; i<h3; i++, y++) {
            *ptr3++ = calc_factor(fabs(yf-y) / ay);
        }
    }

    /* Create and initialize compress object. */
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    if ((fh2 = fopen(file2, "wb")) == NULL) {
        fprintf(stderr, "can't open %s for writing\n", file2);
        exit(1);
    }
    jpeg_stdio_dest(&cinfo, fh2);
    cinfo.image_width = w2;
    cinfo.image_height = h2;
    cinfo.input_components = z1;
    switch (z1) {
    case 1:
        cinfo.in_color_space = JCS_GRAYSCALE;
        break;
    case 3:
        cinfo.in_color_space = JCS_RGB;
        break;
    case 4:
        cinfo.in_color_space = JCS_CMYK;
        break;
    default:
        fprintf(stderr, "Not sure what colorspace to make output for input file with %d components.\n", z1);
        exit(1);
    }
    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, TRUE);
    jpeg_start_compress(&cinfo, TRUE);

    /* Loop through output rows. */
    n1 = 0;  /* (num lines in buffer) */
    yc = -1; /* (last line loaded) */
    for (y2=0; y2<h2; y2++) {
        yf = ((float)y2) * h1 / h2;

        /* Make sure we have the 'yo' rows above and below this row. */
        y = (int)yf - yo;
        if (y - y1 >= h3) n1 = 0;
        ptr1 = n1 ? ptrs[y - y1] : data;
        if (n1) n1 -= y - y1;
        for (i=0; i<h3; i++, y++) {

            /* Move already-loaded lines into place until run out. */
            ptrs[i] = ptr1;
            ptr1 += len;
            if (ptr1 >= data + len * h3) ptr1 = data;

            /* Need to load this line into next available slot. */
            /* It's okay to leave junk in lines outside input image. */
            if (n1-- <= 0 && y >= 0 && y < h1) {

                /* Read lines until get the one we want. */
                for (; yc<y; yc++) {
                    if (!jpeg_read_scanlines(&dinfo, &line, 1)) {
                        fprintf(stderr, "JPEG image corrupted at line %d.\n", yc);
                        exit(1);
                    }
                }

                /* Do horizontal part of convolution now.  Stores a partial
                /* result for each output column for this input row. */
/* ------------------------- start switch 1 on z1 ------------------------- */
                switch (z1) {
                case 1:
                    for (x2=0, ptr2=ptrs[i], ptr3=fx; x2<w2; x2++) {
                        xf = ((float)x2) * w1 / w2;
                        r = s = 0;
                        for (j=0, x=(int)xf-xo; j<w3; j++, x++) {
                            f = *ptr3++;
                            if (x >= 0 && x < w1 && fabs(f) > 1e-8) {
                                ptr4 = line + x;
                                r += f * *ptr4++;
                                s += f;
                            }
                        }
                        if (fabs(s) > 1e-3) {
                            *ptr2++ = r;
                            *ptr2++ = s;
                        } else {
                            fprintf(stderr, "x factor near zero -- shouldn't happen!\n");
                            ptr4 = line + (int)xf;
                            *ptr2++ = *ptr4++;
                            *ptr2++ = 1.0;
                        }
                    }
                    break;

                case 3:
                    for (x2=0, ptr2=ptrs[i], ptr3=fx; x2<w2; x2++) {
                        xf = ((float)x2) * w1 / w2;
                        r = g = b = s = 0;
                        for (j=0, x=(int)xf-xo; j<w3; j++, x++) {
                            f = *ptr3++;
                            if (x >= 0 && x < w1 && fabs(f) > 1e-8) {
                                ptr4 = line + x + x + x;
                                r += f * *ptr4++;
                                g += f * *ptr4++;
                                b += f * *ptr4++;
                                s += f;
                            }
                        }
                        if (fabs(s) > 1e-3) {
                            *ptr2++ = r;
                            *ptr2++ = g;
                            *ptr2++ = b;
                            *ptr2++ = s;
                        } else {
                            fprintf(stderr, "x factor near zero -- shouldn't happen!\n");
                            ptr4 = line + (int)xf * 3;
                            *ptr2++ = *ptr4++;
                            *ptr2++ = *ptr4++;
                            *ptr2++ = *ptr4++;
                            *ptr2++ = 1.0;
                        }
                    }
                    break;

                default:
                    for (x2=0, ptr2=ptrs[i], ptr3=fx; x2<w2; x2++) {
                        xf = ((float)x2) * w1 / w2;
                        for (s=k=0; k<z1; k++)
                            accum[k] = 0;
                        for (j=0, x=(int)xf-xo; j<w3; j++, x++) {
                            f = *ptr3++;
                            if (x >= 0 && x < w1 && fabs(f) > 1e-8) {
                                ptr4 = line + x * z1;
                                for (k=0; k<z1; k++)
                                    accum[k] += f * *ptr4++;
                                s += f;
                            }
                        }
                        if (fabs(s) > 1e-3) {
                            for (k=0; k<z1; k++)
                                *ptr2++ = accum[k];
                            *ptr2++ = s;
                        } else {
                            fprintf(stderr, "x factor near zero -- shouldn't happen!\n");
                            ptr4 = line + (int)xf * z1;
                            for (k=0; k<z1; k++)
                                *ptr2++ = *ptr4++;
                            *ptr2++ = 1.0;
                        }
                    }
                }
/* ------------------------- end switch 1 on z1 ------------------------- */

            }
/* printf("i=%d y2=%d yc=%d y1=%d n1=%d ptrs[i]=%d\n", i, y2, yc, y1, n1, (ptrs[i]-data)/len); */
        }

        /* Now have h3 lines in buffer, starting at y - yo. */
        y1 = (int)yf - yo;
        n1 = h3;

        /* Do vertical part of convolution now.  Finish off calculation for
        /* each output column in this output row by iterating over partial
        /* results for each corresponding input row we calculated above. */
/* ------------------------- start switch 2 on z1 ------------------------- */
        switch (z1) {
        case 1:
            for (x2=0, ptr4=line; x2<w2; x2++) {
                xf = ((float)x2) * w1 / w2;
                r = s = 0;
                ptr3 = fy + y2 * h3;
                for (i=0, y=(int)yf-yo; i<h3; i++, y++) {
                    f = *ptr3++;
                    if (y >= 0 && y < h1 && fabs(f) > 1e-8) {
                        ptr1 = ptrs[i] + x2 + x2;
                        r += f * *ptr1++;
                        s += f * *ptr1++;
                    }
/* printf("x2=%d y2=%d i=%d f=%f s=%f (y=%d ptr1=%d)\n", x2, y2, i, f, s, y, (ptr1-data)/len); */
                }
                if (fabs(s) > 1e-3) {
                    *ptr4++ = (c = r / s) > 255 ? 255 : c < 0 ? 0 : c;
                } else {
                    fprintf(stderr, "y factor near zero -- shouldn't happen!\n");
                    ptr1 = ptrs[h3/2] + ((int)xf) * 4;
                    *ptr4++ = *ptr1++;
                }
            }
            break;

        case 3:
            for (x2=0, ptr4=line; x2<w2; x2++) {
                xf = ((float)x2) * w1 / w2;
                r = g = b = s = 0;
                ptr3 = fy + y2 * h3;
                for (i=0, y=(int)yf-yo; i<h3; i++, y++) {
                    f = *ptr3++;
                    if (y >= 0 && y < h1 && fabs(f) > 1e-8) {
                        ptr1 = ptrs[i] + x2 * 4;
                        r += f * *ptr1++;
                        g += f * *ptr1++;
                        b += f * *ptr1++;
                        s += f * *ptr1++;
                    }
/* printf("x2=%d y2=%d i=%d f=%f s=%f (y=%d ptr1=%d)\n", x2, y2, i, f, s, y, (ptr1-data)/len); */
                }
                if (fabs(s) > 1e-3) {
                    *ptr4++ = (c = r / s) > 255 ? 255 : c < 0 ? 0 : c;
                    *ptr4++ = (c = g / s) > 255 ? 255 : c < 0 ? 0 : c;
                    *ptr4++ = (c = b / s) > 255 ? 255 : c < 0 ? 0 : c;
                } else {
                    fprintf(stderr, "y factor near zero -- shouldn't happen!\n");
                    ptr1 = ptrs[h3/2] + ((int)xf) * 4;
                    *ptr4++ = *ptr1++;
                    *ptr4++ = *ptr1++;
                    *ptr4++ = *ptr1++;
                }
            }
            break;

        default:
            for (x2=0, ptr4=line; x2<w2; x2++) {
                xf = ((float)x2) * w1 / w2;
                for (s=k=0; k<z1; k++)
                    accum[k] = 0;
                ptr3 = fy + y2 * h3;
                for (i=0, y=(int)yf-yo; i<h3; i++, y++) {
                    f = *ptr3++;
                    if (y >= 0 && y < h1 && fabs(f) > 1e-8) {
                        ptr1 = ptrs[i] + x2 * (z1 + 1);
                        for (k=0; k<z1; k++)
                            accum[k] += f * *ptr1++;
                        s += f * *ptr1++;
                    }
/* printf("x2=%d y2=%d i=%d f=%f s=%f (y=%d ptr1=%d)\n", x2, y2, i, f, s, y, (ptr1-data)/len); */
                }
                if (fabs(s) > 1e-3) {
                    for (k=0; k<z1; k++)
                        *ptr4++ = (c = accum[k] / s) > 255 ? 255 : c < 0 ? 0 : c;
                } else {
                    fprintf(stderr, "y factor near zero -- shouldn't happen!\n");
                    ptr1 = ptrs[h3/2] + ((int)xf) * 4;
                    for (k=0; k<z1; k++)
                        *ptr4++ = *ptr1++;
                }
            }
        }
/* ------------------------- end switch 2 on z1 ------------------------- */

        /* Write this output line. */
        jpeg_write_scanlines(&cinfo, &line, 1);
    }

    /* Finish off compression. */
    jpeg_finish_compress(&cinfo);

    /* Clean up. */
    jpeg_destroy_decompress(&dinfo);
    jpeg_destroy_compress(&cinfo);
    free(data);
    free(line);
    free(ptrs);
    free(fx);
    free(accum);
    exit(0);
}

/* ------------------------------- */
/*  Calculate convolution kernel.  */
/* ------------------------------- */

float calc_factor(x)
float x;
{
    float f;
    switch (filter) {

    /* Box interpolation. */
    case F_FLAT:
        f = x < 1.0 ? 1.0 : 0.0;
        break;

    /* Bilinear interpolation. */
    case F_LINEAR:
        f = x < 1.0 ? 1.0 - x : 0.0;
        break;

    /* Hermite cubic spline: 2x^3 - 3x^2 + 1 */
    case F_HERMITE:
        f = x < 1.0 ? (2.0 * x - 3.0) * x * x + 1.0 : 0.0;
        break;

    /* Keys-type filters: generalized two-part spline with variable overshoot
    /* in the second "lobe". */
    case F_KEYS:
        if (x < 1.0) {
            f = ((c1 * x + c2) * x + c3) * x + c4;
        } else if (x < 2.0) {
            float x2 = x - 1.0;
            f = ((c5 * x2 + c6) * x2 + c7) * x2 + c8;
        } else {
            f = 0.0;
        }
        break;

    /* Windowed Lanczos: a sin(pi x) sin(pi x / a) / pi2 x2,
    /* where a is number of "lobes", and x is in output space. */
    case F_LANCZOS:
        if (x < 0.01) {
            float x1 = PI * x;
            float x2 = PI * x / arg1;
            f = (1.0 - x1*x1/6.0) * (1.0 - x2*x2/6.0);
        } else if (x < arg1) {
            f = sin(PI * x) * sin(PI * x / arg1) / x / x * arg1 / PI / PI;
        } else {
            f = 0.0;
        }
        break;

    default:
        fprintf(stderr, "invalid filter: %d\n", filter);
        exit(1);
    }

    /* Add some amount of standard Catmull-Rom filter to it to enhance
    /* sharpening. */
    if (sharp > 0) {
        if (x < 1.0) {
            f += sharp * ((x - 2.0) * x * x + 1.0);
        } else if (x < 2.0) {
            float x2 = x - 1.0;
            f += sharp * ((-x2 + 2.0) * x2 - 1.0) * x2;
        }
    }

    return(f);
}

/* --------------------------- */
/*  Command line processing.   */
/* --------------------------- */

/* Print usage syntax and die. */
void bad_usage(msg, arg)
char *msg, *arg;
{
    fprintf(stderr, "ERROR: ");
    fprintf(stderr, msg, arg);
    fprintf(stderr, "\nUSAGE: %s\n", USAGE);
    exit(1);
}

/* Extract arg at position n and return it. */
char *remove_arg(argv, argc, n)
char **argv;
int *argc;
int n;
{
    int i;
    char *arg;
    arg = argv[n];
    for (i=n+1; i<*argc; i++) argv[i-1] = argv[i];
    (*argc)--;
    return(arg);
}

/* Extract first filename from command line. */
char *get_file(argv, argc)
char **argv;
int *argc;
{
    if (*argc < 2)         bad_usage("missing file", 0);
    if (argv[1][0] == '-') bad_usage("unexpected argument: %s", argv[1]);
    return(remove_arg(argv, argc, 1));
}

/* Extract size from command line as "123x456". */
void get_size(argv, argc, wp, hp)
char **argv;
int *argc;
int *wp;
int *hp;
{
    int i, j, k;
    char *arg;
    for (i=1; i<*argc; i++) {
        arg = argv[i];
        for (j=0; isdigit(arg[j]); j++) {}
        if (j == 0 || arg[j] != 'x') continue;
        for (k=++j; isdigit(arg[j]); j++) {}
        if (j == k || arg[j] != 0) continue;
        *wp = atoi(arg);
        *hp = atoi(arg + k);
        remove_arg(argv, argc, i);
        return;
    }
    bad_usage("missing size", 0);
}

/* Check for and extract a given flag from command line. */
int get_flag(argv, argc, flag1, flag2)
char **argv;
int *argc;
char *flag1;
char *flag2;
{
    int i;
    for (i=1; i<*argc; i++) {
        if (flag1 && !strcmp(argv[i], flag1) ||
            flag2 && !strcmp(argv[i], flag2)) {
            remove_arg(argv, argc, i);
            return(1);
        }
    }
    return(0);
}

/* Check for and extract a given parameter and its value from command line. */
float get_value(argv, argc, flag1, flag2, def)
char **argv;
int *argc;
char *flag1;
char *flag2;
float def;
{
    int i;
    char *arg;
    for (i=1; i<*argc; i++) {
        if (flag1 && !strcmp(argv[i], flag1) ||
            flag2 && !strcmp(argv[i], flag2)) {
            arg = remove_arg(argv, argc, i);
            if (*argc <= i) bad_usage("missing value for %s", arg);
            return(atof(remove_arg(argv, argc, i)));
        }
    }
    return(def);
}

/* Check for and extract a given filter flag and its value(s) if any from
/* the command line. */
int get_filter(argv, argc, flag, num_args, def1, def2)
char **argv;
int *argc;
char *flag;
int num_args;
float def1;
float def2;
{
    int i;
    for (i=1; i<*argc; i++) {
        if (flag && !strcmp(argv[i], flag)) {
            remove_arg(argv, argc, i);
            if (num_args > 0) {
                if (*argc <= i || argv[i][0] == '-' &&
                        !isdigit(argv[i][1]) && argv[i][1] != '.')
                     arg1 = def1;
                else arg1 = atof(remove_arg(argv, argc, i));
            }
            if (num_args > 1) {
                if (*argc <= i || argv[i][0] == '-' &&
                        !isdigit(argv[i][1]) && argv[i][1] != '.')
                     arg2 = def2;
                else arg2 = atof(remove_arg(argv, argc, i));
            }
            return(1);
        }
    }
    return(0);
}

/* Return reasonable JPEG quality depending on output image size. */
/* (This is purely subjective based on my own prefs. -JPH) */
int default_quality(w, h)
int w, h;
{
    if (w < 300  || h <  300) return(95);
    if (w < 600  || h <  600) return(90);
    if (w < 1000 || h < 1000) return(85);
    if (w < 2000 || h < 2000) return(80);
    if (w < 3000 || h < 3000) return(75);
    return(70);
}

