# Homebrew Distribution for Tabami

This directory contains the Homebrew **Cask** (macOS Desktop GUI App) and **Formula** (CLI runner) definitions for distributing **Tabami**.

---

## 1. Setting Up Your Homebrew Tap Repository

To allow users to install Tabami via `brew tap`, create a new GitHub repository named `homebrew-tabami` (or `homebrew-tap`) under your GitHub user or organization account:

1. Create a repository on GitHub: `https://github.com/vitaliyl/homebrew-tabami`
2. Structure the tap repository as follows:
   ```
   homebrew-tabami/
   ├── README.md
   ├── Casks/
   │   └── tabami.rb
   └── Formula/
       └── tabami.rb
   ```
3. Copy `packaging/homebrew/Casks/tabami.rb` into your tap repository's `Casks/tabami.rb`.

---

## 2. User Installation Experience

Once your tap is created and populated, users can install Tabami with:

### Desktop Application (Cask - Recommended)
```bash
# Tap your repository and install the desktop app
brew tap vitaliyl/tabami
brew install --cask tabami
```
Or as a one-liner:
```bash
brew install --cask vitaliyl/tabami/tabami
```

### Command-Line Runner (Formula)
```bash
brew install vitaliyl/tabami/tabami
```

---

## 3. Releasing New Versions

### Automatic Update (GitHub Actions)
When a new Git tag (e.g. `v0.1.0`) is pushed to this repository:
1. The `.github/workflows/release.yml` workflow builds native macOS binaries (`.dmg` for Apple Silicon `aarch64` and Intel `x64`).
2. It generates `checksums.txt` with SHA-256 values.
3. If `HOMEBREW_TAP_TOKEN` secret is configured, it automatically dispatches a repository event to update `homebrew-tabami`.

### Manual Update
You can easily calculate checksums and update the Cask formula using the included helper script:

```bash
./packaging/homebrew/update_cask.sh <version> <github_username_or_org>
```

Example:
```bash
./packaging/homebrew/update_cask.sh 0.1.0 yourname
```

---

## 4. Submitting to Official Homebrew (`homebrew/cask`)

Once Tabami gains adoption and reaches stable releases:
1. Review the official [Homebrew Cask Acceptance Criteria](https://docs.brew.sh/Adding-Software-to-Homebrew#acceptable-casks).
2. Run `brew audit --cask --new tabami` and `brew style --cask tabami` on the Cask file.
3. Submit a PR to [Homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask).
4. Once merged, users will simply run:
   ```bash
   brew install --cask tabami
   ```
