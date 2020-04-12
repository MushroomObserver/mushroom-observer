require "browser"
module Browser
  class Base
    def bot?
      bot.bot? && !bot.device.mobile? && !bot.duck_duck_go?
    end
  end
end
