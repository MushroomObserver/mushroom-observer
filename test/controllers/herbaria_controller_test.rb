# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
class HerbariaControllerTest < FunctionalTestCase
  def herbarium_params
    {
      name: "",
      personal: "",
      code: "",
      place_name: "",
      email: "",
      mailing_address: "",
      description: ""
    }.freeze
  end

  def test_index_herbaria
    get(:index_herbaria)

    assert_response(:success)
    Herbarium.find_each do |herbarium|
      assert_select(
        "a[href *= '#{herbarium_path(herbarium.id)}']", true,
        "Herbarium Index missing link to #{herbarium.name} (##{herbarium.id})"
      )
    end
  end

  def test_index_nonpersonal_herbaria
    get(:index_nonpersonal_herbaria)

    # TODO: replace assert_template with assertions that
    # all nonpersonal, and no personal, herbaria are displayed
    assert_template(:index)
  end

  def test_index
    get(:index)

    assert_response(:success)
    Herbarium.find_each do |herbarium|
      assert_select(
        "a[href *= '#{herbarium_path(herbarium.id)}']", true,
        "Herbarium Index missing link to #{herbarium.name} (##{herbarium.id})"
      )
    end
  end

  def test_search
    get(:search, pattern: "Personal Herbarium")
    # TODO: Assert page contents
  end

  def test_search_number
    herbarium = herbaria(:nybg_herbarium)
    get(:search, params: { pattern: herbarium.id })

    assert_redirected_to(
      herbarium_path(herbarium.id),
      "Herbarium search for ##{herbarium.id} should show " \
        "#{herbarium.name} herbarium"
    )
  end

  def test_index_merge_source
    herb1 = herbaria(:nybg_herbarium)
    herb2 = herbaria(:fundis_herbarium)
    herb3 = herbaria(:dick_herbarium)
    assert_true(herb1.can_edit?(rolf))  # rolf id curator
    assert_true(herb2.can_edit?(rolf))  # no curators
    assert_false(herb3.can_edit?(rolf)) # someone else's personal herbarium

    get(:index)
    assert_select("a[href*=edit]", count: 0)
    assert_select("a[href^='herbaria_merge_path']", count: 0)

    login("dick")
    get(:index)
    assert_select("a[href^='#{edit_herbarium_path(herb1.id)}']", count: 0)
    assert_select("a[href^='#{edit_herbarium_path(herb2.id)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(herb3.id)}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb1.id}']", count: 0)
    assert_select("a[href*='herbaria?merge=#{herb2.id}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb3.id}']", count: 1)
    assert_select("a[href^='herbaria_merge_path']", count: 0)

    login("rolf")
    get(:index)
    assert_select("a[href^='#{edit_herbarium_path(herb1.id)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(herb2.id)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(herb3.id)}']", count: 0)
    assert_select("a[href*='herbaria?merge=#{herb1.id}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb2.id}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb3.id}']", count: 0)
    assert_select("a[href^='herbaria_merge_path']", count: 0)

    make_admin("zero")
    get(:index)
    assert_select("a[href^='#{edit_herbarium_path(herb1.id)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(herb2.id)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(herb3.id)}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb1.id}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb2.id}']", count: 1)
    assert_select("a[href*='herbaria?merge=#{herb3.id}']", count: 1)
    assert_select("a[href^='herbaria_merge_path']", count: 0)
  end

  def test_index_merge_target
    source = herbaria(:field_museum)
    herb1  = herbaria(:nybg_herbarium)
    herb2  = herbaria(:fundis_herbarium)
    herb3  = herbaria(:dick_herbarium)
    assert_true(herb1.can_edit?(rolf))  # rolf id curator
    assert_true(herb2.can_edit?(rolf))  # no curators
    assert_false(herb3.can_edit?(rolf)) # someone else's personal herbarium

    get(:index, params: { merge: source.id })
    assert_select("a[href*=edit]", count: 0)
    assert_select("a[href^='herbaria_merge_path']", count: 0)

    login("dick")
    get(:index, params: { merge: source.id })
    assert_select("a[href*='this=#{source.id}']", count: 0)
    assert_select("a[href*='this=#{herb1.id}']", count: 1)
    assert_select("a[href*='this=#{herb2.id}']", count: 1)
    assert_select("a[href*='this=#{herb3.id}']", count: 1)

    login("rolf")
    get(:index, params: { merge: source.id })
    assert_select("a[href*='this=#{source.id}']", count: 0)
    assert_select("a[href*='this=#{herb1.id}']", count: 1)
    assert_select("a[href*='this=#{herb2.id}']", count: 1)
    assert_select("a[href*='this=#{herb3.id}']", count: 1)

    make_admin("zero")
    get(:index, params: { merge: source.id })
    assert_select("a[href*='this=#{source.id}']", count: 0)
    assert_select("a[href*='this=#{herb1.id}']", count: 1)
    assert_select("a[href*='this=#{herb2.id}']", count: 1)
    assert_select("a[href*='this=#{herb3.id}']", count: 1)
  end

  def test_merge
    # Rule is non-admins can only merge herbaria which they own all the records
    # at, into their own personal herbarium.  Nothing else.  Mary owns all the
    # records at fundis, randomly enough, so if we create a personal
    # herbarium for her, she should be able to merge fundis into it.
    fundis = herbaria(:fundis_herbarium)
    assert_true(fundis.owns_all_records?(mary))
    mary_herbarium = mary.create_personal_herbarium
    id1 = fundis.id
    id2 = mary_herbarium.id
    id3 = herbaria(:nybg_herbarium).id
    id4 = herbaria(:field_museum).id

    get(:merge, params: { this: id1, that: id2 })
    assert_redirected_to(controller: :account, action: :login)

    login("rolf")
    get(:merge, params: { this: id1, that: id2 })
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: id1, new_id: id2)

    login("mary")
    get(:merge)
    assert_flash_error
    get(:merge, params: { this: id2, that: id2 })
    assert_no_flash
    get(:merge, params: { this: 666 })
    assert_flash_error
    get(:merge, params: { this: id1, that: 666 })
    assert_flash_error
    get(:merge, params: { this: id3, that: id3 })
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: id3, new_id: id3)
    get(:merge, params: { this: id1, that: id3 })
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: id1, new_id: id3)
    get(:merge, params: { this: id1, that: id2 })
    assert_flash_success
    # fundis ends up being the destination because it is older.
    assert_redirected_to(action: :index_herbaria, id: fundis.id)

    make_admin("mary")
    get(:merge, params: { this: id3, that: id4 })
    assert_flash_success
    assert_redirected_to(action: :index_herbaria,
                         id: herbaria(:nybg_herbarium).id)
  end

  def test_show
    nybg = herbaria(:nybg_herbarium)
    get(:show, id: nybg.id)

    # TODO: replace with test of content
    assert_template(:show)
  end

  def test_show_herbarium_post
    nybg = herbaria(:nybg_herbarium)
    params = {
      id: nybg.id,
      add_curator: mary.login
    }
    curator_count = nybg.curators.count

    post(:show, params: params)
    assert_equal(curator_count, nybg.reload.curators.count)

    login("mary")
    post(:show, params: params)
    assert_equal(curator_count, nybg.reload.curators.count)

    login("rolf")
    post(:show, params: params)
    assert_equal(curator_count + 1, nybg.reload.curators.count)
    assert_response(:success)
  end

  def test_show_add_nonuser_curator
    herbarium = herbaria(:rolf_herbarium)
    login = "non-user"
    params = {
      id: herbarium.id,
      add_curator: login
    }
    login("rolf")

    assert_no_difference(
      "herbarium.curators.count",
      "Curators should not change when trying to add non-user as curator"
    ) do
      post(:show, params: params)
      herbarium.reload
    end
    assert_flash(
      /#{:show_herbarium_no_user.t(login: login)}/,
      "Error should be flashed if trying to add non-user as curator"
    )
  end

  def test_next_and_prev
    query = Query.lookup_and_save(:Herbarium, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    login
    get(:next, params: { id: number1.id, q: q })
    assert_redirected_to(action: :show, id: number2.id, q: q)

    get(:prev, params: { id: number2.id, q: q })
    assert_redirected_to(action: :show, id: number1.id, q: q)
  end

  def test_new
    get(:new)
    assert_redirected_to(account_login_path)

    login("rolf")
    get(:new)
    assert_form_action(action: :create) # "new" form posts to :create action
  end

  def test_create
    herbarium_count = Herbarium.count
    params = herbarium_params.merge(
      name: " Burbank <blah> Herbarium ",
      code: "BH  ",
      place_name: "Burbank, California, USA",
      email: "curator@bh.org",
      mailing_address: "New Herbarium\n1234 Figueroa\nBurbank, CA, 91234\n\n\n",
      description: "\nSpecializes in local macrofungi. <http:blah>\n"
    )
    post(:create, params: { herbarium: params })
    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:redirect)

    login("katrina")
    post(:create, params: { herbarium: params })
    assert_equal(herbarium_count + 1, Herbarium.count)
    assert_response(:redirect)
    herbarium = Herbarium.last
    assert_equal("Burbank Herbarium", herbarium.name)
    assert_equal("BH", herbarium.code)
    assert_objs_equal(locations(:burbank), herbarium.location)
    assert_equal("curator@bh.org", herbarium.email)
    assert_equal(params[:mailing_address].strip_html.strip_squeeze,
                 herbarium.mailing_address)
    assert_equal(params[:description].strip, herbarium.description)
    assert_empty(herbarium.curators)
    email = ActionMailer::Base.deliveries.last
    assert_equal(katrina.email, email.header["reply_to"].to_s)
    assert_match(/new herbarium/i, email.header["subject"].to_s)
    assert_includes(email.body.to_s, "Burbank Herbarium")
    assert_includes(email.body.to_s, herbarium.show_url)
  end

  def test_create_duplicate_name
    herbarium_count = Herbarium.count
    login("rolf")
    nybg = herbaria(:nybg_herbarium)
    params = herbarium_params.merge(
      name: nybg.name.gsub(/ /, " <spam> "),
      code: "  NEW <spam> ",
      place_name: "New Location",
      email: "  new <spam> email  ",
      mailing_address: "  New <spam> Address  ",
      description: "  New Notes  ",
      personal: "1"
    )
    post(:create, params: { herbarium: params })
    assert_equal(herbarium_count, Herbarium.count)
    assert_flash_text(/already exists/i)
    # Really means we go back to create without having created one.
    assert_response(:success)
    herbarium = assigns(:herbarium)
    assert_equal(nybg.name, herbarium.name)
    assert_equal("NEW", herbarium.code)
    assert_equal("New Location", herbarium.place_name)
    assert_equal("new email", herbarium.email)
    assert_equal("New Address", herbarium.mailing_address)
    assert_equal("New Notes", herbarium.description)
    assert_equal("1", herbarium.personal)
  end

  def test_create_nonexisting_place_name
    herbarium_count = Herbarium.count
    login("rolf")
    params = herbarium_params.merge(
      name: "New Herbarium",
      place_name: "New Location"
    )
    post(:create, params: { herbarium: params })
    assert_flash_text(/must define this location/i)
    assert_equal(herbarium_count + 1, Herbarium.count)
    assert_response(:redirect)
    herbarium = Herbarium.last
    assert_equal("New Herbarium", herbarium.name)
    assert_equal("", herbarium.code)
    assert_nil(herbarium.location)
    assert_equal("", herbarium.email)
    assert_equal("", herbarium.mailing_address)
    assert_equal("", herbarium.description)
    assert_empty(herbarium.curators)
    assert_redirected_to(controller: :location, action: :create_location,
                         where: "New Location", set_herbarium: herbarium.id)
  end

  def test_create_personal_herbarium
    herbarium_count = Herbarium.count
    params = herbarium_params.merge(
      name: "My Herbarium",
      personal: "1"
    )

    login("rolf")
    assert_not_nil(rolf.personal_herbarium)
    post(:create, params: { herbarium: params })
    assert_flash_text(/already.*created.*personal herbarium/i)
    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:success)

    login("mary")
    assert_nil(mary.personal_herbarium)
    post(:create, params: { herbarium: params })
    assert_equal(herbarium_count + 1, Herbarium.count)
    assert_response(:redirect)
    herbarium = Herbarium.last
    assert_equal("My Herbarium", herbarium.name)
    assert_equal("", herbarium.code)
    assert_nil(herbarium.location)
    assert_equal("", herbarium.email)
    assert_equal("", herbarium.mailing_address)
    assert_equal("", herbarium.description)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_create_herbarium_put
    login
    put(:create)

    assert_redirected_to(
      { action: :index_herbaria },
      "Non-GET or -POST :create request should " \
        "redirect to referrer or index_nonpersonal_herbaria"
    )
  end

  def test_create_post_invalid_personal_user
    params = herbarium_params.merge(
      name: "My Herbarium",
      personal: "1",
      personal_user_name: "non-user"
    )
    login("rolf")
    make_admin("rolf")
    post(:create, params: { herbarium: params })

    assert_response(
      :success,
      "Response to :create with invalid personal_user_name " \
      "should be 'success' (re-displaying form), not redirect to new herbarium"
    )
    assert_flash_error(
      ":create with invalid personal_user_name should flash error"
    )
  end

  def test_create_post_second_personal_herbarium
    params = herbarium_params.merge(
      name: "My Herbarium",
      personal: "1",
      personal_user_name: "dick"
    )
    login("rolf")
    make_admin("rolf")
    assert_nil(mary.personal_herbarium)
    post(:create, params: { herbarium: params })

    assert_response(
      :success,
      "Response to creating second personal herbarium for user " \
      "should be 'success' (re-displaying form), not redirect to new herbarium"
    )
    assert_flash_error(
      "Trying to create second personal herbarium for user should flash error"
    )
  end

  def test_edit_herbarium_without_curators
    nybg = herbaria(:nybg_herbarium)
    nybg.curators.delete(rolf)
    nybg.curators.delete(roy)
    assert_empty(nybg.reload.curators)
    get(:edit, params: { id: nybg.id })
    assert_response(:redirect)

    login("mary")
    get_with_dump(:edit, id: nybg.id)
    assert_template("edit")
  end

  def test_edit_herbarium_with_curators
    nybg = herbaria(:nybg_herbarium)
    get(:edit, params: { id: nybg.id })
    assert_response(:redirect)

    login("mary")
    assert_not(nybg.curator?(mary))
    get(:edit, params: { id: nybg.id })
    assert_flash_text(/Permission denied/i)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit, id: nybg.id)
    assert_template("edit")

    make_admin("mary")
    get(:edit, params: { id: nybg.id })
    assert_template("edit")
  end

  def test_edit_herbarium_post
    nybg = herbaria(:nybg_herbarium)
    last_update = nybg.updated_at
    params = herbarium_params.merge(
      name: " New Herbarium <spam> ",
      code: " FOO <spam> ",
      place_name: "Burbank, California, USA",
      email: " new@email.com <spam> ",
      mailing_address: "All\nNew\nLocation\n<spam>\n",
      description: " And  more  stuff. "
    )

    post(:edit, params: { herbarium: params, id: nybg.id })
    assert_redirected_to(controller: :account, action: :login)

    login("mary")
    post(:edit, params: { herbarium: params, id: nybg.id })
    assert_redirected_to(action: :show, id: nybg.id)
    assert_flash_text(/Permission denied/)
    assert_equal(last_update, nybg.reload.updated_at)

    login("rolf")
    post(:edit, params: { herbarium: params, id: nybg.id })
    assert_redirected_to(action: :show, id: nybg.id)
    assert_no_flash
    assert_not_equal(last_update, nybg.reload.updated_at)
    assert_equal("New Herbarium", nybg.name)
    assert_equal("FOO", nybg.code)
    assert_equal(locations(:burbank), nybg.location)
    assert_equal("new@email.com", nybg.email)
    assert_equal("All\nNew\nLocation", nybg.mailing_address)
    assert_equal("And  more  stuff.", nybg.description)
    assert_nil(nybg.personal_user)
  end

  def test_edit_herbarium_post_with_duplicate_name
    nybg  = herbaria(:nybg_herbarium)
    other = herbaria(:rolf_herbarium)
    last_update = nybg.updated_at
    params = herbarium_params.merge(name: other.name)

    # Roy can edit but does not own all the records.
    login("roy")
    post(:edit, params: { herbarium: params, id: nybg.id })
    assert_equal(last_update, nybg.reload.updated_at)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: nybg.id, new_id: other.id)

    # Rolf can both edit and does own all the records.  Should merge.
    login("rolf")
    post(:edit, params: { herbarium: params, id: nybg.id })
    assert_nil(Herbarium.safe_find(other.id))
    assert_not_nil(Herbarium.safe_find(nybg.id))
  end

  def test_edit_herbarium_post_with_nonexisting_place_name
    nybg = herbaria(:nybg_herbarium)
    params = herbarium_params.merge(place_name: "New Location")
    login("rolf")
    post(:edit, params: { herbarium: params, id: nybg.id })
    assert_nil(nybg.reload.location)
    assert_redirected_to(controller: :location, action: :create_location,
                         where: "New Location", set_herbarium: nybg.id)
  end

  def test_edit_herbarium_user_make_personal
    # Make sure this herbarium is ready to be made Mary's personal herbarium.
    herbarium = herbaria(:fundis_herbarium)
    assert_empty(herbarium.curators)
    assert_nil(herbarium.personal_user_id)
    assert_true(herbarium.owns_all_records?(mary))
    assert_true(herbarium.can_make_personal?(mary))

    params = herbarium_params.merge(name: herbarium.name, personal: "1")

    # Rolf doesn't own all the records, so can't make it his.
    login("rolf")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.reload.curators)

    # Make sure if Mary already has one she cannot make this one, too.
    login("mary")
    other = herbaria(:dick_herbarium)
    other.update(personal_user_id: mary.id)
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.reload.curators)

    # But if she owns all the records and doesn't have one, then she can.
    other.update(personal_user_id: dick.id)
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.reload.curators)
  end

  def test_edit_herbarium_cannot_make_personal
    herbarium = herbaria(:fundis_herbarium)
    assert_empty(
      herbarium.curators,
      "Use different fixture: #{herbarium.name} already has curator"
    )
    assert_nil(
      herbarium.personal_user_id,
      "Use different fixture: #{herbarium.name} is already someone's " \
        " personal herbarium"
    )
    user = users(:zero_user)
    assert_false(
      herbarium.can_make_personal?(user),
      "Use different fixture: #{herbarium.name} cannot be made " \
        " #{user}'s personal herbarium"
    )
    params = herbarium_params.merge(name: herbarium.name, personal: "1")
    login(user.login)

    post(:edit, params: { id: herbarium.id, herbarium: params })

    assert_response(
      :success,
      "Response to edit unowned herbarium to make it personal herbarium " \
      "of user who doesn't own all its records should be 'success' " \
      "(re-display form), not redirect to new herbarium"
    )
    assert_flash_error(
      "Trying to edit unowned herbarium to make it personal herbarium " \
      "of user who doesn't own all its records should flash error"
    )
  end

  def test_edit_herbarium_post_admin_set_personal_user
    herbarium = herbaria(:fundis_herbarium)
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_nil(herbarium.reload.personal_user_id)
    login("mary")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_nil(herbarium.reload.personal_user_id)
    make_admin("rolf")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_edit_herbarium_post_admin_change_personal_user
    herbarium = herbaria(:dick_herbarium)
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("mary")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("dick")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
    make_admin("rolf")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_edit_herbarium_post_admin_clear_personal_user
    herbarium = herbaria(:dick_herbarium)
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: ""
    )
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("mary")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("dick")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
    make_admin("rolf")
    post(:edit, params: { id: herbarium.id, herbarium: params })
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.curators)
  end

  def test_edit_herbarium_put
    herbarium = herbaria(:rolf_herbarium)
    back = herbarium_path(herbarium.id)
    params = { id: herbarium.id, back: back }
    login("rolf")
    put(:edit, { params: params })

    assert_redirected_to(
      back,
      "Non-GET or -POST :edit request should " \
        "redirect to referrer or show"
    )
  end

  def test_delete_curator
    nybg = herbaria(:nybg_herbarium)
    assert(nybg.curator?(rolf))
    assert(nybg.curator?(roy))
    curator_count = nybg.curators.count
    params = { id: nybg.id, user: roy.id }

    post(:delete_curator, params: params)
    assert_equal(curator_count, nybg.reload.curators.count)
    assert_response(:redirect)

    login("mary")
    post(:delete_curator, params: params)
    assert_equal(curator_count, nybg.reload.curators.count)
    assert_response(:redirect)

    login("rolf")
    post(:delete_curator, params: params.except(:user))
    assert_equal(curator_count, nybg.reload.curators.count)
    assert_response(:redirect)

    post(:delete_curator, params: params)
    assert_equal(curator_count - 1, nybg.reload.curators.count)
    assert_not(nybg.curator?(roy))
    assert_response(:redirect)

    make_admin("mary")
    post(:delete_curator, params: params.merge(user: rolf.id))
    assert_equal(curator_count - 2, nybg.reload.curators.count)
    assert_not(nybg.curator?(rolf))
    assert_response(:redirect)
  end

  def test_request_to_be_curator
    nybg = herbaria(:nybg_herbarium)
    get(:request_to_be_curator, params: { id: nybg.id })
    assert_response(:redirect)

    login("mary")
    get(:request_to_be_curator)
    assert_response(:redirect)

    get_with_dump(:request_to_be_curator, id: nybg.id)
    assert_response(:success)
  end

  def test_request_to_be_curator_post
    email_count = ActionMailer::Base.deliveries.count
    nybg = herbaria(:nybg_herbarium)
    post(:request_to_be_curator, params: { id: nybg.id })
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    login("mary")
    post(:request_to_be_curator)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    post(:request_to_be_curator, params: { id: nybg.id, notes: "ZZYZX" })
    assert_response(:redirect)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    assert_match(/ZZYZX/, ActionMailer::Base.deliveries.last.to_s)
  end

  def test_destroy_herbarium
    herbarium = herbaria(:nybg_herbarium)
    records = herbarium.herbarium_records
    assert_not_empty(records)
    record_ids = records.map(&:id)

    # Must be logged in.
    get(:destroy, params: { id: herbarium.id })
    assert_not_nil(Herbarium.safe_find(herbarium.id))

    # Must be curator or admin.
    login("mary")
    get(:destroy, params: { id: herbarium.id })
    assert_not_nil(Herbarium.safe_find(herbarium.id))

    # Curator can do it.
    login("roy")
    get(:destroy, params: { id: herbarium.id })
    assert_nil(Herbarium.safe_find(herbarium.id))
    assert_empty(HerbariumRecord.where(herbarium_id: herbarium.id))
    assert_empty(Herbarium.connection.select_values(%(
      SELECT observation_id FROM herbarium_records_observations
      WHERE herbarium_record_id IN (#{record_ids.map(&:to_s).join(",")})
    )))
  end

  def test_destroy_herbarium_noncurator_owns_all_records
    herbarium = herbaria(:fundis_herbarium)
    assert_true(herbarium.owns_all_records?(mary))
    assert_empty(herbarium.curators)

    # Make sure noncurator can do it only if there are no curators.
    login("mary")
    herbarium.add_curator(dick)
    get(:destroy, params: { id: herbarium.id })
    assert_flash_error
    assert_not_nil(Herbarium.safe_find(herbarium.id))

    # But if there are no curators and the user owns all the records.
    # (Note that this means anyone can destroy any uncurated empty herbaria.)
    herbarium.curators.clear
    get(:destroy, params: { id: herbarium.id })
    assert_no_flash
    assert_nil(Herbarium.safe_find(herbarium.id))
  end

  def test_destroy_herbarium_admin
    herbarium = herbaria(:nybg_herbarium)
    make_admin("mary")
    get(:destroy, params: { id: herbarium.id })
    assert_nil(Herbarium.safe_find(herbarium.id))
  end
end
