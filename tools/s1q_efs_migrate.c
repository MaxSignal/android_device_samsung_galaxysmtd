/*
 * s1q_efs_migrate <target dir>: rebuild the modem's /efs files (nv_data.bin
 * with the IMEI, imei/, bluetooth address...) from the factory EFS that the
 * stock firmware left at OneNAND 0x80000 (kernel partition "efs_stock").
 *
 * That area is a Samsung FSR STL volume (a log-structured translation layer
 * on the raw flash) holding an RFS (FAT16, 1024-byte sector) file system. The
 * stock kernel needs its closed fsr/rfs modules for it, so this decodes the
 * STL meta data and the FAT directly and copies the files out. It only ever
 * reads the flash; the copy goes to <target dir> (bind mounted on /efs).
 *
 * Nothing is done when <target dir>/nv_data.bin already exists. Exit status 0
 * when the files are there (copied now or before), 1 when they could not be
 * rebuilt.
 *
 * s1q_efs_migrate --dump <page data> <raw oob> <target dir> decodes a dump
 * made by s1q_mtd_dump instead (host testing).
 *
 * Layouts follow Samsung's FSR headers (FSR_STL_Types.h, FSR_LLD.h and the
 * 4KB-page OneNAND LLD's spare packing).
 */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <mtd/mtd-user.h>
#ifdef __ANDROID__
#include <android/log.h>
#endif

#define PG          4096            /* OneNAND page (main) */
#define OOBSZ       128             /* 8 sectors x 16 bytes spare */
#define PPB         64              /* pages per 256K block */
#define NULL16      0xffff
#define RADIO_UID   1001

static unsigned char *g_data, *g_oob;
static unsigned g_npages;

static void logmsg(const char *fmt, ...)
{
    va_list ap;
    char buf[512];

    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    fprintf(stderr, "s1q_efs_migrate: %s\n", buf);
#ifdef __ANDROID__
    __android_log_print(ANDROID_LOG_INFO, "s1q_efs_migrate", "%s", buf);
#endif
}

static uint16_t le16(const unsigned char *p) { return p[0] | p[1] << 8; }
static uint32_t le32(const unsigned char *p) { return le16(p) | (uint32_t)le16(p + 2) << 16; }

static const unsigned char *page(unsigned p) { return g_data + (size_t)p * PG; }

static int blank(unsigned p)
{
    const unsigned char *o = g_oob + (size_t)p * OOBSZ;
    for (int i = 0; i < OOBSZ; i++)
        if (o[i] != 0xff)
            return 0;
    return 1;
}

/* FSRSpareBuf: the first 6 bytes of each sector's 16-byte spare (the other
 * 10 are hardware ECC): base {bad mark, BML meta, STL meta 0..2} + ext[2] */
static void spare(unsigned p, unsigned char sb[48])
{
    const unsigned char *o = g_oob + (size_t)p * OOBSZ;
    for (int s = 0; s < 8; s++)
        memcpy(sb + s * 6, o + s * 16, 6);
}

/* STL meta 0: logical page offset in the high half, inverted in the low */
static int spare_lpo(const unsigned char sb[48])
{
    uint32_t m0 = le32(sb + 4);
    if ((m0 & 0xffff) != (~(m0 >> 16) & 0xffff))
        return -1;
    return m0 >> 16;
}

/* STL meta 2: page type (low byte 0x40 = meta, high byte = meta type) */
static int spare_type(const unsigned char sb[48])
{
    uint32_t m2 = le32(sb + 12);
    if ((m2 & 0xffff) != (~(m2 >> 16) & 0xffff))
        return -1;
    return m2 >> 16;
}

/* write timer: ext[0].nSTLMetaExt2 and its inverse */
static int spare_timer(const unsigned char sb[48], uint32_t *t)
{
    uint32_t a = le32(sb + 24), b = le32(sb + 28);
    if (a != ~b)
        return 0;
    *t = a;
    return 1;
}

#define META_TYPE(mt)   (0x40 | (mt) << 8)
#define MT_ROOT         0x01
#define MT_BMT          0x04
#define MT_PMT          0x08

struct zone {
    unsigned nblks, nmeta, nuser, k, grps_per_pmt;
    unsigned meta[96];
};

