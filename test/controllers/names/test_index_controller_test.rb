# frozen_string_literal: true

require("test_helper")
require("set")

module Names
  class TestIndexControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def ids_from_links(links)
      links.map do |l|
        l.to_s.match(%r{.*/([0-9]+)})[1].to_i
      end
    end

    def pagination_query_params
      query = Query.lookup_and_save(:Name, :all, by: :name)
      @controller.query_params(query)
    end

    # None of our standard tests ever actually renders pagination_links
    # or pagination_letters.  This tests all the above.
    def test_pagination_page1
      # Straightforward index of all names, showing first 10.
      query_params = pagination_query_params
      login
      get(:test_index, params: { num_per_page: 10 }.merge(query_params))
      # print @response.body
      assert_template("names/index")
      name_links = css_select(".table a")
      assert_equal(10, name_links.length)
      expected = Name.all.order("sort_name, author").limit(10).to_a
      assert_equal(expected.map(&:id), ids_from_links(name_links))
      # assert_equal(@controller.url_with_query(action: "show",
      #  id: expected.first.id, only_path: true), name_links.first.url)
      url = @controller.url_with_query(action: "show",
                                       id: expected.first.id, only_path: true)
      assert_not_nil(name_links.first.to_s.index(url))
      assert_select("a", text: "1", count: 0)
      assert_link_in_html("2", action: :test_index, num_per_page: 10,
                               params: query_params, page: 2)
      assert_select("a", text: "Z", count: 0)
      assert_link_in_html("A", action: :test_index, num_per_page: 10,
                               params: query_params, letter: "A")
    end

    def test_pagination_page2
      # Now go to the second page.
      query_params = pagination_query_params
      login
      get(:test_index,
          params: { num_per_page: 10, page: 2 }.merge(query_params))
      assert_template("names/index")
      name_links = css_select(".table a")
      assert_equal(10, name_links.length)
      expected = Name.all.order("sort_name").limit(10).offset(10).to_a
      assert_equal(expected.map(&:id), ids_from_links(name_links))
      url = @controller.url_with_query(action: "show",
                                       id: expected.first.id, only_path: true)
      assert_not_nil(name_links.first.to_s.index(url))

      assert_select("a", text: "2", count: 0)
      assert_link_in_html("1", action: :test_index, num_per_page: 10,
                               params: query_params, page: 1)
      assert_select("a", text: "Z", count: 0)
      assert_link_in_html("A", action: :test_index, num_per_page: 10,
                               params: query_params, letter: "A")
    end

    def test_pagination_letter
      # Now try a letter.
      query_params = pagination_query_params
      l_names = Name.where("text_name LIKE 'L%'").order("text_name, author").to_a
      login
      get(:test_index, params: { num_per_page: l_names.size,
                                 letter: "L" }.merge(query_params))
      assert_template("names/index")
      assert_select("#content")
      name_links = css_select(".table a")
      assert_equal(l_names.size, name_links.length)
      assert_equal(Set.new(l_names.map(&:id)),
                   Set.new(ids_from_links(name_links)))

      url = @controller.url_with_query(action: "show",
                                       id: l_names.first.id, only_path: true)
      assert_not_nil(name_links.first.to_s.index(url))
      assert_select("a", text: "1", count: 0)
      assert_select("a", text: "Z", count: 0)

      assert_link_in_html("A", action: :test_index, params: query_params,
                               num_per_page: l_names.size, letter: "A")
    end

    def test_pagination_letter_with_page
      query_params = pagination_query_params
      l_names = Name.where("text_name LIKE 'L%'").order("text_name, author").to_a
      # Do it again, but make page size exactly one too small.
      l_names.pop
      login
      get(:test_index, params: { num_per_page: l_names.size,
                                 letter: "L" }.merge(query_params))
      assert_template("names/index")
      name_links = css_select(".table a")

      assert_equal(l_names.size, name_links.length)
      assert_equal(Set.new(l_names.map(&:id)),
                   Set.new(ids_from_links(name_links)))

      assert_select("a", text: "1", count: 0)

      assert_link_in_html("2", action: :test_index, params: query_params,
                               num_per_page: l_names.size,
                               letter: "L", page: 2)

      assert_select("a", text: "3", count: 0)
    end

    def test_pagination_letter_with_page_2
      query_params = pagination_query_params
      l_names = Name.where("text_name LIKE 'L%'").order("text_name, author").to_a
      last_name = l_names.pop
      # Check second page.
      login
      get(:test_index, params: { num_per_page: l_names.size, letter: "L",
                                 page: 2 }.merge(query_params))
      assert_template("names/index")
      name_links = css_select(".table a")
      assert_equal(1, name_links.length)
      assert_equal([last_name.id], ids_from_links(name_links))
      assert_select("a", text: "2", count: 0)
      assert_link_in_html("1", action: :test_index, params: query_params,
                               num_per_page: l_names.size,
                               letter: "L", page: 1)
      assert_select("a", text: "3", count: 0)
    end

    def test_pagination_with_anchors
      query_params = pagination_query_params
      # Some cleverness is required to get pagination links to include anchors.
      login
      get(:test_index, params: {
        num_per_page: 10,
        test_anchor: "blah"
      }.merge(query_params))
      assert_link_in_html("2", action: :test_index, num_per_page: 10,
                               params: query_params, page: 2,
                               test_anchor: "blah", anchor: "blah")
      assert_link_in_html("A", action: :test_index, num_per_page: 10,
                               params: query_params, letter: "A",
                               test_anchor: "blah", anchor: "blah")
    end
  end
end
