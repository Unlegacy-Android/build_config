node('builder') {
    try {
        currentBuild.description = env.BUILD_PRODUCT+'_'+env.DEVICE+'-'+env.BRANCH
        stage('Preparation') {
            //echo 'Checking JDK...'
            if (env.BRANCH == 'aosp-4.4') {
                echo 'Branch=aosp-4.4 -> Setting openjdk-7'
                sh 'update-java-alternatives -s java-1.7.0-openjdk-amd64 2>/dev/null'
            } else {
                echo 'Branch='+env.BRANCH+' -> Setting openjdk-8'
                sh 'update-java-alternatives -s java-1.8.0-openjdk-amd64 2>/dev/null'
            }
            echo 'Creating build directory structure...'
            sh 'mkdir -p /unlegacy/${BRANCH}'
            sh 'mkdir -p /unlegacy/repo-mirror'
            sh 'ln -sf /unlegacy/repo-mirror /unlegacy/${BRANCH}/.repo'
        }
        stage('Code syncing') {
            dir('/unlegacy/build_config') {
                checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: 'master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'WipeWorkspace']], submoduleCfg: [], userRemoteConfigs: [[url: 'git://github.com/Unlegacy-Android/build_config.git']]]
            }
            checkout poll: false, scm: [$class: 'RepoScm', currentBranch: true, destinationDir: '/unlegacy/'+env.BRANCH, forceSync: true, jobs: 8, depth: 1, manifestBranch: '${BRANCH}', manifestRepositoryUrl: 'https://github.com/Unlegacy-Android/android.git', noTags: true, quiet: true]
        }
        stage('Build process') {
            dir('/unlegacy/build_config') {
                sh returnStdout: false, script: 'bash build.sh build'
            }
        }
        stage('OTA Package') {
            if (env.PUBLISH_BUILD == 'true') {
                dir('/unlegacy/build_config') {
                    sh returnStdout: false, script: 'bash build.sh otapackage'
                }
            } else {
                echo "Will not run OTA Package because PUBLISH_BUILD=false"
            }
        }
        stage('Archiving') {
            dir('/unlegacy/archive') {
                archiveArtifacts allowEmptyArchive: true, artifacts: '**', fingerprint: true, onlyIfSuccessful: true
            }
        }
        stage('Publishing') {
            if (env.PUBLISH_BUILD == 'true') {
                sh returnStdout: false, script: 'scp -r /unlegacy/archive/** builds@mirror:./$BRANCH/$DEVICE/.'
            } else {
                echo "Will not publish anything because PUBLISH_BUILD=false"
            }
        }
        slackSend (color: 'good', message: "Jenkins Builder - Job SUCCESS: '${env.JOB_NAME} [${env.BUILD_NUMBER} - ${currentBuild.description}]' (${env.BUILD_URL})")
    } catch (Exception e) {
        slackSend (color: 'danger', message: "Jenkins Builder - Job FAILED: '${env.JOB_NAME} [${env.BUILD_NUMBER} - ${currentBuild.description}]' (${env.BUILD_URL})")
    }
}