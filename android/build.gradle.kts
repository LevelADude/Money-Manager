allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Erzwinge compileSdk 36 für ALLE (Plugin-)Subprojekte. Sonst kompiliert z. B.
// passkeys_doctor gegen android-35, während package_info_plus/device_info_plus
// compileSdk 36 verlangen -> checkReleaseAarMetadata schlägt fehl.
// Wichtig: afterEvaluate VOR evaluationDependsOn registrieren, sonst
// "Cannot run Project.afterEvaluate when the project is already evaluated".
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileSdkVersion(36)
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
