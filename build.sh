#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    (repo forall -c "git reset --hard") > /dev/null
    echo $1
    exit 1
  fi
}

# Define workspace path
export WORKSPACE=/unlegacy

# Set build jobs
export JOBS=$(expr 0 + $(grep -c ^processor /proc/cpuinfo))

# Set CLEAN if not specified
if [ -z "$CLEAN" ]
then
  echo CLEAN not specified, setting to false
  export CLEAN=false
fi

# Check for product
if [ -z "$BUILD_PRODUCT" ]
then
  echo BUILD_PRODUCT not specified, using ua product as default...
  export BUILD_PRODUCT_PREFIX=ua
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
cd $WORKSPACE/$BRANCH

# Make sure ccache is in PATH
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilts/misc/$(uname|awk '{print tolower($0)}')-x86/ccache"
export CCACHE_DIR=$WORKSPACE/.ccache

# Run the bootstrap script if exists
if [ -f $WORKSPACE/build_config/bootstrap.sh ]
then
  bash $WORKSPACE/build_config/bootstrap.sh
fi

# Load build environment
. build/envsetup.sh

# Try to lunch
lunch $LUNCH
check_result "Lunch failed."

if [ "$1" == "build" ]
then
  # Cleanup zip's from OUT directory
  rm -f $OUT/*.zip*

  # Load gerrit changes
  if [ ! -z "$GERRIT_CHANGES" ]
  then
    IS_HTTP=$(echo $GERRIT_CHANGES | grep http)
    if [ -z "$IS_HTTP" ]
    then
      python $WORKSPACE/$BRANCH/vendor/unlegacy/build/tools/repopick.py $GERRIT_CHANGES
      check_result "Gerrit picks failed."
    else
      python $WORKSPACE/$BRANCH/vendor/unlegacy/build/tools/repopick.py $(curl $GERRIT_CHANGES)
      check_result "Gerrit picks failed."
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
    make clean
  else
    echo -e "Skipping full clean: $TIME_SINCE_LAST_CLEAN hours since last clean.\nJust doing installclean."
    make installclean
  fi

  # Build
  if [ $PUBLISH_BUILD = "true" ]
  then
    time make -j$JOBS target-files-package
    check_result "Build failed."
    # Send target_files to be processed by otatools
    export INCOMING_DIR=/incoming/${BRANCH}
    export DEVICE_TARGET_FILES_DIR=${INCOMING_DIR}/${DEVICE}
    export DEVICE_TARGET_FILES_PATH=${DEVICE_TARGET_FILES_DIR}/$(date -u +%Y%m%d%H%M%S).zip
    mkdir -p $DEVICE_TARGET_FILES_DIR
    cp ${OUT}/obj/PACKAGING/target_files_intermediates/*target_files*.zip $DEVICE_TARGET_FILES_PATH
    rm -f $(readlink ${DEVICE_TARGET_FILES_DIR}/last.zip)
    rm -f ${DEVICE_TARGET_FILES_DIR}/last.zip
    rm -f ${DEVICE_TARGET_FILES_DIR}/last.prop
    mv ${DEVICE_TARGET_FILES_DIR}/latest.zip ${DEVICE_TARGET_FILES_DIR}/last.zip
    mv ${DEVICE_TARGET_FILES_DIR}/latest.prop ${DEVICE_TARGET_FILES_DIR}/last.prop
    ln -sf $DEVICE_TARGET_FILES_PATH ${DEVICE_TARGET_FILES_DIR}/latest.zip
    cp -f $OUT/system/build.prop ${DEVICE_TARGET_FILES_DIR}/latest.prop
  else
    time make -j$JOBS otapackage
    check_result "Build failed."
    # Archive zip's
    for f in $(ls $OUT/*.zip*)
      do
        cp $f $WORKSPACE/archive/$(basename $f)
    done
  fi
  # Cleanup product directory and leave just the shared objects
  rm -rf $(cd $OUT/../;pwd)
elif  [ "$1" == "otapackage" ]
then
  export INCOMING_DEVICE_DIR=/incoming/${BRANCH}/${DEVICE}
  export OTA_OPTIONS="-t $JOBS -v -p $ANDROID_HOST_OUT"
  export PLATFORM_VERSION=`grep ro.build.version.release ${INCOMING_DEVICE_DIR}/latest.prop | cut -d '=' -f2`
  export OUTPUT_FILE_NAME="ua_${DEVICE}-${PLATFORM_VERSION}"
  export LATEST_DATE=$(date -r ${INCOMING_DEVICE_DIR}/latest.prop +%Y%m%d%H%M%S)
  if [ -f ${INCOMING_DEVICE_DIR}/last.zip ]
  then
    export LAST_DATE=$(date -r ${INCOMING_DEVICE_DIR}/last.prop +%Y%m%d%H%M%S)
    export FILE_NAME=${OUTPUT_FILE_NAME}-${LAST_DATE}-TO-${LATEST_DATE}
    ./build/tools/releasetools/ota_from_target_files \
                  $OTA_OPTIONS \
                  --incremental_from $INCOMING_DEVICE_DIR/last.zip \
                  $INCOMING_DEVICE_DIR/latest.zip $WORKSPACE/archive/$FILE_NAME.zip
    check_result "Delta OTA Package failed."
    if [ -s $WORKSPACE/archive/$FILE_NAME.zip ]
    then
      export FILE_NAME=${OUTPUT_FILE_NAME}-${LATEST_DATE}
      ./build/tools/releasetools/ota_from_target_files \
                    $OTA_OPTIONS \
                    --block \
                    $INCOMING_DEVICE_DIR/latest.zip $WORKSPACE/archive/$FILE_NAME.zip
      check_result "OTA Package failed."
    else
      rm -f $WORKSPACE/archive/$FILE_NAME.*
    fi
  else
    export FILE_NAME=${OUTPUT_FILE_NAME}-${LATEST_DATE}
    ./build/tools/releasetools/ota_from_target_files \
                  $OTA_OPTIONS \
                  --block \
                  $INCOMING_DEVICE_DIR/latest.zip $WORKSPACE/archive/$FILE_NAME.zip
    check_result "OTA Package failed."
  fi
  for f in $(ls $WORKSPACE/archive/*.zip*)
  do
    md5sum $f | cut -d ' ' -f1 > $WORKSPACE/archive/$(basename $f).md5sum
  done
fi
