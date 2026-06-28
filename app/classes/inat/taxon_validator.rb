# frozen_string_literal: true

class Inat
  # Checks whether iNat taxon IDs are all descendants of taxa importable
  # to Mushroom Observer (Fungi 47170 and Mycetozoa 47685).
  # Used to decide whether a user-supplied taxon_id URL param can be honored
  # or must be stripped.
  class TaxonValidator
    include Inat::Constants

    def initialize(taxon_ids)
      @taxon_ids = Array(taxon_ids).map(&:to_s).compact_blank
    end

    # Returns true if all IDs have a Fungi or Mycetozoa ancestor (or list is
    # empty). Returns false if any ID falls outside those lineages, if iNat
    # returns fewer results than requested (unknown ID), or if the API fails.
    def all_importable?
      return true if @taxon_ids.empty?

      results = fetch_taxa_results
      return false unless results
      return false if results.length < @taxon_ids.length

      results.all? { |taxon| importable_ancestor?(taxon) }
    end

    private

    def fetch_taxa_results
      response = Inat::APIRequest.new(nil).request(
        path: "taxa?id=#{@taxon_ids.join(",")}"
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
