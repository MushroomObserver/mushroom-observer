# frozen_string_literal: true

require("test_helper")

class EmailsControllerTest < FunctionalTestCase
  def test_email_merge_request
    name1 = Name.all.sample
    name2 = Name.all.sample
    params = {
      type: :Name,
      old_id: name1.id,
      new_id: name2.id
    }

    get(:merge_request, params: params)
    assert_response(:redirect)

    login("rolf")
    get(:merge_request, params: params.except(:type))
    assert_response(:redirect)
    get(:merge_request, params: params.except(:old_id))
    assert_response(:redirect)
    get(:merge_request, params: params.except(:new_id))
    assert_response(:redirect)
    get(:merge_request, params: params.merge(type: :Bogus))
    assert_response(:redirect)
    get(:merge_request, params: params.merge(old_id: -123))
    assert_response(:redirect)
    get(:merge_request, params: params.merge(new_id: -456))
    assert_response(:redirect)

    get(:merge_request, params: params)
    assert_response(:success)
    assert_names_equal(name1, assigns(:old_obj))
    assert_names_equal(name2, assigns(:new_obj))
    url = "merge_request?new_id=#{name2.id}&old_id=#{name1.id}&type=Name"
    assert_select("form[action*='#{url}']", count: 1)
  end

  def test_email_merge_request_post
    email_count = ActionMailer::Base.deliveries.count
    name1 = Name.all.sample
    name2 = Name.all.sample
    params = {
      type: :Name,
      old_id: name1.id,
      new_id: name2.id,
      notes: "SHAZAM"
    }

    post(:merge_request, params: params)
    assert_response(:redirect)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    login("rolf")
    post(:merge_request, params: params)
    assert_response(:redirect)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    assert_match(/SHAZAM/, ActionMailer::Base.deliveries.last.to_s)
  end

  def test_email_name_change_request_get
    name = names(:lactarius)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    assert(name.dependents?, "Test needs a fixture with dependents")
    params = {
      name_id: name.id,
      new_name_with_icn_id: "#{name.search_name} [#777]"
    }
    login("mary")

    get(:name_change_request, params: params)
    assert_select(
      "#title", text: :email_name_change_request_title.l, count: 1
    )
  end

  def test_email_name_change_request_post
    name = names(:lactarius)
    assert(name.icn_id, "Test needs a fixture with an icn_id")
    assert(name.dependents?, "Test needs a fixture with dependents")
    params = {
      name_id: name.id,
      new_name_with_icn_id: "#{name.search_name} [#777]"
    }
    login("mary")

    post(:name_change_request, params: params)
    assert_redirected_to(
      name_path(id: name.id),
      "Sending Name Change Request should redirect to Name page"
    )
  end
end
