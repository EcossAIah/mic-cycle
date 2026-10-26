cask "mic-cycle" do
  version "1.4.0"
  sha256 "ba80616be2efaae219a72e0c7ef0623acdc9fb5f51df72169b767e39da129170"

  url "https://github.com/EcossAIah/mic-cycle/releases/download/v#{version}/mic-cycle-#{version}.dmg"
  name "Mic Cycle"
  desc "Menu bar app to choose and cycle the default microphone"
  homepage "https://github.com/EcossAIah/mic-cycle"

  depends_on macos: :ventura

  app "Mic Cycle.app"

  uninstall quit: "io.github.ecossaiah.mic-cycle"

  caveats <<~EOS
    Mic Cycle is not notarized, so macOS blocks the first launch.
    Open it once, then go to System Settings > Privacy & Security and click Open Anyway.
  EOS
end
