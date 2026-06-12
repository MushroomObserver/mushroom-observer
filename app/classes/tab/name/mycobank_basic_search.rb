# frozen_string_literal: true

# MycoBank basic-search external-site link. No Name parameter —
# drops the user on MycoBank's general search page.
class Tab::Name::MycobankBasicSearch < Tab::Name::ExternalBase
  def title
    :mycobank_search.l
  end

  def path
    "#{Tab::Name::MycobankSearch::MYCOBANK_HOST}" \
      "#{Tab::Name::MycobankSearch::MYCOBANK_BASIC_SEARCH_PATH}"
  end
end
