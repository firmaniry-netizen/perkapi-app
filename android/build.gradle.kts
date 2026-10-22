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

// Beberapa plugin (mis. file_picker) masih memakai compileSdk 34, padahal dependency terbaru
// (flutter_plugin_android_lifecycle) mewajibkan minimal 36. Paksa semua plugin library ke 36.
// PENTING: blok ini harus berada SEBELUM evaluationDependsOn di bawah.
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext is com.android.build.gradle.LibraryExtension) {
            ext.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}