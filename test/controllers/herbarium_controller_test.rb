require "test_helper"

# tests of Herbarium controller
class HerbariumControllerTest < FunctionalTestCase
  def herbarium_params
    {
      name:            "",
      personal:        "",
      code:            "",
      place_name:      "",
      email:           "",
      mailing_address: "",
      description:     ""
    }
  end

  def test_index
    get_with_dump(:index)
    assert_template(:list_herbaria)
  end

  def test_list_herbaria
    get_with_dump(:list_herbaria)
  end

  def test_herbarium_search
    get_with_dump(:herbarium_search, pattern: "Personal Herbarium")
  end

  def test_list_herbaria_merge_source
    herb1 = herbaria(:nybg_herbarium)
    herb2 = herbaria(:mycoflora_herbarium)
    herb3 = herbaria(:dick_herbarium)
    assert_true(herb1.can_edit?(rolf))  # rolf id curator
    assert_true(herb2.can_edit?(rolf))  # no curators
    assert_false(herb3.can_edit?(rolf)) # someone else's personal herbarium

    get(:list_herbaria)
    assert_select("a[href*=edit_herbarium]", count: 0)
    assert_select("a[href*=merge_herbaria]", count: 0)

    login("dick")
    get(:list_herbaria)
    assert_select("a[href*='edit_herbarium/#{herb1.id}']", count: 0)
    assert_select("a[href*='edit_herbarium/#{herb2.id}']", count: 1)
    assert_select("a[href*='edit_herbarium/#{herb3.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb1.id}']", count: 0)
    assert_select("a[href*='list_herbaria?merge=#{herb2.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb3.id}']", count: 1)
    assert_select("a[href*=merge_herbaria]", count: 0)

    login("rolf")
    get(:list_herbaria)
    assert_select("a[href*='edit_herbarium/#{herb1.id}']", count: 1)
    assert_select("a[href*='edit_herbarium/#{herb2.id}']", count: 1)
    assert_select("a[href*='edit_herbarium/#{herb3.id}']", count: 0)
    assert_select("a[href*='list_herbaria?merge=#{herb1.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb2.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb3.id}']", count: 0)
    assert_select("a[href*=merge_herbaria]", count: 0)

    make_admin("zero")
    get(:list_herbaria)
    assert_select("a[href*='edit_herbarium/#{herb1.id}']", count: 1)
    assert_select("a[href*='edit_herbarium/#{herb2.id}']", count: 1)
    assert_select("a[href*='edit_herbarium/#{herb3.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb1.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb2.id}']", count: 1)
    assert_select("a[href*='list_herbaria?merge=#{herb3.id}']", count: 1)
    assert_select("a[href*=merge_herbaria]", count: 0)
  end

  def test_list_herbaria_merge_target
    source = herbaria(:field_museum)
    herb1  = herbaria(:nybg_herbarium)
    herb2  = herbaria(:mycoflora_herbarium)
    herb3  = herbaria(:dick_herbarium)
    assert_true(herb1.can_edit?(rolf))  # rolf id curator
    assert_true(herb2.can_edit?(rolf))  # no curators
    assert_false(herb3.can_edit?(rolf)) # someone else's personal herbarium

    get(:list_herbaria, merge: source.id)
    assert_select("a[href*=edit_herbarium]", count: 0)
    assert_select("a[href*=merge_herbaria]", count: 0)

    login("dick")
    get(:list_herbaria, merge: source.id)
    assert_select("a[href*='that=#{source.id}']", count: 0)
    assert_select("a[href*='that=#{herb1.id}']", count: 1)
    assert_select("a[href*='that=#{herb2.id}']", count: 1)
    assert_select("a[href*='that=#{herb3.id}']", count: 1)

    login("rolf")
    get(:list_herbaria, merge: source.id)
    assert_select("a[href*='that=#{source.id}']", count: 0)
    assert_select("a[href*='that=#{herb1.id}']", count: 1)
    assert_select("a[href*='that=#{herb2.id}']", count: 1)
    assert_select("a[href*='that=#{herb3.id}']", count: 1)

    make_admin("zero")
    get(:list_herbaria, merge: source.id)
    assert_select("a[href*='that=#{source.id}']", count: 0)
    assert_select("a[href*='that=#{herb1.id}']", count: 1)
    assert_select("a[href*='that=#{herb2.id}']", count: 1)
    assert_select("a[href*='that=#{herb3.id}']", count: 1)
  end

  def test_merge_herbaria
    # Rule is non-admins can only merge herbaria which they own all the records
    # at, into their own personal herbarium.  Nothing else.  Mary owns all the
    # records at Mycoflora, randomly enough, so if we create a personal
    # herbarium for her, she should be able to merge Mycoflora into it.
    mycoflora = herbaria(:mycoflora_herbarium)
    assert_true(mycoflora.herbarium_records.all? {|r| r.user == mary})
    mary_herbarium = mary.create_personal_herbarium
    id1 = mycoflora.id
    id2 = mary_herbarium.id
    id3 = herbaria(:nybg_herbarium).id
    id4 = herbaria(:field_museum).id

    get(:merge_herbaria, this: id1, that: id2)
    assert_redirected_to(controller: :account, action: :login)

    login("rolf")
    get(:merge_herbaria, this: id1, that: id2)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: id1, new_id: id2)

    login("mary")
    get(:merge_herbaria)
    assert_flash_error
    get(:merge_herbaria, this: id2, that: id2)
    assert_no_flash
    get(:merge_herbaria, this: 666)
    assert_flash_error
    get(:merge_herbaria, this: id1, that: 666)
    assert_flash_error
    get(:merge_herbaria, this: id3, that: id3)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: id3, new_id: id3)
    get(:merge_herbaria, this: id1, that: id3)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: id1, new_id: id3)
    get(:merge_herbaria, this: id1, that: id2)
    assert_flash_success
    # Mycoflora ends up being the destination because it is older.
    assert_redirected_to(mycoflora.show_link_args)

    make_admin("mary")
    get(:merge_herbaria, this: id3, that: id4)
    assert_flash_success
    assert_redirected_to(herbaria(:nybg_herbarium).show_link_args)
  end

  def test_show_herbarium
    nybg = herbaria(:nybg_herbarium)
    get_with_dump(:show_herbarium, id: nybg.id)
    assert_template(:show_herbarium)
  end

  def test_show_herbarium_post
    nybg = herbaria(:nybg_herbarium)
    params = {
      id:          nybg.id,
      add_curator: mary.login
    }
    curator_count = nybg.curators.count

    post(:show_herbarium, params)
    assert_equal(curator_count, nybg.reload.curators.count)

    login("mary")
    post(:show_herbarium, params)
    assert_equal(curator_count, nybg.reload.curators.count)

    login("rolf")
    post(:show_herbarium, params)
    assert_equal(curator_count + 1, nybg.reload.curators.count)
    assert_response(:success)
  end

  def test_create_herbarium
    get(:create_herbarium)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:create_herbarium)
    assert_template(:create_herbarium)
  end

  def test_create_herbarium_post
    herbarium_count = Herbarium.count
    params = herbarium_params.merge(
      name:            " Burbank <blah> Herbarium ",
      code:            "BH  ",
      place_name:      "Burbank, California, USA",
      email:           "curator@bh.org",
      mailing_address: "New Herbarium\n1234 Figueroa\nBurbank, CA, 91234\n\n\n",
      description:     "\nSpecializes in local macrofungi. <http:blah>\n"
    )
    post(:create_herbarium, herbarium: params)
    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:redirect)

    login("katrina")
    post(:create_herbarium, herbarium: params)
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

  def test_create_herbarium_post_with_duplicate_name
    herbarium_count = Herbarium.count
    login("rolf")
    nybg = herbaria(:nybg_herbarium)
    params = herbarium_params.merge(
      name:            nybg.name.gsub(/ /, " <spam> "),
      code:            "  NEW <spam> ",
      place_name:      "New Location",
      email:           "  new <spam> email  ",
      mailing_address: "  New <spam> Address  ",
      description:     "  New Notes  ",
      personal:        "1"
    )
    post(:create_herbarium, herbarium: params)
    assert_equal(herbarium_count, Herbarium.count)
    assert_flash(/already exists/i)
    # Really means we go back to create_herbarium without having created one.
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

  def test_create_herbarium_post_with_nonexisting_place_name
    herbarium_count = Herbarium.count
    login("rolf")
    params = herbarium_params.merge(
      name:       "New Herbarium",
      place_name: "New Location"
    )
    post(:create_herbarium, herbarium: params)
    assert_flash(/must define this location/i)
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
      name:     "My Herbarium",
      personal: "1"
    )

    login("rolf")
    assert_not_nil(rolf.personal_herbarium)
    post(:create_herbarium, herbarium: params)
    assert_flash(/already.*created.*personal herbarium/i)
    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:success)

    login("mary")
    assert_nil(mary.personal_herbarium)
    post(:create_herbarium, herbarium: params)
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

  def test_edit_herbarium_without_curators
    nybg = herbaria(:nybg_herbarium)
    nybg.curators.delete(rolf)
    nybg.curators.delete(roy)
    assert_empty(nybg.reload.curators)
    get(:edit_herbarium, id: nybg.id)
    assert_response(:redirect)

    login("mary")
    get_with_dump(:edit_herbarium, id: nybg.id)
    assert_template("edit_herbarium")
  end

  def test_edit_herbarium_with_curators
    nybg = herbaria(:nybg_herbarium)
    get(:edit_herbarium, id: nybg.id)
    assert_response(:redirect)

    login("mary")
    assert(!nybg.curator?(mary))
    get(:edit_herbarium, id: nybg.id)
    assert_flash(/Permission denied/i)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit_herbarium, id: nybg.id)
    assert_template("edit_herbarium")

    make_admin("mary")
    get(:edit_herbarium, id: nybg.id)
    assert_template("edit_herbarium")
  end

  def test_edit_herbarium_post
    nybg = herbaria(:nybg_herbarium)
    last_update = nybg.updated_at
    params = herbarium_params.merge(
      name:            " New Herbarium <spam> ",
      code:            " FOO <spam> ",
      place_name:      "Burbank, California, USA",
      email:           " new@email.com <spam> ",
      mailing_address: "All\nNew\nLocation\n<spam>\n",
      description:     " And  more  stuff. "
    )

    post(:edit_herbarium, herbarium: params, id: nybg.id)
    assert_redirected_to(controller: :account, action: :login)

    login("mary")
    post(:edit_herbarium, herbarium: params, id: nybg.id)
    assert_redirected_to(action: :show_herbarium, id: nybg.id)
    assert_flash(/Permission denied/)
    assert_equal(last_update, nybg.reload.updated_at)

    login("rolf")
    post(:edit_herbarium, herbarium: params, id: nybg.id)
    assert_redirected_to(action: :show_herbarium, id: nybg.id)
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
    post(:edit_herbarium, herbarium: params, id: nybg.id)
    assert_equal(last_update, nybg.reload.updated_at)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: nybg.id, new_id: other.id)

    # Rolf can both edit and does own all the records.
    login("rolf")
    post(:edit_herbarium, herbarium: params, id: nybg.id)
    assert_nil(Herbarium.safe_find(nybg.id))
  end

  def test_edit_herbarium_post_with_nonexisting_place_name
    nybg = herbaria(:nybg_herbarium)
    params = herbarium_params.merge(place_name: "New Location")
    login("rolf")
    post(:edit_herbarium, herbarium: params, id: nybg.id)
    assert_nil(nybg.reload.location)
    assert_redirected_to(controller: :location, action: :create_location,
                         where: "New Location", set_herbarium: nybg.id)
  end

  def test_edit_herbarium_user_make_personal
    # Make sure this herbarium is ready to be made Mary's personal herbarium.
    herbarium = herbaria(:mycoflora_herbarium)
    assert_empty(herbarium.curators)
    assert_nil(herbarium.personal_user_id)
    assert_true(herbarium.herbarium_records.all? {|r| r.user_id == mary.id })
    assert_true(herbarium.can_make_personal?(mary))

    params = herbarium_params.merge(name: herbarium.name, personal: "1")

    # Rolf doesn't own all the records, so can't make it his.
    login("rolf")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.reload.curators)

    # Make sure if Mary already has one she cannot make this one, too.
    login("mary")
    other = herbaria(:dick_herbarium)
    other.update_columns(personal_user_id: mary.id)
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.reload.curators)

    # But if she owns all the records and doesn't have one, then she can.
    other.update_columns(personal_user_id: dick.id)
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.reload.curators)
  end

  def test_edit_herbarium_post_admin_set_personal_user
    herbarium = herbaria(:mycoflora_herbarium)
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_nil(herbarium.reload.personal_user_id)
    login("mary")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_nil(herbarium.reload.personal_user_id)
    make_admin("rolf")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_edit_herbarium_post_admin_change_personal_user
    herbarium = herbaria(:dick_herbarium)
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("mary")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("dick")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(dick, herbarium.reload.personal_user)
    make_admin("rolf")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_edit_herbarium_post_admin_clear_personal_user
    herbarium = herbaria(:dick_herbarium)
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: ""
    )
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("mary")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(dick, herbarium.reload.personal_user)
    login("dick")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_users_equal(dick, herbarium.reload.personal_user)
    make_admin("rolf")
    post(:edit_herbarium, id: herbarium.id, herbarium: params)
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.curators)
  end

  def test_delete_curator
    nybg = herbaria(:nybg_herbarium)
    assert(nybg.curator?(rolf))
    assert(nybg.curator?(roy))
    curator_count = nybg.curators.count
    params = { id: nybg.id, user: roy.id }

    post(:delete_curator, params)
    assert_equal(curator_count, nybg.reload.curators.count)
    assert_response(:redirect)

    login("mary")
    post(:delete_curator, params)
    assert_equal(curator_count, nybg.reload.curators.count)
    assert_response(:redirect)

    login("rolf")
    post(:delete_curator, params.except(:user))
    assert_equal(curator_count, nybg.reload.curators.count)
    assert_response(:redirect)

    post(:delete_curator, params)
    assert_equal(curator_count - 1, nybg.reload.curators.count)
    assert(!nybg.curator?(roy))
    assert_response(:redirect)

    make_admin("mary")
    post(:delete_curator, params.merge(user: rolf.id))
    assert_equal(curator_count - 2, nybg.reload.curators.count)
    assert(!nybg.curator?(rolf))
    assert_response(:redirect)
  end

  def test_request_to_be_curator
    nybg = herbaria(:nybg_herbarium)
    get(:request_to_be_curator, id: nybg.id)
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
    post(:request_to_be_curator, id: nybg.id)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    login("mary")
    post(:request_to_be_curator)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    post(:request_to_be_curator, id: nybg.id, notes: "ZZYZX")
    assert_response(:success)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    assert_match(/ZZYZX/, ActionMailer::Base.deliveries.last.to_s)
  end

  def test_destroy_herbarium
    herbarium = herbaria(:nybg_herbarium)

    # Must be logged in.
    get(:destroy_herbarium, id: herbarium.id)
    assert_not_nil(Herbarium.safe_find(herbarium.id))

    # Must be curator or admin.
    login("mary")
    get(:destroy_herbarium, id: herbarium.id)
    assert_not_nil(Herbarium.safe_find(herbarium.id))

    # Curator can do it.
    login("roy")
    get(:destroy_herbarium, id: herbarium.id)
    assert_nil(Herbarium.safe_find(herbarium.id))
  end

  def test_destroy_herbarium_admin
    herbarium = herbaria(:nybg_herbarium)
    make_admin("mary")
    get(:destroy_herbarium, id: herbarium.id)
    assert_nil(Herbarium.safe_find(herbarium.id))
  end
end
