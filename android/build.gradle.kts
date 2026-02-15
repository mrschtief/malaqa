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

subprojects {
    val project = this
    plugins.whenPluginAdded {
        // Wir prüfen, ob es ein Android-Plugin ist (Library oder App)
        if (this::class.java.name.contains("com.android.build.gradle.LibraryPlugin") || 
            this::class.java.name.contains("com.android.build.gradle.AppPlugin")) {
            
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                // Wir setzen den Namespace direkt aus der Projektgruppe (z.B. com.example.isar)
                android.namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
