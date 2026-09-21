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
      "/field/Taxon%20name/#{url_encode(taxon_name)}"
  end

  private

  def taxon_name
    return @name.sensu_stricto unless @name.Subgenus?

    # MycoBank abbreviates Subgenus as "subgen.", not "subg."
    @name.sensu_stricto.sub("subg.", "subgen.")
  end
end