static int read_root(struct zone *z)
{
    unsigned best = ~0u;
    uint64_t best_age = ~0ull;

    /* root blocks 0 and 1; the newest page has the smallest age */
    for (unsigned p = 0; p < 2 * PPB && p < g_npages; p++) {
        unsigned char sb[48];
        if (blank(p))
            continue;
        spare(p, sb);
        if (spare_type(sb) != META_TYPE(MT_ROOT) || memcmp(page(p), "FSR_STL", 8))
            continue;
        uint64_t age = (uint64_t)le32(page(p) + 16) << 32 | le32(page(p) + 12);
        if (age <= best_age) {
            best_age = age;
            best = p;
        }
    }
    if (best == ~0u) {
        logmsg("no FSR_STL root page");
        return -1;
    }
    const unsigned char *r = page(best);
    unsigned meta_ver = le32(r + 20), nzone = le16(r + 28), n = le16(r + 32);
    const unsigned char *zi = r + 0x30;
    z->k = le16(r + 34);
    z->nblks = le16(zi + 2);
    z->nmeta = le16(zi + 4);
    z->grps_per_pmt = le16(zi + 10);
    z->nuser = le16(zi + 14);
    logmsg("root at page %u: meta 0x%08x zones %u N %u K %u, %u blocks, %u meta, %u user",
           best, meta_ver, nzone, n, z->k, z->nblks, z->nmeta, z->nuser);
    if (meta_ver != 0x12000400 || nzone != 1 || n != 1 || z->k == 0 || z->k > 32 ||
        z->nmeta == 0 || z->nmeta > 96 || z->nuser == 0 || z->grps_per_pmt == 0 ||
        z->grps_per_pmt > 16) {
        logmsg("unsupported STL layout");
        return -1;
    }
    for (unsigned i = 0; i < z->nmeta; i++)
        z->meta[i] = le16(zi + 32 + 2 * i);
    return 0;
}

/* newest meta page of a type (meta pages carry a down-counting age) */
static int newest_meta(const struct zone *z, int type)
{
    int best = -1;
    uint64_t best_age = ~0ull;

    for (unsigned i = 0; i < z->nmeta; i++)
        for (unsigned pg = 0; pg < PPB; pg++) {
            unsigned p = z->meta[i] * PPB + pg;
            unsigned char sb[48];
            if (p >= g_npages || blank(p))
                continue;
            spare(p, sb);
            if (spare_type(sb) != type)
                continue;
            /* PMT pages start with the context age, BMT+CTX pages carry it
             * in the context after the BMT: compare what is at the start of
             * the PMT and use the spare timer order for the BMT */
            uint64_t age = (uint64_t)le32(page(p) + 4) << 32 | le32(page(p));
            if (type != META_TYPE(MT_PMT)) {
                uint32_t t;
                age = spare_timer(sb, &t) ? ~(uint64_t)t : ~0ull - 1;
            }
            if (age <= best_age) {
                best_age = age;
                best = p;
            }
        }
    return best;
}

/* log group record: Fm(16) + K logs(20) + LBN/numDBlks/VPgCnt lists(3*2K) +
 * page map (2*PPB) + zero bit count confirmation(8) */
static unsigned grp_size(unsigned k) { return 16 + 20 * k + 6 * k + 2 * PPB + 8; }

struct grp {
    unsigned dgn;
    unsigned vbn[32], state[32], cpoffs[32];
    unsigned map[PPB];
};

static void parse_grp(const unsigned char *b, unsigned k, struct grp *g)
{
    g->dgn = le16(b);
    for (unsigned i = 0; i < k; i++) {
        const unsigned char *l = b + 16 + 20 * i;
        g->state[i] = l[0];
        g->vbn[i] = le16(l + 4);
        g->cpoffs[i] = le16(l + 8);
    }
    for (unsigned i = 0; i < PPB; i++)
        g->map[i] = le16(b + 16 + 26 * k + 2 * i);
}

/* resolve one group's pages into (logical page -> physical page); returns the
 * number of pages whose spare disagrees with the map (0 when consistent) */
