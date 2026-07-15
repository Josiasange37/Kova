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

// Force JVM 17 on ALL Java/Kotlin compile tasks AFTER every project has been
// evaluated. Plugin modules (tflite_flutter, mobile_scanner) set their own
// lower JVM target in their build.gradle; projectsEvaluated guarantees our
// override runs last and wins. Using `allprojects { afterEvaluate {} }` fails
// here because evaluationDependsOn(":app") force-evaluates projects early.
gradle.projectsEvaluated {
    allprojects {
        tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget("17"))
            }
        }

        // Force Android SDK root for ALL subprojects (plugins from pub cache
        // inherit the root project's local.properties but AGP may not resolve
        // android.jar for library modules without an explicit sdkDirectory).
        val androidExt = extensions.findByType<com.android.build.gradle.BaseExtension>()
        if (androidExt != null) {
            androidExt.sdkDirectory = file(System.getenv("ANDROID_SDK_ROOT") ?: "/usr/local/lib/android/sdk")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
