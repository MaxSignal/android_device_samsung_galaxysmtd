/*
 * s1q_mtd_erase <mtd char device>: erase every good block of an MTD partition
 * (flash_erase without the mtd-utils). Used once to turn an efs partition
 * that this kernel's yaffs2 cannot read into an empty yaffs2 file system.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <mtd/mtd-user.h>

int main(int argc, char **argv)
{
    struct mtd_info_user info;
    struct erase_info_user erase;
    int fd, bad = 0;
    loff_t ofs;

    if (argc != 2) {
        fprintf(stderr, "usage: %s /dev/mtd/mtdN\n", argv[0]);
        return 2;
    }
    fd = open(argv[1], O_RDWR | O_CLOEXEC);
    if (fd < 0 || ioctl(fd, MEMGETINFO, &info) < 0) {
        fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
        return 1;
    }
    for (erase.start = 0; erase.start < info.size; erase.start += info.erasesize) {
        ofs = erase.start;
        if (ioctl(fd, MEMGETBADBLOCK, &ofs) > 0) {
            bad++;
            continue;
        }
        erase.length = info.erasesize;
        if (ioctl(fd, MEMERASE, &erase) < 0)
            fprintf(stderr, "erase at 0x%x: %s\n", erase.start, strerror(errno));
    }
    printf("%s: erased %u bytes (%d bad blocks skipped)\n", argv[1], info.size, bad);
    close(fd);
    return 0;
}
