# Academic Site Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 Hugo 学术网站改造成“研究叙事型”个人主页，并保持全部学术内容、部署方式与现有简历更新不变。

**Architecture:** 保留 Hugo 0.128.0 Extended 与 LoveIt 主题，以项目根目录的布局覆盖和 `_custom.scss` 建立视觉系统。首页、科研和简历使用职责单一的自定义模板，论文数据继续来自 Markdown front matter；代表成果只读取显式标记，不做日期回退或自动补位。

**Tech Stack:** Hugo 0.128.0 Extended、Go Templates、Markdown、SCSS、PowerShell 合同测试、Codex 内置浏览器视觉验证。

## Global Constraints

- 不修改 `themes/LoveIt/` 内的任何文件。
- 不重写论文、简历、项目或教学材料的实质内容。
- 不加载境外在线字体，不增加大型前端依赖。
- 代表成果只显示显式标记的阮睿本人论文；少于四篇时不补位。
- 保留浅色、深色模式与现有 GitHub Pages 部署方式。
- 390 像素宽度下不得出现持续横向页面滚动。
- 保留 `content/about/index.md` 中已有的未提交项目更新。
- `public/` 是 Hugo 生成结果；源文件验证通过后再统一生成，避免逐任务手工编辑。

---

## File Map

- Create `tests/site-contracts.ps1`: 构建临时站点并验证导航、首页、科研和简历的 HTML 合同。
- Modify `config.toml`: 补充中文语言、描述、短站点名与精简导航。
- Modify `assets/css/_custom.scss`: 全站颜色、字体、布局、响应式、焦点与减少动态效果规则。
- Modify `layouts/partials/header.html`: 为导航提供更明确的无障碍名称和视觉类名。
- Modify `layouts/partials/footer.html`: 增加标签、分类等次级导航。
- Create `layouts/partials/home/academic-hero.html`: 首页身份首屏。
- Create `layouts/partials/home/research-pathway.html`: 首页研究主线。
- Create `layouts/partials/research/paper-card.html`: 首页与科研页复用的论文条目。
- Modify `layouts/index.html`: 组装首页首屏、研究主线、代表成果、教学媒体入口与校园信息。
- Modify `content/_index.md`: 保留联系方式与校园照片，移除会与首页结构重复的内联布局。
- Modify four `content/posts/*/index.md`: 只新增 `featured` 与 `featuredWeight` 元数据。
- Modify `layouts/research_topics/terms.html`: 代表成果与研究主题的双层结构。
- Create `layouts/about/single.html`: 简历专用布局与目录。
- Modify `content/about/index.md`: 只调整 Markdown 标题层级，保留全部文字和现有新增项目。
- Modify `layouts/posts/single.html`: 添加文章布局类名，保留内容渲染与资源逻辑。
- Create `static/og.png`: 与最终站点一致的社交预览图，仅在生成文字准确时采用。

---

### Task 1: Add a Build Contract and Global Visual Shell

**Files:**
- Create: `tests/site-contracts.ps1`
- Modify: `config.toml`
- Modify: `assets/css/_custom.scss`
- Modify: `layouts/partials/header.html`
- Modify: `layouts/partials/footer.html`

**Interfaces:**
- Consumes: Hugo 可执行文件路径与仓库根目录。
- Produces: `tests/site-contracts.ps1 -Section global`；全站 CSS 变量；顶部四项主导航；页脚次级导航。

- [ ] **Step 1: Write the failing global contract test**

Create `tests/site-contracts.ps1` with a temporary Hugo build and a `global` section:

```powershell
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
  $home = Read-Built 'index.html'
  $header = [regex]::Match($home, '<header class="desktop".*?</header>', 'Singleline').Value
  Assert-True ($home -match '<html lang="zh-cn">') 'default site language must be zh-cn'
  Assert-True ($header -match '>\s*简历\s*<') 'desktop header must include 简历'
  Assert-True ($header -match '>\s*科学研究\s*<') 'desktop header must include 科学研究'
  Assert-True ($header -match '>\s*教学\s*<') 'desktop header must include 教学'
  Assert-True ($header -match '>\s*媒体\s*<') 'desktop header must include 媒体'
  Assert-True ($header -notmatch '>\s*标签\s*<') 'desktop header must not include 标签'
  Assert-True ($header -notmatch '>\s*分类\s*<') 'desktop header must not include 分类'
  Assert-True ($home -notmatch 'This is my cool site|My cool site') 'theme placeholder metadata must be removed'
  Assert-True ($home -match 'footer-secondary-nav') 'footer must expose secondary navigation'
}

try {
  & $Hugo --source $siteRoot --destination $outputRoot --noBuildLock --quiet
  if ($LASTEXITCODE -ne 0) { throw "Hugo build failed with exit code $LASTEXITCODE" }
  if ($Section -in @('global','all')) { Test-Global }
  Write-Output "PASS: $Section"
}
finally {
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  $resolved = [IO.Path]::GetFullPath($outputRoot)
  if ($resolved.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $resolved)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
```

