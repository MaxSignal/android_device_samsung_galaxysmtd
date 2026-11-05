#ifndef __PVREGL_H__
#define __PVREGL_H__

#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <cutils/compiler.h>

#ifdef __cplusplus
extern "C" {
#endif

/* libIMGegl entry points, resolved at load time (imgegl.c) */
#ifndef IMGEXTERN
#define IMGEXTERN extern
#endif

typedef int32_t EGLint;
typedef unsigned int EGLBoolean;
typedef unsigned int EGLenum;
typedef void *EGLConfig;
typedef void *EGLContext;
typedef void *EGLDisplay;
typedef void *EGLSurface;
typedef void *EGLClientBuffer;
typedef int EGLNativeDisplayType;
typedef void *EGLNativeWindowType;
typedef void *EGLNativePixmapType;


#define EGL_FALSE	0
#define EGL_TRUE	1
#define EGL_DONT_CARE	((EGLint)-1)

#define EGL_SURFACE_TYPE	0x3033
#define EGL_NONE	0x3038
#define EGL_RENDERABLE_TYPE	0x3040
#define EGL_RECORDABLE_ANDROID	0x3142
#define EGL_FRAMEBUFFER_TARGET_ANDROID	0x3147

#define EGL_PBUFFER_BIT	0x0001
#define EGL_OPENGL_ES2_BIT	0x0004


IMGEXTERN EGLint (*IMGeglGetError)(void);
IMGEXTERN EGLDisplay (*IMGeglGetDisplay)(EGLNativeDisplayType display_id);
IMGEXTERN EGLBoolean (*IMGeglInitialize)(EGLDisplay dpy, EGLint *major, EGLint *minor);
IMGEXTERN EGLBoolean (*IMGeglTerminate)(EGLDisplay dpy);
IMGEXTERN const char * (*IMGeglQueryString)(EGLDisplay dpy, EGLint name);
IMGEXTERN void (*(*IMGeglGetProcAddress)(const char *procname))(void);
IMGEXTERN EGLBoolean (*IMGeglGetConfigs)(EGLDisplay dpy, EGLConfig *configs, EGLint config_size, EGLint *num_config);
IMGEXTERN EGLBoolean (*IMGeglChooseConfig)(EGLDisplay dpy, const EGLint *attrib_list, EGLConfig *configs, EGLint config_size, EGLint *num_config);
IMGEXTERN EGLBoolean (*IMGeglGetConfigAttrib)(EGLDisplay dpy, EGLConfig config, EGLint attribute, EGLint *value);
IMGEXTERN EGLSurface (*IMGeglCreateWindowSurface)(EGLDisplay dpy, EGLConfig config, EGLNativeWindowType window, const EGLint *attrib_list);
IMGEXTERN EGLSurface (*IMGeglCreatePixmapSurface)(EGLDisplay dpy, EGLConfig config, EGLNativePixmapType pixmap, const EGLint *attrib_list);
IMGEXTERN EGLSurface (*IMGeglCreatePbufferSurface)(EGLDisplay dpy, EGLConfig config, const EGLint *attrib_list);
IMGEXTERN EGLBoolean (*IMGeglDestroySurface)(EGLDisplay dpy, EGLSurface surface);
IMGEXTERN EGLBoolean (*IMGeglQuerySurface)(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint *value);
IMGEXTERN EGLContext (*IMGeglCreateContext)(EGLDisplay dpy, EGLConfig config, EGLContext share_list, const EGLint *attrib_list);
IMGEXTERN EGLBoolean (*IMGeglDestroyContext)(EGLDisplay dpy, EGLContext ctx);
IMGEXTERN EGLBoolean (*IMGeglMakeCurrent)(EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx);
IMGEXTERN EGLContext (*IMGeglGetCurrentContext)(void);
IMGEXTERN EGLSurface (*IMGeglGetCurrentSurface)(EGLint readdraw);
IMGEXTERN EGLDisplay (*IMGeglGetCurrentDisplay)(void);
IMGEXTERN EGLBoolean (*IMGeglQueryContext)(EGLDisplay dpy, EGLContext ctx, EGLint attribute, EGLint *value);
IMGEXTERN EGLBoolean (*IMGeglWaitGL)(void);
IMGEXTERN EGLBoolean (*IMGeglWaitNative)(EGLint engine);
IMGEXTERN EGLBoolean (*IMGeglSwapBuffers)(EGLDisplay dpy, EGLSurface draw);
IMGEXTERN EGLBoolean (*IMGeglCopyBuffers)(EGLDisplay dpy, EGLSurface surface, EGLNativePixmapType target);
IMGEXTERN EGLBoolean (*IMGeglSurfaceAttrib)(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint value);
IMGEXTERN EGLBoolean (*IMGeglBindTexImage)(EGLDisplay dpy, EGLSurface surface, EGLint buffer);
IMGEXTERN EGLBoolean (*IMGeglReleaseTexImage)(EGLDisplay dpy, EGLSurface surface, EGLint buffer);
IMGEXTERN EGLBoolean (*IMGeglSwapInterval)(EGLDisplay dpy, EGLint interval);
IMGEXTERN EGLSurface (*IMGeglCreatePbufferFromClientBuffer)(EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer, EGLConfig config, const EGLint *attrib_list);
IMGEXTERN EGLBoolean (*IMGeglBindAPI)(EGLenum api);
IMGEXTERN EGLenum (*IMGeglQueryAPI)(void);
IMGEXTERN EGLBoolean (*IMGeglWaitClient)(void);
IMGEXTERN EGLBoolean (*IMGeglReleaseThread)(void);

#ifdef __cplusplus
}
#endif

#endif /* __PVREGL_H__ */
