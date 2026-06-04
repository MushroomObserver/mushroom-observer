# frozen_string_literal: true

# Index Fungorum search-landing-page external-site link. No Name
# parameter — drops the user on IF's general Names search page.
# Used as a fallback when a Name has no ICN ID.
class Tab::Name::IndexFungorumSearchPage < Tab::Name::ExternalBase
  def title
    :index_fungorum_search.l
  end

  def path
    "http://www.indexfungorum.org/Names/Names.asp"
  end
end