static int resolve_grp(const struct zone *z, const struct grp *g, unsigned data_vbn,
                       unsigned out[PPB], int apply_por)
{
    int bad = 0;
    uint32_t when[PPB];

    for (unsigned lpo = 0; lpo < PPB; lpo++) {
        out[lpo] = ~0u;
        when[lpo] = 0;
        unsigned v = g->map[lpo];
        if (v != NULL16) {
            unsigned li = v / PPB;
            if (li >= z->k || g->vbn[li] >= z->nblks + 2)
                return -1;
            out[lpo] = g->vbn[li] * PPB + v % PPB;
        } else if (data_vbn != NULL16 && data_vbn < z->nblks + 2) {
            out[lpo] = data_vbn * PPB + lpo;
        }
    }
    /* pages programmed into the logs after this map was saved (the STL
     * replays them after a power loss): newer copies, by write timer */
    if (apply_por)
        for (unsigned li = 0; li < z->k; li++) {
            if (g->vbn[li] == NULL16 || g->state[li] == 0 || g->vbn[li] >= z->nblks + 2)
                continue;
            for (unsigned pg = g->cpoffs[li] < PPB ? g->cpoffs[li] : PPB; pg < PPB; pg++) {
                unsigned p = g->vbn[li] * PPB + pg;
                unsigned char sb[48];
                uint32_t t;
                int lpo;
                if (blank(p))
                    continue;
                spare(p, sb);
                lpo = spare_lpo(sb);
                if (lpo < 0 || lpo >= PPB || !spare_timer(sb, &t))
                    continue;
                if (out[lpo] == ~0u || t >= when[lpo]) {
                    out[lpo] = p;
                    when[lpo] = t;
                }
            }
        }
    for (unsigned lpo = 0; lpo < PPB; lpo++) {
        unsigned char sb[48];
        if (out[lpo] == ~0u || blank(out[lpo]))
            continue;
        spare(out[lpo], sb);
        if (spare_lpo(sb) != (int)lpo)
            bad++;
    }
    return bad;
}

static unsigned char *build_volume(const struct zone *z, size_t *len)
{
    int pmt = newest_meta(z, META_TYPE(MT_PMT));
    int bmtp = newest_meta(z, META_TYPE(MT_BMT));
    unsigned bmt[1024];
    unsigned gsz = grp_size(z->k), base = 0;

    if (pmt < 0) {
        logmsg("no PMT page");
        return NULL;
    }
    for (unsigned i = 0; i < 1024; i++)
        bmt[i] = NULL16;
    if (bmtp >= 0 && le16(page(bmtp)) == 0 && le16(page(bmtp) + 2) == 0xffff)
        for (unsigned i = 0; i < z->nuser && i < 1024; i++)
            bmt[i] = le16(page(bmtp) + 4 + 2 * i);

    /* the log groups follow the context in the PMT page; find where by
     * checking every candidate against the spare areas */
    for (unsigned off = 0x80; off + z->grps_per_pmt * gsz <= PG; off += 4) {
        int ok = 1, used = 0;
        for (unsigned i = 0; i < z->grps_per_pmt && ok; i++) {
            const unsigned char *rec = page(pmt) + off + i * gsz;
            struct grp g;
            unsigned map[PPB];
            /* every record ends with its zero bit count and the inverse */
            if (le32(rec + gsz - 8) != ~le32(rec + gsz - 4)) {
                ok = 0;
                break;
            }
            parse_grp(rec, z->k, &g);
            if (g.dgn == NULL16)
                continue;
            if (g.dgn >= z->nuser || resolve_grp(z, &g, bmt[g.dgn], map, 0) != 0)
                ok = 0;
            used++;
        }
        if (ok && used) {
            base = off;
            break;
        }
    }
    if (!base) {
        logmsg("PMT page %u: no consistent log group table", pmt);
        return NULL;
    }
    logmsg("PMT page %u (groups at 0x%x), BMT page %d", pmt, base, bmtp);

    *len = (size_t)z->nuser * PPB * PG;
    unsigned char *vol = malloc(*len);
    if (!vol)
        return NULL;
    memset(vol, 0xff, *len);
    unsigned done[1024] = { 0 };
    unsigned copied = 0, mism = 0;
    for (unsigned i = 0; i < z->grps_per_pmt; i++) {
        struct grp g;
        unsigned map[PPB];
        parse_grp(page(pmt) + base + i * gsz, z->k, &g);
        if (g.dgn == NULL16 || g.dgn >= z->nuser)
            continue;
        mism += resolve_grp(z, &g, bmt[g.dgn], map, 1);
        for (unsigned lpo = 0; lpo < PPB; lpo++)
            if (map[lpo] != ~0u) {
                memcpy(vol + ((size_t)g.dgn * PPB + lpo) * PG, page(map[lpo]), PG);
                copied++;
            }
        done[g.dgn] = 1;
    }
    /* blocks without a log group: straight from their data block */
    for (unsigned lbn = 0; lbn < z->nuser && lbn < 1024; lbn++)
        if (!done[lbn] && bmt[lbn] != NULL16 && bmt[lbn] < z->nblks + 2)
            for (unsigned lpo = 0; lpo < PPB; lpo++)
                if (!blank(bmt[lbn] * PPB + lpo)) {
                    memcpy(vol + ((size_t)lbn * PPB + lpo) * PG, page(bmt[lbn] * PPB + lpo), PG);
                    copied++;
                }
    logmsg("%u pages mapped, %u replayed pages disagree with their spare", copied, mism);
    return vol;
}

