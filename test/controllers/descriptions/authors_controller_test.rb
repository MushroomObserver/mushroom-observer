# frozen_string_literal: true

require("test_helper")

module Descriptions
  # test of actions to manage who's a author of a description
  class AuthorsControllerTest < FunctionalTestCase
    def test_review_locations
      desc = location_descriptions(:albion_desc)
      params = { id: desc.id, type: "LocationDescription" }
      desc.authors.clear
      assert_user_arrays_equal([], desc.reload.authors)

      # Make sure it lets Rolf and only Rolf see this page.
      assert_not(mary.in_group?("reviewers"))
      assert(rolf.in_group?("reviewers"))
      login("rolf")
      requires_user(:show,
                    [{ controller: "/locations",
                       action: :show,
                       id: desc.location_id }],
                    params)
      assert_response(:success)

      # Remove Rolf from reviewers group.
      user_groups(:reviewers).users.delete(rolf)
      rolf.reload
      assert_not(rolf.in_group?("reviewers"))

      # Make sure it fails to let unauthorized users see page.
      get(:show, params: params)
      assert_redirected_to(location_path(id: locations(:albion).id))

      # Make Rolf an author.
      desc.add_author(rolf)
      desc.save
      desc.reload
      assert_user_arrays_equal([rolf], desc.authors)

      # Rolf should be able to do it now.
      get(:show, params: params)
      assert_response(:success)

      # Rolf giveth with one hand...
      post(:create, params: params.merge(add: mary.unique_text_name))
      assert_redirected_to(description_authors_path)
      desc.reload
      assert_user_arrays_equal([mary, rolf], desc.authors, :sort)

      # ...and taketh with the other.
      delete(:destroy, params: params.merge(remove: mary.id))
      assert_redirected_to(description_authors_path)
      desc.reload
      assert_user_arrays_equal([rolf], desc.authors)

      # Add via the namespaced FormObject param shape that the
      # add-author autocompleter form actually submits (the typed/
      # selected unique_text_name, not an id).
      post(:create,
           params: params.merge(
             description_author: { user: mary.unique_text_name }
           ))
      desc.reload
      assert_user_arrays_equal([mary, rolf], desc.authors, :sort)
    end

    def test_create_no_user
      desc = location_descriptions(:albion_desc)
      desc.add_author(rolf)
      login("rolf")

      post(:create,
           params: { id: desc.id, type: "LocationDescription",
                     add: "no such user" })

      assert_redirected_to(description_authors_path)
      assert_flash_error
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end

    def test_create_already_author
      desc = location_descriptions(:albion_desc)
      desc.add_author(rolf)
      login("rolf")

      post(:create,
           params: { id: desc.id, type: "LocationDescription",
                     add: rolf.unique_text_name })

      assert_redirected_to(description_authors_path)
      assert_flash_error
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end

    def test_destroy_not_an_author
      desc = location_descriptions(:albion_desc)
      desc.add_author(rolf)
      login("rolf")

      delete(:destroy,
             params: { id: desc.id, type: "LocationDescription",
                       remove: mary.id })

      assert_redirected_to(description_authors_path)
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end

    # Neither an author nor a reviewer -- create/destroy must deny the
    # same way show does, not just skip the UI and allow the mutation.
    def test_create_denied_for_non_author_non_reviewer
      desc = location_descriptions(:albion_desc)
      desc.add_author(rolf)
      user_groups(:reviewers).users.delete(mary)
      login("mary")

      post(:create,
           params: { id: desc.id, type: "LocationDescription",
                     add: mary.unique_text_name })

      assert_redirected_to(location_path(id: desc.location_id))
      assert_flash(:review_authors_denied)
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end

    def test_destroy_denied_for_non_author_non_reviewer
      desc = location_descriptions(:albion_desc)
      desc.add_author(rolf)
      user_groups(:reviewers).users.delete(mary)
      login("mary")

      delete(:destroy,
             params: { id: desc.id, type: "LocationDescription",
                       remove: rolf.id })

      assert_redirected_to(location_path(id: desc.location_id))
      assert_flash(:review_authors_denied)
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end

    def test_review_name
      name = names(:peltigera)
      desc = name.description

      params = { id: desc.id, type: "NameDescription" }

      # Make sure it lets reviewers get to page.
      requires_login(:show, params)
      assert_response(:success)

      # Remove Rolf from reviewers group.
      user_groups(:reviewers).users.delete(rolf)
      assert_not(rolf.reload.in_group?("reviewers"))

      # Make sure it fails to let unauthorized users see page.
      get(:show, params: params)
      assert_redirected_to(name_path(id: name.id))

      # Make Rolf an author.
      desc.add_author(rolf)
      assert_user_arrays_equal([rolf], desc.reload.authors)

      # Rolf should be able to do it again now.
      get(:show, params: params)
      assert_response(:success)

      # Rolf giveth with one hand...
      post(:create, params: params.merge(add: mary.unique_text_name))
      assert_redirected_to(description_authors_path)
      assert_user_arrays_equal([mary, rolf], desc.reload.authors, :sort)

      # ...and taketh with the other.
      delete(:destroy, params: params.merge(remove: mary.id))
      assert_redirected_to(description_authors_path)
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end
  end
end
