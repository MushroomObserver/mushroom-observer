# frozen_string_literal: true

require("browser")

# extensino to Browser gem. https://github.com/fnando/browser
module Browser
  class Base
    def bot?
      return false unless bot.bot?

      # Stop Browser gem from saying that mobile DuckDuckGo browsers are bots
      return !device.mobile? && !duck_duck_go? unless Rails.env.test?

      # Ensure that test requests aren't from bots, unless test uses a known bot
      bot.why? == Browser::Bot::KnownBotsMatcher
    end
  end
end
