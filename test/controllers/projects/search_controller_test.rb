# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Locations search
# ------------------------------------------------------------
module Projects
  class SearchControllerTest < FunctionalTestCase
    def test_new_projects_search
      login
      get(:new)
    end

    def test_new_projects_search_turbo
      login
      get(:new, format: :turbo_stream)
      assert_template("shared/_search_form")
    end

    def test_new_projects_search_form_prefilled_from_existing_query
      login
      query = @controller.find_or_create_query(
        :Project,
        members: [users(:mary).id, users(:katrina).id],
        title_has: "Symbiota",
        has_summary: true,
        has_observations: true
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("textarea#query_projects_members",
                    text: "Mary Newbie\nKatrina")
      assert_select("input#query_projects_title_has", value: "Symbiota")
      assert_select("select#query_projects_has_summary", selected: "yes")
      assert_select("select#query_projects_has_observations", selected: "yes")
    end

    def test_create_projects_search
      login
      params = {
        title_has: "Symbiota",
        has_observations: true
      }
      post(:create, params: { query_projects: params })

      assert_redirected_to(controller: "/projects", action: :index,
                           params: { q: { model: :Project, **params } })
    end
  end
end
