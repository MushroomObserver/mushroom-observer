# frozen_string_literal: true

require("test_helper")

# Controller tests for author pages
class AuthorsControllerTest < FunctionalTestCase
  def test_email_request
    id = name_descriptions(:coprinus_comatus_desc).id
    requires_login(:email_request, id: id, type: :name_description)
    assert_form_action(action: :email_request, id: id,
                       type: :name_description)

    id = location_descriptions(:albion_desc).id
    requires_login(:email_request, id: id, type: :location_description)
    assert_form_action(action: :email_request, id: id,
                       type: :location_description)

    params = {
      id: name_descriptions(:coprinus_comatus_desc).id,
      type: :name_description,
      email: {
        subject: "Author request subject",
        message: "Message for authors"
      }
    }
    post_requires_login(:email_request, params)
    assert_redirected_to(
      controller: :name,
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
    post_requires_login(:email_request, params)
    assert_redirected_to(controller: :location,
                         action: :show_location_description,
                         id: location_descriptions(:albion_desc).id)
    assert_flash_text(:request_success.t)
  end

  def test_review_locations
    desc = location_descriptions(:albion_desc)
    params = { id: desc.id, type: "LocationDescription" }
    desc.authors.clear
    assert_user_list_equal([], desc.reload.authors)

    # Make sure it lets Rolf and only Rolf see this page.
    assert_not(mary.in_group?("reviewers"))
    assert(rolf.in_group?("reviewers"))
    requires_user(:review,
                  [{ controller: :location,
                     action: :show_location,
                     id: desc.location_id }],
                  params)
    assert_template(:review)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    rolf.reload
    assert_not(rolf.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review, params: params)
    assert_redirected_to(controller: :location,
                         action: :show_location,
                         id: locations(:albion).id)

    # Make Rolf an author.
    desc.add_author(rolf)
    desc.save
    desc.reload
    assert_user_list_equal([rolf], desc.authors)

    # Rolf should be able to do it now.
    get(:review, params: params)
    assert_template(:review)

    # Rolf giveth with one hand...
    post(:review, params: params.merge(add: mary.id))
    assert_template(:review)
    desc.reload
    assert_user_list_equal([mary, rolf], desc.authors, :sort)

    # ...and taketh with the other.
    post(:review, params: params.merge(remove: mary.id))
    assert_template(:review)
    desc.reload
    assert_user_list_equal([rolf], desc.authors)
  end

  def test_review_name
    name = names(:peltigera)
    desc = name.description

    params = { id: desc.id, type: "NameDescription" }

    # Make sure it lets reviewers get to page.
    requires_login(:review, params)
    assert_template(:review)

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(rolf)
    assert_not(rolf.reload.in_group?("reviewers"))

    # Make sure it fails to let unauthorized users see page.
    get(:review, params: params)
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)

    # Make Rolf an author.
    desc.add_author(rolf)
    assert_user_list_equal([rolf], desc.reload.authors)

    # Rolf should be able to do it again now.
    get(:review, params: params)
    assert_template(:review)

    # Rolf giveth with one hand...
    post(:review, params: params.merge(add: mary.id))
    assert_template(:review)
    assert_user_list_equal([mary, rolf], desc.reload.authors, :sort)

    # ...and taketh with the other.
    post(:review, params: params.merge(remove: mary.id))
    assert_template(:review)
    assert_user_list_equal([rolf], desc.reload.authors)
  end

end
