# frozen_string_literal: true

# MushroomExpert.com external-site link for a Name. Searches via
# DuckDuckGo with a site:mushroomexpert.com filter — see
# https://github.com/MushroomObserver/mushroom-observer/issues/1884#issuecomment-1950137454
# Quotes name s.s. to get the right number of hits.
class Tab::Name::MushroomExpert < Tab::Name::ExternalBase
  def title
    "MushroomExpert"
  end

  def path
    "https://duckduckgo.com/?q=site%3Amushroomexpert.com+" \
      "%22#{@name.sensu_stricto}%22&ia=web"
  end
end
