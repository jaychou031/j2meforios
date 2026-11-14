# Run manually in your normal PowerShell session if Codex cannot reach GitHub.
# Uses your Git login; prompts for missing author identity only in this checkout.
# Never changes global configuration.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$checkout = Join-Path $projectRoot ('build/publish-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$repository = 'https://github.com/jaychou031/j2meforios.git'
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Git failed (exit $LASTEXITCODE). Stop here; no force push is performed." }
}
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'build/tmp') -Force | Out-Null
$audioLock = Get-Content -LiteralPath (Join-Path $projectRoot 'audio-dependencies.lock.json') -Raw | ConvertFrom-Json
$audioFiles = @($audioLock.files.PSObject.Properties.Name)
foreach ($file in $audioFiles) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $projectRoot $file) -Algorithm SHA256).Hash
    if ($actual -ne $audioLock.files.$file) { throw "Local audio dependency checksum mismatch: $file" }
}
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $env:TEMP = Join-Path $projectRoot 'build/tmp'
    $env:TMP = $env:TEMP
    Invoke-Git clone $repository $checkout
    $name = & git -C $checkout config user.name
    $email = & git -C $checkout config user.email
    if (!$name) {
        $name = Read-Host 'Commit author name (your GitHub username is OK)'
        if ([string]::IsNullOrWhiteSpace($name)) { throw 'Commit author name cannot be empty.' }
        Invoke-Git -C $checkout config --local user.name $name
    }
    if (!$email) {
        $email = Read-Host 'Commit author email (your GitHub email or GitHub no-reply email)'
        if ([string]::IsNullOrWhiteSpace($email)) { throw 'Commit author email cannot be empty.' }
        Invoke-Git -C $checkout config --local user.email $email
    }
    foreach ($item in @('.github', '.gitattributes', '.gitignore', 'CMakeLists.txt', 'upstream.lock.json', 'audio-dependencies.lock.json', 'README.md', 'FEASIBILITY.md', 'STATUS.md', 'ios', 'scripts', 'tests', 'cmake', 'third_party')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $item) -Destination $checkout -Recurse -Force
    }
    Invoke-Git -C $checkout add .github .gitattributes .gitignore CMakeLists.txt upstream.lock.json audio-dependencies.lock.json README.md FEASIBILITY.md STATUS.md ios scripts tests cmake third_party
    # Re-stage previously tracked dependencies under the new attributes, even
    # when a checkout's CRLF bytes appear unchanged from the old working tree.
    Invoke-Git -C $checkout add --renormalize -- @audioFiles
    foreach ($file in $audioFiles) {
        $expectedBlob = Invoke-Git -C $checkout hash-object --no-filters -- (Join-Path $projectRoot $file)
        $stagedBlob = Invoke-Git -C $checkout rev-parse ":$file"
        if ($expectedBlob -ne $stagedBlob) { throw "Git altered staged audio dependency bytes: $file" }
    }
    & git -C $checkout diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { Write-Host 'The repository already contains these files.'; return }
    if ($LASTEXITCODE -ne 1) { throw 'Unable to inspect staged changes.' }
    Invoke-Git -C $checkout commit -m 'Update iOS port and unsigned IPA build workflow'
    Invoke-Git -C $checkout push origin HEAD:main
    Write-Host 'Uploaded. Open GitHub Actions > Build iOS IPA to follow the build.'
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
}
