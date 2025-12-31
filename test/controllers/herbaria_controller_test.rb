# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
class HerbariaControllerTest < FunctionalTestCase
  include ActiveJob::TestHelper

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

  def field_museum
    herbaria(:field_museum)
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

    assert_page_title(herbarium.format_name)
    assert_select(
      "a[href^='#{new_herbaria_curator_request_path(id: herbarium)}']",
      { text: :show_herbarium_curator_request.l },
      "Fungarium page missing a link to #{:show_herbarium_curator_request.l}"
    )
  end

  def test_show_mcp_db
    herbarium = nybg
    assert(herbarium.mcp_searchable?,
           "Test needs a herbarium serachble via MyCoPortal")

    login("mary")
    get(:show, params: { id: herbarium.id })

    assert_select(
      "#mcp_number",
      { text: /#{:herbarium_mcp_db.l}:\s+#{herbarium.mcp_collid}/ }
    )
  end

  def test_show_no_mcp_db
    herbarium = dicks_personal

    login("mary")
    get(:show, params: { id: herbarium.id })

    assert_select("#mcp_number", false)
  end

  def test_show_destroy_buttons_presence
    herbarium = nybg
    assert(herbarium.curator?(roy))
    login("rolf")
    get(:show, params: { id: herbarium.id })

    assert_page_title(herbarium.format_name)
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

  def test_show_next
    query = Query.lookup_and_save(:Herbarium)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = @controller.q_param(query)

    login
    get(:show, params: { id: number1.id, q: q, flow: "next" })
    assert_redirected_to(herbarium_path(number2, q: q))
  end

  def test_show_prev
    query = Query.lookup_and_save(:Herbarium)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = @controller.q_param(query)

    login
    get(:show, params: { id: number2.id, q: q, flow: "prev" })
    assert_redirected_to(herbarium_path(number1, q: q))
  end

  def test_index
    set = [nybg, herbaria(:rolf_herbarium)]
    query = Query.lookup_and_save(:Herbarium, order_by: :name, id_in_set: set)
    login("zero") # Does not own any herbarium in set
    get(:index, params: { q: @controller.q_param(query) })

    assert_response(:success)
    assert_page_title(:HERBARIA.l)
    assert_select(
      "a:match('href', ?)", %r{^#{herbaria_path}/(\d+)}, { count: set.size },
      "Filtered index should list the results of the latest Herbaria query"
    )
  end

  def test_index_all
    login
    get(:index)

    assert_response(:success)
    assert_page_title(:HERBARIA.l)
    Herbarium.find_each do |herbarium|
      assert_select(
        "a[href *= '#{herbarium_path(herbarium)}']", true,
        "Herbarium Index missing link to #{herbarium.format_name})"
      )
    end
  end

  def test_index_with_non_default_sort
    check_index_sorting
  end

  def test_index_all_merge_source_links_presence_rolf
    assert_true(nybg.can_edit?(rolf)) # rolf is a curator
    assert_true(fundis.can_edit?(rolf)) # herbarium has no curators
    assert_false(dicks_personal.can_edit?(rolf)) # another user's hebarium

    login("rolf")
    get(:index)

    assert_select("a[href^='#{edit_herbarium_path(nybg)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(fundis)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(dicks_personal)}']",
                  count: 0)
    assert_select("a[href='#{herbaria_path(merge: nybg)}']", count: 1)
    assert_select("a[href='#{herbaria_path(merge: fundis)}']", count: 1)
    assert_select("a[href='#{herbaria_path(merge: dicks_personal)}']",
                  count: 0)
    assert_select("a[href^='herbaria_merge_path']", count: 0)
  end

  def test_index_all_merge_source_links_presence_dick
    assert_false(nybg.can_edit?(dick)) # not a curator
    assert_true(fundis.can_edit?(dick)) # no curators
    assert_true(dicks_personal.can_edit?(dick)) # user's personal herbarium

    login("dick")
    get(:index)

    assert_select("a[href^='#{edit_herbarium_path(nybg)}']", count: 0)
    assert_select("a[href^='#{edit_herbarium_path(fundis)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(dicks_personal)}']",
                  count: 1)
    assert_select("a[href='#{herbaria_path(merge: nybg)}']", count: 0)
    assert_select("a[href='#{herbaria_path(merge: fundis)}']", count: 1)
    assert_select("a[href='#{herbaria_path(merge: dicks_personal)}']",
                  count: 1)
    assert_select("a[href^='herbaria_merge_path']", count: 0)
  end

  def test_index_all_merge_source_links_presence_admin
    make_admin("zero")
    get(:index)

    assert_select("a[href^='#{edit_herbarium_path(nybg)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(fundis)}']", count: 1)
    assert_select("a[href^='#{edit_herbarium_path(dicks_personal)}']",
                  count: 1)
    assert_select("a[href='#{herbaria_path(merge: nybg)}']", count: 1)
    assert_select("a[href='#{herbaria_path(merge: fundis)}']", count: 1)
    assert_select("a[href='#{herbaria_path(merge: dicks_personal)}']",
                  count: 1)
    assert_select("a[href^='herbaria_merge_path']", count: 0)
  end

  def test_index_all_no_login
    get(:index)
    assert_redirected_to(new_account_login_path)
    assert_select("a[href*=edit]", count: 0)
    assert_select("a[href^='herbaria_merge_path']", count: 0)
  end

  def test_index_all_merge_target_buttons_presence_rolf
    source = field_museum
    assert_true(nybg.can_edit?(rolf)) # rolf id curator
    assert_true(fundis.can_edit?(rolf)) # no curators
    assert_false(dicks_personal.can_edit?(rolf)) # another user's hebarium

    login("rolf")
    get(:index, params: { merge: source.id })

    assert_select("form[action *= 'dest=#{source.id}']", count: 0)
    assert_select("form[action *= 'dest=#{nybg.id}']", count: 1)
    assert_select("form[action *= 'dest=#{fundis.id}']", count: 1)
    assert_select("form[action *= 'dest=#{dicks_personal.id}']", count: 1)
  end

  def test_index_all_merge_target_buttons_presence_dick
    source = field_museum
    assert_false(nybg.can_edit?(dick)) # dick is not a curator
    assert_true(fundis.can_edit?(dick)) # no curators
    assert_true(dicks_personal.can_edit?(dick)) # user's personal herbarium

    login("dick")
    get(:index, params: { merge: source.id })
    assert_select("form[action *= 'dest=#{source.id}']", count: 0)
    assert_select("form[action *= 'dest=#{nybg.id}']", count: 1)
    assert_select("form[action *= 'dest=#{fundis.id}']", count: 1)
    assert_select("form[action *= 'dest=#{dicks_personal.id}']", count: 1)
  end

  def test_index_all_merge_target_buttons_presence_admin
    source = field_museum
    make_admin("zero")
    get(:index, params: { merge: source.id })

    assert_select("form[action *= 'dest=#{source.id}']", count: 0)
    assert_select("form[action *= 'dest=#{nybg.id}']", count: 1)
    assert_select("form[action *= 'dest=#{fundis.id}']", count: 1)
    assert_select("form[action *= 'dest=#{dicks_personal.id}']", count: 1)
  end

  def test_index_all_merge_target_buttons_presence_no_login
    source = field_museum
    get(:index, params: { merge: source.id })

    assert_redirected_to(new_account_login_path)
    assert_select("a[href*=edit]", count: 0)
    assert_select("form[action *= 'herbaria_merges_path']", count: 0)
  end

  def test_index_nonpersonal
    login
    get(:index, params: { nonpersonal: true })

    assert_page_title(:HERBARIA.l)
    assert_displayed_filters(:query_nonpersonal.l)
    Herbarium.where(personal_user_id: nil).find_each do |herbarium|
      assert_select(
        "a[href ^= '#{herbarium_path(herbarium)}']", true,
        "List of Institutional Fungaria is missing a link to " \
        "#{herbarium.format_name})"
      )
    end
    Herbarium.where.not(personal_user_id: nil).find_each do |herbarium|
      assert_select(
        "a[href ^= '#{herbarium_path(herbarium)}']", false,
        "List of Institutional Fungaria should not have a link to " \
        "#{herbarium.format_name})"
      )
    end
  end

  def test_index_pattern_text_personal
    pattern = "Personal Herbarium"

    login
    get(:index, params: { q: { model: Herbarium, pattern: pattern } })

    assert_page_title(:HERBARIA.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
    Herbarium.where.not(personal_user_id: nil).find_each do |herbarium|
      assert_select(
        "a[href ^= '#{herbarium_path(herbarium)}']", true,
        "Search for #{pattern} is missing a link to " \
        "#{herbarium.format_name})"
      )
    end
    Herbarium.where(personal_user_id: nil).find_each do |herbarium|
      assert_select(
        "a[href ^= '#{herbarium_path(herbarium)}']", false,
        "Search for #{pattern} should not have a link to " \
        "#{herbarium.format_name})"
      )
    end
  end

  def test_index_reverse_records
    login
    by = "reverse_records"
    get(:index, params: { by: })

    assert_response(:success)
    assert_page_title(:HERBARIA.l)
    assert_sorted_by(by)
    Herbarium.find_each do |herbarium|
      assert_select(
        "a[href *= '#{herbarium_path(herbarium)}']", true,
        "Fungaria by reverse #Records missing link to #{herbarium.format_name})"
      )
    end
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

  def test_new_turbo
    login("rolf")
    get(:new, format: :turbo_stream)
    assert_template("shared/_modal_form")
    # Verify HerbariumForm component rendered
    assert_select("form#herbarium_form")
    assert_select("input#herbarium_name")
    assert_select("input#herbarium_place_name")
  end

  def test_new_no_login
    get(:new)
    assert_redirected_to(new_account_login_path)
  end

  def test_edit_no_login
    get(:edit, params: { id: nybg.id })
    assert_redirected_to(new_account_login_path)
  end

  def test_edit_without_curators
    herbarium = herbaria(:curatorless_herbarium)
    login("mary")
    get(:edit, params: { id: herbarium.id })

    assert_response(:success)
    assert_page_title(:EDIT.l)
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
    assert_page_title(:EDIT.l)
  end

  def test_edit_turbo
    assert(nybg.curator?(rolf))
    login("rolf")
    get(:edit, params: { id: nybg.id }, format: :turbo_stream)
    assert_template("shared/_modal_form")
    # Verify HerbariumForm component rendered
    assert_select("form#herbarium_form")
    assert_select("input#herbarium_name[value='#{nybg.name}']")
    assert_select("input#herbarium_place_name")
  end

  def test_edit_with_curators_by_admin
    assert_not(nybg.curator?(mary))
    make_admin("mary")
    get(:edit, params: { id: nybg.id })

    assert_response(:success)
    assert_page_title(:EDIT.l)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def test_create
    email_count = ActionMailer::Base.deliveries.count
    herbarium_count = Herbarium.count
    login("katrina")
    perform_enqueued_jobs do
      post(:create, params: { herbarium: create_params })
    end

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
    # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    email = ActionMailer::Base.deliveries.last
    assert_match(/katrina/, email.to_s)
    assert_match(/new herbarium/i, email.to_s)
    assert_match(/Burbank Herbarium/, email.to_s)
  end

  def test_create_no_login
    herbarium_count = Herbarium.count
    post(:create, params: { herbarium: create_params })

    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:redirect)
  end

  def test_create_blank_name
    herbarium_count = Herbarium.count
    login("rolf")
    params = herbarium_params
    post(:create, params: { herbarium: params })

    assert_equal(herbarium_count, Herbarium.count)
    assert_flash_text(:create_herbarium_name_blank.t)
    assert_response(:success) # Back to form for creating herbarium
  end

  # Turbo stream submissions should reload the modal form with flash errors
  def test_create_blank_name_turbo_stream
    herbarium_count = Herbarium.count
    login("rolf")

    post(:create, params: { herbarium: herbarium_params }, as: :turbo_stream)

    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:success)
    # Should render modal_form_reload partial to update modal with flash
    assert_template("shared/_modal_form_reload")
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
    assert_nil(herbarium.code)
    assert_nil(herbarium.location)
    assert_equal("", herbarium.email)
    assert_equal("", herbarium.mailing_address)
    assert_equal("", herbarium.description)
    assert_empty(herbarium.curators)
    assert_redirected_to(new_location_path(
                           where: "New Location", set_herbarium: herbarium.id
                         ))
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
    assert_nil(herbarium.code)
    assert_nil(herbarium.location)
    assert_equal("", herbarium.email)
    assert_equal("", herbarium.mailing_address)
    assert_equal("", herbarium.description)
    assert_user_arrays_equal([mary], herbarium.curators)
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

  # Regression test: blank codes should be stored as nil, not empty string.
  # This prevents duplicate key errors on the unique index.
  def test_create_with_blank_code_stores_nil
    login("rolf")
    herbarium_count = Herbarium.count

    # First herbarium with blank code
    post(:create, params: { herbarium: herbarium_params.merge(
      name: "First Blank Code Herbarium",
      code: ""
    ) })
    assert_equal(herbarium_count + 1, Herbarium.count)
    first = Herbarium.last
    assert_nil(first.code, "Blank code should be stored as nil")

    # Second herbarium with blank code should also work (no duplicate key error)
    post(:create, params: { herbarium: herbarium_params.merge(
      name: "Second Blank Code Herbarium",
      code: ""
    ) })
    assert_equal(herbarium_count + 2, Herbarium.count)
    second = Herbarium.last
    assert_nil(second.code, "Blank code should be stored as nil")
  end

  # Regression test: save failure should return to form, not redirect.
  def test_create_save_failure_returns_to_form
    login("rolf")
    herbarium_count = Herbarium.count

    # Simulate save failure by creating herbarium with duplicate name
    existing = herbaria(:nybg_herbarium)
    post(:create, params: { herbarium: herbarium_params.merge(
      name: existing.name
    ) })

    # Should flash error and stay on form (not redirect with nil id)
    assert_flash_text(/already exists/i)
    assert_equal(herbarium_count, Herbarium.count)
    assert_response(:success) # Back to the form, not a redirect
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

  # Turbo stream submissions should reload the modal form with flash errors
  def test_update_blank_name_turbo_stream
    last_update = nybg.updated_at
    login("rolf")

    patch(:update,
          params: { herbarium: herbarium_params.merge(name: ""), id: nybg.id },
          as: :turbo_stream)

    assert_equal(last_update, nybg.reload.updated_at)
    assert_response(:success)
    # Should render modal_form_reload partial to update modal with flash
    assert_template("shared/_modal_form_reload")
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
    assert_redirected_to(new_account_login_path)
  end

  def test_update_with_duplicate_name_by_owner_of_some_records
    other = herbaria(:rolf_herbarium)
    last_update = nybg.updated_at
    params = herbarium_params.merge(name: other.name)
    # Roy can edit but does not own all the records.
    login("roy")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_equal(last_update, nybg.reload.updated_at)
    assert_redirected_to(new_admin_emails_merge_requests_path(
                           type: :Herbarium, old_id: nybg.id, new_id: other.id
                         ))
  end

  def test_update_with_duplicate_name_by_owner_of_all_records
    dest = herbaria(:rolf_herbarium)
    params = herbarium_params.merge(name: dest.name)
    # Rolf can both edit and does own all the records.
    # When he changes nybg's name == Rolf's personal herbarium name,
    # Should merge nybg into Rolf's personal herbarium.
    login("rolf")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_not_nil(Herbarium.safe_find(dest.id))
    assert_nil(Herbarium.safe_find(nybg.id))
  end

  def test_update_with_nonexisting_place_name
    params = {
      name: nybg.name,
      personal: nybg.personal_user_id,
      code: nybg.code,
      place_name: "New Location",
      email: nybg.email,
      mailing_address: nybg.mailing_address,
      description: nybg.description
    }
    login("rolf")
    patch(:update, params: { herbarium: params, id: nybg.id })

    assert_nil(nybg.reload.location)
    assert_redirected_to(new_location_path(where: "New Location",
                                           set_herbarium: nybg.id))
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
    assert_user_arrays_equal([mary], herbarium.reload.curators)
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
      "personal herbarium"
    )
    user = users(:zero_user)
    assert_false(
      herbarium.can_make_personal?(user),
      "Use different fixture: #{herbarium.name} cannot be made " \
      "#{user}'s personal herbarium"
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
    assert_user_arrays_equal([mary], herbarium.curators)
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
    assert_user_arrays_equal([mary], herbarium.curators)
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
    assert(HerbariumRecord.exists?(herbarium_id: nybg.id))
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
    assert_not(HerbariumRecord.exists?(herbarium_id: nybg.id))
    assert_not(
      Observation.joins(:herbarium_records).
                  exists?("herbarium_records.id" => record_ids),
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

  # This was a bug found in the wild, presumably from a user which was deleted
  # but the corresponding personal_user_id was not cleared and therefore then
  # referred to a nonexistent user.  It caused the herbarium index to crash.
  def test_herbarium_personal_user_id_corrupt
    # Intentionally "break" the user link for Rolf's personal herbarium.
    herbaria(:rolf_herbarium).update(personal_user_id: -1)
    login("mary")
    get(:index)
  end
end
