<div align="center">

# 💎 Tabami

**A fast, lightweight, and modern database studio for SQLite, PostgreSQL, and MySQL.**

Built with **Hanami 3.0**, **Inertia.js**, **Vue 3**, and **Tauri 2.0 (Rust)**.

[![CI](https://github.com/vitaliyl/tabami/actions/workflows/ci.yml/badge.svg)](https://github.com/vitaliyl/tabami/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/vitaliyl/tabami?include_prereleases&color=emerald)](https://github.com/vitaliyl/tabami/releases)
[![Homebrew](https://img.shields.io/badge/homebrew-cask-orange.svg)](https://github.com/vitaliyl/homebrew-tabami)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Vue](https://img.shields.io/badge/Vue-3.5-42b883.svg)](https://vuejs.org/)
[![Rust](https://img.shields.io/badge/Rust-Tauri_2.0-dea584.svg)](https://tauri.app/)
[![Hanami](https://img.shields.io/badge/Hanami-3.0-e95420.svg)](https://hanamirb.org/)

</div>

---

## ✨ Key Features

- 💎 **Universal Database Support**: Connect seamlessly to **PostgreSQL**, **SQLite**, and **MySQL** with auto-discovery and live connection testing.
- 🎨 **Multi-Theme Color Schemes**: Choose between **Sumi Dark** (Obsidian/Urushi), **Matcha Earth** (Muted photopic green), and **Washi Light** (Parchment) themes.
- ⚡ **High-Performance SQL Console**: Syntax highlighting, line numbers, synchronized scrolling, execution time metrics, and dedicated full-screen view toggles for both the editor and the query results.
- 📊 **Virtualized Data Grid**: Virtualized result rendering for large datasets with draggable column resizing, double-click auto-fit, and instant CSV/JSON exports.
- 🔍 **Value Inspector**: Deep inspector for complex JSON and text payloads with tree view, search highlighting, syntax validation, prettify, and minify.
- 🗺️ **Schema & Domain Classification**: Heuristic bounded context clustering of tables into logical domain categories and detailed table schema inspection (columns, types, nullability, primary keys, foreign keys, and indexes).
- 🖥️ **Dual Runtime Modes**: Run as a native **Desktop GUI App (macOS / Linux / Windows)** via Tauri 2.0 or as a lightweight **Web / CLI Server** via Hanami.

---

## 📦 Installation

### Option 1: Homebrew (macOS Desktop App)

Install the desktop application using Homebrew:

```bash
brew tap vitaliyl/tabami
brew install --cask tabami
```

### Option 2: Direct Binary Download

Download pre-compiled binaries for your operating system from [GitHub Releases](https://github.com/vitaliyl/tabami/releases/latest):

- **macOS**: `.dmg` (Universal, Apple Silicon `aarch64`, Intel `x64`)
  > *Note*: If macOS Gatekeeper displays an unverified developer prompt on first launch, allow it in **System Settings > Privacy & Security > Open Anyway**, or run:
  > ```bash
  > xattr -cr /Applications/Tabami.app
  > ```
- **Linux**: `.AppImage` / `.deb` (x86_64)
- **Windows**: `.msi` / `.exe` (x64)

### Option 3: Build from Source

#### Prerequisites
- Ruby 3.2+ (or 4.0+)
- Node.js 20+ and npm
- Rust 1.77+ and Cargo (for Tauri Desktop App)

#### Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/vitaliyl/tabami.git
   cd tabami
   ```

2. **Install dependencies**:
   ```bash
   bundle install
   npm install
   ```

3. **Run Web / Hanami Server**:
   ```bash
   bin/dev
   ```
   Open **http://localhost:2300** in your browser.

4. **Run Tauri Desktop Application**:
   ```bash
   npm run tauri dev
   ```

---

## 🛠️ Tech Stack & Architecture

| Layer | Technology |
|---|---|
| **Desktop Core** | [Tauri 2.0](https://tauri.app/) (Rust), [SQLx](https://github.com/launchbadge/sqlx) async drivers, Tokio |
| **Backend & CLI** | Ruby 3+, [Hanami 3.0](https://hanamirb.org/), [Sequel](https://sequel.jeremyevans.net/), [Dry-rb](https://dry-rb.org/), [Puma](https://puma.io/) |
| **Frontend SPA** | [Vue 3.5](https://vuejs.org/), [Inertia.js](https://inertiajs.com/), TypeScript, [Tailwind CSS](https://tailwindcss.com/) |
| **Data Grid & UI** | [TanStack Virtual](https://tanstack.com/virtual), [Lucide Icons](https://lucide.dev/) |
| **Packaging** | Homebrew Cask & Formula, Tauri Multi-Platform Release Actions |

---

## 💻 CLI Usage

Tabami includes a built-in CLI runner:

```bash
# Display Tabami version
bin/tabami version

# Start web server on custom port and open browser automatically
bin/tabami server --port 3000 --open
```

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
