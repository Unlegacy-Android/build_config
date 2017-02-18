node {
    stage('Preparation') {
        //echo 'Checking JDK...'
        if (env.BRANCH == 'aosp-4.4') {
            echo 'Branch=aosp-4.4 - Setting openjdk-7'
            sh 'update-java-alternatives -s java-1.7.0-openjdk-amd64 2>&1 | cat - > /dev/null'
        } else {
            echo 'Branch>aosp-4.4 - Setting openjdk-8'
            sh 'update-java-alternatives -s java-1.8.0-openjdk-amd64 2>&1 | cat - > /dev/null'
        }
        echo 'Creating build directory...'
        sh 'mkdir -p /unlegacy/${BRANCH}'
    }
    stage('Code syncing') {
        checkout poll: false, scm: [$class: 'GitSCM', currentBranch: true, destinationDir: '/unlegacy/build_config', forceSync: true, jobs: 8, manifestBranch: '${BRANCH}', manifestRepositoryUrl: 'https://github.com/Unlegacy-Android/build_config.git', noTags: true, quiet: true]
        //checkout poll: false, scm: [$class: 'RepoScm', currentBranch: true, destinationDir: '/unlegacy/'+env.BRANCH, forceSync: true, jobs: 8, manifestBranch: '${BRANCH}', manifestRepositoryUrl: 'https://github.com/Unlegacy-Android/android.git', noTags: true, quiet: true]
    }
    stage('Build process') {
        sh returnStdout: true, script: '''cd /unlegacy/build_config
        bash build.sh'''
    }
    stage('Signing package') {
        // TODO
    }
    stage('Publishing package') {
        archiveArtifacts allowEmptyArchive: true, artifacts: 'archive/**', excludes: 'archive/*ota*', fingerprint: true, onlyIfSuccessful: true
    }
}
