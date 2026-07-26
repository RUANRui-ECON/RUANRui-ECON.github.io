param(
  [ValidateSet('global','home','research','about','accessibility','all')]
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
    @{ Nav = 'research'; Label = Convert-CodePoints @(0x7814, 0x7A76) },
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
    '<a data-nav="research">' + (Convert-CodePoints @(0x7814, 0x7A76)) + '</a>',
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

function Test-PublicOutputHygiene {
  $publicRoot = Join-Path $siteRoot 'public'
  Assert-True (Test-Path -LiteralPath $publicRoot) 'tracked public output must exist'

  $publicHtml = Get-ChildItem -LiteralPath $publicRoot -Recurse -Filter '*.html' -File
  $staleMatches = @($publicHtml | Select-String -Pattern 'livereload\.js|localhost:1313|This is my cool site' -AllMatches)
  Assert-True ($staleMatches.Count -eq 0) "tracked public HTML must not contain development or placeholder output; got $($staleMatches.Count) matches"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot 'lib'))) 'obsolete tracked public/lib must be absent'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot 'page\1\index.html'))) 'obsolete root paginator output must be absent'
}

function Test-MobileMenuAccessibility {
  $homePage = Read-Built 'index.html'
  $style = Read-Built 'css/style.min.css'
  $mobileHeader = [regex]::Match($homePage, '<header class="mobile".*?</header>', 'Singleline').Value
  $openMenuLabel = Convert-CodePoints @(0x6253, 0x5F00, 0x5BFC, 0x822A, 0x83DC, 0x5355)
  $expectedToggle = '<button type="button" class="menu-toggle" id="menu-toggle-mobile" aria-label="' + $openMenuLabel + '" aria-controls="menu-mobile" aria-expanded="false">'

  Assert-True ($mobileHeader -match [regex]::Escape($expectedToggle)) 'mobile menu toggle must be a native button with exact accessible markup'
  Assert-True ($mobileHeader -notmatch '<div class="menu-toggle"') 'mobile menu toggle must not be a non-interactive div'
  Assert-True ($homePage -match '<script id="mobile-menu-state-sync">' -and $homePage -match 'MutationObserver' -and $homePage -match 'aria-expanded') 'mobile menu must synchronize aria-expanded with theme-controlled active state'
  Assert-True ($homePage -match "addEventListener\('keydown'" -and $homePage -match "event\.key === 'Enter'" -and $homePage -match "event\.key === ' '" -and $homePage -match 'event\.preventDefault\(\)' -and $homePage -match 'toggle\.click\(\)') 'mobile menu must explicitly handle Enter and Space exactly through a prevented fallback click'
  $toggleRule = [regex]::Match($style, '#menu-toggle-mobile\{[^}]*\}').Value
  Assert-True ($toggleRule -match 'min-width:44px' -and $toggleRule -match 'min-height:44px') 'mobile menu toggle must compile to a minimum 44 by 44 pixel interactive target'
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
  Test-MobileMenuAccessibility
  Test-PublicOutputHygiene
}

