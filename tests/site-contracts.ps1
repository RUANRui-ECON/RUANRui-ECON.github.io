param(
  [ValidateSet('global','home','research','about','all')]
  [string]$Section = 'all',
  [string]$Hugo = 'hugo',
  [switch]$MutationTest
)

$siteRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path ([IO.Path]::GetTempPath()) ("ruanrui-contracts-" + [guid]::NewGuid())

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "CONTRACT FAILED: $Message" }
}

function Read-Built([string]$RelativePath) {
  Get-Content -Raw -Encoding utf8 (Join-Path $outputRoot $RelativePath)
}

function Convert-CodePoints([int[]]$CodePoints) {
  -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Assert-PrimaryNavigation([string]$Markup, [string]$Location) {
  $expectedLinks = @(
    @{ Nav = 'about'; Label = Convert-CodePoints @(0x7B80, 0x5386) },
    @{ Nav = 'research'; Label = Convert-CodePoints @(0x79D1, 0x5B66, 0x7814, 0x7A76) },
    @{ Nav = 'teaching'; Label = Convert-CodePoints @(0x6559, 0x5B66) },
    @{ Nav = 'media'; Label = Convert-CodePoints @(0x5A92, 0x4F53) }
  )
  # Header menu entries carry data-nav; the theme toggle and search controls do not.
  $primaryLinks = [regex]::Matches($Markup, '<a[^>]*data-nav="[^"]+"[^>]*>.*?</a>', 'Singleline')

  Assert-True ($primaryLinks.Count -eq 4) "$Location navigation must contain exactly four primary links"
  foreach ($expected in $expectedLinks) {
    $pattern = '<a[^>]*data-nav="' + $expected.Nav + '"[^>]*>\s*' + [regex]::Escape($expected.Label) + '\s*</a>'
    Assert-True ($Markup -match $pattern) "$Location navigation must expose the $($expected.Nav) label"
  }
}

function Test-PrimaryNavigationMutation {
  $fixture = @(
    '<a data-nav="about">' + (Convert-CodePoints @(0x7B80, 0x5386)) + '</a>',
    '<a data-nav="research">' + (Convert-CodePoints @(0x79D1, 0x5B66, 0x7814, 0x7A76)) + '</a>',
    '<a data-nav="teaching">' + (Convert-CodePoints @(0x6559, 0x5B66)) + '</a>',
    '<a data-nav="media">' + (Convert-CodePoints @(0x5A92, 0x4F53)) + '</a>',
    '<a data-nav="unexpected">Extra</a>'
  ) -join ''
  $rejected = $false

  try {
    Assert-PrimaryNavigation $fixture 'mutation fixture'
  }
  catch {
    $rejected = $true
  }

  Assert-True $rejected 'primary navigation contract must reject a fifth menu link'
}

function Test-Global {
  $homePage = Read-Built 'index.html'
  $desktopHeader = [regex]::Match($homePage, '<header class="desktop".*?</header>', 'Singleline').Value
  $mobileHeader = [regex]::Match($homePage, '<header class="mobile".*?</header>', 'Singleline').Value
  $footer = [regex]::Match($homePage, '<footer class="footer".*?</footer>', 'Singleline').Value
  $footerNav = [regex]::Match($footer, '<nav class="footer-secondary-nav".*?</nav>', 'Singleline').Value

  Assert-True ($homePage -match '<html lang="zh-cn">') 'default site language must be zh-cn'
  Assert-PrimaryNavigation $desktopHeader 'desktop'
  Assert-PrimaryNavigation $mobileHeader 'mobile'
  Assert-True ($desktopHeader -notmatch 'data-nav="tags"|data-nav="categories"') 'desktop header must not include taxonomy links'
  Assert-True ($mobileHeader -notmatch 'data-nav="tags"|data-nav="categories"') 'mobile header must not include taxonomy links'
  Assert-True ($homePage -notmatch 'This is my cool site|My cool site') 'theme placeholder metadata must be removed'
  Assert-True ($footerNav -match 'href="/tags/"') 'footer secondary navigation must link to tags'
  Assert-True ($footerNav -match 'href="/categories/"') 'footer secondary navigation must link to categories'
}

function Test-Home {
  $homeMarkup = Read-Built 'index.html'
  Assert-True ($homeMarkup -match 'class="academic-hero"') 'home must contain academic hero'
  Assert-True ($homeMarkup -match (Convert-CodePoints @(0x653F, 0x7B56, 0x4FE1, 0x53F7))) 'home must state the research pathway'
  Assert-True ($homeMarkup -match 'class="research-pathway"') 'home must contain research pathway component'
  Assert-True ($homeMarkup -match 'class="featured-research"') 'home must contain featured research section'
  $cards = [regex]::Matches($homeMarkup, '<article\s+class="paper-card"(?:\s|>)').Count
  Assert-True ($cards -eq 4) "home must show exactly four explicitly featured papers; got $cards"
  Assert-True ($homeMarkup -notmatch 'data-home="posts"') 'home must not render the full chronological post stream'
}

function Test-Research {
  $research = Read-Built 'research_topics/index.html'
  $longAbstractPrefix = Convert-CodePoints @(0x957F, 0x6458, 0x8981, 0x2D)

  Assert-True ($research -match 'class="research-intro"') 'research page must contain overview'
  Assert-True ($research -match 'class="research-featured"') 'research page must contain explicit featured papers'
  Assert-True ($research -match 'class="research-topic-grid"') 'research page must retain topic browsing'
  Assert-True ($research -notmatch ('>' + [regex]::Escape($longAbstractPrefix))) 'research display titles must remove the long-abstract prefix'
  $cards = [regex]::Matches($research, '<article\s+class="paper-card"(?:\s|>)').Count
  Assert-True ($cards -eq 4) "research page must render the four featured paper cards; got $cards"
}

$exitCode = 0
try {
  & $Hugo --source $siteRoot --destination $outputRoot --noBuildLock --quiet
  if ($LASTEXITCODE -ne 0) { throw "Hugo build failed with exit code $LASTEXITCODE" }
  if ($MutationTest) {
    Test-PrimaryNavigationMutation
    Write-Output 'PASS: mutation'
  }
  elseif ($Section -eq 'global') {
    Test-Global
    Write-Output 'PASS: global'
  }
  elseif ($Section -eq 'home') {
    Test-Home
    Write-Output 'PASS: home'
  }
  elseif ($Section -eq 'research') {
    Test-Research
    Write-Output 'PASS: research'
  }
  elseif ($Section -eq 'all') {
    Test-Global
    Write-Output 'PASS: global'
    Test-Home
    Write-Output 'PASS: home'
    Test-Research
    Write-Output 'PASS: research'
  }
}
catch {
  Write-Error $_
  $exitCode = 1
}
finally {
  $separator = [IO.Path]::DirectorySeparatorChar
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd($separator)
  $resolved = [IO.Path]::GetFullPath($outputRoot)
  if ($resolved.StartsWith($tempRoot + $separator, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $resolved)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}

exit $exitCode
