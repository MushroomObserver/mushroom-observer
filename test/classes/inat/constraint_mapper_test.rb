# frozen_string_literal: true

require("test_helper")

# An MO project's constraints as iNat observation-search params (#5416).
class Inat::ConstraintMapperTest < UnitTestCase
  include InatStubHelpers

  def setup
    super
    Rails.cache.clear
    @project = projects(:rare_fungi_project)
  end

  def stub_json(path_fragment, results)
    stub_request(:get, inat_api_matcher(path_fragment)).
      to_return(status: 200, body: { results: results }.to_json)
  end

  def stub_taxon(text_name, id)
    stub_request(
      :get,
      "#{Inat::Constants::API_BASE}/taxa?q=#{ERB::Util.url_encode(text_name)}" \
      "&per_page=5"
    ).to_return(status: 200,
                body: { results: [{ id: id, name: text_name }] }.to_json)
  end

  # A place iNat gives a box for is accepted only when that box meets
  # the MO location's.
  def stub_place(query, id, bounds)
    geojson = { "coordinates" => [[bounds]] }
    stub_request(
      :get,
      "#{Inat::Constants::API_BASE}/places/autocomplete?" \
      "q=#{ERB::Util.url_encode(query)}"
    ).to_return(
      status: 200,
      body: { results: [{ id: id, name: query,
                          bounding_box_geojson: geojson }] }.to_json
    )
  end

  def burbank_bounds
    burbank = locations(:burbank)
    [[burbank.west, burbank.south], [burbank.east, burbank.north]]
  end

  def test_a_project_with_no_constraints_has_no_params
    assert_empty(Inat::ConstraintMapper.new(projects(:eol_project)).params)
  end

  def test_target_names_become_taxon_ids
    stub_taxon("Coprinus comatus", 47_347)
    stub_taxon("Agaricus campestris", 48_701)
    stub_place("Burbank", 1, burbank_bounds)

    params = Inat::ConstraintMapper.new(@project).params

    assert_equal("47347,48701", params[:taxon_id])
  end

  # Unresolved names leave MO's own fungi-and-slime-moulds filter, so a
  # search is never opened up to every taxon on iNat.
  def test_unresolved_names_fall_back_to_the_importable_taxa
    stub_json("taxa", [])
    stub_json("places", [])
    mapper = Inat::ConstraintMapper.new(@project)
    params = mapper.params

    assert_equal(Inat::Constants::IMPORTABLE_TAXON_IDS_ARG, params[:taxon_id])
    assert_equal(["Coprinus comatus", "Agaricus campestris"],
                 mapper.unresolved_names)
  end

  def test_target_locations_become_place_ids
    stub_json("taxa", [])
    stub_place("Burbank", 962, burbank_bounds)

    params = Inat::ConstraintMapper.new(@project).params

    assert_equal("962", params[:place_id])
  end

  # Kingston, Rhode Island is not Kingston, Jamaica: a place whose box
  # misses the MO location's is no answer at all.
  def test_a_place_elsewhere_is_rejected
    stub_json("taxa", [])
    stub_place("Burbank", 962, [[100.0, 10.0], [101.0, 11.0]])
    mapper = Inat::ConstraintMapper.new(@project)
    params = mapper.params

    assert_nil(params[:place_id])
    assert_equal(["Burbank, California, USA"], mapper.unresolved_locations)
  end

  def test_the_project_box_and_dates
    project = projects(:eol_project)
    project.update!(location: locations(:burbank),
                    start_date: Date.parse("2026-08-01"),
                    end_date: Date.parse("2026-08-08"))
    stub_json("taxa", [])
    stub_json("places", [])

    params = Inat::ConstraintMapper.new(project).params

    assert_equal(locations(:burbank).south, params[:swlat])
    assert_equal(locations(:burbank).east, params[:nelng])
    assert_equal(Date.parse("2026-08-01"), params[:d1])
    assert_equal(Date.parse("2026-08-08"), params[:d2])
  end

  # The mapping is the same wherever a name is targeted, so it is asked
  # for once and remembered. The test environment caches nothing, so
  # this one supplies a store of its own.
  def test_a_resolved_name_is_not_looked_up_twice
    stub_taxon("Coprinus comatus", 47_347)
    stub_taxon("Agaricus campestris", 48_701)
    stub_place("Burbank", 1, burbank_bounds)

    with_memory_cache do
      2.times { Inat::ConstraintMapper.new(@project).params }
    end

    assert_requested(:get, inat_api_matcher("taxa"), times: 2)
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  # iNat writes an infraspecific name without MO's rank marker, so the
  # stripped spelling is tried when the full one finds nothing.
  def test_a_name_without_its_rank_marker
    project = projects(:eol_project)
    project.add_target_name(names(:amanita_boudieri_var_beillei))
    stub_taxon_miss("Amanita boudieri var. beillei")
    stub_taxon("Amanita boudieri beillei", 352_461)

    params = Inat::ConstraintMapper.new(project).params

    assert_equal("352461", params[:taxon_id])
  end

  # MO abbreviates a county where iNat writes it out.
  def test_a_county_written_out
    project = projects(:eol_project)
    project.add_target_location(locations(:elgin_co))
    stub_json("taxa", [])
    stub_place_miss("Elgin Co.")
    stub_place("Elgin County", 7_898, elgin_bounds)

    params = Inat::ConstraintMapper.new(project).params

    assert_equal("7898", params[:place_id])
  end

  def elgin_bounds
    elgin = locations(:elgin_co)
    [[elgin.west, elgin.south], [elgin.east, elgin.north]]
  end

  def stub_taxon_miss(text_name)
    stub_request(
      :get,
      "#{Inat::Constants::API_BASE}/taxa?q=#{ERB::Util.url_encode(text_name)}" \
      "&per_page=5"
    ).to_return(status: 200, body: { results: [] }.to_json)
  end

  def stub_place_miss(query)
    stub_request(
      :get,
      "#{Inat::Constants::API_BASE}/places/autocomplete?" \
      "q=#{ERB::Util.url_encode(query)}"
    ).to_return(status: 200, body: { results: [] }.to_json)
  end
end
