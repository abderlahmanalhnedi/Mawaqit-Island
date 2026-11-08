# Publishing to GitHub (when you're ready)

Do **not** publish an app binary as production-ready before the macOS release checklist passes.

## Via GitHub website

1. Create a new empty **public** repository named `mawaqit-island` (without adding a README or license online; both are already in this folder).
2. In Terminal inside the unzipped project:

```bash
git init -b main
git add .
git commit -m "Initial community source preview v0.4.1"
git remote add origin https://github.com/YOUR_USERNAME/mawaqit-island.git
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub account name. GitHub may request browser authentication or a personal access token. Never include tokens in source.

## Using GitHub CLI (alternative)

```bash
git init -b main
git add .
git commit -m "Initial community source preview v0.4.1"
gh auth login
gh repo create mawaqit-island --public --source=. --remote=origin --push
```

## Downloadable builds

`build.yml` creates an artifact after a normal push/PR. Once you've verified the macOS UI on a real Mac and CI passes, create a version tag:

```bash
git tag v0.4.1
git push origin v0.4.1
```

`release.yml` creates a GitHub Release containing an **ad-hoc-signed, unnotarized** universal ZIP. Until you configure Apple Developer ID signing and notarization, warn users about Gatekeeper, and don't describe the release as a one-click, trusted Mac App Store installation.
