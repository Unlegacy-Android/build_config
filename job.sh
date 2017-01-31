#!/usr/bin/env bash

# This should be copied to a shell command in jenkins project
# curl -ksO https://raw.githubusercontent.com/Unlegacy-Android/build_config/master/job.sh
# chmod a+x job.sh
# bash job.sh

if [ -z "$CHECK_JDK" ];
then
  export CHECK_JDK="false"
fi

if [ "$CHECK_JDK" == "true" ]; then
  if [ "$BRANCH" == "aosp-4.4" ]; then
    echo "Setting default jdk to 1.7"
    echo 1 | sudo /usr/bin/update-alternatives --config java > /dev/null
    echo 1 | sudo /usr/bin/update-alternatives --config javac > /dev/null
    echo 1 | sudo /usr/bin/update-alternatives --config javap > /dev/null
  else
    echo "Setting default jdk to 1.8"
    echo 0 | sudo /usr/bin/update-alternatives --config java > /dev/null
    echo 0 | sudo /usr/bin/update-alternatives --config javac > /dev/null
    echo 0 | sudo /usr/bin/update-alternatives --config javap > /dev/null
  fi
fi

if [ ! -d build_config ]
then
  git clone git://github.com/Unlegacy-Android/build_config.git
fi

cd build_config
## Get rid of possible local changes
git reset --hard
git pull -s resolve

chmod a+x ./build.sh
exec ./build.sh