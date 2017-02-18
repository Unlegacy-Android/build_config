# To test the build environment build_config project should be cloned to the same directory
# where UA "source" is in, enter in build_config directory, edit env-test.sh and execute:
# . env-test.sh
# bash -xe build.sh

export BRANCH="aosp-7.1"
export BUILD_TYPE="userdebug"
export BUILD_PRODUCT="ua"
export DEVICE="tuna"
export CLEAN=false
export GERRIT_CHANGES=""
