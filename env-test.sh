# To test the build environment build_config project should be cloned to the same directory
# where UA "source" is in, enter in build_config directory, edit env-test.sh and execute:
# . env-test.sh
# bash -xe build.sh

export WORKSPACE=$(cd ..; pwd)
export BRANCH="aosp-7.1"
export BUILD_TYPE="eng"
export BUILD_PRODUCT="aosp"
export DEVICE="arm"
export BUILD_TARGETS=""
export CLEAN=false
export CLEAN_TARGETS="installclean"
export GERRIT_CHANGES=""
export EXTRA_DEBUGGABLE_BOOT=false
