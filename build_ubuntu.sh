VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <termusic_version> <build_version> [architecture]"
    echo "Example: $0 0.13.2 1 arm64"
    echo "Example: $0 0.13.2 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

# Function to map Ubuntu architecture to termusic release name
get_termusic_release() {
    local arch=$1
    case "$arch" in
        "amd64")
            echo "x86_64"
            ;;
        "arm64")
            echo "aarch64"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1
    local termusic_arch
    local termusic_release_dir
    local tarball

    termusic_arch=$(get_termusic_release "$build_arch")
    if [ -z "$termusic_arch" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    termusic_release_dir="termusic-v${VERSION}-${termusic_arch}-linux"
    tarball="${termusic_release_dir}.tar.xz"

    echo "Building for architecture: $build_arch using $termusic_release_dir"

    # Clean up any previous builds for this architecture
    rm -rf "$termusic_release_dir" || true
    rm -f "$tarball" || true

    # Download and extract termusic binary for this architecture
    if ! wget "https://github.com/tramhao/termusic/releases/download/v${VERSION}/${tarball}"; then
        echo "❌ Failed to download termusic binary for $build_arch"
        return 1
    fi

    if ! tar -xf "$tarball"; then
        echo "❌ Failed to extract termusic binary for $build_arch"
        return 1
    fi

    rm -f "$tarball"

    # Build packages for Ubuntu distributions
    declare -a arr=("jammy" "noble" "questing" "resolute")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$VERSION-${BUILD_VERSION}~${dist}_${build_arch}_ubu"
        echo "  Building $FULL_VERSION"

        if ! docker build . -f Dockerfile.ubu -t "termusic-ubuntu-$dist-$build_arch" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg VERSION="$VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg TERMUSIC_RELEASE="$termusic_release_dir"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "termusic-ubuntu-$dist-$build_arch")"
        if ! docker cp "$id:/termusic_$FULL_VERSION.deb" - > "./termusic_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./termusic_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    # Clean up extracted directory
    rm -rf "$termusic_release_dir" || true

    echo "✅ Successfully built for $build_arch"
    return 0
}

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building termusic $VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    # All supported architectures
    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la termusic_*.deb
else
    # Build for single architecture
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
