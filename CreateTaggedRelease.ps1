param(
    [Parameter(Mandatory = $true)]
    [string]$CommitHash,

    [Parameter(Mandatory = $true)]
    [string]$TagName,

    [Parameter(Mandatory = $true)]
    [string]$TagMessage
)

function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

# 0) Check that git is installed
if (-not (Test-CommandExists -CommandName "git")) {
    Write-Error "git is not installed or not on PATH."
    exit 1
}

# 1) Check that gh is installed
if (-not (Test-CommandExists -CommandName "gh")) {
    Write-Error "GitHub CLI (gh) is not installed or not on PATH."
    exit 1
}

# 2) Check gh authentication status
gh auth status > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not authenticated. Run 'gh auth login' first."
    exit 1
}

# 3) Get the commit's author date in RFC 2822 format
$commitDate = git show -s --format=%aD $CommitHash

if (-not $commitDate) {
    Write-Error "Could not get date for commit $CommitHash."
    exit 1
}

# 4) Set GIT_COMMITTER_DATE for this PowerShell process
$env:GIT_COMMITTER_DATE = $commitDate

# 5) Create annotated tag using that date and message
git tag -a $TagName $CommitHash -m $TagMessage

if ($LASTEXITCODE -ne 0) {
    Write-Error "git tag failed."
    exit $LASTEXITCODE
}

# 6) Push the tag to origin
git push origin $TagName

if ($LASTEXITCODE -ne 0) {
    Write-Error "git push origin $TagName failed."
    exit $LASTEXITCODE
}

# 7) Create GitHub Release from that tag, using the tag annotation as notes
gh release create $TagName --notes-from-tag

if ($LASTEXITCODE -ne 0) {
    Write-Error "gh release create failed."
    exit $LASTEXITCODE
}

Write-Host "Tag '$TagName' and GitHub release created successfully."