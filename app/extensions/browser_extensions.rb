# frozen_string_literal: true

require("browser")

# extensino to Browser gem. https://github.com/fnando/browser
module Browser
  class Base
    def bot?
      # Stop Browser gem from saying that mobile DuckDuckGo browsers are bots
      bot.bot? && !device.mobile? && !duck_duck_go? && MO.bot_enabled
    end
  end
end
