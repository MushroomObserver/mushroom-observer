# frozen_string_literal: true

require("test_helper")
require("set")

module Locations
  class DescriptionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    ##########################################################################
    #
    #    SHOW

    def test_show_location_description
      # happy path
      desc = location_descriptions(:albion_desc)
      login
      get(:show, params: { id: desc.id })
      assert_template("show")
      assert_template("show/_location_description")

      # Unhappy paths
      # Prove they flash an error and redirect to the appropriate page

      # description is private and belongs to a project
      desc = location_descriptions(:bolete_project_private_location_desc)
      get(:show_location_description, params: { id: desc.id })
      assert_flash_error
      assert_redirected_to(project_path(desc.project.id))

      # description is private, for a project, project doesn't exist
      # but project doesn't existb
      desc = location_descriptions(:non_ex_project_private_location_desc)
      get(:show_location_description, params: { id: desc.id })
      assert_flash_error
      assert_redirected_to(action: :show_location, id: desc.location_id)

      # description is private, not for a project
      desc = location_descriptions(:user_private_location_desc)
      get(:show_location_description, params: { id: desc.id })
      assert_flash_error
      assert_redirected_to(action: :show_location, id: desc.location_id)
    end

    ############################################################################
    #
    #    INDEX

    def test_list_location_descriptions
      login("mary")
      burbank = locations(:burbank)
      burbank.description = LocationDescription.create!(
        location_id: burbank.id,
        source_type: "public"
      )
      get(:index)
      assert_template("index")
    end

    def test_location_descriptions_by_author
      desc = location_descriptions(:albion_desc)
      login
      get(:index, params: { by_author: rolf.id })
      assert_redirected_to(
        %r{/locations/descriptions/#{desc.id}}
      )
    end

    def test_location_descriptions_by_editor
      login
      get(:index, params: { by_editor: rolf.id })
      assert_template("index")
    end

    ############################################################################
    #
    #    NEW

    def test_create_location_description
      loc = locations(:albion)
      requires_login(:create_location_description, id: loc.id)
      assert_form_action(action: :create_location_description, id: loc.id)
    end

    def test_create_and_save_location_description
      loc = locations(:nybg_location) # use a location that has no description
      assert_nil(loc.description,
                 "Test should use a location that has no description.")
      params = { description: { source_type: "public",
                                source_name: "",
                                project_id: "",
                                public_write: "1",
                                public: "1",
                                license_id: "3",
                                gen_desc: "nifty botanical garden",
                                ecology: "varied",
                                species: "all",
                                notes: "FunDiS participant",
                                refs: "" },
                 id: loc.id }

      post_requires_login(:create_location_description, params)

      assert_redirected_to(location_description_path(loc.descriptions.last.id))
      assert_not_empty(loc.descriptions)
      assert_equal(params[:description][:notes], loc.descriptions.last.notes)
    end

    def test_unsuccessful_create_location_description
      loc = locations(:albion)
      user = login(users(:spammer).name)
      assert_false(user.successful_contributor?)
      get(:create_location_description, params: { id: loc.id })
      assert_response(:redirect)
    end

    def test_edit_location_description
      desc = location_descriptions(:albion_desc)
      requires_login(:edit_location_description, { id: desc.id })
      assert_form_action(action: :edit_location_description, id: desc.id)
    end

    def test_edit_and_save_location_description
      loc = locations(:albion) # use a location that has no description
      assert_not_nil(loc.description,
                     "Test should use a location that has a description.")
      params = { description: { source_type: "public",
                                source_name: "",
                                project_id: "",
                                public_write: "1",
                                public: "1",
                                license_id: licenses(:ccwiki30).id.to_s,
                                gen_desc: "research station",
                                ecology: "redwood",
                                species: "redwood zone",
                                notes: "church camp",
                                refs: "" },
                 id: location_descriptions(:albion_desc).id }

      post_requires_login(:edit_location_description, params)

      assert_redirected_to(location_description_path(loc.descriptions.last.id))
      assert_not_empty(loc.descriptions)
      assert_equal(params[:description][:notes], loc.descriptions.last.notes)
    end

    ############################################################################
    #
    #    EDIT
  end
end
