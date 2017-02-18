node {
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
            checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: 'refs/changes/35/1335/10']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'WipeWorkspace']], submoduleCfg: [], userRemoteConfigs: [[refspec: '+refs/changes/*:refs/changes/*', url: 'git://github.com/Unlegacy-Android/build_config.git']]]
        }
        checkout poll: false, scm: [$class: 'RepoScm', currentBranch: true, destinationDir: '/unlegacy/'+env.BRANCH, forceSync: true, jobs: 8, depth: 1, manifestBranch: '${BRANCH}', manifestRepositoryUrl: 'https://github.com/Unlegacy-Android/android.git', noTags: true, quiet: true]
    }
    stage('Build process') {
        dir('/unlegacy/build_config') {
            sh returnStdout: false, script: 'bash build.sh'
        }
    }
    stage('Signing package') {
        // TODO
    }
    stage('Publishing package') {
        archiveArtifacts allowEmptyArchive: true, artifacts: 'archive/**', excludes: 'archive/*ota*', fingerprint: true, onlyIfSuccessful: true
    }
}