- [ ] **Step 2: Run the global contract and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tests/site-contracts.ps1 -Section global -Hugo "$env:LOCALAPPDATA\Programs\Hugo\hugo.exe"
```

Expected: FAIL because the header still contains 标签/分类, the language is not `zh-cn`, and placeholder metadata remains.

- [ ] **Step 3: Implement the global configuration and shell**

Update `config.toml` with:

```toml
defaultContentLanguage = "zh-cn"

[params]
  description = "阮睿，中央财经大学长聘副教授、博士生导师，研究宏观政策沟通、企业预期、财政治理与政府企业行为。"

  [params.header.title]
    name = "阮睿"

  [params.app]
    title = "阮睿"
```

Keep only four `menu.main` entries: 简历、科学研究、教学、媒体. Add footer links for `/tags/` and `/categories/` in `layouts/partials/footer.html` using a `.footer-secondary-nav` container.

Extend `assets/css/_custom.scss` without deleting the existing responsive image/table fixes:

```scss
:root {
  --rr-navy: #17324d;
  --rr-red: #9e3b33;
  --rr-paper: #f4f7f9;
  --rr-ink: #1c252c;
  --rr-muted: #687681;
  --rr-line: #d8e0e6;
  --rr-serif: "Songti SC", "STSong", "Noto Serif CJK SC", SimSun, serif;
  --rr-sans: system-ui, -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
}

[theme="dark"] {
  --rr-navy: #a9c7e2;
  --rr-red: #e08c82;
  --rr-paper: #151b20;
  --rr-ink: #eef3f6;
  --rr-muted: #aab7c1;
  --rr-line: #34414a;
}

body { background: var(--rr-paper); color: var(--rr-ink); font-family: var(--rr-sans); }
h1, h2, h3, .header-title { font-family: var(--rr-serif); }
a:focus-visible, button:focus-visible, .menu-item:focus-visible {
  outline: 3px solid color-mix(in srgb, var(--rr-red) 70%, white);
  outline-offset: 3px;
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: .01ms !important; animation-iteration-count: 1 !important; scroll-behavior: auto !important; }
}
```

- [ ] **Step 4: Run the global contract and verify GREEN**

Run the Step 2 command. Expected: `PASS: global` with no Hugo build error.

- [ ] **Step 5: Commit the global shell**

```powershell
git add tests/site-contracts.ps1 config.toml assets/css/_custom.scss layouts/partials/header.html layouts/partials/footer.html
git commit -m "feat: establish academic site visual system"
```

---

### Task 2: Build the Research-Narrative Homepage

**Files:**
- Create: `layouts/partials/home/academic-hero.html`
- Create: `layouts/partials/home/research-pathway.html`
- Create: `layouts/partials/research/paper-card.html`
- Modify: `layouts/index.html`
- Modify: `content/_index.md`
- Modify: `content/posts/New event and old antidote/index.md`
- Modify: `content/posts/宏观经济政策沟通与预期管理：来自新闻发布会的证据/index.md`
- Modify: `content/posts/安全与效益可以兼得/index.md`
- Modify: `content/posts/上游垄断与市场化改革的“供给悖论”/index.md`
- Modify: `assets/css/_custom.scss`
- Modify: `tests/site-contracts.ps1`

**Interfaces:**
- Consumes: `.Site.Params.author`, `.Site.Params.home.profile`, explicitly featured post pages.
- Produces: `.academic-hero`, `.research-pathway`, `.featured-research`, and reusable `research/paper-card.html`.

- [ ] **Step 1: Add the failing homepage contract**

Add to `tests/site-contracts.ps1`:

```powershell
function Test-Home {
  $home = Read-Built 'index.html'
  Assert-True ($home -match 'class="academic-hero"') 'home must contain academic hero'
  Assert-True ($home -match '政策信号') 'home must state the research pathway'
  Assert-True ($home -match 'class="research-pathway"') 'home must contain research pathway component'
  Assert-True ($home -match 'class="featured-research"') 'home must contain featured research section'
  $cards = [regex]::Matches($home, 'class="paper-card').Count
  Assert-True ($cards -eq 4) "home must show exactly four explicitly featured papers; got $cards"
  Assert-True ($home -notmatch 'data-home="posts"') 'home must not render the full chronological post stream'
}
```

Call `Test-Home` when `$Section -in @('home','all')`.

- [ ] **Step 2: Run the homepage contract and verify RED**

Run the contract with `-Section home`. Expected: FAIL because `.academic-hero` does not exist.

- [ ] **Step 3: Implement the reusable paper card**

Create `layouts/partials/research/paper-card.html` with a page-only interface:

```go-html-template
{{- $page := .Page -}}
{{- $displayTitle := strings.TrimPrefix "长摘要-" $page.Title -}}
<article class="paper-card">
  <p class="paper-card-kicker">
    {{- with $page.Params.subtitle }}{{ . }}{{ else }}{{ $page.Date.Format "2006" }}{{ end -}}
  </p>
  <h3><a href="{{ $page.RelPermalink }}">{{ $displayTitle }}</a></h3>
  {{- with $page.Params.author }}<p class="paper-card-authors">{{ . }}</p>{{ end -}}
  {{- with $page.Summary }}<p class="paper-card-summary">{{ . | plainify | truncate 150 }}</p>{{ end -}}
  {{- with $page.Params.research_topics }}
    <p class="paper-card-topics">{{ delimit . " · " }}</p>
  {{- end -}}
