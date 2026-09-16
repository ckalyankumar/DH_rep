import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.variant.LibraryAndroidComponentsExtension

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

// Align JVM targets on Android *library* plugins only (not a global
// JavaCompile rewrite — that strips AGP's android.jar bootclasspath,
// which is what broke flutter_local_notifications).
//
// finalizeDsl runs after the plugin's own `android { compileOptions }`
// block and before AGP locks the DSL — afterEvaluate is too late
// (sourceCompatibility has been finalized). Kotlin 17 is set both
// eagerly (configureEach) and again inside finalizeDsl so plugins that
// nest `kotlinOptions { jvmTarget = "1.8" }` (workmanager) cannot win.
subprojects {
    val libraryProject = this
    pluginManager.withPlugin("com.android.library") {
        libraryProject.extensions
            .getByType<LibraryAndroidComponentsExtension>()
            .finalizeDsl { dsl: LibraryExtension ->
                dsl.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                libraryProject.tasks
                    .withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                    .configureEach {
                        compilerOptions {
                            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                        }
                    }
            }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
