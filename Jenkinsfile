//Requires the following plugins
//Email Extension Plugin
//SSH Pipeline Steps
//user build vars plugin

//Requires the following values under http://jenkinsHostname/scriptApproval - "Signatures already approved:"
//method groovy.lang.Binding getVariables
//method hudson.FilePath delete
//method hudson.FilePath read
//staticMethod org.codehaus.groovy.runtime.DefaultGroovyMethods getBytes java.io.InputStream
//staticMethod org.codehaus.groovy.runtime.EncodingGroovyMethods encodeBase64 byte[]

//Requires a single credentials entry with the following specifications
//ID = Remote Server Hostname
//Username = Remote Server SSH Username
//Password = Remote Server SSH Password
//Scope = Global, could probably be something else but haven't tested it otherwise

//Requires the Jenkins Build to have "This Project Is Parameterized" checked with a "Credentials Parameter" and the following values
//Name = Destination Server
//Credential Type = Username with password
//Required = Checked
//Default Value = One of the Remote Server Credentials - Sorta Optional

def global_remote = [:]

global_unallocatedPort = null

def global_archiveToDecompile = "archiveToDecompile.zip"
def global_archiveToDecompile_testArchive = "testArchive.jar"

def global_recursiveDecompileScript = "recursiveDecompile.sh"
def global_recursiveDecompileJar = "jd-cli.jar"

def global_dockerImage_repo = "codercom/code-server"
def global_dockerImage_tag = "2.preview.5-vsc1.37.0"
def global_dockerImage = "$global_dockerImage_repo:$global_dockerImage_tag"

def global_dockerContainer_id = null

def global_dockerImage_file = "codercom_code-server_2.preview.5-vsc1.37.0.tar.gz"
def global_remoteTempDirectory = "/opt"

def global_testMode = false

global_inputFile = null

pipeline {
    agent any

    stages {

        stage('Upload File') {
            steps {
                script{
                    if(global_testMode == false)
                    {
                        email_notifyUploadRequirement()
                        global_inputFile = input message: 'Upload file', parameters: [file(name: global_archiveToDecompile)]
                        writeFile(file: global_archiveToDecompile, encoding: 'Base64', text: global_inputFile.read().getBytes().encodeBase64().toString())
                        global_inputFile.delete()
                    }
                }
            }
        }

        stage('Setup Credentials') {
            steps {
                //notifyStarted()

                script {
                    withCredentials([usernamePassword(credentialsId: params['Destination Server'], passwordVariable: 'pass', usernameVariable: 'user')]) {
                        global_remote.name = params['Destination Server']
                        global_remote.host = params['Destination Server']
                        global_remote.user = "$user"
                        global_remote.password = "$pass"
                        global_remote.allowAnyHosts = true
                    }
                }
            }
        }

        stage('Perform') {
            steps {
                script {
                    try {
                        //Run the getFreePort.sh Script and retrieve an unallocated TCP Port to host the docker container on
                        global_unallocatedPort = sshScript remote: global_remote, script: "getFreePort.sh"

                        //Run the Docker Images command remotely to see if the image dependency for VS Code exists
                        currentImages = sshCommand remote: global_remote, command: "docker images"

                        //Check if the image dependency is in the output, if not then copy the archive to the server 
                        //and load it into the docker daemon, then delete it after
                        if(!currentImages.contains(global_dockerImage_repo) && !currentImages.contains(global_dockerImage_tag))
                        {
                            transferOverSsh(global_dockerImage_file, null, global_remoteTempDirectory, global_remote)
                            sshCommand remote: global_remote, command: "docker load --input " + '"' + "$global_remoteTempDirectory/$global_dockerImage_file" + '"'
                            sshCommand remote: global_remote, command: "rm -f " + '"' + "$global_remoteTempDirectory/$global_dockerImage_file" + '"'
                        }

                        //Create Docker Container for the Visual Studio Code Workspace
                        createWorkspaceCommand = "docker run -d --rm -p $global_unallocatedPort:8080 " + '"' + "$global_dockerImage" + '"'
                        global_dockerContainer_id = sshCommand remote: global_remote, command: createWorkspaceCommand

                        //For Continuous Integration Testing
                        if(global_testMode == true)
                        {
                            global_archiveToDecompile = global_archiveToDecompile_testArchive
                        }

                        destinationDockerFolder = "/home/coder/project/"

                        //Transfer Archive to Decompile to Docker Container
                        transferOverSsh_copyToDockerContainer_removeFile(global_archiveToDecompile, global_remoteTempDirectory, global_remote, global_dockerContainer_id, destinationDockerFolder)
                        
                        //Transfer Recursive Decompile Jar to Docker Container
                        transferOverSsh_copyToDockerContainer_removeFile(global_recursiveDecompileJar, global_remoteTempDirectory, global_remote, global_dockerContainer_id, destinationDockerFolder)
                        
                        //Transfer Recursive Decompile Script to Docker Container
                        transferOverSsh_copyToDockerContainer_removeFile(global_recursiveDecompileScript, global_remoteTempDirectory, global_remote, global_dockerContainer_id, destinationDockerFolder)

                        //Update Linux Application Repository
                        command_updateRepository = "apt-get update"
                        runCommand_onDockerContainer(global_remote, command_updateRepository, global_dockerContainer_id, true) 

                        //Install Java and Unzip Commands
                        command_installDependencies = "apt-get install -y default-jdk unzip"
                        runCommand_onDockerContainer(global_remote, command_installDependencies, global_dockerContainer_id, true) 

                        //Run Recursive Decompile
                        command_recursiveDecompile = destinationDockerFolder + global_recursiveDecompileScript  + " " + destinationDockerFolder + global_archiveToDecompile
                        runCommand_onDockerContainer(global_remote, command_recursiveDecompile, global_dockerContainer_id, false) 

                        email_workspaceUrl(global_remote, global_unallocatedPort)

                    } catch(exception) {
                        removeContainerCommand = "docker stop $global_dockerContainer_id"
                        sshCommand remote: global_remote, command: removeContainerCommand
                        error exception.toString()
                    }
                }
            }
        }

        stage('Workspace Cleanup') {
            steps {
                script {
                    message = "Extension of Workspace Life"
                    warningMessage = "Termination, deletion, and cleanup of Workspace"
                    hoursToSleep = 24
                    hoursToWaitBeforeTimeout = 1
                    extendWorkspace = timeout(message, warningMessage, hoursToSleep, hoursToWaitBeforeTimeout, "HOURS")

                    if(extendWorkspace == false)
                    {
                        sshCommand remote: global_remote, command: "docker stop " + global_dockerContainer_id
                        sshCommand remote: global_remote, command: "docker rm " + global_dockerContainer_id
                    }
                }
            }
        }
    }
}

