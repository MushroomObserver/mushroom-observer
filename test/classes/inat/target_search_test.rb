# frozen_string_literal: true

require("test_helper")

# Asking iNaturalist about one target, and about a taxon id it was
# given earlier.
class Inat::TargetSearchTest < UnitTestCase
  include InatStubHelpers

  def setup
    super
    @name = names(:coprinus_comatus)
    @location = locations(:burbank)
  end

  def test_the_matching_version_depends_on_the_kind_of_target
    assert_equal(Inat::TargetSearch::TAXON_MATCHING_VERSION,
                 Inat::TargetSearch.matching_version(@name))
    assert_equal(Inat::TargetSearch::PLACE_MATCHING_VERSION,
                 Inat::TargetSearch.matching_version(@location))
  end

  def test_a_name_is_asked_about_as_a_taxon
    stub_taxon(@name.text_name, 47_347)

    assert_equal(47_347, search.answer_for(@name))
  end

  def test_a_location_is_asked_about_as_a_place
    stub_json("places", [])

    assert_equal(false, search.answer_for(@location),
                 "iNat knowing no such place is an answer")
  end

  # The point of asking the taxon rather than re-running the search.
  def test_a_current_taxon_confirms_as_active
    stub_one_taxon(47_347, is_active: true)
    confirmation = search.confirm_taxon(47_347)

    assert(confirmation.active)
    assert_nil(confirmation.replacement_id)
  end

  def test_a_swapped_taxon_names_its_replacement
    stub_one_taxon(351_380, is_active: false,
                            current_synonymous_taxon_ids: [1_525_548])
    confirmation = search.confirm_taxon(351_380)

    assert_not(confirmation.active)
    assert_equal(1_525_548, confirmation.replacement_id)
  end

  # A split has several outputs and no single answer to adopt.
  def test_a_split_taxon_offers_no_replacement
    stub_one_taxon(351_380, is_active: false,
                            current_synonymous_taxon_ids: [111, 222])
    confirmation = search.confirm_taxon(351_380)

    assert_not(confirmation.active)
    assert_nil(confirmation.replacement_id)
  end

  # iNat answers 200 with no results for an id it does not have, so
  # this is an answer and must not read as a refusal.
  def test_a_taxon_inat_has_dropped_confirms_as_inactive
    stub_request(:get, inat_api_matcher("taxa/999")).
      to_return(status: 200, body: { results: [] }.to_json)
    searcher = search
    confirmation = searcher.confirm_taxon(999)

    assert_not(confirmation.active)
    assert_nil(confirmation.replacement_id)
    assert_not(searcher.refused?, "an empty answer is not a refusal")
  end

  def test_a_refusal_stops_the_pass
    stub_request(:get, inat_api_matcher("taxa")).
      to_return(status: 429, body: "")
    searcher = search

    assert_nil(searcher.confirm_taxon(47_347))
    assert(searcher.refused?)
    assert_nil(searcher.answer_for(@name),
               "nothing more is asked once iNat has refused")
  end

  def test_the_whole_taxon_comes_back_for_a_caller_adopting_its_name
    stub_one_taxon(1_525_548, is_active: true, name: "Collybia nuda",
                              rank: "species")
    taxon = search.taxon(1_525_548)

    assert_equal("Collybia nuda", taxon["name"])
    assert_equal("species", taxon["rank"])
  end

  def test_an_unknown_id_has_no_taxon
    stub_request(:get, inat_api_matcher("taxa/999")).
      to_return(status: 200, body: { results: [] }.to_json)

    assert_nil(search.taxon(999))
  end

  def test_lookups_after_the_first_wait_the_pace
    stub_taxon(@name.text_name, 47_347)
    stub_one_taxon(47_347, is_active: true)
    searcher = Inat::TargetSearch.new(pace: 3)
    pauses = []

    searcher.stub(:sleep, ->(seconds) { pauses << seconds }) do
      searcher.answer_for(@name)
      searcher.confirm_taxon(47_347)
    end

    assert_equal([3], pauses, "the first lookup does not wait, the second does")
  end

  private

  def search
    Inat::TargetSearch.new
  end

  # One taxon as `GET /taxa/:id` returns it.
  def stub_one_taxon(inat_id, **attributes)
    taxon = { id: inat_id, name: "Lepista nuda", rank: "species",
              ancestor_ids: [Inat::Constants::FUNGI_TAXON_ID, inat_id] }.
            merge(attributes)
    stub_request(:get, inat_api_matcher("taxa/#{inat_id}")).
      to_return(status: 200, body: { results: [taxon] }.to_json)
  end

  def stub_json(path_fragment, results)
    stub_request(:get, inat_api_matcher(path_fragment)).
      to_return(status: 200, body: { results: results }.to_json)
  end

  def stub_taxon(text_name, inat_id)
    stub_request(
      :get,
      "#{Inat::Constants::API_BASE}/taxa?q=#{ERB::Util.url_encode(text_name)}" \
      "&per_page=5"
    ).to_return(status: 200,
                body: { results: [fungal_taxon(inat_id, text_name)] }.to_json)
  end
end
