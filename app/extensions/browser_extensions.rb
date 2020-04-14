require "browser"
module Browser
  class Base
    def bot?
      bot.bot? && !browser.device.mobile? && !browser.duck_duck_go?
    end
  end
end
