#include <seccomp.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/prctl.h>
#include <errno.h>

int main() {
    // Initialize seccomp with a default deny policy
    scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ERRNO(EPERM)); // Deny by default, return permission denied
    
    if (!ctx) {
        printf("seccomp_init failed\n");
        return 1;
    }

    // Allow essential system calls for Python and HTTP server
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(read), 0);      // Reading from sockets/files
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(write), 0);     // Writing to sockets/files
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(close), 0);     // Closing file descriptors
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(socket), 0);    // Creating sockets
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(bind), 0);      // Binding to port 8000
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(listen), 0);    // Listening for connections
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(accept), 0);    // Accepting connections
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(exit), 0);      // Exiting the program
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(exit_group), 0); // Exiting all threads
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(brk), 0);       // Memory allocation (Python needs this)
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(mmap), 0);      // Memory mapping (Python needs this)
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(munmap), 0);    // Memory unmapping

    // Explicitly deny dangerous system calls (optional, since default is deny)
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(execve), 0);  // No new executables
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(fork), 0);    // No forking
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(clone), 0);   // No cloning
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(mount), 0);   // No mounting
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(chmod), 0);   // No permission changes
    seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(ptrace), 0);  // No tracing

    // Load the seccomp filter
    if (seccomp_load(ctx) != 0) {
        printf("seccomp_load failed\n");
        seccomp_release(ctx);
        return 1;
    }

    // Ensure child processes inherit the filter
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) == -1) {
        perror("prctl failed");
        seccomp_release(ctx);
        return 1;
    }

    // Execute Python
    execlp("python3", "python3", "/home/hnguser/server.py", NULL);
    perror("exec failed");
    seccomp_release(ctx);
    return 1;
}
















