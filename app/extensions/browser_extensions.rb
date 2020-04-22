# frozen_string_literal: true

require "browser"

module Browser
  # Prevent `browser` gem from saying that mobile DuckDuckGo browsers are bots
  class Base
    def bot?
      bot.bot? && !device.mobile? && !duck_duck_go?
    end
  end
end
