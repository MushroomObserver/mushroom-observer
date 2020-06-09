require "test_helper"

class Locations::DescriptionsControllerTest < FunctionalTestCase

  fixtures 'locations'

  def test_list_location_descriptions
    login("mary")
    burbank = locations(:burbank)
    burbank.description = Location::Description.create!(
      location_id: burbank.id,
      source_type: "public"
    )
    get_with_dump(:index)
    assert_template("index")
  end

  def test_location_descriptions_by_author
    descs = Location::Description.all
    desc = location_descriptions(:albion_desc)
    get_with_dump(:location_descriptions_by_author, id: rolf.id)
    assert_redirected_to(
      %r{/locations/show_location_description/#{desc.id}}
    )
  end

  def test_location_descriptions_by_editor
    get_with_dump(:location_descriptions_by_editor, id: rolf.id)
    assert_template(:index)
  end

  def test_show_location_description
    # happy path
    desc = location_descriptions(:albion_desc)
    get_with_dump(:show, id: desc.id)
    assert_template partial: "_show_description"
    assert_template partial: "_location_description"

    # Unhappy paths
    # Prove they flash an error and redirect to the appropriate page

    # description is private and belongs to a project
    desc = location_descriptions(:bolete_project_private_location_desc)
    get_with_dump(:show, id: desc.id)
    assert_flash_error
    assert_redirected_to(
      controller: "/projects",
      action: :show,
      id: desc.project.id
    )

    # description is private, for a project, project doesn't exist
    # but project doesn't exist
    desc = location_descriptions(:non_ex_project_private_location_desc)
    get_with_dump(:show, id: desc.id)
    assert_flash_error
    assert_redirected_to(controller: "/locations", action: :show,
                         id: desc.location_id)

    # description is private, not for a project
    desc = location_descriptions(:user_private_location_desc)
    get_with_dump(:show, id: desc.id)
    assert_flash_error
    assert_redirected_to(controller: "/locations", action: :show,
                         id: desc.location_id)
  end

  def test_show_past_location_description
    login("dick")
    desc = location_descriptions(:albion_desc)
    old_versions = desc.versions.length
    desc.update(gen_desc: "something new")
    desc.reload
    new_versions = desc.versions.length
    assert(new_versions > old_versions)
    get_with_dump(:show_past_location_description, id: desc.id)
    assert_template(:show_past_location_description,
                    partial: "_location_description")
  end

  # TODO model needs to be moved into subdirectory
  def test_create_location_description
    loc = locations(:albion)
    requires_login(:new, id: loc.id)
    assert_form_action(action: :create, id: loc.id)
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
                              notes: "NAMP participant",
                              refs: "" },
               id: loc.id }

    post_requires_login(:create, params)

    assert_redirected_to(action: :show, id: loc.descriptions.last.id)
    assert_not_empty(loc.descriptions)
    assert_equal(params[:description][:notes], loc.descriptions.last.notes)
  end

  def test_unsuccessful_create_location_description
    loc = locations(:albion)
    user = login(users(:spammer).name)
    assert_false(user.is_successful_contributor?)
    get_with_dump(:new, id: loc.id)
    assert_response(:redirect)
  end

  # TODO model needs to be moved into subdirectory
  def test_edit_location_description
    desc = location_descriptions(:albion_desc)
    requires_login(:edit, id: desc.id)
    assert_form_action(action: :edit, id: desc.id)
  end

  # TODO model needs to be moved into subdirectory
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

    post_requires_login(:edit, params)

    assert_redirected_to(controller: :locations,
                         action: :show,
                         id: loc.descriptions.last.id)
    assert_not_empty(loc.descriptions)
    assert_equal(params[:description][:notes], loc.descriptions.last.notes)
  end
end
