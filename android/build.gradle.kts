allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Force all plugins to compile against SDK 36
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class)?.apply {
            compileSdkVersion(36)
        }
    }
}