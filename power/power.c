/*
 * Galaxy S (aries) power HAL.
 *
 * The 3.0 kernel uses Android earlysuspend: "mem" written to /sys/power/state
 * runs the early-suspend handlers (panel, touch, ...) and lets the kernel
 * suspend once no kernel wakelock is held; "on" runs the late-resume handlers.
 * Android 10 never writes "on", so the display would stay off after the first
 * screen-off. Interactive state drives it here instead (SystemSuspend keeps
 * the wakelocks in the kernel on such kernels).
 */
#define LOG_TAG "power.aries"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#include <hardware/hardware.h>
#include <hardware/power.h>
#include <log/log.h>

#define SYS_POWER_STATE "/sys/power/state"

static void sysfs_write(const char *path, const char *s)
{
    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) {
        ALOGE("open %s: %s", path, strerror(errno));
        return;
    }
    if (write(fd, s, strlen(s)) < 0)
        ALOGE("write %s to %s: %s", s, path, strerror(errno));
    close(fd);
}

static void power_init(struct power_module *module __unused)
{
}

static void power_set_interactive(struct power_module *module __unused, int on)
{
    ALOGI("interactive %d", on);
    sysfs_write(SYS_POWER_STATE, on ? "on" : "mem");
}

static void power_hint(struct power_module *module __unused, power_hint_t hint __unused,
                       void *data __unused)
{
}

static struct hw_module_methods_t power_module_methods = {
    .open = NULL,
};

struct power_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = POWER_MODULE_API_VERSION_0_2,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = POWER_HARDWARE_MODULE_ID,
        .name = "Galaxy S power HAL",
        .author = "s1q",
        .methods = &power_module_methods,
    },
    .init = power_init,
    .setInteractive = power_set_interactive,
    .powerHint = power_hint,
};
