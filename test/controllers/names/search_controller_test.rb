# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Names search
# ------------------------------------------------------------
module Names
  class SearchControllerTest < FunctionalTestCase
    def test_show_help
      login
      get(:show)
      assert_template("names/search/_help")
    end

    def test_show_help_turbo
      login
      get(:show, format: :turbo_stream)
      assert_template("names/search/_help")
    end

    def test_new_names_search
      login
      get(:new)
      assert_template("names/search/new")
      assert_template("shared/_search_form")
    end

    def test_new_names_search_turbo
      login
      get(:new, format: :turbo_stream)
      assert_template("shared/_search_form")
    end

    def test_new_names_search_form_prefilled_from_existing_query
      login
      query = @controller.find_or_create_query(
        :Name,
        names: { lookup: "petigera", include_synonyms: true },
        misspellings: :either,
        has_classification: true, author_has: "Pers.",
        rank: %w[Species Form]
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("textarea#query_names_names_lookup", text: "petigera")
      assert_select("select#query_names_names_include_synonyms",
                    selected: "yes")
      assert_select("select#query_names_misspellings", selected: "either")
      assert_select("select#query_names_has_classification", selected: "yes")
      assert_select("input#query_names_author_has", value: "Pers.")
      assert_select("select#query_names_rank", selected: "Species")
      assert_select("select#query_names_rank_range", selected: "Form")
    end

    def test_create_names_search
      login
      params = {
        has_classification: true,
        classification_has: names(:agaricus_campestris).classification,
        misspellings: :either
      }
      post(:create, params: { query_names: params })

      assert_redirected_to(controller: "/names", action: :index,
                           params: { q: { model: :Name, **params } })
    end

    def test_create_names_search_nested
      login
      params = {
        names: {
          lookup: "Agaricus campestris",
          include_synonyms: true
        },
        rank: :Species,
        rank_range: :Genus,
        misspellings: :either
      }
      post(:create, params: { query_names: params })

      # The controller joins :rank and :rank_range into an array.
      # Query validation turns :lookup into an array.
      validated_params = {
        names: {
          lookup: ["Agaricus campestris"],
          include_synonyms: true
        },
        rank: [:Species, :Genus],
        misspellings: :either
      }
      assert_redirected_to(controller: "/names", action: :index,
                           params: { q: { model: :Name, **validated_params } })
    end
  end
end
