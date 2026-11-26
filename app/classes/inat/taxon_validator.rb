# frozen_string_literal: true

class Inat
  # Checks whether iNat taxon IDs are all descendants of taxa importable
  # to Mushroom Observer (Fungi 47170 and Mycetozoa 47685).
  # Used to decide whether a user-supplied taxon_id URL param can be honored
  # or must be stripped.
  class TaxonValidator
    include Inat::Constants

    def initialize(taxon_ids)
      @taxon_ids = Array(taxon_ids).map(&:to_s).compact_blank.uniq
    end

    # Are IDs Fungi or Mycetozoa (or list is empty)?
    # False if any ID falls outside those lineages, iNat
    # returns fewer results than requested, or the API fails.
    def all_importable?
      return true if @taxon_ids.empty?

      @taxon_ids.each_slice(MAX_PER_PAGE).all? { |ids| batch_importable?(ids) }
    end

    private

    def batch_importable?(ids)
      results = fetch_taxa_results(ids)
      return false unless results
      return false if results.length < ids.length

      results.all? { |taxon| importable_ancestor?(taxon) }
    end

    def fetch_taxa_results(ids)
      response = Inat::APIRequest.new(nil).request(
        path: "taxa?id=#{ids.join(",")}&per_page=#{MAX_PER_PAGE}"
      )
      JSON.parse(response.body)["results"]
    rescue StandardError
      nil
    end

    def importable_ancestor?(taxon)
      ancestor_ids = taxon["ancestor_ids"] || []
      IMPORTABLE_TAXON_IDS.intersect?(ancestor_ids)
    end
  end
end
