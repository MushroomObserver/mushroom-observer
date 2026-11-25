# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module Observations
  class ImagesControllerTest < FunctionalTestCase
    def test_edit_image
      image = images(:connected_coprinus_comatus_image)
      params = { "id" => image.id.to_s }
      assert_equal("rolf", image.user.login)
      requires_user(:edit,
                    { controller: "/images", action: :show, id: image.id },
                    params)
      assert_form_action(action: :update, id: image.id.to_s)
    end

    def test_update_image
      image = images(:agaricus_campestris_image)
      obs = image.observations.first
      assert(obs)
      assert_not_nil(obs.rss_log)
      new_name = "new nāme.jpg"

      params = {
        "id" => image.id,
        "image" => {
          "when(1i)" => "2001",
          "when(2i)" => "5",
          "when(3i)" => "12",
          "copyright_holder" => "Rolf Singer",
          "notes" => "",
          "original_name" => new_name
        }
      }
      put_requires_login(:update, params)
      # A same-URL 200 render on a Turbo-enabled form hangs Turbo
      # Drive, so the update success branch redirects to the image's
      # show page rather than rendering it in place.
      assert_redirected_to(image_path(image.id))
      assert_equal(10, rolf.reload.contribution)

      assert(obs.reload.rss_log)
      assert(obs.rss_log.notes.include?("log_image_updated"))
      assert(obs.rss_log.notes.include?("user #{obs.user.login}"))
      assert(
        obs.rss_log.notes.include?("name ##{image.id}")
      )
      assert_equal(new_name, image.reload.original_name)
    end

    def test_update_image_no_changes
      image = images(:agaricus_campestris_image)
      params = {
        "id" => image.id,
        "image" => {
          "when(1i)" => image.when.year.to_s,
          "when(2i)" => image.when.month.to_s,
          "when(3i)" => image.when.day.to_s,
          "copyright_holder" => image.copyright_holder,
          "notes" => image.notes,
          "original_name" => image.original_name,
          "license" => image.license
        }
      }

      put_requires_login(:update, params)

      assert_flash(:runtime_no_changes,
                   on_fail: "Flash should say no changes " \
                            "if no changes made when editing image")
    end

    # Prove that user can remove image from project
    # by updating image without changes
    def test_update_image_unchanged_remove_from_project
      project = projects(:bolete_project)
      assert(project.images.present?,
             "Test needs Project fixture that has an Image")
      image = project.images.first
      user = image.user
      # `project_ids: [""]` is the sentinel-only submission — the
      # form's hidden sentinel ensures the key is present in params
      # even when every checkbox is unchecked. The controller's
      # `compact_blank` strips the empty, leaving `[]` → remove all.
      params = {
        "id" => image.id,
        "image" => {
          "when(1i)" => image.when.year.to_s,
          "when(2i)" => image.when.month.to_s,
          "when(3i)" => image.when.day.to_s,
          "copyright_holder" => image.copyright_holder,
          "notes" => image.notes,
          "original_name" => image.original_name,
          "license" => image.license,
          project_ids: [""]
        }
      }
      login(user.login)

      put(:update, params: params)

      assert(project.reload.images.exclude?(image),
             "Failed to remove image from project")
    end

    # Mirrors test_update_image_unchanged_remove_from_project but
    # tests the ADD branch in `attach_images_to_projects_and_flash_
    # notices`. The user adds the image to a project they're a
    # member of by submitting `project_ids: [<id>]` for a project
    # the image isn't yet in.
    def test_update_image_unchanged_add_to_project
      project = projects(:eol_project)
      user = users(:rolf) # member of eol_project
      image = images(:commercial_inquiry_image) # rolf's, no projects
      assert(user.projects_member.include?(project))
      assert_empty(image.projects, "Test wants image with no projects yet")

      params = {
        "id" => image.id,
        "image" => {
          "when(1i)" => image.when.year.to_s,
          "when(2i)" => image.when.month.to_s,
          "when(3i)" => image.when.day.to_s,
          "copyright_holder" => image.copyright_holder,
          "notes" => image.notes,
          "original_name" => image.original_name,
          "license" => image.license,
          project_ids: [project.id.to_s]
        }
      }
      login(user.login)

      put(:update, params: params)

      assert(project.reload.images.include?(image),
             "Failed to add image to project")
    end

    def test_update_image_save_fail
      image = images(:turned_over_image)
      assert_not_empty(image.projects,
                       "Use Image fixture with a Project for best coverage")
      params = {
        "id" => image.id,
        "image" => {
          "when(1i)" => "2001",
          "when(2i)" => "5",
          "when(3i)" => "12",
          "copyright_holder" => "Rolf Singer",
          "notes" => "",
          "original_name" => "new name"
        }
      }

      login(image.user.login)
      # Simulate image save failure. `find_or_goto_index` uses
      # `Image.find_by` (Image has no `show_includes` scope), so stub
      # find_by to surface our save-mocked instance.
      image.stub(:save, false) do
        Image.stub(:find_by, image) do
          put(:update, params: params)
        end
      end

      assert_page_title("Edit Image",
                        "It should return to form if image save fails")
      assert_unprocessable
      assert_select("form[data-turbo='true']")
    end

    # Appear on both observations/images/new and images/edit
    # TODO: Move to integration test or move edit to this controller
    def test_project_checkboxes
      proj1 = projects(:eol_project)
      proj2 = projects(:bolete_project)
      obs1 = observations(:minimal_unknown_obs)
      obs2 = observations(:detailed_unknown_obs)
      img1 = images(:in_situ_image)
      img2 = images(:commercial_inquiry_image)
      assert_users_equal(mary, obs1.user)
      assert_users_equal(mary, obs2.user)
      assert_users_equal(mary, img1.user)
      assert_users_equal(rolf, img2.user)
      assert_obj_arrays_equal([],      obs1.projects)
      assert_obj_arrays_equal([proj2], obs2.projects)
      assert_obj_arrays_equal([proj2], img1.projects)
      assert_obj_arrays_equal([],      img2.projects)
      # Membership order isn't guaranteed; compare as sets.
      assert_obj_arrays_equal([rolf, mary, katrina], proj1.user_group.users,
                              :sort)
      assert_obj_arrays_equal([mary, dick], proj2.user_group.users, :sort)

      # NOTE: It is impossible, apparently, to get edit_image to fail,
      # so there is no way to test init_project_vars_for_reload().

      login("rolf")
      get(:edit, params: { id: img1.id })
      assert_response(:redirect)
      get(:edit, params: { id: img2.id })
      assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)

      login("mary")
      get(:edit, params: { id: img1.id })
      assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
      get(:edit, params: { id: img2.id })
      assert_response(:redirect)

      login("dick")
      get(:edit, params: { id: img1.id })
      assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
      get(:edit, params: { id: img2.id })
      assert_response(:redirect)
      proj1.add_image(img1)
      get(:edit, params: { id: img1.id })
      assert_project_checks(proj1.id => :checked_but_disabled,
                            proj2.id => :checked)
    end

    def assert_project_checks(project_states)
      project_states.each do |id, state|
        assert_checkbox_state("image_project_ids_#{id}", state)
      end
    end
  end
end