def transferOverSsh(parameter_workspaceFileName, parameter_tempFileName, parameter_tempDirectory, parameter_remoteObject) {
    filePath_toReturn = ""

    if(parameter_tempFileName != null)
    {
        filePath_toReturn = "$parameter_tempDirectory/$parameter_tempFileName"
        sshPut remote: parameter_remoteObject, from: parameter_workspaceFileName, into: filePath_toReturn
    }
    else
    {
        filePath_toReturn = "$parameter_tempDirectory/$parameter_workspaceFileName"
        sshPut remote: parameter_remoteObject, from: parameter_workspaceFileName, into: filePath_toReturn
    }

    return filePath_toReturn
}

def copyToDockerContainer(parameter_remoteFilePath, parameter_destinationDockerFilePath, parameter_remoteObject, parameter_dockerContainerId, parameter_removeRemoteFileAfter) {  
    command_copyToDockerContainer = "docker cp " + '"' + parameter_remoteFilePath + '"' + " " +  '"' + "$parameter_dockerContainerId:$parameter_destinationDockerFilePath" + '"'
    sshCommand remote: parameter_remoteObject, command: command_copyToDockerContainer

    setDockerFilePermissions(parameter_destinationDockerFilePath, parameter_remoteObject, parameter_dockerContainerId)

    if(parameter_removeRemoteFileAfter == true)
    {
        command_removeFromRemote = "rm -f " + '"' + parameter_remoteFilePath + '"'
        sshCommand remote: parameter_remoteObject, command: command_removeFromRemote
    }
}

def setDockerFilePermissions(parameter_destinationDockerFilePath, parameter_remoteObject, parameter_dockerContainerId) {
    setPermissionsCommand = "docker exec -t --privileged --user 0 -w / $parameter_dockerContainerId chmod 777 " + '"' + parameter_destinationDockerFilePath + '"'
    sshCommand remote: parameter_remoteObject, command: setPermissionsCommand
}