</article>
```

- [ ] **Step 4: Implement hero, pathway, and homepage composition**

`academic-hero.html` must render the existing avatar, name, position, institution, research sentence, and links to `/about/`, `/research_topics/`, and `mailto:ruanrui@cufe.edu.cn`.

`research-pathway.html` must render:

```html
<section class="research-pathway" aria-labelledby="research-pathway-title">
  <p class="section-kicker">研究主线</p>
  <h2 id="research-pathway-title">从政策信号到微观行为</h2>
  <ol class="pathway-steps">
    <li><strong>政策信号</strong><span>财政与货币政策沟通</span></li>
    <li><strong>主体感知与预期</strong><span>企业如何理解不确定性</span></li>
    <li><strong>企业及地方政府行为</strong><span>投融资、供给与债务响应</span></li>
  </ol>
</section>
```

In `layouts/index.html`, filter only explicit featured posts:

```go-html-template
{{- $posts := where .Site.RegularPages "Type" "posts" -}}
{{- $featured := where $posts "Params.featured" true -}}
{{- $featured = sort $featured "Params.featuredWeight" "asc" -}}
```

Render the featured section only inside `with $featured`; do not append recent posts. Remove the existing chronological `.Render "summary"` loop. Keep `.Content` as the lower contact/campus section.

- [ ] **Step 5: Add explicit featured metadata**

Add only the following fields to the four paper front matter blocks listed under **Files**:

```yaml
featured: true
featuredWeight: 1
```

Use weights 1, 2, 3, and 4 in listed order. Do not alter any title, abstract, author, date, taxonomy, or body content.

- [ ] **Step 6: Add homepage styles**

Add exact component selectors to `_custom.scss`: `.academic-hero`, `.academic-hero-copy`, `.academic-hero-portrait`, `.hero-actions`, `.research-pathway`, `.pathway-steps`, `.featured-research`, `.paper-grid`, `.paper-card`, `.home-contact`. Use a two-column hero above 900px and one column below 900px. Preserve the existing 390px image constraint.

- [ ] **Step 7: Run the homepage contract and verify GREEN**

Run with `-Section home`. Expected: PASS with exactly four explicitly marked paper cards and no chronological post stream.

- [ ] **Step 8: Commit the homepage structure**

```powershell
git add layouts/index.html layouts/partials/home/academic-hero.html layouts/partials/home/research-pathway.html layouts/partials/research/paper-card.html content/_index.md content/posts assets/css/_custom.scss tests/site-contracts.ps1
git commit -m "feat: build research narrative homepage"
```

---

### Task 3: Present Explicit Featured Research

**Files:**
- Modify: `layouts/research_topics/terms.html`
- Modify: `assets/css/_custom.scss`
- Modify: `tests/site-contracts.ps1`

**Interfaces:**
- Consumes: `featured: true`, `featuredWeight: 1..4`, existing `author`, `subtitle`, `summary`, `research_topics`.
- Produces: exactly four featured papers on home and research pages; no automatic fallback.

- [ ] **Step 1: Add the failing research-page contract**

```powershell
function Test-Research {
  $research = Read-Built 'research_topics/index.html'
  Assert-True ($research -match 'class="research-intro"') 'research page must contain overview'
  Assert-True ($research -match 'class="research-featured"') 'research page must contain explicit featured papers'
  Assert-True ($research -match 'class="research-topic-grid"') 'research page must retain topic browsing'
  Assert-True ($research -notmatch '>长摘要-') 'research display titles must remove 长摘要 prefix'
  $cards = [regex]::Matches($research, 'class="paper-card').Count
  Assert-True ($cards -ge 4) 'research page must render the four featured paper cards'
}
```

Call it for `research` and `all`, then run `-Section research`. Expected: FAIL on missing `.research-intro`.

- [ ] **Step 2: Rebuild the research taxonomy layout**

Update `layouts/research_topics/terms.html` to:

1. Render a `.research-intro` with the approved research sentence.
2. Filter featured posts using the same explicit query as the homepage and reuse `research/paper-card.html`.
3. Render all taxonomy terms in `.research-topic-grid` below the featured area.
4. Apply `strings.TrimPrefix "长摘要-"` to topic-list display titles.
5. Never append latest posts to the featured set.

- [ ] **Step 3: Add research-page styles and run GREEN tests**

Add `.research-intro`, `.research-featured`, `.research-topic-grid`, `.research-topic-card`, and mobile stacking rules. Run:

```powershell
powershell -ExecutionPolicy Bypass -File tests/site-contracts.ps1 -Section home -Hugo "$env:LOCALAPPDATA\Programs\Hugo\hugo.exe"
powershell -ExecutionPolicy Bypass -File tests/site-contracts.ps1 -Section research -Hugo "$env:LOCALAPPDATA\Programs\Hugo\hugo.exe"
```

Expected: both PASS, with exactly four explicitly marked homepage papers.

- [ ] **Step 4: Commit featured research**

```powershell
git add content/posts layouts/research_topics/terms.html assets/css/_custom.scss tests/site-contracts.ps1
git commit -m "feat: curate explicit featured research"
```

---

### Task 4: Create the CV Layout and Refine Article Reading

**Files:**
- Create: `layouts/about/single.html`
- Modify: `content/about/index.md`
- Modify: `layouts/posts/single.html`
- Modify: `assets/css/_custom.scss`
- Modify: `tests/site-contracts.ps1`

**Interfaces:**
- Consumes: `.Content`, `.TableOfContents`, existing post metadata and resources.
- Produces: one-H1 CV with `.about-toc`; `.academic-article` reading layout.

- [ ] **Step 1: Add the failing CV/article contract**

```powershell
function Test-About {
  $about = Read-Built 'about/index.html'
  Assert-True ($about -match 'class="about-layout"') 'about page must use custom layout'
  Assert-True ($about -match 'class="about-toc"') 'about page must expose section navigation'
  $main = [regex]::Match($about, '<main.*?</main>', 'Singleline').Value
  $h1Count = [regex]::Matches($main, '<h1\b').Count
  Assert-True ($h1Count -eq 1) "about main must contain exactly one h1; got $h1Count"

  $post = Read-Built 'posts/new-event-and-old-antidote/index.html'
  Assert-True ($post -match 'class="page single academic-article') 'posts must use academic reading layout'
}
```

Call it for `about` and `all`, then run `-Section about`. Expected: FAIL because `.about-layout` does not exist.

- [ ] **Step 2: Implement the CV-specific layout**

Create `layouts/about/single.html`:

```go-html-template
{{- define "title" }}{{ .Title }} - {{ .Site.Title }}{{ end -}}
{{- define "content" -}}
{{- $params := .Scratch.Get "params" -}}
<div class="page single about-page">
  <div class="about-layout">
    <aside class="about-toc" aria-label="简历章节">
      <p class="section-kicker">目录</p>
      {{ .TableOfContents }}
    </aside>
    <article class="about-content content" id="content">
      {{- dict "Content" .Content "Ruby" $params.ruby "Fraction" $params.fraction "Fontawesome" $params.fontawesome | partial "function/content.html" | safeHTML -}}
    </article>
  </div>
