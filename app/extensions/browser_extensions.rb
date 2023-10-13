# frozen_string_literal: true

require("browser")

module Browser
  class Base
    def bot?
      # Ensure that test requests aren't from bots, unless test uses a known bot
      return (bot.why? == Browser::Bot::KnownBotsMatcher) if Rails.env.test?

      # Stop `browser` gem from saying that mobile DuckDuckGo browsers are bots
      bot.bot? && !device.mobile? && !duck_duck_go?
    end
  end
end
