/*
 * socket_loopback_server() was dropped from libcutils after Android 8; the
 * Samsung libsec-ril blob still imports it. Same behaviour as the old
 * libcutils/socket_loopback_server.c.
 */
#include <arpa/inet.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define LISTEN_BACKLOG 4

int socket_loopback_server(int port, int type)
{
    struct sockaddr_in addr;
    int s, n;

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    s = socket(AF_INET, type, 0);
    if (s < 0)
        return -1;

    n = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &n, sizeof(n));

    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(s);
        return -1;
    }

    if (type == SOCK_STREAM && listen(s, LISTEN_BACKLOG) < 0) {
        close(s);
        return -1;
    }

    return s;
}