</div>
{{- end -}}
```

- [ ] **Step 3: Correct only Markdown heading levels**

Keep the first `# 阮睿`. Change later top-level section headings from `#` to `##`; keep existing `### 中文` and `### 英文` as third-level headings. Do not change any prose, publication, date, table row, or the existing “中央财经大学教育教学改革基金项目-专项研究项目” entry.

- [ ] **Step 4: Mark and style academic articles**

Change the opening page class in `layouts/posts/single.html` to include `academic-article`. Add SCSS for a 720px reading column, serif article title, metadata hierarchy, responsive images/tables, and natural long-title wrapping. Do not change the article content rendering or resource lookup logic.

- [ ] **Step 5: Run the CV/article contract and verify GREEN**

Run `-Section about`. Expected: PASS and Hugo build success.

- [ ] **Step 6: Commit CV and reading layout**

```powershell
git add layouts/about/single.html content/about/index.md layouts/posts/single.html assets/css/_custom.scss tests/site-contracts.ps1
git commit -m "feat: refine cv and academic reading layouts"
```

---

### Task 5: Generate the Social Preview and Finalize Metadata

**Files:**
- Create: `static/og.png`
- Modify: `config.toml`

**Interfaces:**
- Consumes: final palette, typography treatment, name, title, institution, and research pathway.
- Produces: one validated landscape social card and Hugo site image metadata.

