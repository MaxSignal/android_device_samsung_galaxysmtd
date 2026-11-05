/*
 * Resolve the libIMGegl entry points the wrapper forwards to. The DDK 1.8 blobs
 * have no DT_SONAME, so linking against them would record a build path; load
 * the library at run time instead.
 */
#include <dlfcn.h>
#include <log/log.h>

#define IMGEXTERN
#include "egl.h"

#define F(n) { #n, (void **)&n }
static const struct { const char *name; void **ptr; } imgegl_syms[] = {
    F(IMGeglGetError),
    F(IMGeglGetDisplay),
    F(IMGeglInitialize),
    F(IMGeglTerminate),
    F(IMGeglQueryString),
    F(IMGeglGetConfigs),
    F(IMGeglChooseConfig),
    F(IMGeglGetConfigAttrib),
    F(IMGeglCreateWindowSurface),
    F(IMGeglCreatePixmapSurface),
    F(IMGeglCreatePbufferSurface),
    F(IMGeglDestroySurface),
    F(IMGeglQuerySurface),
    F(IMGeglCreateContext),
    F(IMGeglDestroyContext),
    F(IMGeglMakeCurrent),
    F(IMGeglGetCurrentContext),
    F(IMGeglGetCurrentSurface),
    F(IMGeglGetCurrentDisplay),
    F(IMGeglQueryContext),
    F(IMGeglWaitGL),
    F(IMGeglWaitNative),
    F(IMGeglSwapBuffers),
    F(IMGeglCopyBuffers),
    F(IMGeglSurfaceAttrib),
    F(IMGeglBindTexImage),
    F(IMGeglReleaseTexImage),
    F(IMGeglSwapInterval),
    F(IMGeglCreatePbufferFromClientBuffer),
    F(IMGeglBindAPI),
    F(IMGeglQueryAPI),
    F(IMGeglWaitClient),
    F(IMGeglReleaseThread),
    F(IMGeglGetProcAddress),};

__attribute__((constructor)) static void imgegl_load(void)
{
    void *lib = dlopen("libIMGegl.so", RTLD_NOW | RTLD_GLOBAL);
    size_t i;

    if (!lib) {
        ALOGE("libEGL_POWERVR: %s", dlerror());
        return;
    }
    for (i = 0; i < sizeof(imgegl_syms) / sizeof(imgegl_syms[0]); i++) {
        *imgegl_syms[i].ptr = dlsym(lib, imgegl_syms[i].name);
        if (!*imgegl_syms[i].ptr)
            ALOGE("libEGL_POWERVR: missing %s", imgegl_syms[i].name);
    }
}
