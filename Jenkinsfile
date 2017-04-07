void resetSourceTree() {
  echo 'Reseting source tree...'
  dir(env.SOURCE_DIR) {
    sh '''#!/usr/bin/env bash
    repo forall -c "git reset --hard"'''
  }
}

void repoPickGerritChanges() {
  echo 'Applying gerrit changes...'
  dir(env.SOURCE_DIR) {
    try {
      sh '''#!/usr/bin/env bash
      if [ ! -z "$GERRIT_CHANGES" ]
      then
        IS_HTTP=$(echo $GERRIT_CHANGES | grep http)
        if [ -z "$IS_HTTP" ]
        then
          python ./vendor/unlegacy/build/tools/repopick.py $GERRIT_CHANGES
        else
          python ./vendor/unlegacy/build/tools/repopick.py $(curl $GERRIT_CHANGES)
        fi
      fi'''
    } catch (Exception e) {
      echo 'Gerrit picks failed.'
    }
  }
}

int build(String buildTargets) {
  echo 'Building android...'
  env.BUILD_TARGETS = buildTargets
  dir(env.SOURCE_DIR) {
    return sh (returnStatus: true, script: '''#!/usr/bin/env bash
    # Make sure ccache is in PATH
    export PATH="$PATH:/opt/local/bin/:$PWD/prebuilts/misc/$(uname|awk '{print tolower($0)}')-x86/ccache"

    # Load build environment
    . build/envsetup.sh

    # Try to lunch
    lunch $LUNCH

    # Setup ccache size
    if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "100.0" ]
    then
      ccache -M 100G
    fi

    # Check if we need to cleanup the OUT directory
    LAST_CLEAN=0
    if [ -f .clean ]
    then
      LAST_CLEAN=$(date -r .clean +%s)
    fi
    TIME_SINCE_LAST_CLEAN=$(expr $(date +%s) - $LAST_CLEAN)
    # Convert this to hours
    TIME_SINCE_LAST_CLEAN=$(expr $TIME_SINCE_LAST_CLEAN / 60 / 60)
    if [ $TIME_SINCE_LAST_CLEAN -gt "24" -o $CLEAN = "true" ]
    then
      echo "Cleaning!"
      touch .clean
      make clean
    else
      echo -e "Skipping full clean: $TIME_SINCE_LAST_CLEAN hours since last clean.\nJust doing installclean."
      #make installclean
    fi

    time make -j$JOBS $BUILD_TARGETS
    ''')
  }
}

int createOtaPackage(String otaType) {
  echo 'Creating OTA Package...'
  env.OTA_TYPE = otaType
  dir(env.SOURCE_DIR) {
    return sh (returnStatus: true, script: '''#!/usr/bin/env bash
    # Load build environment
    . build/envsetup.sh
    lunch $LUNCH

    export DEVICE_TARGET_FILES_PATH=$DEVICE_TARGET_FILES_DIR/$(date -u +%Y%m%d%H%M%S).zip
    mkdir -p $DEVICE_TARGET_FILES_DIR
    cp ${OUT}/obj/PACKAGING/target_files_intermediates/*target_files*.zip $DEVICE_TARGET_FILES_PATH
    rm -f $(readlink ${DEVICE_TARGET_FILES_DIR}/last.zip) 2>/dev/null
    rm -f ${DEVICE_TARGET_FILES_DIR}/last.zip 2>/dev/null
    rm -f ${DEVICE_TARGET_FILES_DIR}/last.prop 2>/dev/null
    mv ${DEVICE_TARGET_FILES_DIR}/latest.zip ${DEVICE_TARGET_FILES_DIR}/last.zip 2>/dev/null
    mv ${DEVICE_TARGET_FILES_DIR}/latest.prop ${DEVICE_TARGET_FILES_DIR}/last.prop 2>/dev/null
    ln -sf $DEVICE_TARGET_FILES_PATH ${DEVICE_TARGET_FILES_DIR}/latest.zip
    cp -f $OUT/system/build.prop ${DEVICE_TARGET_FILES_DIR}/latest.prop

    export PLATFORM_VERSION=`grep ro.build.version.release $DEVICE_TARGET_FILES_DIR/latest.prop | cut -d '=' -f2`
    export OUTPUT_FILE_NAME=$BUILD_PRODUCT_$DEVICE-$PLATFORM_VERSION
    export LATEST_DATE=$(date -r $DEVICE_TARGET_FILES_DIR/latest.prop +%Y%m%d%H%M%S)
    export OTA_OPTIONS="-v -p $ANDROID_HOST_OUT $OTA_PREDF_OPTIONS"

    if [ -f ${DEVICE_TARGET_FILES_DIR}/last.zip && $OTA_TYPE = "incremental"]
    then
      export LAST_DATE=$(date -r $DEVICE_TARGET_FILES_DIR/last.prop +%Y%m%d%H%M%S)
      export FILE_NAME=$OUTPUT_FILE_NAME-$LAST_DATE-TO-$LATEST_DATE
      ./build/tools/releasetools/ota_from_target_files \
        $OTA_OPTIONS \
        --incremental_from $DEVICE_TARGET_FILES_DIR/last.zip \
        $DEVICE_TARGET_FILES_DIR/latest.zip $ARCHIVE_DIR/$FILE_NAME.zip || exit 1
      if [ -s $ARCHIVE_DIR/$FILE_NAME.zip ]
      then
        export FILE_NAME=${OUTPUT_FILE_NAME}-${LATEST_DATE}
        ./build/tools/releasetools/ota_from_target_files \
          $OTA_OPTIONS \
          --block \
          $DEVICE_TARGET_FILES_DIR/latest.zip $ARCHIVE_DIR/$FILE_NAME.zip || exit 1
      else
        rm -f $ARCHIVE_DIR/$FILE_NAME.*
      fi
    else
      export FILE_NAME=${OUTPUT_FILE_NAME}-${LATEST_DATE}
      ./build/tools/releasetools/ota_from_target_files \
        $OTA_OPTIONS \
        --block \
        $DEVICE_TARGET_FILES_DIR/latest.zip $ARCHIVE_DIR/$FILE_NAME.zip
    fi
    for f in $(ls $ARCHIVE_DIR/*.zip*)
    do
      md5sum $f | cut -d ' ' -f1 > $ARCHIVE_DIR/$(basename $f).md5sum
    done
    rm -rf $INCOMING_TMP_DIR/
    ''')
  }
}

