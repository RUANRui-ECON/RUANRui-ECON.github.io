param(
  [ValidateSet('global','home','research','about','post','accessibility','all')]
  [string]$Section = 'all',
  [string]$Hugo = 'hugo',
  [switch]$MutationTest
)

$siteRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path ([IO.Path]::GetTempPath()) ("ruanrui-contracts-" + [guid]::NewGuid())
$cacheRoot = Join-Path ([IO.Path]::GetTempPath()) ("ruanrui-contract-cache-" + [guid]::NewGuid())
$resourceRoot = Join-Path $cacheRoot 'resources'
$previousResourceDir = [Environment]::GetEnvironmentVariable('HUGO_RESOURCEDIR', 'Process')

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
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $publicRoot 'page\1\index.html'))) 'obsolete root paginator output must be absent'
}

function Test-SelfHostedThemeAssets {
  $builtHtml = Get-ChildItem -LiteralPath $outputRoot -Recurse -Filter '*.html' -File
  $remoteMatches = @($builtHtml | Select-String -Pattern 'cdn\.jsdelivr\.net' -AllMatches)
  $builtMarkup = ($builtHtml | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8
  }) -join "`n"
  $requiredReferences = @(
    '/lib/fontawesome-free/css/all\.min\.css',
    '/lib/lazysizes/lazysizes\.min\.js',
    '/lib/katex/katex\.min\.css'
  )
  $missingReferences = @($requiredReferences | Where-Object { $builtMarkup -notmatch $_ })

  $publicRoot = Join-Path $siteRoot 'public'
  $requiredTrackedAssets = @(
    'lib\animate\animate.min.css',
    'lib\clipboard\clipboard.min.js',
    'lib\fontawesome-free\css\all.min.css',
    'lib\fontawesome-free\webfonts\fa-solid-900.woff2',
    'lib\katex\fonts\KaTeX_Main-Regular.woff2',
    'lib\katex\katex.min.css',
    'lib\katex\katex.min.js',
    'lib\lazysizes\lazysizes.min.js',
    'lib\sharer\sharer.min.js'
  )
  $missingTrackedAssets = @($requiredTrackedAssets | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $publicRoot $_) -PathType Leaf)
  })

  Assert-True (
    $remoteMatches.Count -eq 0 -and
    $missingReferences.Count -eq 0 -and
    $missingTrackedAssets.Count -eq 0
  ) "theme assets must be self-hosted; jsDelivr matches=$($remoteMatches.Count), missing generated references=$($missingReferences.Count), missing tracked assets=$($missingTrackedAssets.Count)"
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
  Test-SelfHostedThemeAssets
}

