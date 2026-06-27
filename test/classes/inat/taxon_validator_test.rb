# frozen_string_literal: true

require("test_helper")

class Inat
  class TaxonValidatorTest < UnitTestCase
    include Inat::Constants

    TAXA_URL = %r{api\.inaturalist\.org/v1/taxa}

    def fungi_result(id)
      { "id" => id, "ancestor_ids" => [48_460, FUNGI_TAXON_ID, id] }
    end

    def mycetozoa_result(id)
      { "id" => id, "ancestor_ids" => [48_460, MYCETOZOA_TAXON_ID, id] }
    end

    def non_fungi_result(id)
      { "id" => id, "ancestor_ids" => [id] }
    end

    def taxa_body(*results)
      { "total_results" => results.length, "results" => results }.to_json
    end

    # ---- all_importable? when list is empty ---------------------------------

    def test_returns_true_for_empty_id_list
      result = TaxonValidator.new([]).all_importable?

      assert(result, "Empty taxon ID list should return true without API call")
    end

    # ---- all_importable? when all taxa are fungi/slime molds ----------------

    def test_returns_true_for_single_fungi_taxon
      stub_request(:get, TAXA_URL).
        to_return(status: 200, body: taxa_body(fungi_result(417_357)))

      result = TaxonValidator.new(["417357"]).all_importable?

      assert(result, "A taxon within Fungi should be importable")
    end

    def test_returns_true_for_fungi_taxon_id_itself
      stub_request(:get, TAXA_URL).
        to_return(status: 200,
                  body: taxa_body({ "id" => FUNGI_TAXON_ID,
                                    "ancestor_ids" => [48_460,
                                                       FUNGI_TAXON_ID] }))

      result = TaxonValidator.new([FUNGI_TAXON_ID.to_s]).all_importable?

      assert(result, "Fungi root taxon itself should be importable")
    end

    def test_returns_true_for_mycetozoa_taxon
      stub_request(:get, TAXA_URL).
        to_return(status: 200, body: taxa_body(mycetozoa_result(417_358)))

      result = TaxonValidator.new(["417358"]).all_importable?

      assert(result, "A taxon within Mycetozoa should be importable")
    end

    def test_returns_true_when_all_multiple_taxa_are_importable
      stub_request(:get, TAXA_URL).
        to_return(status: 200,
                  body: taxa_body(fungi_result(417_357),
                                  mycetozoa_result(417_358)))

      result = TaxonValidator.new(%w[417357 417358]).all_importable?

      assert(result, "All taxa within Fungi/Mycetozoa should be importable")
    end

    # ---- all_importable? when any taxon is outside fungi/slime molds --------

    def test_returns_false_for_non_fungi_taxon
      stub_request(:get, TAXA_URL).
        to_return(status: 200, body: taxa_body(non_fungi_result(3)))

      result = TaxonValidator.new(["3"]).all_importable?

      assert_not(result,
                 "A taxon outside Fungi/Mycetozoa should not be importable")
    end

    def test_returns_false_when_any_taxon_not_importable
      stub_request(:get, TAXA_URL).
        to_return(status: 200,
                  body: taxa_body(fungi_result(417_357), non_fungi_result(3)))

      result = TaxonValidator.new(%w[417357 3]).all_importable?

      assert_not(result, "Should be false when any taxon is not importable")
    end

    def test_returns_false_when_api_returns_fewer_results_than_ids
      stub_request(:get, TAXA_URL).
        to_return(status: 200, body: taxa_body(fungi_result(417_357)))

      result = TaxonValidator.new(%w[417357 99999999]).all_importable?

      assert_not(result,
                 "Unknown taxon ID (not returned by API) is not importable")
    end

    # ---- all_importable? on API failure (fail closed) -----------------------

    def test_returns_false_when_api_returns_error
      stub_request(:get, TAXA_URL).to_return(status: 500, body: "error")

      result = TaxonValidator.new(["417357"]).all_importable?

      assert_not(result,
                 "API error should return false to prevent unsafe imports")
    end

    def test_returns_false_when_api_returns_invalid_json
      stub_request(:get, TAXA_URL).to_return(status: 200, body: "not json")

      result = TaxonValidator.new(["417357"]).all_importable?

      assert_not(result, "Invalid JSON response should return false")
    end
  end
end