def transferOverSsh_copyToDockerContainer_removeFile(parameter_workspaceFileName, parameter_tempDirectory, parameter_remoteObject, parameter_dockerContainerId, parameter_destinationDockerFolder){
    parameter_tempFileName = parameter_dockerContainerId + "_" + parameter_workspaceFileName
    
    parameter_remoteFilePath = transferOverSsh(parameter_workspaceFileName, parameter_tempFileName, parameter_tempDirectory, parameter_remoteObject) 
    
    parameter_destinationDockerFilePath = parameter_destinationDockerFolder + parameter_workspaceFileName

    parameter_removeRemoteFileAfter = true

    copyToDockerContainer(parameter_remoteFilePath, parameter_destinationDockerFilePath, parameter_remoteObject, parameter_dockerContainerId, parameter_removeRemoteFileAfter)
}

def runCommand_onDockerContainer(parameter_remoteObject, parameter_commandToRun, parameter_dockerContainerId, parameter_runAsRoot) {
    commandToRun = ""
    
    if(parameter_runAsRoot == true)
    {
        commandToRun = "docker exec -t --privileged --user 0 -w / $parameter_dockerContainerId bash -c " + '"' + parameter_commandToRun + '"'
    }
    else
    {
        commandToRun = "docker exec -t $parameter_dockerContainerId bash -c " + '"' + parameter_commandToRun + '"'
    }

    sshCommand remote: parameter_remoteObject, command: commandToRun
}

def getBuildUserEmail(){
    wrap([$class: 'BuildUser']) {
        return env.BUILD_USER_EMAIL
    }
}



def timeout(message, warningMessage, timeToSleep, timeToSleepBeforeTimeout, timeUnits) {
    yesNo = false
    yesNoTimeout = false
    
    try {
        echo "Waiting before prompting user for input..."

        sleep(time:timeToSleep,unit:timeUnits)
        
        timeWarning = timeToSleepBeforeTimeout + " " + timeUnits

        email_notifyActionRequired(message, warningMessage, timeWarning)

        timeout(time: timeToSleepBeforeTimeout, unit: timeUnits) 
        {
            yesNo = input (
                            id: 'Proceed1', 
                            message: message, 
                            parameters: [
                                            [
                                                $class: 'BooleanParameterDefinition',
                                                defaultValue: true, 
                                                description: '', 
                                                name: message
                                            ]
                                        ]
                        )
        }

    } catch(err) { // timeout reached or input false
        def user = err.getCauses()[0].getUser()
        if('SYSTEM' == user.toString()) { // SYSTEM means timeout.
            yesNoTimeout = false
            yesNo = false
        } else {
            yesNo = false
            echo "Aborted by: [${user}]"
        }
    }
    
    if(yesNo == true)
    {
        timeout(message, warningMessage, timeToSleep, timeToSleepBeforeTimeout, timeUnits)
    }

    return yesNo
}

def email_notifyActionRequired(message, warningMessage, timeWarning) {

  // send to email
  emailext (
      subject: "[JENKINS] Action Required within "+ timeWarning + " - " + message,
      body: """
Hello,

Please navigate to the below URL to address the requested action.
- ${env.BUILD_URL}input

Failure to do so within ${timeWarning} will result in the below conditions:
- ${warningMessage}

Thanks,
Jenkins Automated System

""",
      to: getBuildUserEmail()
    )
}

def email_notifyUploadRequirement() {

  // send to email
  emailext (
      subject: "[JENKINS] Action Required - Upload The JAR/WAR to Decompile",
      body: """
Hello,

Please navigate to the below URL to upload the required JAR/WAR for Decompilation.
- ${env.BUILD_URL}input

Thanks,
Jenkins Automated System

""",
      to: getBuildUserEmail()
    )
}

def email_workspaceUrl(parameter_remoteObject, parameter_unallocatedPort) {

    workspaceHostname = parameter_remoteObject.host

  // send to email
  emailext (
      subject: "[JENKINS] Decompiled JAR/WAR Environment Created",
      body: """
Jenkins Job Name:
- ${env.JOB_NAME}
Jenkins Job Build Number: 
- ${env.BUILD_NUMBER}
   
Access your environment at the following endpoint:
- http://$workspaceHostname:$parameter_unallocatedPort/

""",
      to: getBuildUserEmail()
    )
}
