# frozen_string_literal: true

require("test_helper")

# ------------------------------------------------------------
#  Herbaria search
# ------------------------------------------------------------
module Herbaria
  class SearchControllerTest < FunctionalTestCase
    def test_new_herbaria_search
      login
      get(:new)
    end

    def test_new_herbaria_search_turbo
      login
      get(:new, format: :turbo_stream)
      assert_template("shared/_search_form")
    end

    def test_new_herbaria_search_form_prefilled_from_existing_query
      login
      query = @controller.find_or_create_query(
        :Herbarium,
        by_users: [users(:mary).id, users(:katrina).id],
        name_has: "Rolf",
        description_has: "Something",
        nonpersonal: false
      )
      assert(query.id)
      assert_equal(query.id, session[:query_record])
      get(:new)
      assert_select("textarea#query_herbaria_by_users",
                    text: "Mary Newbie\nKatrina")
      assert_select("input#query_herbaria_name_has", value: "Rolf")
      assert_select("input#query_herbaria_description_has", value: "Something")
      assert_select("select#query_herbaria_nonpersonal", selected: nil)
    end

    def test_create_herbaria_search
      login
      params = {
        code_has: "No",
        nonpersonal: true,
        mailing_address_has: "Oregon, USA"
      }
      post(:create, params: { query_herbaria: params })

      validated_params = params
      assert_redirected_to(
        controller: "/herbaria", action: :index,
        params: { q: { model: :Herbarium, **validated_params } }
      )
    end
  end
end
