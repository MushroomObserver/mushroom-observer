/* Build with: cc color_picker.c -ljpeg -o color_picker */

#include <stdio.h>
#include <stdlib.h>
#include <jpeglib.h>

int main(int argc, char **argv) {
    struct jpeg_decompress_struct cinfo;
    struct jpeg_error_mgr jerr;
    FILE *infile;
    char *filename;
    JSAMPLE *buffer;
    JSAMPLE r, g, b;
    int x, y, w, h;
    int i;

    /* Get command line args. */
    if (argc != 4) {
        fprintf(stderr, "Usage: %s file.jpg x y\n", argv[0]);
        exit(1);
    }
    filename = argv[1];
    x = atoi(argv[2]);
    y = atoi(argv[3]);

    /* Allocate and create decompress object. */
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&cinfo);

    /* Open file and let decompressor know. */
    if ((infile = fopen(filename, "rb")) == NULL) {
        fprintf(stderr, "can't open %s\n", filename);
        exit(1);
    }
    jpeg_stdio_src(&cinfo, infile);

    /* Read header info. */
    jpeg_read_header(&cinfo, TRUE);

    /* Start decompression... */
    jpeg_start_decompress(&cinfo);

    /* Allocate buffer to hold one line. */
    w = cinfo.output_width;
    h = cinfo.output_height;   
    if (w < x+1 || h < y+1) {
        fprintf(stderr, "Image is only %dx%d pixels.\n", w, h);
        exit(1);
    }
    buffer = (JSAMPLE*)malloc(w * cinfo.output_components * sizeof(JSAMPLE));

    /* Decompress line by line until we reach right line. */
    for (i=0; i<=y; i++) {
        if (!jpeg_read_scanlines(&cinfo, &buffer, 1)) {
            fprintf(stderr, "JPEG image corrupted at line %d.\n", i+1);
            exit(1);
        }
    }

    /* Grab pixel finally. */
    r = buffer[x*3+0];
    g = buffer[x*3+1];
    b = buffer[x*3+2];
    fprintf(stdout, "%d %d %d\n", (int)r, (int)g, (int)b);

    /* Clean up. */
    jpeg_destroy_decompress(&cinfo);
    free(buffer);
    exit(0);
}