/* ---- FAT12/16 (RFS) ---- */

struct fat {
    const unsigned char *v;
    size_t len;
    unsigned bps, csize, fat_off, root_off, nroot, data_off, fat16;
};

static int fat_open(struct fat *f, const unsigned char *v, size_t len)
{
    f->v = v;
    f->len = len;
    f->bps = le16(v + 11);
    unsigned spc = v[13], rsv = le16(v + 14), nfat = v[16], fatsz = le16(v + 22);
    unsigned tot = le16(v + 19) ? le16(v + 19) : le32(v + 32);
    f->nroot = le16(v + 17);
    if (v[510] != 0x55 || v[511] != 0xaa || !f->bps || !spc || f->bps & 511)
        return -1;
    f->csize = f->bps * spc;
    f->fat_off = rsv * f->bps;
    f->root_off = f->fat_off + nfat * fatsz * f->bps;
    f->data_off = f->root_off + f->nroot * 32;
    if ((size_t)tot * f->bps > len || f->data_off >= len)
        return -1;
    f->fat16 = (tot * f->bps - f->data_off) / f->csize >= 4085;
    return 0;
}

static unsigned fat_next(const struct fat *f, unsigned c)
{
    if (f->fat16)
        return le16(f->v + f->fat_off + 2 * c);
    unsigned x = le16(f->v + f->fat_off + c * 3 / 2);
    return c & 1 ? x >> 4 : x & 0xfff;
}

/* read a cluster chain (up to max bytes); returns a malloc'ed buffer */
static unsigned char *fat_read(const struct fat *f, unsigned c, size_t max, size_t *got)
{
    unsigned end = f->fat16 ? 0xfff8 : 0xff8, n = 0;
    size_t cap = max ? max : 64 * 1024, len = 0;
    unsigned char *buf = malloc(cap ? cap : 1);

    while (buf && c >= 2 && c < end && n++ < 65536 && (!max || len < max)) {
        size_t off = f->data_off + (size_t)(c - 2) * f->csize;
        size_t chunk = f->csize;
        if (off + chunk > f->len)
            break;
        if (max && len + chunk > max)
            chunk = max - len;
        if (len + chunk > cap) {
            cap = (len + chunk) * 2;
            buf = realloc(buf, cap);
            if (!buf)
                break;
        }
        memcpy(buf + len, f->v + off, chunk);
        len += chunk;
        c = fat_next(f, c);
    }
    *got = len;
    return buf;
}

static int write_file(const char *path, const unsigned char *d, size_t n, mode_t mode)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, mode);
    if (fd < 0)
        return -1;
    int ok = write(fd, d, n) == (ssize_t)n && fsync(fd) == 0;
    close(fd);
    if (chown(path, RADIO_UID, RADIO_UID) || chmod(path, mode))
        logmsg("%s: cannot set owner", path);
    return ok ? 0 : -1;
}

