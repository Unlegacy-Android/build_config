# Set build jobs
export JOBS=$(expr 0 + $(grep -c ^processor /proc/cpuinfo))

# Set build tag
if [ -z "$BUILD_TAG" ]
then
  echo BUILD_TAG not specified, using the default one...
  export BUILD_NUMBER=$(date +%Y%m%d)
else
  export BUILD_NUMBER=$BUILD_TAG
fi

# Set build targets
if [ -z "$BUILD_TARGETS" ]
then
  echo BUILD_TARGETS not specified, using otapackage as default...
  export BUILD_TARGETS=otapackage
fi

# Enable CCACHE
export USE_CCACHE=1
export CCACHE_NLEVELS=4

# Set LUNCH variable
export LUNCH=$(set -- ${BRANCH};IFS='-';declare -a Array=\(\$*\);echo ${Array[0]}_${DEVICE}-${BUILD_TYPE})

# Build
cd ../source
. build/envsetup.sh
lunch $LUNCH
make -j$JOBS $BUILD_TARGETS
