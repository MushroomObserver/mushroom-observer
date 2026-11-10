# frozen_string_literal: true

require("test_helper")

class InatPageParserTest < UnitTestCase
  def test_inat_username_required
    import = inat_imports(:ollie_inat_import)
    assert_raises(ArgumentError) do
      Inat::PageParser.new(import)
    end
  end

  def test_id_list_is_sent_in_chunks_above_the_cursor
    parser = id_list_parser("5, 1, 4, 2, 3", per_page: 2)
    requested = stub_observations { |ids| ids.map { |id| { id: id } } }

    assert_equal([1, 2], ids_of(parser.next_page))
    assert(parser.more_pages?(nil))
    parser.last_import_id = 2
    assert_equal([3, 4], ids_of(parser.next_page))
    parser.last_import_id = 4
    page = parser.next_page

    assert_equal([5], ids_of(page))
    assert_equal(1, page["total_results"],
                 "The count is the listed ids still ahead")
    parser.last_import_id = 5
    assert_not(parser.more_pages?(page))
    assert_equal(%w[1,2 3,4 5], requested)
  end

  # Ids iNat filters out (not fungi, say) return an empty page; the
  # parser moves past them instead of ending the import.
  def test_a_chunk_with_no_results_is_skipped
    parser = id_list_parser("1, 2, 3, 4", per_page: 2)
    requested = stub_observations do |ids|
      ids.select { |id| id > 2 }.map { |id| { id: id } }
    end

    assert_equal([3, 4], ids_of(parser.next_page))
    assert_equal(%w[1,2 3,4], requested)
  end

  def test_an_id_list_with_no_results_ends_with_an_empty_page
    parser = id_list_parser("1, 2", per_page: 2)
    stub_observations { [] }

    page = parser.next_page

    assert_equal(0, page["total_results"])
    assert_empty(page["results"])
  end

  private

  def id_list_parser(ids, per_page:)
    import = inat_imports(:rolf_inat_import)
    import.update!(inat_ids: ids, token: "MockJWT")
    Inat::PageParser.new(import, per_page: per_page)
  end

  # Stubs iNat's observation search, answering with the results the
  # block builds from the requested ids. Returns the `id` param of each
  # request, in order.
  def stub_observations
    requested = []
    stub_request(:get, %r{api\.inaturalist\.org/v1/observations}).
      to_return do |request|
        ids = Rack::Utils.parse_query(URI(request.uri.to_s).query)["id"]
        requested << ids
        results = yield(ids.split(",").map(&:to_i))
        { status: 200,
          body: { total_results: results.size, page: 1, per_page: 2,
                  results: results }.to_json }
      end
    requested
  end

  def ids_of(page)
    page["results"].pluck("id")
  end
end