static int fat_extract(const struct fat *f, const unsigned char *dir, size_t dlen,
                       const char *dst, int depth, unsigned *nfiles)
{
    uint16_t lfn[256];
    int have_lfn = 0, rc = 0;

    if (depth > 8)
        return 0;
    memset(lfn, 0, sizeof(lfn));
    for (size_t i = 0; i + 32 <= dlen; i += 32) {
        const unsigned char *e = dir + i;
        char name[256], path[1024];
        unsigned attr = e[11];

        if (e[0] == 0)
            break;
        if (e[0] == 0xe5) {
            have_lfn = 0;
            continue;
        }
        if (attr == 0x0f) {
            unsigned seq = (e[0] & 0x1f) - 1;
            static const int pos[13] = { 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30 };
            if (e[0] & 0x40)
                memset(lfn, 0, sizeof(lfn));
            if (seq < 19)
                for (int j = 0; j < 13; j++)
                    lfn[seq * 13 + j] = le16(e + pos[j]);
            have_lfn = 1;
            continue;
        }
        if (attr & 0x08) {          /* volume label, RFS extension entries */
            have_lfn = 0;
            continue;
        }
        if (have_lfn) {
            int j;
            for (j = 0; j < 255 && lfn[j] && lfn[j] != 0xffff; j++)
                name[j] = lfn[j] < 0x80 ? (char)lfn[j] : '_';
            name[j] = 0;
        } else {
            int j = 0;
            for (int k = 0; k < 8 && e[k] != ' '; k++)
                name[j++] = e[k];
            if (e[8] != ' ') {
                name[j++] = '.';
                for (int k = 8; k < 11 && e[k] != ' '; k++)
                    name[j++] = e[k];
            }
            name[j] = 0;
        }
        have_lfn = 0;
        if (!name[0] || !strcmp(name, ".") || !strcmp(name, "..") || strchr(name, '/'))
            continue;
        snprintf(path, sizeof(path), "%s/%s", dst, name);
        unsigned clus = le16(e + 26) | (unsigned)le16(e + 20) << 16;
        size_t size = le32(e + 28), got = 0;
        if (attr & 0x10) {
            unsigned char *sub = fat_read(f, clus, 0, &got);
            if (mkdir(path, 0775) && errno != EEXIST)
                rc = -1;
            if (chown(path, RADIO_UID, RADIO_UID) || chmod(path, 0775))
                logmsg("%s: cannot set owner", path);
            if (sub)
                rc |= fat_extract(f, sub, got, path, depth + 1, nfiles);
            free(sub);
        } else {
            unsigned char *d = size ? fat_read(f, clus, size, &got) : malloc(1);
            if (!d || got != size) {
                logmsg("%s: short read (%zu of %zu)", path, got, size);
                rc = -1;
            } else if (write_file(path, d, size, 0660)) {
                logmsg("%s: %s", path, strerror(errno));
                rc = -1;
            } else {
                (*nfiles)++;
            }
            free(d);
        }
    }
    return rc;
}

/* ---- input ---- */

static int find_efs_stock(char *dev, size_t len)
{
    FILE *f = fopen("/proc/mtd", "re");
    char line[256];
    int n = -1;

    if (!f)
        return -1;
    while (fgets(line, sizeof(line), f)) {
        int idx;
        if (sscanf(line, "mtd%d:", &idx) == 1 && strstr(line, "\"efs_stock\""))
            n = idx;
    }
    fclose(f);
    if (n < 0)
        return -1;
    snprintf(dev, len, "/dev/mtd%dro", n);
    if (access(dev, R_OK))
        snprintf(dev, len, "/dev/mtd%d", n);
    return 0;
}

