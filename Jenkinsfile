node {
    stage('Preparation') {
        //echo 'Checking JDK...'
        //if (${BRANCH} == 'aosp-4.4') {
            // jdk for 4.4
        //} else {
            // jdk for others
        //}
        echo 'Moving to the build directory...'
        sh 'mkdir -p /unlegacy/${BRANCH}'
    }
    stage('Code syncing') {
        checkout poll: false, scm: [$class: 'RepoScm', currentBranch: true, destinationDir: '/unlegacy/'+env.BRANCH, forceSync: true, jobs: 8, manifestBranch: '${BRANCH}', manifestRepositoryUrl: 'https://github.com/Unlegacy-Android/android.git', noTags: true, quiet: true]
    }
    stage('Build process') {
        // some block
    }
    stage('Archive files') {
        archiveArtifacts allowEmptyArchive: true, artifacts: 'archive/**', fingerprint: true, onlyIfSuccessful: true
    }
}