function Test-Home {
  $homeMarkup = Read-Built 'index.html'
  $style = Read-Built 'css/style.min.css'
  $indexTemplate = Get-Content -Raw -Encoding utf8 (Join-Path $siteRoot 'layouts\index.html')
  Assert-True ($homeMarkup -match 'class="academic-hero"') 'home must contain academic hero'
  Assert-True ($homeMarkup -match (Convert-CodePoints @(0x653F, 0x7B56, 0x4FE1, 0x53F7))) 'home must state the research pathway'
  Assert-True ($homeMarkup -match 'class="research-pathway"') 'home must contain research pathway component'
  Assert-True ($homeMarkup -match 'class="featured-research"') 'home must contain featured research section'
  $featuredMarkup = [regex]::Match($homeMarkup, '<section class="featured-research".*?</section>', 'Singleline').Value
  $disclosureSummary = Convert-CodePoints @(0x5728, 0x4E0D, 0x786E, 0x5B9A, 0x6027, 0x7684, 0x65F6, 0x4EE3, 0xFF0C, 0x6C89, 0x9ED8, 0x7684, 0x4EE3, 0x4EF7, 0x8FDC, 0x9AD8, 0x4E8E, 0x771F, 0x8BDD, 0x7684, 0x98CE, 0x9669, 0x3002, 0x5E02, 0x573A, 0x8BB0, 0x5F97, 0x8C01, 0x9009, 0x62E9, 0x4E86, 0x5766, 0x8BDA, 0xFF0C, 0x4E5F, 0x4F1A, 0x7528, 0x66F4, 0x4F4E, 0x7684, 0x878D, 0x8D44, 0x6210, 0x672C, 0x548C, 0x66F4, 0x7A33, 0x5B9A, 0x7684, 0x4F30, 0x503C, 0x6765, 0x56DE, 0x62A5, 0x900F, 0x660E, 0x5EA6, 0x3002)
  $communicationSummary = Convert-CodePoints @(0x653F, 0x7B56, 0x7684, 0x6548, 0x679C, 0xFF0C, 0x4E0D, 0x53EA, 0x53D6, 0x51B3, 0x4E8E, 0x505A, 0x4E86, 0x4EC0, 0x4E48, 0xFF0C, 0x4E5F, 0x53D6, 0x51B3, 0x4E8E, 0x5E02, 0x573A, 0x542C, 0x89C1, 0x4E86, 0x4EC0, 0x4E48, 0x3001, 0x5982, 0x4F55, 0x7406, 0x89E3, 0x3002, 0x53CA, 0x65F6, 0x3001, 0x6E05, 0x6670, 0x4E14, 0x53EF, 0x4FE1, 0x7684, 0x6C9F, 0x901A, 0xFF0C, 0x80FD, 0x591F, 0x6821, 0x51C6, 0x9884, 0x671F, 0x5E76, 0x63D0, 0x632F, 0x4FE1, 0x5FC3, 0x3002)
  $featuredResearchTitle = Convert-CodePoints @(0x4EE3, 0x8868, 0x6027, 0x7814, 0x7A76)
  $featuredResearchSubtitle = Convert-CodePoints @(0x4ECE, 0x5B66, 0x672F, 0x8BBA, 0x6587, 0x8FDB, 0x5165, 0x7814, 0x7A76, 0x73B0, 0x573A)
  Assert-True ($featuredMarkup -match ('<h2 id="featured-research-title">' + [regex]::Escape($featuredResearchTitle) + '</h2>')) 'home featured section must use the concise approved h2'
  Assert-True ($featuredMarkup -notmatch [regex]::Escape($featuredResearchSubtitle)) 'home must remove the redundant featured-research subtitle'
  Assert-True ($featuredMarkup -match [regex]::Escape($disclosureSummary)) 'home must show the disclosure summary on the English paper'
  Assert-True ($featuredMarkup -match [regex]::Escape($communicationSummary)) 'home must show the approved policy-communication summary'
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
    '/posts/%E5%AE%8F%E8%A7%82%E7%BB%8F%E6%B5%8E%E6%84%9F%E7%9F%A5%E8%B4%A7%E5%B8%81%E6%94%BF%E7%AD%96%E4%B8%8E%E5%BE%AE%E8%A7%82%E4%BC%81%E4%B8%9A%E6%8A%95%E8%9E%8D%E8%B5%84%E8%A1%8C%E4%B8%BA/'
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
  $researchMain = [regex]::Match($research, '<main.*?</main>', 'Singleline').Value
  $researchDirection = Convert-CodePoints @(0x7814, 0x7A76, 0x65B9, 0x5411)
  $featuredResearchTitle = Convert-CodePoints @(0x4EE3, 0x8868, 0x6027, 0x7814, 0x7A76)
  $browseByTopic = Convert-CodePoints @(0x6309, 0x4E3B, 0x9898, 0x6D4F, 0x89C8)
  $redundantResearchLabels = (@(
    Convert-CodePoints @(0x79D1, 0x5B66, 0x7814, 0x7A76)
    Convert-CodePoints @(0x4ECE, 0x5B66, 0x672F, 0x8BBA, 0x6587, 0x8FDB, 0x5165, 0x7814, 0x7A76, 0x73B0, 0x573A)
    Convert-CodePoints @(0x7814, 0x7A76, 0x8BAE, 0x9898)
  ) -join '|')
  Assert-True ($researchMain -match ('<h1>' + $researchDirection + '</h1>')) 'research page must promote research direction to h1'
  Assert-True ($researchMain -match ('<h2 id="research-featured-title">' + $featuredResearchTitle + '</h2>')) 'research page must use representative research as the featured h2'
  Assert-True ($researchMain -match ('<h2 id="research-topic-title">' + $browseByTopic + '</h2>')) 'research page must use browse by topic as the taxonomy h2'
  Assert-True ($researchMain -notmatch $redundantResearchLabels) 'research main must remove the three redundant labels'

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
  $style = Read-Built 'css\style.min.css'
  Assert-True ($about -match 'class="about-layout"') 'about page must use custom layout'
  Assert-True ($about -match 'class="about-toc"') 'about page must expose section navigation'
  $main = [regex]::Match($about, '<main.*?</main>', 'Singleline').Value
  $h1Count = [regex]::Matches($main, '<h1\b').Count
  Assert-True ($h1Count -eq 1) "about main must contain exactly one h1; got $h1Count"
  Assert-True ($main -match 'id="about-table-of-contents"') 'about custom toc must use a page-specific id'
  Assert-True ($main -notmatch 'id="TableOfContents"') 'about custom toc must not trigger the theme single-page toc initializer'
  $updatedLabel = Convert-CodePoints @(0x66F4, 0x65B0, 0x65F6, 0x95F4)
  Assert-True ($main -match ('<h3 id="' + $updatedLabel + '">' + $updatedLabel + '</h3>')) 'about update time must be an h3'
  Assert-True ($main -notmatch ('<h4 id="' + $updatedLabel + '">' + $updatedLabel + '</h4>')) 'about update time must not be an h4'
  Assert-True ($style -match '\.page\.single \.about-content>h2>\.header-mark:{1,2}before\{content:none\s*!important;margin-right:0\}') 'about h2 anchor marker override must defeat theme decoration'

  $post = Read-Built 'posts/new-event-and-old-antidote/index.html'
  Assert-True ($post -match 'class="page single academic-article') 'posts must use academic reading layout'
}

