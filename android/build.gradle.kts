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
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker skips applying the Kotlin plugin on AGP 9+, assuming AGP's
// built-in Kotlin will compile it — but android.builtInKotlin=false here
// (needed by flutter_foreground_task and nsd_android, which still apply the
// classic plugin unconditionally). Without this, FilePickerPlugin.kt never
// compiles. Reusable if the project ever needs the same nudge for another
// migrating plugin.
subprojects {
    if (project.name == "file_picker" && !project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
        project.pluginManager.apply("org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
