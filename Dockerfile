ARG DEBIAN_DIST=bookworm
FROM buildpack-deps:$DEBIAN_DIST

ARG DEBIAN_DIST
ARG VERSION
ARG BUILD_VERSION
ARG FULL_VERSION

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.90.0

RUN set -eux; \
    wget "https://static.rust-lang.org/rustup/archive/1.28.1/x86_64-unknown-linux-gnu/rustup-init"; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.85.0 --default-host x86_64-unknown-linux-gnu;

RUN apt update && apt install -y libgstreamer1.0-dev libasound2-dev protobuf-compiler libclang-dev libmpv-dev
RUN mkdir -p /output/usr/bin
RUN mkdir -p /output/usr/share/doc/termusic
RUN git clone https://github.com/tramhao/termusic.git
RUN cd termusic && cargo build --release --all-features && cp ./target/release/termusic /output/usr/bin/ && cp ./target/release/termusic-server /output/usr/bin/
RUN mkdir -p /output/DEBIAN

COPY output/DEBIAN/control /output/DEBIAN/
COPY output/copyright /output/usr/share/doc/termusic/
COPY output/changelog.Debian /output/usr/share/doc/termusic/
COPY output/README.md /output/usr/share/doc/termusic/

RUN sed -i "s/DIST/$DEBIAN_DIST/" /output/usr/share/doc/termusic/changelog.Debian
RUN sed -i "s/FULL_VERSION/$FULL_VERSION/" /output/usr/share/doc/termusic/changelog.Debian
RUN sed -i "s/DIST/$DEBIAN_DIST/" /output/DEBIAN/control
RUN sed -i "s/VERSION/$VERSION/" /output/DEBIAN/control
RUN sed -i "s/BUILD_VERSION/$BUILD_VERSION/" /output/DEBIAN/control

RUN dpkg-deb --build /output /termusic_${FULL_VERSION}.deb
