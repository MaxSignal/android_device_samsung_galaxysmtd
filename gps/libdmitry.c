/*
 * Symbols the Galaxy S gpsd blob needs that BoringSSL dropped.
 * gpsd links this library by name (libdmitry.so).
 */
#include <openssl/ssl.h>

const SSL_METHOD *SSLv3_method(void) {
    return TLS_method();
}
