node('builder') {
    currentBuild.description = env.env.BUILD_PRODUCT+'_'+env.DEVICE+'-'+env.BRANCH
    stage('Preparation') {0
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
        dir('/unlegacy/build_config') {
            checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: 'master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'WipeWorkspace']], submoduleCfg: [], userRemoteConfigs: [[url: 'git://github.com/Unlegacy-Android/build_config.git']]]
        }
        dir('/unlegacy/build_config') {
            sh returnStdout: false, script: 'bash build.sh otapackage'
        }
    }
    stage('Archiving') {
        archiveArtifacts allowEmptyArchive: true, artifacts: '/unlegacy/archive/**', fingerprint: true, onlyIfSuccessful: true
    }
    stage('Publishing') {
        sh returnStdout: false, script: 'scp -r /unlegacy/archive/** builds@mirror:./$BRANCH/$DEVICE/.'
    }
}