node('builder') {
    try {
        currentBuild.description = env.BUILD_PRODUCT+'_'+env.DEVICE+'-'+env.BRANCH
        stage('Preparation') {
            echo 'Setting up environment...'
            env.WORKSPACE = '/unlegacy'
            env.SOURCE_DIR = env.WORKSPACE + '/' + env.BRANCH
            env.ARCHIVE_DIR = env.WORKSPACE + '/archive'
            env.INCOMING_TMP_DIR = '/tmp/incoming'
            env.INCOMING_DIR = ((env.PUBLISH_BUILD == 'true') ? '/incoming' : env.INCOMING_TMP_DIR ) + env.BRANCH
            env.DEVICE_TARGET_FILES_DIR = env.INCOMING_DIR + '/' + env.DEVICE
            env.LUNCH = env.BUILD_PRODUCT + '_' + env.DEVICE + '-' + env.BUILD_TYPE
            env.CCACHE_DIR = env.WORKSPACE + '/.ccache'
            env.USE_CCACHE = 1
            env.CCACHE_NLEVELS = 4
            env.PYTHONDONTWRITEBYTECODE = 1

            // Number of available cores to build
            echo 'Getting the number of available cores...'
            env.JOBS = sh (returnStdout: true, script: '''#!/usr/bin/env bash
            expr 0 + $(grep -c ^processor /proc/cpuinfo)
            ''').trim()
            echo 'Cores available: ' + env.JOBS

            echo 'Setting JDK and OTA Package prerequisites...'
            if (env.BRANCH == 'aosp-4.4') {
                echo 'Branch=aosp-4.4 -> Setting openjdk-7'
                sh script: '''#!/usr/bin/env bash
                update-java-alternatives -s java-1.7.0-openjdk-amd64 2>/dev/null'''
                env.OTA_OPTIONS = ''
            } else {
                echo 'Branch='+env.BRANCH+' -> Setting openjdk-8'
                sh script: '''#!/usr/bin/env bash
                update-java-alternatives -s java-1.8.0-openjdk-amd64 2>/dev/null'''
                env.OTA_OPTIONS = '-t ' + envJOBS
            }

            echo 'Creating build directory structure...'
            sh script: '''#!/usr/bin/env bash
            mkdir -p /unlegacy/$BRANCH
            mkdir -p /unlegacy/repo-mirror
            ln -sf /unlegacy/repo-mirror /unlegacy/$BRANCH/.repo'''

            echo 'Preparing archive directory...'
            sh '''#!/usr/bin/env bash
            mkdir -p $ARCHIVE_DIR
            rm -rf $ARCHIVE_DIR/**'''
        }
        stage('Code syncing') {
            //checkout poll: false, scm: [$class: 'RepoScm', currentBranch: true, destinationDir: '/unlegacy/'+env.BRANCH, forceSync: true, jobs: env.JOBS, depth: 1, manifestBranch: env.BRANCH, manifestRepositoryUrl: 'https://github.com/Unlegacy-Android/android.git', noTags: true, quiet: true]
            //saveManifest() : TODO
            repoPickGerritChanges()
        }
        stage('Build process') {
            ret = build('target-files-package')
            if ( ret != 0 )
                trow 'Build failed!'
        }
        stage('OTA Package') {
            ret = createOtaPackage(((env.PUBLISH_BUILD == 'true') ? 'incremental' : 'full'))
            if ( ret != 0 )
                trow 'Failed to create OTA Package!'
        }
        stage('Archiving') {
            dir(env.ARCHIVE_DIR) {
                //archiveArtifacts allowEmptyArchive: true, artifacts: '**', excludes: '*-ota-*', fingerprint: true, onlyIfSuccessful: true
            }
        }
        stage('Publishing') {
            dir(env.ARCHIVE_DIR) {
              if (env.PUBLISH_BUILD == 'true') {
                  echo 'Publishing...'
                  //sh returnStdout: false, script: 'scp -r ./** builds@mirror:./$BRANCH/$DEVICE/.'
              } else
                  echo 'Will not publish anything because PUBLISH_BUILD=false'
            }
        }
        //slackSend (color: 'good', message: "Jenkins Builder - Job SUCCESS: '${env.JOB_NAME} [${env.BUILD_NUMBER} - ${currentBuild.description}]' (${env.BUILD_URL})")
        currentBuild.result = 'SUCCESS'
    } catch (Exception e) {
        //slackSend (color: 'danger', message: "Jenkins Builder - Job FAILED: '${env.JOB_NAME} [${env.BUILD_NUMBER} - ${currentBuild.description}]' (${env.BUILD_URL})")
        currentBuild.result = 'FAILURE'
        //resetSourceTree()
    }
    echo "RESULT: ${currentBuild.result}"
}