function Test-Home {
  $homeMarkup = Read-Built 'index.html'
  $style = Read-Built 'css/style.min.css'
  $indexTemplate = Get-Content -Raw -Encoding utf8 (Join-Path $siteRoot 'layouts\index.html')
  Assert-True ($homeMarkup -match 'class="academic-hero"') 'home must contain academic hero'
  Assert-True ($homeMarkup -match (Convert-CodePoints @(0x653F, 0x7B56, 0x4FE1, 0x53F7))) 'home must state the research pathway'
  Assert-True ($homeMarkup -match 'class="research-pathway"') 'home must contain research pathway component'
  Assert-True ($homeMarkup -match 'class="featured-research"') 'home must contain featured research section'
  $cards = [regex]::Matches($homeMarkup, '<article\s+class="paper-card"(?:\s|>)').Count
  Assert-True ($cards -eq 4) "home must show exactly four explicitly featured papers; got $cards"
  Assert-True ($homeMarkup -notmatch 'data-home="posts"') 'home must not render the full chronological post stream'

  $heroActions = [regex]::Match($homeMarkup, '<div class="hero-actions".*?</div>', 'Singleline').Value
  $cvLabel = Convert-CodePoints @(0x5B66, 0x672F, 0x7B80, 0x5386)
  $researchLabel = Convert-CodePoints @(0x7814, 0x7A76, 0x6210, 0x679C)
  $emailLabel = Convert-CodePoints @(0x90AE, 0x4EF6, 0x8054, 0x7CFB)
  Assert-True ($heroActions -match ('<a href="/about/">' + $cvLabel + '</a>')) 'hero must link to CV with exact approved label'
  Assert-True ($heroActions -match ('<a href="/research_topics/">' + $researchLabel + '</a>')) 'hero must link to research with exact approved label'
  Assert-True ($heroActions -match ('<a href="mailto:ruanrui@cufe\.edu\.cn">' + $emailLabel + '</a>')) 'hero must link to email with exact approved label'

  $explore = [regex]::Match($homeMarkup, '<section class="home-explore".*?</section>', 'Singleline').Value
  $allResearchLabel = Convert-CodePoints @(0x67E5, 0x770B, 0x5168, 0x90E8, 0x7814, 0x7A76)
  $teachingLabel = Convert-CodePoints @(0x6559, 0x5B66)
  $mediaLabel = Convert-CodePoints @(0x5A92, 0x4F53)
  Assert-True ([regex]::IsMatch($explore, ('href="/research_topics/"[^>]*>.*?' + $allResearchLabel), 'IgnoreCase, Singleline')) 'home exploration must link to all research'
  Assert-True ([regex]::IsMatch($explore, ('href="/courses/"[^>]*>.*?' + $teachingLabel), 'IgnoreCase, Singleline')) 'home exploration must link to teaching'
  Assert-True ([regex]::IsMatch($explore, ('href="/categories/%E5%AA%92%E4%BD%93/"[^>]*>.*?' + $mediaLabel), 'IgnoreCase, Singleline')) 'home exploration must link to media'
  Assert-True ([regex]::IsMatch($indexTemplate, '\{\{- with \$featured -\}\}.*?</section>\s*\{\{- end -\}\}\s*\{\{- partial "home/explore\.html" \. -\}\}', 'Singleline')) 'home exploration partial must remain outside the featured conditional'

  # A replaced image keeps its intrinsic height unless both the wrapper and image
  # participate in the crop. This guards the first viewport against a tall portrait.
  $portraitRule = [regex]::Match($style, '\.academic-hero-portrait\{[^}]*\}').Value
  $portraitImageRule = [regex]::Match($style, '\.academic-hero-portrait img\{[^}]*\}').Value
  $campusPhotoRule = [regex]::Match($style, '\.home-campus-photo\{[^}]*\}').Value
  Assert-True ($portraitRule -match 'aspect-ratio:4 / 5') 'home portrait wrapper must enforce a 4:5 crop'
  Assert-True ($portraitImageRule -match 'height:100%\s*!important' -and $portraitImageRule -match 'object-fit:cover') 'home portrait image must fill the constrained crop height'
  Assert-True ($campusPhotoRule -match 'max-width:100%') 'home campus photo must size against its content container to prevent mobile overflow'
}

