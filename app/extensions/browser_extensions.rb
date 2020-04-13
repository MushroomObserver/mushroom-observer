require "browser"
module Browser
  class Base
    def bot?
      bot.bot? && !self.device.mobile? && !self.duck_duck_go?
    end
  end
end
