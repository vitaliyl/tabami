class Tabami < Formula
  desc "Lightweight and modern database studio for SQLite, PostgreSQL, and MySQL (CLI)"
  homepage "https://github.com/vitaliyl/tabami"
  url "https://github.com/vitaliyl/tabami/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/vitaliyl/tabami.git", branch: "main"

  depends_on "node" => :build
  depends_on "rust" => :build
  depends_on "ruby" => :recommended

  def install
    system "npm", "ci"
    system "npm", "run", "build"

    # Install application files into libexec
    libexec.install Dir["*"]

    # Wrapper script for bin/tabami CLI runner
    (bin/"tabami").write <<~EOS
      #!/usr/bin/env bash
      cd "#{libexec}" && bundle exec "#{libexec}/bin/tabami" "$@"
    EOS
  end

  test do
    assert_match "Tabami v", shell_output("#{bin}/tabami --version 2>&1", 0)
  end
end
