# frozen_string_literal: true

# "MycoBank search" external-site link for a Name. Composed by
# the names show page nomenclature panel.
class Tab::Name::MycobankSearch < Tab::Name::ExternalBase
  MYCOBANK_HOST = "https://www.mycobank.org/"
  MYCOBANK_BASIC_SEARCH_PATH = "page/Basic%20names%20search"

  def title
    :mycobank_search.l
  end

  def path
    "#{MYCOBANK_HOST}#{MYCOBANK_BASIC_SEARCH_PATH}" \
      "/field/Taxon%20name/#{@name.sensu_stricto.gsub(" ", "%20")}"
  end
end
