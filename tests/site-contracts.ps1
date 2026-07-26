param(
  [ValidateSet('global','home','research','about','all')]
  [string]$Section = 'all',
  [string]$Hugo = 'hugo'
)

$siteRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path ([IO.Path]::GetTempPath()) ("ruanrui-contracts-" + [guid]::NewGuid())

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "CONTRACT FAILED: $Message" }
}

function Read-Built([string]$RelativePath) {
  Get-Content -Raw -Encoding utf8 (Join-Path $outputRoot $RelativePath)
}

function Test-Global {
  $homePage = Read-Built 'index.html'
  $header = [regex]::Match($homePage, '<header class="desktop".*?</header>', 'Singleline').Value
  Assert-True ($homePage -match '<html lang="zh-cn">') 'default site language must be zh-cn'
  Assert-True ($header -match 'data-nav="about"') 'desktop header must include the about link'
  Assert-True ($header -match 'data-nav="research"') 'desktop header must include the research link'
  Assert-True ($header -match 'data-nav="teaching"') 'desktop header must include the teaching link'
  Assert-True ($header -match 'data-nav="media"') 'desktop header must include the media link'
  Assert-True ($header -notmatch 'data-nav="tags"') 'desktop header must not include the tags link'
  Assert-True ($header -notmatch 'data-nav="categories"') 'desktop header must not include the categories link'
  Assert-True ($homePage -notmatch 'This is my cool site|My cool site') 'theme placeholder metadata must be removed'
  Assert-True ($homePage -match 'footer-secondary-nav') 'footer must expose secondary navigation'
}

try {
  & $Hugo --source $siteRoot --destination $outputRoot --noBuildLock --quiet
  if ($LASTEXITCODE -ne 0) { throw "Hugo build failed with exit code $LASTEXITCODE" }
  if ($Section -in @('global','all')) { Test-Global }
  Write-Output "PASS: $Section"
}
finally {
  $separator = [IO.Path]::DirectorySeparatorChar
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd($separator)
  $resolved = [IO.Path]::GetFullPath($outputRoot)
  if ($resolved.StartsWith($tempRoot + $separator, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $resolved)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
