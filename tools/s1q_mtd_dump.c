/*
 * s1q_mtd_dump <mtd char device> <output prefix>: read-only dump of an MTD
 * partition, page data to <prefix>.data and the raw spare area of every page
 * to <prefix>.oob (nanddump without the mtd-utils). Used to study the factory
 * EFS (Samsung FSR STL keeps its page mapping in the spare area).
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <mtd/mtd-user.h>

int main(int argc, char **argv)
{
    struct mtd_info_user info;
    struct mtd_oob_buf oob;
    char path[512];
    unsigned char *page, *spare;
    FILE *fd_data, *fd_oob;
    unsigned int ofs, errors = 0;
    int fd;

    if (argc != 3) {
        fprintf(stderr, "usage: %s /dev/mtdNro <output prefix>\n", argv[0]);
        return 2;
    }
    fd = open(argv[1], O_RDONLY | O_CLOEXEC);
    if (fd < 0 || ioctl(fd, MEMGETINFO, &info) < 0) {
        fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
        return 1;
    }
    page = malloc(info.writesize);
    spare = malloc(info.oobsize);
    snprintf(path, sizeof(path), "%s.data", argv[2]);
    fd_data = fopen(path, "wb");
    snprintf(path, sizeof(path), "%s.oob", argv[2]);
    fd_oob = fopen(path, "wb");
    if (!page || !spare || !fd_data || !fd_oob) {
        fprintf(stderr, "cannot create %s.*: %s\n", argv[2], strerror(errno));
        return 1;
    }
    for (ofs = 0; ofs < info.size; ofs += info.writesize) {
        if (pread(fd, page, info.writesize, ofs) != (ssize_t)info.writesize) {
            memset(page, 0xee, info.writesize);   /* uncorrectable: mark */
            errors++;
        }
        oob.start = ofs;
        oob.length = info.oobsize;
        oob.ptr = spare;
        if (ioctl(fd, MEMREADOOB, &oob) < 0)
            memset(spare, 0xee, info.oobsize);
        fwrite(page, 1, info.writesize, fd_data);
        fwrite(spare, 1, info.oobsize, fd_oob);
    }
    fclose(fd_data);
    fclose(fd_oob);
    printf("%s: %u bytes, page %u, oob %u, erase %u, %u read errors\n", argv[1],
           info.size, info.writesize, info.oobsize, info.erasesize, errors);
    return 0;
}
