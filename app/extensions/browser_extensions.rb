require "browser"
module Browser
  class Base
    def bot?
      bot.bot? && !bot.ua.match(/Mobile.*DuckDuckGo/)
    end
  end
end
