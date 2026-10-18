FROM rust:1-slim-bookworm
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends python3 make binutils git ca-certificates >/dev/null
WORKDIR /w
COPY src/ /w/
RUN rustup show active-toolchain || true
RUN : > /w/dummy.initramfs
ENV INITRAMFS_PATH=dummy.initramfs INIT_SCRIPT=/bin/sh ARCH=x64 RUSTFLAGS="-Z emit-stack-sizes"
RUN cargo build --release -Z build-std=core,alloc -Z build-std-features=compiler-builtins-mem --target kernel/arch/x64/x64.json --manifest-path kernel/Cargo.toml 2>&1 | tail -30
RUN ls -l target/x64/release/kerla_kernel && strip -o /w/kerla.stripped target/x64/release/kerla_kernel && ls -l /w/kerla.stripped
