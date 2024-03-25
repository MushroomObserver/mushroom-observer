# frozen_string_literal: true

require("test_helper")

module Authors
  # test of actions to manage who's a author of an object
  class ReviewsControllerTest < FunctionalTestCase
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
      assert_template(:show)

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
      assert_template(:show)

      # Rolf giveth with one hand...
      post(:create, params: params.merge(add: mary.id))
      assert_redirected_to(description_authors_path)
      desc.reload
      assert_user_arrays_equal([mary, rolf], desc.authors, :sort)

      # ...and taketh with the other.
      delete(:destroy, params: params.merge(remove: mary.id))
      assert_redirected_to(description_authors_path)
      desc.reload
      assert_user_arrays_equal([rolf], desc.authors)
    end

    def test_review_name
      name = names(:peltigera)
      desc = name.description

      params = { id: desc.id, type: "NameDescription" }

      # Make sure it lets reviewers get to page.
      requires_login(:show, params)
      assert_template(:show)

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
      assert_template(:show)

      # Rolf giveth with one hand...
      post(:create, params: params.merge(add: mary.id))
      assert_redirected_to(description_authors_path)
      assert_user_arrays_equal([mary, rolf], desc.reload.authors, :sort)

      # ...and taketh with the other.
      delete(:destroy, params: params.merge(remove: mary.id))
      assert_redirected_to(description_authors_path)
      assert_user_arrays_equal([rolf], desc.reload.authors)
    end
  end
end
