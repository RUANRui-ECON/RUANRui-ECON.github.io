# Featured Research Summary Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the two featured-paper introductions, replace the fourth representative paper, and simplify the research headings without changing unrelated publication content.

**Architecture:** Hugo continues to derive both the home and research-page paper grids from explicit `featured` front matter ordered by `featuredWeight`. Contract tests will assert the approved copy, URL order, and visible heading hierarchy before minimal front-matter and template changes are made.

**Tech Stack:** Hugo, Go templates, Markdown/YAML front matter, PowerShell contract tests.

## Global Constraints

- Keep exactly four explicitly featured papers; do not add automatic fallback selection.
- Preserve the English paper as `featuredWeight: 1`, the press-conference paper as `featuredWeight: 2`, and the existing safety-and-efficiency paper as `featuredWeight: 3`.
- Change only the approved `summary`, `featured`, and `featuredWeight` front matter fields in publication files.
- Do not change publication titles, authors, journals, dates, tags, research topics, images, or body text.
- Keep home and research pages backed by the same featured-paper data.
- Preserve heading anchors and accessible H1/H2 hierarchy.

---

### Task 1: Lock the approved content and headings into contract tests

**Files:**
- Modify: `tests/site-contracts.ps1:108-190`

**Interfaces:**
- Consumes: Hugo-built `index.html` and `research_topics/index.html`.
- Produces: contracts for exact introductions, featured URL order, visible labels, and heading levels.

- [ ] **Step 1: Add failing home-page assertions**

In `Test-Home`, extract the featured section and assert the exact approved summaries and heading markup:

```powershell
$featuredMarkup = [regex]::Match($homeMarkup, '<section class="featured-research".*?</section>', 'Singleline').Value
$disclosureSummary = '在不确定性的时代，沉默的代价远高于真话的风险。市场记得谁选择了坦诚，也会用更低的融资成本和更稳定的估值来回报透明度。'
$communicationSummary = '政策的效果，不只取决于做了什么，也取决于市场听见了什么、如何理解。及时、清晰且可信的沟通，能够校准预期并提振信心。'
Assert-True ($featuredMarkup -match ('<h2 id="featured-research-title">' + [regex]::Escape('代表性研究') + '</h2>')) 'home featured section must use the concise approved h2'
Assert-True ($featuredMarkup -notmatch [regex]::Escape('从学术论文进入研究现场')) 'home must remove the redundant featured-research subtitle'
Assert-True ($featuredMarkup -match [regex]::Escape($disclosureSummary)) 'home must show the disclosure summary on the English paper'
Assert-True ($featuredMarkup -match [regex]::Escape($communicationSummary)) 'home must show the approved policy-communication summary'
```

- [ ] **Step 2: Update the expected fourth featured URL and add research-heading assertions**

Replace the fourth entry of `$expectedFeaturedLinks` with:

```powershell
'/posts/%E5%AE%8F%E8%A7%82%E7%BB%8F%E6%B5%8E%E6%84%9F%E7%9F%A5%E8%B4%A7%E5%B8%81%E6%94%BF%E7%AD%96%E4%B8%8E%E5%BE%AE%E8%A7%82%E4%BC%81%E4%B8%9A%E6%8A%95%E8%9E%8D%E8%B5%84%E8%A1%8C%E4%B8%BA/'
```

Add these assertions in `Test-Research`:

```powershell
$researchMain = [regex]::Match($research, '<main.*?</main>', 'Singleline').Value
Assert-True ($researchMain -match '<h1>研究方向</h1>') 'research page must promote research direction to h1'
Assert-True ($researchMain -match '<h2 id="research-featured-title">代表性研究</h2>') 'research page must use representative research as the featured h2'
Assert-True ($researchMain -match '<h2 id="research-topic-title">按主题浏览</h2>') 'research page must use browse by topic as the taxonomy h2'
Assert-True ($researchMain -notmatch '科学研究|从学术论文进入研究现场|研究议题') 'research main must remove the three redundant labels'
```

- [ ] **Step 3: Run the focused contracts and verify RED**

