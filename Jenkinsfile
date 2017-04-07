void resetSourceTree() {
  dir(env.SOURCE_DIR) {
    echo 'Reseting source tree...'
    sh '''#!/usr/bin/env bash
    repo forall -c "git reset --hard"'''
  }
}

void repoPickGerritChanges() {
  dir(env.SOURCE_DIR) {
    echo 'Applying gerrit changes...'
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

int build(String buildTarget) {
  dir(env.SOURCE_DIR) {
    echo 'Building android...'
    sh '''#!/usr/bin/env bash
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
      make installclean
    fi
##################################################_>>>>>>>>>>>>>>>>>>>>>>>>> #TODO<-----------------
    '''
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
            env.INCOMING_DIR='/incoming/'+ env.BRANCH
            env.DEVICE_TARGET_FILES_DIR = env.INCOMING_DIR + '/' + env.DEVICE
            env.LUNCH = env.BUILD_PRODUCT + '_' + env.DEVICE + '-' + env.BUILD_TYPE
            env.USE_CCACHE = 1
            env.CCACHE_NLEVELS = 4
            env.PYTHONDONTWRITEBYTECODE = 1

            // Number of available cores to build
            echo 'Getting the number of available cores...'
            env.JOBS = sh (returnStdout: true, script: '''#!/usr/bin/env bash
            expr 0 + $(grep -c ^processor /proc/cpuinfo)
            ''').trim()
            echo 'Cores available: ' + env.JOBS

            echo 'Setting JDK...'
            if (env.BRANCH == 'aosp-4.4') {
                echo 'Branch=aosp-4.4 -> Setting openjdk-7'
                sh script: '''#!/usr/bin/env bash
                update-java-alternatives -s java-1.7.0-openjdk-amd64 2>/dev/null'''
            } else {
                echo 'Branch='+env.BRANCH+' -> Setting openjdk-8'
                sh script: '''#!/usr/bin/env bash
                update-java-alternatives -s java-1.8.0-openjdk-amd64 2>/dev/null'''
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
        }
        stage('Build process') {
            build('build')
        }
        stage('OTA Package') {
            if (env.PUBLISH_BUILD == 'true') {
                build('otapackage')
            } else {
                echo "Will not run OTA Package because PUBLISH_BUILD=false"
            }
        }
        stage('Archiving') {
            dir('/unlegacy/archive') {
                //archiveArtifacts allowEmptyArchive: true, artifacts: '**', excludes: '*-ota-*', fingerprint: true, onlyIfSuccessful: true
            }
        }
        stage('Publishing') {
            if (env.PUBLISH_BUILD == 'true') {
                //sh returnStdout: false, script: 'scp -r /unlegacy/archive/** builds@mirror:./$BRANCH/$DEVICE/.'
            } else {
                echo "Will not publish anything because PUBLISH_BUILD=false"
            }
        }
        //slackSend (color: 'good', message: "Jenkins Builder - Job SUCCESS: '${env.JOB_NAME} [${env.BUILD_NUMBER} - ${currentBuild.description}]' (${env.BUILD_URL})")
        currentBuild.result = 'SUCCESS'
    } catch (Exception e) {
        //slackSend (color: 'danger', message: "Jenkins Builder - Job FAILED: '${env.JOB_NAME} [${env.BUILD_NUMBER} - ${currentBuild.description}]' (${env.BUILD_URL})")
        currentBuild.result = 'FAILURE'
    }
    echo "RESULT: ${currentBuild.result}"
}