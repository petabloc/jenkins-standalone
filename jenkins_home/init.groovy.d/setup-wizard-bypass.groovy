#!groovy
import jenkins.model.*
import jenkins.install.*

def instance = Jenkins.getInstance()
def currentState = instance.getInstallState()

println "Current Jenkins install state: ${currentState}"

// Only proceed if we're still in the setup process
if (currentState == InstallState.NEW || 
    currentState == InstallState.INITIAL_SETUP_COMPLETED ||
    currentState == InstallState.INITIAL_SECURITY_SETUP ||
    currentState == InstallState.INITIAL_PLUGINS_INSTALLING) {
    
    println "Setting Jenkins install state to INITIAL_SETUP_COMPLETED to bypass plugin customization screen"
    instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
    instance.save()
    
    println "Jenkins install state successfully set to: ${instance.getInstallState()}"
} else {
    println "Jenkins is already configured (state: ${currentState}), skipping setup wizard bypass"
}