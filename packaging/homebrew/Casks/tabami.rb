cask "tabami" do
  arch arm: "aarch64", intel: "x64"

  version "0.1.0"
  sha256 arm:   "0000000000000000000000000000000000000000000000000000000000000000",
         intel: "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/vitaliyl/tabami/releases/download/v#{version}/Tabami_#{version}_#{arch}.dmg"
  name "Tabami"
  desc "Lightweight and modern database studio for SQLite, PostgreSQL, and MySQL"
  homepage "https://github.com/vitaliyl/tabami"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :catalina"

  app "Tabami.app"

  zap trash: [
    "~/Library/Application Support/com.tabami.studio",
    "~/Library/Caches/com.tabami.studio",
    "~/Library/Preferences/com.tabami.studio.plist",
    "~/Library/Saved Application State/com.tabami.studio.savedState",
    "~/Library/WebKit/com.tabami.studio",
    "~/.tabami.json",
  ]
end
