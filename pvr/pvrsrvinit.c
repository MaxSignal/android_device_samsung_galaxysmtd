/* Initialise the SGX540 services (loads the microkernel) before any GL client. */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    void *lib = dlopen("libsrv_init.so", RTLD_NOW);
    int (*SrvInit)(int);

    if (!lib) {
        fprintf(stderr, "pvrsrvinit: %s\n", dlerror());
        return EXIT_FAILURE;
    }
    SrvInit = (int (*)(int))dlsym(lib, "SrvInit");
    if (!SrvInit) {
        fprintf(stderr, "pvrsrvinit: %s\n", dlerror());
        return EXIT_FAILURE;
    }
    SrvInit(1);
    return EXIT_SUCCESS;
}
