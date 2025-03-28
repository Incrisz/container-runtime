#include <seccomp.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/prctl.h>
#include <errno.h> // Added for EPERM

int main() {
    // Initialize seccomp
    scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW); // Start by allowing everything
    
    if (!ctx) {
        printf("seccomp_init failed\n");
        return 1;
    }

    // Deny the mount system call
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(mount), 0); // No mounting

    // Load the seccomp filter
    if (seccomp_load(ctx) != 0) {
        printf("seccomp_load failed\n");
        seccomp_release(ctx);
        return 1;
    }

    // Execute Python
    execlp("python3", "python3", "/home/hnguser/server.py", NULL);
    perror("exec failed");
    seccomp_release(ctx);
    return 1;
}