pipeline {

    agent any

    environment {
        ARTIFACT = readMavenPom().getArtifactId()
        VERSION = readMavenPom().getVersion()
    }

    stages {
      stage ('Initialize') {
        steps {
          sh 'docker --version && mvn --version && git --version'

          withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GIT_USERNAME', passwordVariable: 'PASSWORD')]) {
            sh 'git config user.name ${GIT_USERNAME} && git config credential.helper store'
          }
        }
      }

      stage ('Build') {
        steps {
          sh 'mvn clean package'
          sh 'docker rmi ${ARTIFACT} && docker build --rm=false -t ${ARTIFACT} .'
        }
      }

      stage ('Test') {
        steps {
          sh 'chmod +x scripts/integration-test.sh && ./scripts/integration-test.sh'
        }
      }

      stage ('Deploy Dev') {
	      when {
  	       branch 'master'
  	    }
        steps {
          sh 'chmod +x scripts/deploy-dev.sh && ./scripts/deploy-dev.sh ${ARTIFACT}'
        }
      }

      stage ('Deploy Staging') {
      	when {
      	   branch 'release-*'
      	}
        steps {
	         sh 'chmod +x scripts/deploy-staging.sh && ./scripts/deploy-staging.sh ${VERSION}.beta.${BUILD_NUMBER} ${GIT_BRANCH} ${ARTIFACT}'
        }
      }
    }

    post {
        success {
            slackSend (color: '#00FF00', message: "SUCCESSFUL: Job ${JOB_NAME} Build #${BUILD_NUMBER} from branch '${BRANCH_NAME}' (${BUILD_URL})")
        }
        failure {
            slackSend (color: '#FF0000', message: "FAILED: Job ${JOB_NAME} Build #${BUILD_NUMBER} from branch '${BRANCH_NAME}' (${BUILD_URL})")
        }
        unstable {
            slackSend (color: '#FF8A00', message: "UNSTABLE: Job ${JOB_NAME} Build #${BUILD_NUMBER} from branch '${BRANCH_NAME}' (${BUILD_URL})")
        }
        always {
            slackSend (color: '#FFFF00', message: "STARTED: Job ${JOB_NAME} Build #${BUILD_NUMBER} from branch '${BRANCH_NAME}' (${BUILD_URL})")
        }
    }

}

