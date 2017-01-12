#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    (repo forall -c "git reset --hard") > /dev/null
    echo $1
    exit 1
  fi
}

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

# Set build jobs
export JOBS=$(expr 0 + $(grep -c ^processor /proc/cpuinfo))

# Set CLEAN if not specified
if [ -z "$CLEAN" ]
then
  echo CLEAN not specified, setting to false
  export CLEAN=false
fi

# Set CLEAN_TARGETS if not specified
if [ -z "$CLEAN_TARGETS" ]
then
  echo CLEAN_TARGETS not specified, setting to clean
  export CLEAN_TARGETS="clean"
fi

# Set IGNORE_COMMIT_COUNT if not specified
if [ -z "$IGNORE_COMMIT_COUNT" ]
then
  echo IGNORE_COMMIT_COUNT not specified, setting to true
  export IGNORE_COMMIT_COUNT=true
fi

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
  export BUILD_TARGETS="otapackage"
fi

# Check for product
if [ -z "$BUILD_PRODUCT" ]
then
  echo BUILD_PRODUCT not specified, using aosp product as default...
  export BUILD_PRODUCT_PREFIX=aosp
else
  export BUILD_PRODUCT_PREFIX=$BUILD_PRODUCT
fi

# Set LUNCH variable
export LUNCH=${BUILD_PRODUCT_PREFIX}_${DEVICE}-${BUILD_TYPE}

# Colorization fix in Jenkins and enable CCACHE
export CL_RED="\"\033[31m\""
export CL_GRN="\"\033[32m\""
export CL_YLW="\"\033[33m\""
export CL_BLU="\"\033[34m\""
export CL_MAG="\"\033[35m\""
export CL_CYN="\"\033[36m\""
export CL_RST="\"\033[0m\""
export BUILD_WITH_COLORS=0
export USE_CCACHE=1
export CCACHE_NLEVELS=4
export PYTHONDONTWRITEBYTECODE=1

# Setup archive directory
cd $WORKSPACE
mkdir -p archive
rm -rf archive/**

# Move to cd source directory
cd source

# Count the total number of commits from all the source projects
export COMMITS_PER_PROJECT=$(repo forall -c "git rev-list --count HEAD")
export ACTUAL_COMMITS_COUNT=$(( ${COMMITS_PER_PROJECT//$'\n'/+} ))

# Load last build commits count
LAST_COMMITS_COUNT=0
LAST_COMMITS_FILENAME=".${DEVICE}_${BRANCH}_COMMIT_COUNT"
if [ -f $LAST_COMMITS_FILENAME ]
then
  LAST_COMMITS_COUNT=$(cat $LAST_COMMITS_FILENAME)
fi

# Check if changes were made
if [ $LAST_COMMITS_COUNT = $ACTUAL_COMMITS_COUNT ] && [ $IGNORE_COMMIT_COUNT != true ]
then
  echo "Skipping build, no changes."
  exit 1
fi

# Save the number of commits
echo $ACTUAL_COMMITS_COUNT > $LAST_COMMITS_FILENAME

# Make sure ccache is in PATH
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilts/misc/$(uname|awk '{print tolower($0)}')-x86/ccache"
export CCACHE_DIR=~/.ccache

# Run the bootstrap script if exists
if [ -f $WORKSPACE/build_config/bootstrap.sh ]
then
  bash $WORKSPACE/build_config/bootstrap.sh
fi

# Show the core manifest
echo Core Manifest:
cat .repo/manifest.xml

# Check last branch
if [ -f .last_branch ]
then
  LAST_BRANCH=$(cat .last_branch)
else
  echo "Last build branch is unknown, assume clean build"
  LAST_BRANCH=$BRANCH
  CLEAN="true"
  CLEAN_TARGETS="clean"
fi

# If last branch is different from actual branch we force a cleanup
if [ "$LAST_BRANCH" != "$BRANCH" ]
then
  echo "Branch has changed since the last build happened here. Forcing cleanup."
  CLEAN="true"
  CLEAN_TARGETS="clean"
fi

# Load build environment
. build/envsetup.sh

# Try to lunch
lunch $LUNCH
check_result "Lunch failed."

# Cleanup zip's from OUT directory
rm -f $OUT/*.zip*

# Load gerrit changes
if [ ! -z "$GERRIT_CHANGES" ]
then
  IS_HTTP=$(echo $GERRIT_CHANGES | grep http)
  if [ -z "$IS_HTTP" ]
  then
    python $WORKSPACE/build_config/repopick.py $GERRIT_CHANGES
    check_result "Gerrit picks failed."
  else
    python $WORKSPACE/hudson/repopick.py $(curl $GERRIT_CHANGES)
    check_result "gerrit picks failed."
  fi
fi

# Setup ccache size
if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "100.0" ]
then
  ccache -M 100G
fi

# Check if we need to cleanup the out directory
LAST_CLEAN=0
if [ -f .clean ]
then
  LAST_CLEAN=$(date -r .clean +%s)
fi
TIME_SINCE_LAST_CLEAN=$(expr $(date +%s) - $LAST_CLEAN)
# convert this to hours
TIME_SINCE_LAST_CLEAN=$(expr $TIME_SINCE_LAST_CLEAN / 60 / 60)
if [ $TIME_SINCE_LAST_CLEAN -gt "24" -o $CLEAN = "true" ]
then
  echo "Cleaning!"
  touch .clean
  make $CLEAN_TARGETS
else
  echo "Skipping clean: $TIME_SINCE_LAST_CLEAN hours since last clean."
fi

# Save last branch
echo "$BRANCH" > .last_branch

# Build
time make -j$JOBS $BUILD_TARGETS
check_result "Build failed."

# Archive zip's
for f in $(ls $OUT/*.zip*)
  do
    ln $f $WORKSPACE/archive/$(basename $f)
done

# Archive recovery
if [ -f $OUT/recovery.img ]
then
  cp $OUT/recovery.img $WORKSPACE/archive
fi

# Archive boot
if [ -f $OUT/boot.img ]
then
  cp $OUT/boot.img $WORKSPACE/archive
fi

# Archive the build.prop
if [ -f $OUT/system/build.prop ]
then
  cp -f $OUT/system/build.prop $WORKSPACE/archive/build.prop
fi

# Build debuggable boot.img if needed
if [ "$EXTRA_DEBUGGABLE_BOOT" = "true" ]
then
  # Minimal rebuild to get a debuggable boot image, just in case
  rm -f $OUT/root/default.prop
  DEBLUNCH=$(echo $LUNCH|sed -e 's|-userdebug$|-eng|g' -e 's|-user$|-eng|g')
  lunch $DEBLUNCH
  make -j$JOBS bootimage
  check_result "Failed to generate a debuggable bootimage"
  cp $OUT/boot.img $WORKSPACE/archive/boot-debuggable.img
fi

# chmod the files in case UMASK blocks permissions
chmod -R ugo+r $WORKSPACE/archive