static int load_mtd(const char *dev)
{
    struct mtd_info_user info;
    struct mtd_oob_buf oob;
    int fd = open(dev, O_RDONLY | O_CLOEXEC);

    if (fd < 0 || ioctl(fd, MEMGETINFO, &info) < 0) {
        logmsg("%s: %s", dev, strerror(errno));
        return -1;
    }
    if (info.writesize != PG || info.oobsize != OOBSZ || info.erasesize != PG * PPB) {
        logmsg("%s: page %u oob %u erase %u not supported", dev, info.writesize,
               info.oobsize, info.erasesize);
        return -1;
    }
    g_npages = info.size / PG;
    g_data = malloc((size_t)g_npages * PG);
    g_oob = malloc((size_t)g_npages * OOBSZ);
    if (!g_data || !g_oob)
        return -1;
    for (unsigned p = 0; p < g_npages; p++) {
        if (pread(fd, g_data + (size_t)p * PG, PG, (off_t)p * PG) != PG)
            memset(g_data + (size_t)p * PG, 0xff, PG);
        oob.start = p * PG;
        oob.length = OOBSZ;
        oob.ptr = g_oob + (size_t)p * OOBSZ;
        if (ioctl(fd, MEMREADOOB, &oob) < 0)
            memset(g_oob + (size_t)p * OOBSZ, 0xff, OOBSZ);
    }
    close(fd);
    return 0;
}

static unsigned char *slurp(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    unsigned char *b;

    if (!f)
        return NULL;
    fseek(f, 0, SEEK_END);
    *len = ftell(f);
    fseek(f, 0, SEEK_SET);
    b = malloc(*len ? *len : 1);
    if (b && fread(b, 1, *len, f) != *len) {
        free(b);
        b = NULL;
    }
    fclose(f);
    return b;
}

static int remove_tree(const char *path)
{
    DIR *d = opendir(path);
    struct dirent *de;

    if (!d)
        return unlink(path);
    while ((de = readdir(d))) {
        char sub[1024];
        if (!strcmp(de->d_name, ".") || !strcmp(de->d_name, ".."))
            continue;
        snprintf(sub, sizeof(sub), "%s/%s", path, de->d_name);
        remove_tree(sub);
    }
    closedir(d);
    return rmdir(path);
}

int main(int argc, char **argv)
{
    const char *target;
    char dev[64], tmp[1024], probe[1100];
    struct zone z;
    struct fat f;
    size_t len;
    unsigned nfiles = 0;

    if (argc == 5 && !strcmp(argv[1], "--dump")) {
        size_t dl, ol;
        g_data = slurp(argv[2], &dl);
        g_oob = slurp(argv[3], &ol);
        if (!g_data || !g_oob || dl % PG || ol != dl / PG * OOBSZ) {
            logmsg("bad dump files");
            return 1;
        }
        g_npages = dl / PG;
        target = argv[4];
    } else if (argc == 2) {
        target = argv[1];
        snprintf(probe, sizeof(probe), "%s/nv_data.bin", target);
        if (!access(probe, F_OK))
            return 0;
        if (find_efs_stock(dev, sizeof(dev))) {
            logmsg("no efs_stock partition");
            return 1;
        }
        if (load_mtd(dev))
            return 1;
    } else {
        fprintf(stderr, "usage: %s <target dir> | --dump <data> <oob> <target dir>\n", argv[0]);
        return 2;
    }

    if (read_root(&z))
        return 1;
    unsigned char *vol = build_volume(&z, &len);
    if (!vol || fat_open(&f, vol, len)) {
        logmsg("no FAT file system in the STL volume");
        return 1;
    }

    /* extract next to the target, then rename into place */
    snprintf(tmp, sizeof(tmp), "%s.new", target);
    remove_tree(tmp);
    if (mkdir(tmp, 0775)) {
        logmsg("%s: %s", tmp, strerror(errno));
        return 1;
    }
    if (chown(tmp, RADIO_UID, RADIO_UID))
        logmsg("%s: cannot set owner", tmp);
    if (fat_extract(&f, f.v + f.root_off, f.nroot * 32, tmp, 0, &nfiles)) {
        logmsg("extraction incomplete");
        return 1;
    }
    snprintf(probe, sizeof(probe), "%s/nv_data.bin", tmp);
    if (access(probe, F_OK)) {
        logmsg("no nv_data.bin among %u files", nfiles);
        return 1;
    }
    remove_tree(target);
    if (rename(tmp, target)) {
        logmsg("%s: %s", target, strerror(errno));
        return 1;
    }
    logmsg("%u files copied to %s", nfiles, target);
    return 0;
}
