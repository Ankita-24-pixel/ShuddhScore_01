param([string]$Device = 'emulator-5554')

$ErrorActionPreference = 'Stop'
$familyAppRoot = Split-Path -Parent $PSScriptRoot
$familyWorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $familyAppRoot '..\..')).Path
$familyJavaTemp = Join-Path $familyWorkspaceRoot 'build\java-tmp'
New-Item -ItemType Directory -Force -Path $familyJavaTemp | Out-Null

$previousFamilyJavaOptions = $env:JAVA_TOOL_OPTIONS
$previousFamilyGradleOptions = $env:GRADLE_OPTS
$familyRunExitCode = 1
Push-Location -LiteralPath $familyAppRoot
try {
    # Short Windows socket path and bounded workers avoid local build failures.
    $env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir="' + $familyJavaTemp + '" -XX:ActiveProcessorCount=2'
    $env:GRADLE_OPTS = '-Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false -Dorg.gradle.jvmargs="-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ActiveProcessorCount=2"'
    $familyFlutterArguments = @('run', '-d', $Device, '-t', 'lib/entrypoints/android/main_google_play.dart', '--no-pub')
    if (Test-Path -LiteralPath 'config\groq.local.json') {
        $familyFlutterArguments += '--dart-define-from-file=config/groq.local.json'
        Write-Host 'Loading local Groq configuration (key hidden).'
    }
    & flutter @familyFlutterArguments
    $familyRunExitCode = $LASTEXITCODE
} finally {
    $env:JAVA_TOOL_OPTIONS = $previousFamilyJavaOptions
    $env:GRADLE_OPTS = $previousFamilyGradleOptions
    Pop-Location
}
exit $familyRunExitCode
