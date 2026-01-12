# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hugo-based academic personal website for an economics professor (阮睿/Ruan Rui) at Central University of Finance and Economics. The site uses the LoveIt theme and is deployed to GitHub Pages via GitHub Actions.

**Site URL:** https://ruanrui.com.cn
**Hugo Version:** 0.128.0 (extended)
**Theme:** LoveIt (Git submodule in `themes/LoveIt`)
**Language:** Simplified Chinese (zh-CN)

## Development Commands

### Build and Preview
```bash
# Local development server with drafts
hugo server -D

# Build for production (output to public/)
hugo --minify

# Build without minifying
hugo
```

### Content Management
```bash
# Create new post using default archetype
hugo new posts/your-post-name/index.md

# The archetype will create front matter with title, date, and draft status
```

### Deployment
The site deploys automatically via GitHub Actions on push to `main` branch. See [.github/workflows/hugo.yml](.github/workflows/hugo.yml) for the workflow configuration.

Manual deployment is not typically needed, but the GitHub Actions workflow:
1. Installs Hugo CLI (extended version)
2. Installs Dart Sass
3. Checks out with submodules (for theme)
4. Builds with `hugo --minify --baseURL`
5. Deploys to GitHub Pages

## Architecture

### Content Structure

The site uses a hierarchical content organization in the `content/` directory:

- **`content/_index.md`** - Home page contact information and styling
- **`content/about/`** - CV/Resume (简历) with full academic profile
- **`content/posts/`** - Research papers, media articles, and academic writings
  - Each post is a page bundle (folder with `index.md` and resources)
  - Posts can have featured images defined in front matter resources

### Custom Taxonomies

The site defines two custom taxonomies beyond Hugo's defaults (tags, categories):

1. **`research_topics`** - Research topic classification for academic papers
2. **`courses`** - Course classification for teaching materials

Both are defined in [config.toml](config.toml) under `[taxonomies]` and have custom term display layouts.

### Layout Customization

Custom layouts override/extend the LoveIt theme in `layouts/`:

- **`layouts/posts/single.html`** - Single post template with subtitle support, featured images, and metadata display (word count, reading time, author, categories)
- **`layouts/research_topics/terms.html`** - Custom taxonomy listing for research topics (shows up to 10 posts per topic with "more" links)
- **`layouts/courses/terms.html`** - Custom taxonomy listing for courses (similar structure to research_topics)
- **`layouts/_default/`** - Default templates
- **`layouts/partials/`** - Partial templates
- **`layouts/shortcodes/`** - Custom shortcodes

### Menu Structure

The main navigation menu is configured in [config.toml](config.toml) under `[menu]`:
1. 简历 (About/CV) - `/about/`
2. 科学研究 (Research) - `/research_topics/`
3. 教学 (Teaching) - `/courses/`
4. 媒体 (Media) - `/categories/媒体/`
5. 标签 (Tags) - `/tags/`
6. 分类 (Categories) - `/categories/`

### Front Matter Standards

Posts use the following front matter structure:

```yaml
---
title: "Post Title"
subtitle: "Optional subtitle (displayed below title)"
date: 2026-01-05
draft: false
author: "Author names"
summary: "Brief summary for listing pages"
categories: ["Category"]
research_topics: ["Topic"]  # Custom taxonomy
tags: ["tag1", "tag2"]

resources:
- name: featured-image
  src: coverpage.png
- name: featured-image-preview
  src: preview.webp
  width: 800
---
```

### Theme Integration

The LoveIt theme is included as a Git submodule. Theme customizations are made through:
- Config parameters in [config.toml](config.toml) under `[params]`
- Layout overrides in `layouts/` (which take precedence over theme layouts)
- Asset customizations in `assets/`

**Important:** Never modify files directly in `themes/LoveIt/`. Always override in the project root.

### Configuration Highlights

Key configuration settings in [config.toml](config.toml):

- **Math support enabled** - Supports LaTeX math with `$$` delimiters
- **Asset fingerprinting disabled** - For simplicity (`disableFingerprinting = true`)
- **Goldmark renderer** - Unsafe HTML is allowed (`unsafe = true`) for custom HTML in markdown
- **Syntax highlighting** - Using classes (not inline styles)
- **Author info** - Defined under `[params.author]`
- **Home profile** - Avatar, title, subtitle configured under `[params.home.profile]`

## Important Notes

### Content Organization
- All research papers and articles are stored in `content/posts/` as page bundles
- Each post folder contains `index.md` plus any images/resources
- Posts use Chinese titles for directory names (e.g., `企业不确定性感知、投资决策和金融资产配置/`)

### Images and Resources
- Images can be referenced relatively from the page bundle
- Featured images are defined in front matter under `resources` section
- Large images (>400KB) should be optimized before committing

### Git Submodules
When cloning or updating, remember to initialize submodules:
```bash
git submodule update --init --recursive
```

### Deployment Workflow
- All pushes to `main` trigger automatic deployment
- The `public/` directory is generated during CI/CD and should not be committed
- Hugo cache is stored in runner temp during builds