function Test-PostHeadings {
  $postDirectory = Get-ChildItem -LiteralPath (Join-Path $outputRoot 'posts') -Directory |
    Where-Object { $_.Name -like '*-ai-*' } |
    Select-Object -First 1
  Assert-True ($null -ne $postDirectory) 'heading contract fixture post must be generated'
  $post = Get-Content -Raw -Encoding utf8 (Join-Path $postDirectory.FullName 'index.html')
  $style = Read-Built 'css\style.min.css'
  $toc = [regex]::Match($post, '<nav id="TableOfContents">.*?</nav>', 'Singleline').Value

  Assert-True ($toc -match 'href="#[^"]*attention-is-all-you-need"') 'post toc must include level-one content headings'
  Assert-True ($toc -match 'href="#1-ai-[^"]+"') 'post toc must retain nested level-two headings'
  Assert-True ($style -match '\.page\.single\.academic-article \.content>h2>\.header-mark:{1,2}before\{content:none\s*!important;margin-right:0\}') 'post h2 anchor marker override must defeat theme decoration'
}

$exitCode = 0
try {
  $env:HUGO_RESOURCEDIR = $resourceRoot
  & $Hugo --source $siteRoot --destination $outputRoot --cacheDir $cacheRoot --noBuildLock --quiet
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
  elseif ($Section -eq 'post') {
    Test-PostHeadings
    Write-Output 'PASS: post'
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
    Test-PostHeadings
    Write-Output 'PASS: post'
  }
}
catch {
  Write-Error $_
  $exitCode = 1
}
finally {
  if ($null -eq $previousResourceDir) {
    Remove-Item Env:HUGO_RESOURCEDIR -ErrorAction SilentlyContinue
  }
  else {
    $env:HUGO_RESOURCEDIR = $previousResourceDir
  }
  $separator = [IO.Path]::DirectorySeparatorChar
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd($separator)
  foreach ($generatedRoot in @($outputRoot, $cacheRoot)) {
    $resolved = [IO.Path]::GetFullPath($generatedRoot)
    if ($resolved.StartsWith($tempRoot + $separator, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $resolved)) {
      Remove-Item -LiteralPath $resolved -Recurse -Force
    }
  }
}

exit $exitCode
