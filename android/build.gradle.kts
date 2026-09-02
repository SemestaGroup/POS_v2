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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                android.compileSdkVersion(36)
                if (android.namespace.isNullOrEmpty()) {
                    val manifest = project.file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val pkg = javax.xml.parsers.DocumentBuilderFactory.newInstance()
                            .newDocumentBuilder()
                            .parse(manifest)
                            .documentElement
                            .getAttribute("package")
                        if (pkg.isNotEmpty()) {
                            android.namespace = pkg
                        }
                    }
                }
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
