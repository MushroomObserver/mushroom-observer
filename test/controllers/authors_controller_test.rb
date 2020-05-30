require "test_helper"

class AuthorControllerTest < FunctionalTestCase

  # ------------------------------------------------------------
  #
  # ------------------------------------------------------------


  def test_author_request
    id = name_descriptions(:coprinus_comatus_desc).id
    requires_login(:author_request, id: id, type: :name_description)
    assert_form_action(action: :author_request, id: id,
                       type: :name_description)

    id = location_descriptions(:albion_desc).id
    requires_login(:author_request, id: id, type: :location_description)
    assert_form_action(action: :author_request, id: id,
                       type: :location_description)

    params = {
      id: name_descriptions(:coprinus_comatus_desc).id,
      type: :name_description,
      email: {
        subject: "Author request subject",
        message: "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_redirected_to(
      controller: :names,
      action: :show_name_description,
      id: name_descriptions(:coprinus_comatus_desc).id
    )
    assert_flash_text(:request_success.t)

    params = {
      id: location_descriptions(:albion_desc).id,
      type: :location_description,
      email: {
        subject: "Author request subject",
        message: "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_redirected_to(controller: :locations,
                         action: :show_location_description,
                         id: location_descriptions(:albion_desc).id)
    assert_flash_text(:request_success.t)
  end

  def test_review_authors_locations
    desc = location_descriptions(:albion_desc)
    params = { id: desc.id, type: "LocationDescription" }
    desc.authors.clear
    assert_user_list_equal([], desc.reload.authors)

    # Make sure it lets Rolf and only Rolf see this page.
    assert_not(mary.in_group?("reviewers"))
    assert(rolf.in_group?("reviewers"))
    requires_user(:review_authors,
                  [controller: :locations,
                   action: :show,
                   id: desc.location_id],
                  params)
    assert_template(:review_authors)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    rolf.reload
    assert_not(rolf.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params: params)
    assert_redirected_to(controller: :locations,
                         action: :show,
                         id: locations(:albion).id)

    # Make Rolf an author.
    desc.add_author(rolf)
    desc.save
    desc.reload
    assert_user_list_equal([rolf], desc.authors)

    # Rolf should be able to do it now.
    get(:review_authors, params: params)
    assert_template(:review_authors)

    # Rolf giveth with one hand...
    post(:review_authors, params: params.merge(add: mary.id))
    assert_template(:review_authors)
    desc.reload
    assert_user_list_equal([mary, rolf], desc.authors, :sort)

    # ...and taketh with the other.
    post(:review_authors, params: params.merge(remove: mary.id))
    assert_template(:review_authors)
    desc.reload
    assert_user_list_equal([rolf], desc.authors)
  end

  def test_review_authors_name
    name = names(:peltigera)
    desc = name.description

    params = { id: desc.id, type: "NameDescription" }

    # Make sure it lets reviewers get to page.
    requires_login(:review_authors, params)
    assert_template(:review_authors)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    assert_not(rolf.reload.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params: params)
    assert_redirected_to(controller: :names,
                         action: :show,
                         id: name.id)

    # Make Rolf an author.
    desc.add_author(rolf)
    assert_user_list_equal([rolf], desc.reload.authors)

    # Rolf should be able to do it again now.
    get(:review_authors, params: params)
    assert_template(:review_authors)

    # Rolf giveth with one hand...
    post(:review_authors, params: params.merge(add: mary.id))
    assert_template(:review_authors)
    assert_user_list_equal([mary, rolf], desc.reload.authors, :sort)

    # ...and taketh with the other.
    post(:review_authors, params: params.merge(remove: mary.id))
    assert_template(:review_authors)
    assert_user_list_equal([rolf], desc.reload.authors)
  end


end