function Test-Research {
  $research = Read-Built 'research_topics/index.html'
  $longAbstractPrefix = Convert-CodePoints @(0x957F, 0x6458, 0x8981, 0x2D)
  $expectedFeaturedLinks = @(
    '/posts/new-event-and-old-antidote/',
    '/posts/%E5%AE%8F%E8%A7%82%E7%BB%8F%E6%B5%8E%E6%94%BF%E7%AD%96%E6%B2%9F%E9%80%9A%E4%B8%8E%E9%A2%84%E6%9C%9F%E7%AE%A1%E7%90%86%E6%9D%A5%E8%87%AA%E6%96%B0%E9%97%BB%E5%8F%91%E5%B8%83%E4%BC%9A%E7%9A%84%E8%AF%81%E6%8D%AE/',
    '/posts/%E5%AE%89%E5%85%A8%E4%B8%8E%E6%95%88%E7%9B%8A%E5%8F%AF%E4%BB%A5%E5%85%BC%E5%BE%97/',
    '/posts/%E4%B8%8A%E6%B8%B8%E5%9E%84%E6%96%AD%E4%B8%8E%E5%B8%82%E5%9C%BA%E5%8C%96%E6%94%B9%E9%9D%A9%E7%9A%84%E4%BE%9B%E7%BB%99%E6%82%96%E8%AE%BA/'
  )
  $expectedTopicLinks = @(
    '/research_topics/%E4%B8%8D%E7%A1%AE%E5%AE%9A%E6%80%A7/',
    '/research_topics/%E7%BB%84%E7%BB%87%E7%BB%8F%E6%B5%8E%E5%AD%A6/',
    '/research_topics/%E4%BF%A1%E6%81%AF%E6%8A%AB%E9%9C%B2/',
    '/research_topics/%E5%9B%BD%E6%9C%89%E4%BC%81%E4%B8%9A/',
    '/research_topics/%E5%AE%8F%E8%A7%82%E7%BB%8F%E6%B5%8E%E6%84%9F%E7%9F%A5/',
    '/research_topics/%E6%94%BF%E5%BA%9C%E5%80%BA%E5%8A%A1/',
    '/research_topics/%E6%94%BF%E7%AD%96%E6%B2%9F%E9%80%9A/',
    '/research_topics/%E8%B4%A2%E6%94%BF%E4%BD%93%E5%88%B6/'
  )

  Assert-True ($research -match 'class="research-intro"') 'research page must contain overview'
  Assert-True ($research -match 'class="research-featured"') 'research page must contain explicit featured papers'
  Assert-True ($research -match 'class="research-topic-grid"') 'research page must retain topic browsing'
  Assert-True ($research -notmatch ('>' + [regex]::Escape($longAbstractPrefix))) 'research display titles must remove the long-abstract prefix'

  $featuredMarkup = [regex]::Match($research, '<section class="research-featured".*?</section>', 'Singleline').Value
  $featuredCards = [regex]::Matches($featuredMarkup, '<article\s+class="paper-card"(?:\s|>).*?</article>', 'Singleline')
  Assert-True ($featuredCards.Count -eq 4) "research page must render exactly four featured paper cards; got $($featuredCards.Count)"
  $featuredLinks = @($featuredCards | ForEach-Object {
    [regex]::Match($_.Value, '<h3><a href="([^"]+)"').Groups[1].Value
  })
  Assert-True (($featuredLinks -join '|') -eq ($expectedFeaturedLinks -join '|')) 'research featured cards must use the approved paper URLs in featuredWeight order'

  $topicGrid = [regex]::Match($research, '<div class="research-topic-grid">.*?</div>\s*</section>', 'Singleline').Value
  $topicCards = [regex]::Matches($topicGrid, '<article class="research-topic-card".*?</article>', 'Singleline')
  Assert-True ($topicCards.Count -eq 8) "research page must render exactly eight topic cards; got $($topicCards.Count)"
  $topicLinks = @($topicCards | ForEach-Object {
    [regex]::Match($_.Value, '<h3>\s*<a href="([^"]+)"', 'Singleline').Groups[1].Value
  })
  foreach ($expectedTopicLink in $expectedTopicLinks) {
    Assert-True ($topicLinks -contains $expectedTopicLink) "research topic grid must link to $expectedTopicLink"
  }
}

function Test-About {
  $about = Read-Built 'about/index.html'
  Assert-True ($about -match 'class="about-layout"') 'about page must use custom layout'
  Assert-True ($about -match 'class="about-toc"') 'about page must expose section navigation'
  $main = [regex]::Match($about, '<main.*?</main>', 'Singleline').Value
  $h1Count = [regex]::Matches($main, '<h1\b').Count
  Assert-True ($h1Count -eq 1) "about main must contain exactly one h1; got $h1Count"
  Assert-True ($main -match 'id="about-table-of-contents"') 'about custom toc must use a page-specific id'
  Assert-True ($main -notmatch 'id="TableOfContents"') 'about custom toc must not trigger the theme single-page toc initializer'

  $post = Read-Built 'posts/new-event-and-old-antidote/index.html'
  Assert-True ($post -match 'class="page single academic-article') 'posts must use academic reading layout'
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
  elseif ($Section -eq 'about') {
    Test-About
    Write-Output 'PASS: about'
  }
  elseif ($Section -eq 'accessibility') {
    Test-MobileMenuAccessibility
    Write-Output 'PASS: accessibility'
  }
  elseif ($Section -eq 'all') {
    Test-Global
    Write-Output 'PASS: global'
    Test-Home
    Write-Output 'PASS: home'
    Test-Research
    Write-Output 'PASS: research'
    Test-About
    Write-Output 'PASS: about'
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
