require "browser"
require "browser/aliases"

Browser::Base.include(Browser::Aliases)

module Browser
  class Base
    # bot? is already defined in Browser::Base
    # def bot?(browser)
    #   bot.bot? && !browser.device.mobile? && !browser.duck_duck_go?
    # end
    def modern_browser?
      [
        chrome?(">= 65"),
        safari?(">= 10"),
        firefox?(">= 52"),
        ie?(">= 11") && !compatibility_view?,
        edge?(">= 15"),
        opera?(">= 50")
        # facebook?
        #   && safari_webapp_mode?
        #   && webkit_full_version.to_i >= 602
        # browser.chrome? && browser.version.to_i >= 65,
        # browser.safari? && browser.version.to_i >= 10,
        # browser.firefox? && browser.version.to_i >= 52,
        # browser.ie? && browser.version.to_i >= 11 && !browser.compatibility_view?,
        # browser.edge? && browser.version.to_i >= 15,
        # browser.opera? && browser.version.to_i >= 50,
        # browser.facebook? && browser.safari_webapp_mode? && browser.webkit_full_version.to_i >= 602
      ].any?
    end
  end
end
