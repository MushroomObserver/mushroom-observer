# frozen_string_literal: true

require("test_helper")

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
      assert_template("descriptions/_description_details_and_alts_panel")

      # Unhappy paths
      # Prove they flash an error and redirect to the appropriate page

      # description is private and belongs to a project
      desc = location_descriptions(:bolete_project_private_location_desc)
      get(:show, params: { id: desc.id })
      assert_flash_error
      assert_redirected_to(project_path(desc.project.id))

      # description is private, for a project, project doesn't exist
      # but project doesn't existb
      desc = location_descriptions(:non_ex_project_private_location_desc)
      get(:show, params: { id: desc.id })
      assert_flash_error
      assert_redirected_to(location_path(desc.location_id))

      # description is private, not for a project
      desc = location_descriptions(:user_private_location_desc)
      get(:show, params: { id: desc.id })
      assert_flash_error
      assert_redirected_to(location_path(desc.location_id))
    end

    ############################################################################
    #
    #    INDEX

    def test_index_default_sort_order
      login
      get(:index)

      assert_page_title(:LOCATION_DESCRIPTIONS.l)
    end

    def test_index_with_non_default_sort
      check_index_sorting
    end

    def test_index_with_id
      desc = location_descriptions(:albion_desc)

      login
      get(:index, params: { id: desc.id })

      assert_page_title(:LOCATION_DESCRIPTIONS.l)
      assert_select("body.descriptions__index", true)
    end

    def test_index_by_author_of_one_description
      desc = location_descriptions(:albion_desc)
      user = users(:rolf)
      assert_equal(
        1,
        LocationDescription.joins(:authors).where(user: user).count,
        "Test needs a user who authored exactly one description"
      )

      login
      get(:index, params: { by_author: user.id })

      assert_redirected_to(/#{location_description_path(desc)}/)
    end

    # Prevent reversion of error. See PR #1358
    def test_index_by_author_of_one_description_different_user_logged_in
      desc = location_descriptions(:albion_desc)

      login("dick")
      get(:index, params: { by_author: rolf.id })

      assert_redirected_to(
        %r{/locations/descriptions/#{desc.id}}
      )
    end

    def test_index_by_author_of_multiple_descriptions
      user = users(:dick)
      descs_authored_by_user_count =
        LocationDescription.joins(:authors).where(user: user).count
      assert_operator(
        descs_authored_by_user_count, :>, 1,
        "Test needs a user who authored multiple descriptions"
      )

      login
      get(:index, params: { by_author: user.id })

      assert_template("index")
      assert_page_title(:LOCATION_DESCRIPTIONS.l)
      assert_displayed_filters("#{:query_by_author.l}: #{user.name}")
      assert_equal(
        assert_select("#results .list-group-item").count,
        descs_authored_by_user_count
      )
      assert_select("a:match('href',?)", %r{^/locations/descriptions/\d+},
                    { count: descs_authored_by_user_count },
                    "Wrong number of results")
    end

    def test_index_by_author_of_no_descriptions
      user = users(:zero_user)

      login
      get(:index, params: { by_author: user.id })

      assert_flash_text("No matching location descriptions found.")
      assert_template("index")
    end

    def test_index_by_author_bad_user_id
      bad_user_id = images(:in_situ_image).id
      assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

      login
      get(:index, params: { by_author: bad_user_id })

      assert_flash_text(
        :runtime_object_not_found.l(type: "user", id: bad_user_id)
      )
      assert_redirected_to(location_descriptions_index_path)
    end

    def test_index_by_editor_of_one_description
      user = users(:mary)
      # This ersatz factory is a work-around for the problem documented here:
      # https://www.pivotaltracker.com/story/show/184501787
      desc = location_descriptions(:albion_desc)
      desc.editors = [user]
      desc.save

      login
      get(:index, params: { by_editor: user })

      assert_redirected_to(
        %r{/locations/descriptions/#{desc.id}}
      )
    end

    def test_index_by_editor_of_multiple_descriptions
      user = users(:mary)
      # This ersatz factory is a work-around for the problem documented here:
      # https://www.pivotaltracker.com/story/show/184501787
      [location_descriptions(:albion_desc),
       location_descriptions(:no_mushrooms_location_desc)].each do |desc|
        desc.editors = [user]
        desc.save
      end
      descs_edited_by_user_count =
        LocationDescriptionEditor.where(user: user).count

      login
      get(:index, params: { by_editor: user.id })

      assert_template("index")
      assert_page_title(:LOCATION_DESCRIPTIONS.l)
      assert_displayed_filters("#{:query_by_editor.l}: #{user.name}")
      assert_select("a:match('href',?)", %r{^/locations/descriptions/\d+},
                    { count: descs_edited_by_user_count },
                    "Wrong number of results")
    end

    def test_index_by_editor_of_no_descriptions
      user = users(:zero_user)

      login
      get(:index, params: { by_editor: user.id })

      assert_flash_text("No matching location descriptions found.")
      assert_template("index")
    end

    def test_index_by_editor_bad_user_id
      bad_user_id = images(:in_situ_image).id
      # Above should ensure there's no user with that id. But just in case:
      assert_empty(User.where(id: bad_user_id), "Test needs different 'bad_id'")

      login
      get(:index, params: { by_editor: bad_user_id })

      assert_flash_text(
        :runtime_object_not_found.l(type: "user", id: bad_user_id)
      )
      assert_redirected_to(location_descriptions_index_path)
    end

    ############################################################################
    #
    #    NEW

    def test_create_location_description
      loc = locations(:albion)
      requires_login(:new, location_id: loc.id)
      assert_form_action(action: :create, location_id: loc.id)
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
                 location_id: loc.id }

      post_requires_login(:create, params)

      assert_redirected_to(location_description_path(loc.descriptions.last.id))
      assert_not_empty(loc.descriptions)
      assert_equal(params[:description][:notes], loc.descriptions.last.notes)
    end

    def test_unsuccessful_create_location_description
      loc = locations(:albion)
      user = login(users(:spammer).name)
      assert_false(user.successful_contributor?)
      get(:new, params: { location_id: loc.id })
      assert_response(:redirect)
    end

    ############################################################################
    #
    #    EDIT

    def test_edit_location_description
      desc = location_descriptions(:albion_desc)
      requires_login(:edit, { id: desc.id })
      assert_form_action(action: :update, id: desc.id)
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

      put_requires_login(:update, params)

      assert_redirected_to(location_description_path(loc.descriptions.last.id))
      assert_not_empty(loc.descriptions)
      assert_equal(params[:description][:notes], loc.descriptions.last.notes)
    end

    def test_next_description
      description = location_descriptions(:albion_desc)
      id = description.id
      object = LocationDescription.find(id)
      login
      get(:show, params: { flow: :next, id: })
      next_data = @controller.find_query_and_next_object(object, :next, id)
      if next_data
        params = { id: next_data[:id],
                   q: @controller.q_param(next_data[:query]) }
        assert_redirected_to(location_description_path(**params))
      end
    end

    def test_prev_description
      description = location_descriptions(:albion_desc)
      id = description.id
      object = LocationDescription.find(id)
      login
      get(:show, params: { flow: :prev, id: })
      prev_data = @controller.find_query_and_next_object(object, :prev, id)
      if prev_data
        params = { id: prev_data[:id],
                   q: @controller.q_param(prev_data[:query]) }
        assert_redirected_to(location_description_path(**params))
      end
    end

    def test_destroy_location_description
      desc = location_descriptions(:albion_desc)
      loc = desc.location
      login("rolf")

      delete(:destroy, params: { id: desc.id })

      assert_flash_success
      assert_redirected_to(location_path(loc.id))
      assert_nil(LocationDescription.safe_find(desc.id))
    end

    def test_destroy_location_description_not_admin
      desc = location_descriptions(:albion_desc)
      login("dick")

      delete(:destroy, params: { id: desc.id })

      assert_flash_error(:runtime_destroy_description_not_admin.t)
      assert(LocationDescription.safe_find(desc.id))
    end

    def test_update_description_no_changes
      desc = location_descriptions(:albion_desc)
      login("rolf")
      params = {
        id: desc.id,
        description: {
          gen_desc: desc.gen_desc,
          ecology: desc.ecology,
          species: desc.species
        }
      }
      put(:update, params: params)
      assert_flash_warning(:runtime_edit_location_description_no_change.t)
    end

    # Cover create with project source type
    def test_create_description_for_project
      loc = locations(:nybg_location)
      project = projects(:eol_project)

      login("mary") # project admin
      get(:new, params: { location_id: loc.id, project: project.id })

      assert_template("new")
      desc = assigns(:description)
      assert_equal("project", desc.source_type)
      assert_equal(project.title, desc.source_name)
    end

    # Cover create with project when not a member
    def test_create_description_for_project_not_member
      loc = locations(:nybg_location)
      project = projects(:eol_project)

      login("dick") # not a member
      get(:new, params: { location_id: loc.id, project: project.id })

      assert_flash_error
      assert_redirected_to(project_path(project.id))
    end

    # Cover create with source type
    def test_create_description_source_type
      loc = locations(:nybg_location)
      login("dick")

      params = {
        location_id: loc.id,
        description: {
          source_type: "source",
          source_name: "Local Guidebook",
          public: "0",
          public_write: "0",
          gen_desc: "Nice area"
        }
      }
      post(:create, params: params)

      assert_flash_success
      desc = LocationDescription.last
      assert_equal("source", desc.source_type)
      assert_equal("Local Guidebook", desc.source_name)
      assert_false(desc.public)
    end
  end
end
