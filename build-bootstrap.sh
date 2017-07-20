#!/usr/bin/env bash


JENKINS_ANDROID_JOB="$JENKINS_URL/job/android/buildWithParameters?token=$JENKINS_BUILD_TOKEN&PUBLISH_BUILD=true"

WEEK_DAY=$(date +%u)    # day of the week (1..7); 1 is Monday
MONTH_DAY=$(date +%d)   # day of the month; (01..NN)

SPECIFIED_BRANCH=

curl -s https://raw.githubusercontent.com/Unlegacy-Android/build_config/master/build-targets > build-targets

function process_line {
  LINE=$1
  if [ "$LINE" != "" ] && [[ $LINE != \#* ]] ;
    then
      IFS=' '
      declare -a LINE_ARRAY=($*)
      DEVICE=${LINE_ARRAY[0]}
      BUILD_TYPE=${LINE_ARRAY[1]}
      BRANCH=${LINE_ARRAY[2]}
      FREQ=${LINE_ARRAY[3]}
      BUILD_DAY=${LINE_ARRAY[4]}
      if [ $FORCE_BUILD == "false" ] ; then
        if [ "$FREQ" == "" ] || [ "$FREQ" == "D" ] ; then
          curl $JENKINS_ANDROID_JOB\&BRANCH=$BRANCH\&DEVICE=$DEVICE\&BUILD_TYPE=$BUILD_TYPE
        elif [ "$FREQ" == "W" ] && [ "$WEEK_DAY" == "$BUILD_DAY" ] ; then
          curl $JENKINS_ANDROID_JOB\&BRANCH=$BRANCH\&DEVICE=$DEVICE\&BUILD_TYPE=$BUILD_TYPE
        elif [ "$FREQ" == "M" ] && [ "$MONTH_DAY" == "$BUILD_DAY" ] ; then
          curl $JENKINS_ANDROID_JOB\&BRANCH=$BRANCH\&DEVICE=$DEVICE\&BUILD_TYPE=$BUILD_TYPE
        fi
      else
        if [ "$SPECIFIED_BRANCH" == "$BRANCH" ] ; then
          curl $JENKINS_ANDROID_JOB\&BRANCH=$BRANCH\&DEVICE=$DEVICE\&BUILD_TYPE=$BUILD_TYPE
        fi
      fi
  fi
}

while read i;
  do
    process_line "$i";
    sleep 1
done < ./build-targets