Run:

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe' version
pwsh -NoProfile -File tests/site-contracts.ps1 -Section home -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
pwsh -NoProfile -File tests/site-contracts.ps1 -Section research -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
```

Expected: both focused contracts fail because the old summary, fourth paper, and headings are still rendered.

- [ ] **Step 4: Commit the contract changes**

```powershell
git add -- tests/site-contracts.ps1
git commit -m "test: specify featured research corrections"
```

### Task 2: Correct featured-paper front matter

**Files:**
- Modify: `content/posts/宏观经济政策沟通与预期管理：来自新闻发布会的证据/index.md:8`
- Modify: `content/posts/上游垄断与市场化改革的“供给悖论”/index.md:6-7`
- Modify: `content/posts/宏观经济感知、货币政策与微观企业投融资行为/index.md:6`

**Interfaces:**
- Consumes: Hugo page parameters `summary`, `featured`, and `featuredWeight`.
- Produces: the approved four-item featured collection shared by both templates.

- [ ] **Step 1: Replace only the press-conference paper summary**

Set the front-matter line to:

```yaml
summary: 政策的效果，不只取决于做了什么，也取决于市场听见了什么、如何理解。及时、清晰且可信的沟通，能够校准预期并提振信心。
```

- [ ] **Step 2: Move the fourth featured marker**

Delete these two lines from the Management World paper:

```yaml
featured: true
featuredWeight: 4
```

Add the same two lines after `draft: false` in the Economic Research paper:

```yaml
featured: true
featuredWeight: 4
```

- [ ] **Step 3: Run the research contract**

Run:

```powershell
pwsh -NoProfile -File tests/site-contracts.ps1 -Section research -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
```

Expected: featured URL order passes, while heading assertions still fail until Task 3.

- [ ] **Step 4: Commit publication metadata**

```powershell
git add -- 'content/posts/宏观经济政策沟通与预期管理：来自新闻发布会的证据/index.md' 'content/posts/上游垄断与市场化改革的“供给悖论”/index.md' 'content/posts/宏观经济感知、货币政策与微观企业投融资行为/index.md'
git commit -m "content: correct featured research selection"
```

### Task 3: Simplify the visible research headings

**Files:**
- Modify: `layouts/index.html:12-16`
- Modify: `layouts/research_topics/terms.html:13-37`

**Interfaces:**
- Consumes: the existing featured collection and topic taxonomy.
- Produces: one H1 and concise H2 labels with the existing `aria-labelledby` anchors.

- [ ] **Step 1: Simplify the home featured heading**

Replace the two visible labels inside `.featured-research-heading` with:

```html
<h2 id="featured-research-title">代表性研究</h2>
```

- [ ] **Step 2: Simplify the research-page heading hierarchy**

Use these exact headings while preserving the existing wrapper elements:

```html
<h1>研究方向</h1>
<h2 id="research-featured-title">代表性研究</h2>
<h2 id="research-topic-title">按主题浏览</h2>
```

Remove the three corresponding `.section-kicker` paragraphs and the old visible labels `科学研究`, `从学术论文进入研究现场`, and `研究议题`.

- [ ] **Step 3: Run focused contracts and verify GREEN**

Run:

```powershell
pwsh -NoProfile -File tests/site-contracts.ps1 -Section home -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
pwsh -NoProfile -File tests/site-contracts.ps1 -Section research -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
```

Expected: `PASS: home` and `PASS: research`.

- [ ] **Step 4: Commit the template changes**

```powershell
git add -- layouts/index.html layouts/research_topics/terms.html
git commit -m "style: simplify research section headings"
```

### Task 4: Rebuild and verify the complete site

**Files:**
- Modify: `public/**` generated production output

**Interfaces:**
- Consumes: all updated content, templates, styles, and Hugo configuration.
- Produces: deployable static HTML plus fresh verification evidence.

- [ ] **Step 1: Run all contract and accessibility checks**

```powershell
pwsh -NoProfile -File tests/site-contracts.ps1 -Section all -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
pwsh -NoProfile -File tests/site-contracts.ps1 -Section accessibility -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
pwsh -NoProfile -File tests/site-contracts.ps1 -MutationTest -Hugo 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe'
```

Expected: all sections print `PASS`, and the mutation fixture is rejected as designed.

- [ ] **Step 2: Generate clean production output**

```powershell
& 'C:\Users\Administrator\AppData\Local\Programs\Hugo\hugo.exe' --cleanDestinationDir --minify --noBuildLock
```

Expected: Hugo exits with code 0 and reports no build error.

- [ ] **Step 3: Verify output hygiene and the live preview visually**

Run the full contract once more after generation, then inspect `/` and `/research_topics/` at `http://127.0.0.1:1313/`. Confirm the two exact summaries, four featured cards in order, the Economic Research paper as card four, and the concise H1/H2 labels at desktop and mobile widths.

- [ ] **Step 4: Commit generated output and the implementation plan**

```powershell
git add -- public docs/superpowers/plans/2026-07-28-featured-research-summary-correction.md
git commit -m "build: publish featured research corrections"
```
