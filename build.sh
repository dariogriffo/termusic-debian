VERSION=$1
BUILD_VERSION=$2
declare -a arr=("bookworm" "trixie" "sid")
for i in "${arr[@]}"
do
  DEBIAN_DIST=$i
  FULL_VERSION=$VERSION-${BUILD_VERSION}+${DEBIAN_DIST}_amd64
  docker build . -t termusic-$DEBIAN_DIST  --build-arg DEBIAN_DIST=$DEBIAN_DIST --build-arg VERSION=$VERSION --build-arg BUILD_VERSION=$BUILD_VERSION --build-arg FULL_VERSION=$FULL_VERSION
  id="$(docker create termusic-$DEBIAN_DIST)"
  docker cp $id:/termusic_$FULL_VERSION.deb - > ./termusic_$FULL_VERSION.deb
  tar -xf ./termusic_$FULL_VERSION.deb
done