- [ ] **Step 1: Freeze and execute one social-card brief**

Generate one landscape card using the final site palette. The exact brief must request: “阮睿”, “宏观政策如何影响微观主体”, “中央财经大学”, the墨蓝/政策红/cold-paper palette, restrained academic typography, and the pathway motif “政策信号 → 主体感知与预期 → 企业及地方政府行为”. Do not invent awards, metrics, affiliations, or publications.

- [ ] **Step 2: Inspect text accuracy**

Verify every Chinese character, affiliation, and pathway label. If text is unusable, retry once; if the retry is still inaccurate, omit `og.png` rather than ship an incorrect card.

- [ ] **Step 3: Wire successful image metadata**

When the card passes, save it as `static/og.png` and add to `config.toml`:

```toml
images = ["/og.png"]
```

Run the global contract and confirm the final HTML contains `og:image` with `/og.png`. If no card passes, leave `images` unset and document that omission.

- [ ] **Step 4: Commit social metadata**

```powershell
git add static/og.png config.toml
git commit -m "feat: add academic site social preview"
```

Skip the image path in `git add` when generation was omitted.

---

### Task 6: Full Build, Browser QA, and Generated Output

**Files:**
- Modify: `public/**` only through the final Hugo build because this repository currently tracks generated output.
- Verify: all source files changed in Tasks 1–5.

**Interfaces:**
- Consumes: complete source implementation.
- Produces: passing contracts, production Hugo output, and verified desktop/mobile preview.

- [ ] **Step 1: Run all source contracts**

```powershell
powershell -ExecutionPolicy Bypass -File tests/site-contracts.ps1 -Section all -Hugo "$env:LOCALAPPDATA\Programs\Hugo\hugo.exe"
```

Expected: `PASS: all`, no Hugo error.

- [ ] **Step 2: Run the production build**

```powershell
& "$env:LOCALAPPDATA\Programs\Hugo\hugo.exe" --minify --noBuildLock
```

Expected: exit code 0 and a complete page count without template errors.

- [ ] **Step 3: Verify in the existing local preview**

At 1280×720 verify homepage first viewport, four-item desktop navigation, visible hero actions, research pathway, featured papers, research page hierarchy, CV table of contents, and article reading width.

At 390×844 verify homepage, `/about/`, `/research_topics/`, `/courses/`, one featured paper, and `/tags/`. For each page assert `document.documentElement.scrollWidth <= innerWidth` after animations settle.

- [ ] **Step 4: Verify theme and accessibility states**

Toggle dark mode and confirm contrast for background, text, links, cards, borders, and policy-red accents. Emulate reduced motion and confirm nonessential animations do not run. Tab through header, hero actions, featured paper links, CV table of contents, and footer links; every focus target must be visible.

- [ ] **Step 5: Inspect the final diff**

Run:

```powershell
git diff --check
git status --short
git diff --stat
```

Confirm that the existing CV project row remains, no theme file changed, and no temporary preview/cache file is included.

- [ ] **Step 6: Commit generated output and final verification state**

```powershell
git add public tests docs/superpowers/plans/2026-07-26-academic-site-visual-refresh.md
git commit -m "build: publish refreshed academic site"
```

Do not stage unrelated user files. If source commits already include `tests` or the plan, stage only `public` here.
