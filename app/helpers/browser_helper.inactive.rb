#
#  = Browser Helper
#
#  Helper method available to Browser gem to replace old "modern" method
#  Expects a Browser instance,
#  like in `Browser.new(user_agent, accept_language: language)`.
#
################################################################################

module BrowserHelper
  def modern_browser?(browser)
    [
      browser.chrome? && browser.version.to_i >= 65,
      browser.safari? && browser.version.to_i >= 10,
      browser.firefox? && browser.version.to_i >= 52,
      browser.ie? && browser.version.to_i >= 11 && !browser.compatibility_view?,
      browser.edge? && browser.version.to_i >= 15,
      browser.opera? && browser.version.to_i >= 50,
      browser.facebook? && browser.safari_webapp_mode? && browser.webkit_full_version.to_i >= 602
    ].any?
  end
  
  def bot?(browser)
    bot.bot? && !browser.device.mobile? && !browser.duck_duck_go?
  end
end
