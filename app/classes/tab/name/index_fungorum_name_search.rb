# frozen_string_literal: true

# Index Fungorum name web-search external-site link for a Name.
# IF's internal search is a JS form (no GET URL), so the link
# instead goes through DuckDuckGo with a site:indexfungorum.org
# filter — see
# https://github.com/MushroomObserver/mushroom-observer/issues/1884#issuecomment-1950137454
# Quotes name s.s. to surface the right record near the top.
class Tab::Name::IndexFungorumNameSearch < Tab::Name::ExternalBase
  def title
    :index_fungorum_web_search.l
  end

  def path
    "https://duckduckgo.com/?q=site%3Aindexfungorum.org+" \
      "%22#{@name.sensu_stricto}%22"
  end
end
