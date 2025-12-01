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
      assert_select("#names_search_form")
    end

    def test_new_names_search_turbo
      login
      get(:new, format: :turbo_stream)
      assert_select("#names_search_form")
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
      # Form normalizes rank range to [low, high] order
      assert_select("select#query_names_rank", selected: "Form")
      assert_select("select#query_names_rank_range", selected: "Species")
      assert_equal(session[:search_type], :names)
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
        misspellings: :either,
        created_at: "2007"
      }
      post(:create, params: { query_names: params })

      # The controller joins :rank and :rank_range into an array.
      # Query validation turns :lookup into an array.
      validated_params = {
        names: {
          lookup: ["Agaricus campestris"],
          include_synonyms: true
        },
        rank: %w[Species Genus],
        misspellings: :either,
        created_at: %w[2007-01-01 2007-12-31]
      }
      assert_redirected_to(controller: "/names", action: :index,
                           params: { q: { model: :Name, **validated_params } })
    end

    # ---------------------------------------------------------------
    #  Range value ordering tests
    #  Ensure that range values are sorted correctly regardless of input order
    # ---------------------------------------------------------------

    def test_create_with_rank_range_reversed
      # Submit with higher rank first (Genus), lower rank second (Species)
      # In Name.all_ranks, Form < Species < Genus, so Genus has higher index
      login
      params = {
        rank: "Genus", # higher rank (index 8)
        rank_range: "Species" # lower rank (index 3)
      }
      post(:create, params: { query_names: params })

      # Should be sorted as [lower, higher] = ["Species", "Genus"]
      assert_redirected_to(
        controller: "/names", action: :index,
        params: {
          q: { model: :Name, rank: %w[Species Genus] }
        }
      )
    end

    def test_create_with_rank_range_correct_order
      # Submit with lower rank first (Form), higher rank second (Species)
      login
      params = {
        rank: "Form",         # lower rank (index 0)
        rank_range: "Species" # higher rank (index 3)
      }
      post(:create, params: { query_names: params })

      # Should remain as ["Form", "Species"]
      assert_redirected_to(
        controller: "/names", action: :index,
        params: {
          q: { model: :Name, rank: %w[Form Species] }
        }
      )
    end

    # ---------------------------------------------------------------
    #  Rank range prefill tests
    #  Form should always display [low, high] order regardless of query order
    # ---------------------------------------------------------------

    def test_prefill_rank_range_normalizes_to_low_high_order
      # Even if query stores [high, low], form should display [low, high]
      login
      # Query stores reversed order: ["Species", "Form"] (high to low)
      query = @controller.find_or_create_query(
        :Name,
        rank: %w[Species Form]
      )
      assert(query.id)
      get(:new)

      # Form should normalize to [low, high] order:
      # Form (lower rank) should be in the first select
      assert_select("select#query_names_rank", selected: "Form")
      # Species (higher rank) should be in the range select
      assert_select("select#query_names_rank_range", selected: "Species")
    end
  end
end
