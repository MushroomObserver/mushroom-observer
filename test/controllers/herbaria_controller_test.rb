# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
class HerbariaControllerTest < FunctionalTestCase
  # ---------- Helpers ----------

  def nybg
    herbaria(:nybg_herbarium)
  end

  def fundis
    herbaria(:fundis_herbarium)
  end

  def dicks_personal
    herbaria(:dick_herbarium)
  end

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

  def field_museum
    herbaria(:field_museum)
  end

  # params used in test_create
  def create_params
    herbarium_params.merge(
      name: " Burbank <blah> Herbarium ",
      code: "BH  ",
      place_name: "Burbank, California, USA",
      email: "curator@bh.org",
      mailing_address: "New Herbarium\n1234 Figueroa\nBurbank, CA, 91234\n\n\n",
      description: "\nSpecializes in local macrofungi. <http:blah>\n"
    )
  end

  # ---------- Actions to Display data (index, show, etc.) ---------------------
  def test_show
    herbarium = nybg
    assert_not(herbarium.curator?(mary))
    login("mary")
    get(:show, params: { id: herbarium.id })

    assert_select("#title-caption", text: herbarium.format_name, count: 1)
    assert_select(
      "a[href^='#{new_herbaria_curator_request_path(id: herbarium)}']",
      { text: :show_herbarium_curator_request.l },
      "Fungarium page missing a link to #{:show_herbarium_curator_request.l}"
    )
  end

  def test_show_destroy_buttons_presence
    herbarium = nybg
    assert(herbarium.curator?(roy))
    login("rolf")
    get(:show, params: { id: herbarium.id })

    assert_select("#title-caption", text: herbarium.format_name)
    assert_select("form[action^='#{herbarium_path(herbarium)}']") do
      assert_select("input[value='delete']", true,
                    "Show Herbarium page is missing a destroy herbarium button")
    end
    herbarium.curators.each do |curator|
      assert_select(
        "form[action^='#{herbaria_curator_path(herbarium, user: curator.id)}']"
      ) do
        assert_select("input[value='delete']", true,
                      "Show Herbarium page is missing a destroy curator button")
      end
    end
  end

  def test_next
    query = Query.lookup_and_save(:Herbarium, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:next, params: { id: number1.id, q: q })
    assert_redirected_to(herbarium_path(number2, q: q))
  end

  def test_prev
    query = Query.lookup_and_save(:Herbarium, :all)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = query.record.id.alphabetize

    get(:prev, params: { id: number2.id, q: q })
    assert_redirected_to(herbarium_path(number1, q: q))
  end

  def test_index
    set = [nybg, herbaria(:rolf_herbarium)]
    query = Query.lookup_and_save(:Herbarium, :in_set, by: :name, ids: set)
    get(:index, params: { q: query.record.id.alphabetize })

    assert_response(:success)
    assert_select(
      "a:match('href', ?)", %r{^#{herbaria_path}/(\d+)}, { count: set.size },
      "Filtered index should list the results of the latest Herbaria query"
    )
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def test_new
    login("rolf")
    get(:new)
    assert_select(
      "form[action='#{herbaria_path}'][method='post']", { count: 1 },
      "'new' action should render a form that posts to #{herbaria_path}"
    )
  end

  def test_new_no_login
    get(:new)
    assert_redirected_to(account_login_path)
  end

  def test_edit_no_login
    get(:edit, params: { id: nybg.id })
    assert_redirected_to(account_login_path)
  end

  def test_edit_without_curators
    herbarium = herbaria(:curatorless_herbarium)
    login("mary")
    get(:edit, params: { id: herbarium.id })

    assert_response(:success)
    assert_select("#title-caption", text: :edit_herbarium_title.l, count: 1)
  end

  def test_edit_with_curators_by_non_curator
    login("mary")
    assert_not(nybg.curator?(mary))
    get(:edit, params: { id: nybg.id })

    assert_flash_text(/Permission denied/i)
    assert_response(:redirect)
  end

  def test_edit_with_curators_by_curator
    assert(nybg.curator?(rolf))
    login("rolf")
    get(:edit, params: { id: nybg.id })
    assert_response(:success)
    assert_select("#title-caption", text: :edit_herbarium_title.l, count: 1)
  end

  def test_edit_with_curators_by_admin
    assert_not(nybg.curator?(mary))
    make_admin("mary")
    get(:edit, params: { id: nybg.id })

    assert_response(:success)
    assert_select("#title-caption", text: :edit_herbarium_title.l, count: 1)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def test_create
    herbarium_count = Herbarium.count
    login("katrina")
    post(:create, params: { herbarium: create_params })

    assert_equal(herbarium_count + 1, Herbarium.count)
    assert_response(:redirect)
    herbarium = Herbarium.last
    assert_equal("Burbank Herbarium", herbarium.name)
    assert_equal("BH", herbarium.code)
    assert_objs_equal(locations(:burbank), herbarium.location)
    assert_equal("curator@bh.org", herbarium.email)
    assert_equal(create_params[:mailing_address].strip_html.strip_squeeze,
                 herbarium.mailing_address)
    assert_equal(create_params[:description].strip, herbarium.description)
    assert_empty(herbarium.curators)
    email = ActionMailer::Base.deliveries.last
    assert_equal(katrina.email, email.header["reply_to"].to_s)
    assert_match(/new herbarium/i, email.header["subject"].to_s)
    assert_includes(email.body.to_s, "Burbank Herbarium")
    assert_includes(email.body.to_s, herbarium.show_url)
  end

  def test_create_no_login
    herbarium_count = Herbarium.count
    post(:create, params: { herbarium: create_params })

    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:redirect)
  end

  def test_create_duplicate_name
    herbarium_count = Herbarium.count
    login("rolf")
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
    assert_response(:success) # Back to form with creating herbarium
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

  def test_create_second_personal_herbarium
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
    assert_response(:success) # Back to the form
  end

  def test_create_second_personal_herbarium_by_admin
    params = herbarium_params.merge(
      name: "My Herbarium",
      personal: "1",
      personal_user_name: "dick"
    )
    assert_not_nil(dick.personal_herbarium)

    login("rolf")
    make_admin("rolf")
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

  def test_create_invalid_personal_user
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

  def test_update_by_curator
    last_update = nybg.updated_at
    params = herbarium_params.merge(
      name: " New Herbarium <spam> ",
      code: " FOO <spam> ",
      place_name: "Burbank, California, USA",
      email: " new@email.com <spam> ",
      mailing_address: "All\nNew\nLocation\n<spam>\n",
      description: " And  more  stuff. "
    )
    login("rolf")

    patch(:update, params: { herbarium: params, id: nybg.id })
    assert_redirected_to(herbarium_path(nybg))
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

  def test_update_by_non_curator
    last_update = nybg.updated_at
    params = herbarium_params.merge(
      name: " New Herbarium <spam> ",
      code: " FOO <spam> ",
      place_name: "Burbank, California, USA",
      email: " new@email.com <spam> ",
      mailing_address: "All\nNew\nLocation\n<spam>\n",
      description: " And  more  stuff. "
    )
    login("mary")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_redirected_to(herbarium_path(nybg))
    assert_flash_text(/Permission denied/)
    assert_equal(last_update, nybg.reload.updated_at)
  end

  def test_update_no_login
    patch(:update, params: { herbarium: herbarium_params, id: nybg.id })
    assert_redirected_to(account_login_path)
  end

  def test_update_with_duplicate_name_by_owner_of_some_records
    other = herbaria(:rolf_herbarium)
    last_update = nybg.updated_at
    params = herbarium_params.merge(name: other.name)
    # Roy can edit but does not own all the records.
    login("roy")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_equal(last_update, nybg.reload.updated_at)
    assert_redirected_to(controller: :observer, action: :email_merge_request,
                         type: :Herbarium, old_id: nybg.id, new_id: other.id)
  end

  def test_update_with_duplicate_name_by_owner_of_all_records
    other = herbaria(:rolf_herbarium)
    params = herbarium_params.merge(name: other.name)
    # Rolf can both edit and does own all the records.  Should merge.
    login("rolf")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_nil(Herbarium.safe_find(other.id))
    assert_not_nil(Herbarium.safe_find(nybg.id))
  end

  def test_update_with_nonexisting_place_name
    params = herbarium_params.merge(place_name: "New Location")
    login("rolf")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_nil(nybg.reload.location)
    assert_redirected_to(controller: :location, action: :create_location,
                         where: "New Location", set_herbarium: nybg.id)
  end

  def test_update_user_make_personal_by_owner_of_some_records
    herbarium = fundis
    params = herbarium_params.merge(name: herbarium.name, personal: "1")
    # Rolf doesn't own all the records, so can't make it his.
    login("rolf")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.reload.curators)
  end

  def test_update_user_make_second_personal_herbarium
    # Make sure this herbarium is ready to be made Mary's personal herbarium.
    herbarium = fundis
    assert_empty(herbarium.curators)
    assert_nil(herbarium.personal_user_id)
    assert_true(herbarium.owns_all_records?(mary))
    assert_true(herbarium.can_make_personal?(mary))

    params = herbarium_params.merge(name: herbarium.name, personal: "1")

    # Make sure if Mary already has one she cannot make this one, too.
    login("mary")
    other = herbaria(:dick_herbarium)
    other.update(personal_user_id: mary.id)

    patch(:update, params: { id: herbarium.id, herbarium: params })
    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.reload.curators)
  end

  def test_update_user_make_personal
    # Make sure this herbarium is ready to be made Mary's personal herbarium.
    herbarium = fundis
    assert_empty(herbarium.curators)
    assert_nil(herbarium.personal_user_id)
    assert_true(herbarium.owns_all_records?(mary))
    assert_true(herbarium.can_make_personal?(mary))

    params = herbarium_params.merge(name: herbarium.name, personal: "1")
    login("mary")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.reload.curators)
  end

  def test_update_cannot_make_personal
    herbarium = fundis
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

    patch(:update, params: { id: herbarium.id, herbarium: params })

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

  def test_update_admin_set_personal_user_no_login
    herbarium = fundis
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_nil(herbarium.reload.personal_user_id)
  end

  def test_update_admin_set_personal_user_by_non_admin
    herbarium = fundis
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    login("mary")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_nil(herbarium.reload.personal_user_id)
  end

  def test_update_admin_set_personal_user_by_admin
    herbarium = fundis
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    make_admin("rolf")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_update_change_personal_user_no_login
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    patch(:update, params: { id: herbarium.id, herbarium: params })
    assert_users_equal(dick, herbarium.reload.personal_user)
  end

  def test_update_change_personal_user_by_non_owner
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    login("mary")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(dick, herbarium.reload.personal_user)
  end

  def test_update_change_personal_user_by_owner
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    login("dick")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(dick, herbarium.reload.personal_user)
  end

  def test_update_change_personal_user_by_admin
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: "mary"
    )
    make_admin("rolf")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(mary, herbarium.reload.personal_user)
    assert_user_list_equal([mary], herbarium.curators)
  end

  def test_update_clear_personal_user_no_login
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: ""
    )
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(dick, herbarium.reload.personal_user)
  end

  def test_update_clear_personal_user_by_other_user
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: ""
    )
    login("mary")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(dick, herbarium.reload.personal_user)
  end

  def test_update_clear_personal_user_by_owner
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: ""
    )
    login("dick")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_users_equal(dick, herbarium.reload.personal_user)
  end

  def test_update_clear_personal_user_by_admin
    herbarium = dicks_personal
    params = herbarium_params.merge(
      name: herbarium.name,
      personal_user_name: ""
    )
    make_admin("rolf")
    patch(:update, params: { id: herbarium.id, herbarium: params })

    assert_nil(herbarium.reload.personal_user_id)
    assert_empty(herbarium.curators)
  end

  def test_destroy_no_login
    # Must be logged in.
    get(:destroy, params: { id: nybg.id })

    assert_not_nil(Herbarium.safe_find(nybg.id))
  end

  def test_destroy_by_non_curator
    assert(HerbariumRecord.where(herbarium_id: nybg.id).exists?)
    # Must be curator or admin.
    login("mary")
    get(:destroy, params: { id: nybg.id })
    assert_not_nil(Herbarium.safe_find(nybg.id))
  end

  def test_destroy_by_curator
    record_ids = HerbariumRecord.where(herbarium_id: nybg.id).pluck(:id)
    assert_not_empty(record_ids)

    # Curator can do it.
    login("roy")
    get(:destroy, params: { id: nybg.id })

    assert_nil(Herbarium.safe_find(nybg.id))
    assert_not(HerbariumRecord.where(herbarium_id: nybg.id).exists?)
    assert_not(
      Observation.joins(:herbarium_records).
                  where("herbarium_records.id" => record_ids).exists?,
      "Destroying Herbarium should destroy herbarium records -- " \
      "There should not be herbarium records for Observations " \
      "whose only records were in destroyed herbarium #{nybg.name}"
    )
  end

  def test_destroy_curated_herbarium_by_noncurator_owning_all_records
    herbarium = fundis
    assert_true(herbarium.owns_all_records?(mary))
    assert_empty(herbarium.curators)

    # Make sure noncurator can do it only if there are no curators.
    login("mary")
    herbarium.add_curator(dick)
    get(:destroy, params: { id: herbarium.id })

    assert_flash_error
    assert_not_nil(Herbarium.safe_find(herbarium.id))
  end

  def test_destroy_uncurated_herbarium_by_noncurator_owning_all_records
    herbarium = fundis
    assert_true(herbarium.owns_all_records?(mary))
    assert_empty(herbarium.curators)

    # Noncurator can destroy herbarium
    # if there are no curators and the user owns all the records.
    # (Note that this means anyone can destroy any uncurated empty herbaria.)
    login("mary")
    get(:destroy, params: { id: herbarium.id })

    assert_no_flash
    assert_nil(Herbarium.safe_find(herbarium.id))
  end

  def test_destroy_admin
    make_admin("mary")
    get(:destroy, params: { id: nybg.id })
    assert_nil(Herbarium.safe_find(nybg.id))
  end

  def test_destroy_nonexistent_herbarium
    assert_not(Herbarium.exists?(314_159))
    login("mary")
    get(:destroy, params: { id: 314_159 })

    assert_redirected_to(
      herbaria_path,
      "Attempt to destroy non-existent herbarium should redirect to index"
    )
  end
end
