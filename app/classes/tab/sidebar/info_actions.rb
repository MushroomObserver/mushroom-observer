# frozen_string_literal: true

# Sidebar "More" section — info / help / donate / contributor /
# publication / policy links.
class Tab::Sidebar::InfoActions < Tab::Collection
  private

  def tabs
    [Tab::Sidebar::Info::MobileApp.new,
     Tab::Sidebar::Info::Intro.new,
     Tab::Sidebar::Info::HowToUse.new,
     Tab::Sidebar::Info::Donate.new,
     Tab::Sidebar::Info::HowToHelp.new,
     Tab::Sidebar::Info::ReportABug.new,
     Tab::Sidebar::Info::SendAComment.new,
     Tab::Sidebar::Info::Contributors.new,
     Tab::Sidebar::Info::SiteStats.new,
     Tab::Sidebar::Info::TranslatorsNote.new,
     Tab::Sidebar::Info::Publications.new,
     Tab::Sidebar::Info::PrivacyPolicy.new]
  end
end
