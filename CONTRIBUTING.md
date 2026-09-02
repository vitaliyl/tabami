# Contributing to Tabami

Thank you for your interest in contributing to **Tabami**! We welcome bug reports, feature requests, documentation improvements, and code contributions.

---

## Code of Conduct

Please review and adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) in all project interactions.

---

## Architectural Overview

Tabami is architected with a modern, dual-runtime architecture:

```
tabami/
├── app/                  # Hanami 3.0 backend (Actions, Services, Structs, CLI)
│   ├── actions/          # HTTP & Inertia endpoints
│   ├── assets/           # Frontend source (Vue 3, TypeScript, Tailwind)
│   │   └── js/           # Components, Pages, Utilities
│   └── services/         # Connection management & query execution (Sequel)
├── gems/                 # Embedded gems (hanami-inertia)
├── public/               # Static assets & compiled frontend distribution
├── src-tauri/            # Tauri 2.0 native Rust core (SQLx multi-engine)
└── packaging/            # Distribution definitions (Homebrew Cask & Formula)
```

1. **Frontend**: Vue 3.5, TypeScript, Tailwind CSS, TanStack Virtual, Inertia.js, Vite.
2. **Web / CLI Mode**: Ruby 3.2+/4.0+, Hanami 3.0, Sequel, Dry-rb, Puma.
3. **Desktop Mode**: Tauri 2.0 (Rust) using async SQLx drivers for SQLite, PostgreSQL, and MySQL.

---

## Development Setup

### Prerequisites

- **Ruby**: 3.2+ (or 4.0+)
- **Node.js**: 18+ (Node 20+ LTS recommended) and npm
- **Rust**: 1.77+ (via `rustup`) for Tauri desktop development
- **Bundler**: `gem install bundler`

### Step-by-Step Setup

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

3. **Running the Web / Hanami Environment**:
   ```bash
   bin/dev
   ```
   This boots the Hanami Puma server on port `2300` and Vite HMR on port `5173`. Open [http://localhost:2300](http://localhost:2300).

4. **Running the Desktop / Tauri Environment**:
   ```bash
   npm run tauri dev
   ```
   This launches the native macOS / Linux / Windows Tauri desktop application window with live HMR.

---

## Development Guidelines

### Code Style

- **Frontend (Vue/TypeScript)**:
  - Run type checking: `npm run build`
  - Keep components modular, accessible, and reactive.
  - Tailwind CSS classes should follow logical grouping (layout -> sizing -> typography -> colors).
- **Rust (Tauri Core)**:
  - Format code: `cargo fmt --manifest-path src-tauri/Cargo.toml`
  - Check lints: `cargo clippy --manifest-path src-tauri/Cargo.toml`
  - Check builds: `cargo check --manifest-path src-tauri/Cargo.toml`
- **Ruby (Backend)**:
  - Follow standard Ruby 3/4 style guidelines and immutable data flow with Dry-rb and Sequel.

---

## Submitting Pull Requests

1. **Fork & Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Make focused, readable commits** with clear commit messages following Conventional Commits (e.g. `feat: add DuckDB support`, `fix: virtual grid scroll calculation`).
3. **Test thoroughly**:
   - Ensure `npm run build` compiles with zero TypeScript errors.
   - Ensure `cargo check --manifest-path src-tauri/Cargo.toml` passes.
4. **Push & Open PR**:
   - Push your branch to your fork.
   - Open a Pull Request targeting the `main` branch.
   - Fill out the PR template with description, rationale, and screenshots if applicable.

---

## Questions and Discussions

If you have questions or want to discuss architectural ideas before coding, please open an Issue or start a GitHub Discussion.
