FROM alpine:3.22
RUN apk add -q bash build-base linux-headers flex bison bc perl xz bzip2 curl openssl-dev elfutils-dev cpio
RUN curl -sL https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz | tar xJ && mv linux-6.6 /k
