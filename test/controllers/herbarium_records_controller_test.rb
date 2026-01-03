# frozen_string_literal: true

require("test_helper")

class HerbariumRecordsControllerTest < FunctionalTestCase
  ##############################################################################
  # INDEX
  #
  def test_index
    login
    get(:index)

    assert_response(:success)
    assert_page_title(:HERBARIUM_RECORDS.l)
    # In results, expect 1 row per herbarium_record
    assert_select("#results tr", HerbariumRecord.count,
                  "Wrong number of Herbarium Records")
  end

  def test_index_with_non_default_sort
    check_index_sorting
  end

  def test_index_pattern_with_multiple_matching_records
    # Two herbarium_records match this pattern.
    pattern = "Coprinus comatus"

    login
    get(:index, params: { q: { model: :HerbariumRecord, pattern: pattern } })

    assert_response(:success)
    assert_page_title(:HERBARIUM_RECORDS.l)
    assert_displayed_filters("#{:query_pattern.l}: #{pattern}")
    # In results, expect 1 row per herbarium_record
    assert_select("#results tr", 2)
  end

  def test_index_herbarium_id_with_multiple_records
    herbarium = herbaria(:nybg_herbarium)

    login
    get(:index, params: { herbarium: herbarium.id })

    assert_page_title(:HERBARIUM_RECORDS.l)
    assert_displayed_filters("#{:query_herbaria.l}: #{herbarium.name}")

    # In results, expect 1 row per herbarium_record
    assert_select("#results tr",
                  HerbariumRecord.where(herbarium: herbarium).count)
  end

  def test_index_herbarium_id_no_matching_records
    herbarium = herbaria(:dick_herbarium)

    login
    get(:index, params: { herbarium: herbarium.id })

    assert_page_title(:HERBARIUM_RECORDS.l)
    assert_flash_text(:runtime_no_matches.l(type: :herbarium_records.l))
  end

  def test_index_observation_id
    obs = observations(:coprinus_comatus_obs)

    login
    get(:index, params: { observation: obs.id })

    assert_page_title(:HERBARIUM_RECORDS.l)
    assert_displayed_filters("#{:query_observations.l}: #{obs.id}")
    #  "Fungarium Records attached to '#{obs.unique_text_name}'")
    assert_select("#results tr", obs.herbarium_records.size)
  end

  def test_index_observation_id_with_no_herbarium_records
    login

    obs = observations(:strobilurus_diminutivus_obs)
    get(:index, params: { observation: obs.id })

    assert_page_title(:HERBARIUM_RECORDS.l)
    assert_flash_text(:runtime_no_matches.l(type: :herbarium_records.l))
  end

  ##############################################################################
  # SHOW
  #
  def test_show_herbarium_record_without_notes
    herbarium_record = herbarium_records(:coprinus_comatus_nybg_spec)
    assert(herbarium_record)
    login

    get(:show, params: { id: herbarium_record.id })

    assert_template(:show)
    assert_select("a[href=?]", new_herbarium_record_path, false,
                  "Fungarium Index should not have a `new` button")
  end

  def test_show_herbarium_record_has_notes
    herbarium_record = herbarium_records(:interesting_unknown)
    assert(herbarium_record)
    login
    get(:show, params: { id: herbarium_record.id })
    assert_template(:show)
  end

  def test_show_herbarium_record_mcp_searchable
    herbarium_record = herbarium_records(:agaricus_campestris_spec)
    assert(
      herbarium_record&.herbarium&.mcp_searchable?,
      "Test needs HerbariumRecord fixture that's searchable via MyCoPortal"
    )

    login
    get(:show, params: { id: herbarium_record.id })

    assert_select("a[href=?]", herbarium_record.mcp_url, true,
                  "Missing link to MyCoPortal record")
  end

  def test_show_herbarium_record_mcp_unsearchable
    herbarium_record = herbarium_records(:agaricus_campestris_spec)
    herbarium = herbarium_record.herbarium
    assert(
      herbarium&.mcp_searchable?,
      "Test needs HerbariumRecord in a Herbarium with a MyCoPortal db"
    )
    # Make the Herbarium code something that's not in the MyCoPortal network
    herbarium.update(code: "notInMcp")
    assert_not(herbarium.mcp_searchable?)

    login
    get(:show, params: { id: herbarium_record.id })

    assert_select("a[href=?]", herbarium_record.mcp_url, false,
                  "Missing link to MyCoPortal record")
  end

  def test_next_and_prev_herbarium_record
    query = Query.lookup_and_save(:HerbariumRecord)
    assert_operator(query.num_results, :>, 1)
    number1 = query.results[0]
    number2 = query.results[1]
    q = @controller.q_param(query)

    login
    get(:show, params: { id: number1.id, q: q, flow: :next })
    assert_redirected_to(herbarium_record_path(id: number2.id, q: q))

    get(:show, params: { id: number2.id, q: q, flow: :prev })
    assert_redirected_to(herbarium_record_path(id: number1.id, q: q))
  end

  ##############################################################################
  # NEW
  #
  def test_new_herbarium_record
    obs_id = observations(:unknown_with_no_naming).id
    get(:new, params: { observation_id: obs_id })
    assert_response(:redirect)

    login("rolf")
    get(:new, params: { observation_id: obs_id })
    assert_template("new")
    assert_equal(assigns(:herbarium_record).accession_number, "MO #{obs_id}")
  end

  def test_new_herbarium_record_turbo
    obs_id = observations(:unknown_with_no_naming).id

    login("rolf")
    get(:new, params: { observation_id: obs_id }, format: :turbo_stream)
    assert_select("#modal_herbarium_record")
    assert_select("form#herbarium_record_form")
    assert_equal(assigns(:herbarium_record).accession_number, "MO #{obs_id}")
  end

  def test_new_herbarium_record_with_collection_number
    obs = observations(:coprinus_comatus_obs)
    get(:new, params: { observation_id: obs.id })
    assert_response(:redirect)

    login("rolf")
    get(:new, params: { observation_id: obs.id })
    assert_template("new")
    assert(assigns(:herbarium_record))
    assert_equal(assigns(:herbarium_record).accession_number,
                 obs.collection_numbers.first.format_name)
  end

  def test_new_herbarium_record_with_field_slip
    obs = observations(:owner_accepts_general_questions)
    get(:new, params: { observation_id: obs.id })
    assert_response(:redirect)

    login("rolf")
    get(:new, params: { observation_id: obs.id })
    assert_template("new")
    assert(assigns(:herbarium_record))
    assert_equal(assigns(:herbarium_record).accession_number,
                 obs.field_slips.first.code)
  end

  ##############################################################################
  # EDIT
  #
  def test_edit_herbarium_record
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    get(:edit, params: { id: nybg.id })
    assert_response(:redirect)

    login("mary") # Non-curator
    get(:edit, params: { id: nybg.id })
    assert_flash_text(/permission denied/i)
    assert_response(:redirect)

    login("rolf")
    get(:edit, params: { id: nybg.id })
    assert_template(:edit)

    make_admin("mary") # Non-curator, but an admin
    get(:edit, params: { id: nybg.id })
    assert_template(:edit)
  end

  def test_edit_herbarium_record_turbo
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)

    login("rolf")
    get(:edit, params: { id: nybg.id }, format: :turbo_stream)
    assert_template("shared/_modal_form")
    assert_select("form#herbarium_record_form")
  end

  def test_edit_herbarium_record_multiple_obs
    # obs1 = observations(:coprinus_comatus_obs)
    obs2 = observations(:agaricus_campestris_obs)
    hr1 = herbarium_records(:coprinus_comatus_nybg_spec)
    hr1.add_observation(obs2)
    assert(hr1.observations.size > 1)

    login
    get(:edit, params: { id: hr1.id })
    assert_select(
      ".multiple-observations-warning",
      text: :edit_affects_multiple_observations.t(type: :herbarium_record)
    )
  end

  ##############################################################################
  # CREATE
  #
  def test_create_herbarium_record
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    obs = Observation.find(params[:observation_id])
    assert_not(obs.specimen)
    post(:create, params:)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    herbarium_record = HerbariumRecord.last
    assert_equal("The New York Botanical Garden",
                 herbarium_record.herbarium.name)
    assert_equal(params[:herbarium_record][:initial_det],
                 herbarium_record.initial_det)
    assert_equal(params[:herbarium_record][:accession_number],
                 herbarium_record.accession_number)
    assert_equal(rolf, herbarium_record.user)
    obs = Observation.find(params[:observation_id])
    assert(obs.specimen)
    assert_response(:redirect)
  end

  def test_create_herbarium_record_with_turbo
    login
    assert_difference("HerbariumRecord.count", 1) do
      post(:create, params: herbarium_record_params, format: :turbo_stream)
    end
  end

  def test_create_herbarium_record_turbo_validation_error
    obs = observations(:strobilurus_diminutivus_obs)
    login(obs.user.login)

    params = {
      observation_id: obs.id,
      herbarium_record: { herbarium_name: "", accession_number: "" }
    }

    assert_no_difference("HerbariumRecord.count") do
      post(:create, params: params, format: :turbo_stream)
    end

    assert_response(:success)
    assert_select("turbo-stream[action=?][target=?]",
                  "replace", "herbarium_record_form")
  end

  def test_create_herbarium_record_new_herbarium
    mary = login("mary")
    herbarium_count = mary.curated_herbaria.count
    params = herbarium_record_params
    params[:herbarium_record][:herbarium_name] = mary.personal_herbarium_name
    post(:create, params:)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    herbarium = Herbarium.reorder(created_at: :desc)[0]
    assert(herbarium.curators.member?(mary))
  end

  def test_create_herbarium_record_duplicate
    login("rolf")
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    existing = herbarium_records(:coprinus_comatus_nybg_spec)
    params[:herbarium_record][:herbarium_name]   = existing.herbarium.name
    params[:herbarium_record][:initial_det]      = existing.initial_det
    params[:herbarium_record][:accession_number] = existing.accession_number
    post(:create, params:)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_flash_text(/already exists/i)
    assert_response(:redirect)

    # Do the same via Turbo
    post(:create, params:, format: :turbo_stream)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_flash_text(/already exists/i)
    assert_template("shared/_modal_flash_update")
  end

  # I keep thinking only curators should be able to add herbarium_records.
  # However, for now anyone can.
  def test_create_herbarium_record_not_curator
    nybg = herbaria(:nybg_herbarium)
    obs  = observations(:strobilurus_diminutivus_obs)
    obs.update(user: dick)
    herbarium_record_count = HerbariumRecord.count
    params = herbarium_record_params
    params[:observation_id] = obs.id
    params[:herbarium_record][:herbarium_name] = nybg.name

    login("mary")
    assert_not(nybg.curators.member?(mary))
    assert_not(obs.can_edit?(mary))
    post(:create, params:)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
    assert_flash_text(/only curators can/i)

    login("dick")
    assert_not(nybg.curators.member?(dick))
    assert(obs.can_edit?(dick))
    post(:create, params:)
    assert_equal(herbarium_record_count + 1, HerbariumRecord.count)
    assert_response(:redirect)
    assert_flash_success
  end

  def test_create_herbarium_record_already_used_by_someone_else
    # Use mary's observation - she can't edit rolf's herbarium record
    obs = observations(:other_user_owns_obs)
    user = obs.user
    assert_equal("mary", user.login)

    # Use rolf's herbarium record at NYBG
    existing = herbarium_records(:interesting_unknown)
    herbarium = existing.herbarium

    # Ensure mary can't edit the existing record
    assert_not_equal(user, existing.user)
    assert_not(herbarium.curator?(user))

    login(user.login)

    params = {
      observation_id: obs.id,
      herbarium_record: {
        herbarium_name: herbarium.name,
        accession_number: existing.accession_number
      }
    }

    assert_no_difference("HerbariumRecord.count") do
      post(:create, params: params)
    end

    assert_flash_error
  end

  def test_create_herbarium_record_cannot_auto_create_herbarium
    obs = observations(:strobilurus_diminutivus_obs)
    login(obs.user.login)

    # Use a name that doesn't match the personal herbarium pattern
    params = {
      observation_id: obs.id,
      herbarium_record: {
        herbarium_name: "Some Random Herbarium",
        accession_number: "12345"
      }
    }

    assert_no_difference("HerbariumRecord.count") do
      post(:create, params: params)
    end

    assert_flash_warning
  end

  def test_create_herbarium_record_redirect
    obs = observations(:coprinus_comatus_obs)
    @controller.find_or_create_query(:HerbariumRecord)
    params = {
      observation_id: obs.id,
      herbarium_record: { herbarium_name:
                          obs.user.preferred_herbarium.autocomplete_name }
    }

    # Prove that query params are added to form action.
    login(obs.user.login)
    get(:new, params:)
    assert_select(
      "form[action*='records?observation_id=#{obs.id}']"
    )
    assert_session_query_record_is_correct

    # Prove that post keeps query params intact.
    post(:create, params:)
    assert_redirected_to(permanent_observation_path(id: obs.id))
    assert_session_query_record_is_correct
  end

  ##############################################################################
  # UPDATE
  #
  def test_update_herbarium_record
    herbarium_record_setup => { params:, nybg_rec:, nybg_user:, rolf_herb: }

    post(:update, params:)

    assert_record_updated(params:, nybg_rec:, nybg_user:, rolf_herb:)
    assert_response(:redirect)
  end

  def test_update_herbarium_record_turbo
    herbarium_record_setup => { params:, nybg_rec:, nybg_user:, rolf_herb: }

    post(:update, params:, format: :turbo_stream)

    assert_template("observations/show/_section_update")
    assert_record_updated(params:, nybg_rec:, nybg_user:, rolf_herb:)
  end

  def test_update_herbarium_record_no_specimen
    login("rolf")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    post(:update, params: { id: nybg.id })
    assert_redirected_to(action: :edit)

    # Test turbo shows flash
    post(:update, params: { id: nybg.id }, format: :turbo_stream)
    assert_flash_text(/missing/i)
    assert_template("shared/_modal_form_reload")
  end

  def test_update_herbarium_record_wrong_user
    login("mary")
    nybg = herbarium_records(:coprinus_comatus_nybg_spec)
    obs = observations(:coprinus_comatus_obs)
    post(:update, params: { id: nybg.id })
    assert_redirected_to(controller: "/observations", action: :show, id: obs.id)

    # Test turbo shows flash
    post(:update, params: { id: nybg.id }, format: :turbo_stream)
    assert_flash_text(/permission denied/i)
    assert_template("shared/_modal_flash_update")
  end

  def test_update_herbarium_record_label_already_used
    record = herbarium_records(:coprinus_comatus_rolf_spec)
    existing = herbarium_records(:interesting_unknown)
    login("rolf")

    params = {
      id: record.id,
      herbarium_record: {
        herbarium_name: existing.herbarium.name,
        accession_number: existing.accession_number
      }
    }

    patch(:update, params: params)

    assert_flash_warning
    # Record should not have changed
    record.reload
    assert_not_equal(existing.accession_number, record.accession_number)
  end

  def test_update_herbarium_record_redirect
    obs   = observations(:detailed_unknown_obs)
    rec   = obs.herbarium_records.first
    query = @controller.find_or_create_query(:HerbariumRecord)
    q     = @controller.q_param(query)
    make_admin("rolf")
    params = {
      id: rec.id,
      herbarium_record: {
        herbarium_name: rec.herbarium.autocomplete_name,
        initial_det: rec.initial_det,
        accession_number: rec.accession_number,
        notes: rec.notes
      }
    }

    # Prove that GET passes "back" and query param through to form.
    get(:edit, params: params.merge(back: "foo"))
    assert_select("form[action*='?back=foo']")
    assert_session_query_record_is_correct

    # Prove that POST keeps query param when returning to observation.
    post(:update, params: params.merge(back: obs.id))
    assert_redirected_to(permanent_observation_path(id: obs.id))
    assert_session_query_record_is_correct

    # Prove that POST can return to show_herbarium_record with query intact.
    post(:update, params: params.merge(back: "show"))
    assert_redirected_to(herbarium_record_path(id: rec.id))
    assert_session_query_record_is_correct

    # Prove that POST can return to index_herbarium_record with query intact.
    post(:update, params: params.merge(back: "index"))
    assert_redirected_to(herbarium_records_path(id: rec.id, q:))
    assert_session_query_record_is_correct
  end

  ##############################################################################
  # DESTROY
  #
  def test_destroy_herbarium_record
    login("rolf")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    observations = herbarium_record.observations
    obs_rec_count = observations.sum { |o| o.herbarium_records.count }
    delete(:destroy, params: params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    observations.map(&:reload)
    assert_true(
      obs_rec_count > observations.sum { |o| o.herbarium_records.count }
    )
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_not_curator
    login("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    delete(:destroy, params: params)
    assert_equal(herbarium_record_count, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_admin
    make_admin("mary")
    herbarium_record = herbarium_records(:interesting_unknown)
    params = { id: herbarium_record.id }
    herbarium_record_count = HerbariumRecord.count
    delete(:destroy, params: params)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    assert_response(:redirect)
  end

  def test_destroy_herbarium_record_redirect
    obs   = observations(:detailed_unknown_obs)
    recs  = obs.herbarium_records
    query = @controller.find_or_create_query(:HerbariumRecord)
    q     = @controller.q_param(query)
    assert_operator(recs.length, :>, 1)
    make_admin("rolf")

    # Prove by default it goes back to index.
    delete(:destroy, params: { id: recs[0].id })
    assert_redirected_to(herbarium_records_path(q:))
    assert_session_query_record_is_correct
  end

  def test_destroy_herbarium_record_redirect_to_observation
    login("rolf")
    herbarium_record = herbarium_records(:coprinus_comatus_rolf_spec)
    observation = herbarium_record.observations.first
    herbarium_record_count = HerbariumRecord.count

    # Use HTML format to test redirect behavior
    delete(:destroy,
           params: { id: herbarium_record.id, back: observation.id.to_s })

    # Should successfully destroy and redirect to observation
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    assert_redirected_to(observation_path(observation))
  end

  # Bug: Destroy button on show page uses turbo_stream format, causing error
  # because @observation is nil. Should redirect with HTML format instead.
  def test_destroy_herbarium_record_turbo_from_show_page
    login("rolf")
    herbarium_record = herbarium_records(:coprinus_comatus_rolf_spec)
    herbarium_record_count = HerbariumRecord.count

    # Simulate clicking Destroy button on the show page (back: "show")
    # The button incorrectly requests turbo_stream format
    delete(:destroy, params: { id: herbarium_record.id, back: "show" },
                     format: :turbo_stream)

    # Should still successfully destroy and redirect (not error)
    assert_equal(herbarium_record_count - 1, HerbariumRecord.count)
    # Should redirect to index since we can't do turbo_stream update
    assert_redirected_to(herbarium_records_path)
  end

  # -------- Remove from observation (destroy with observation_id) ------------

  def test_remove_from_observation_must_be_logged_in
    obs = observations(:agaricus_campestris_obs)
    rec = obs.herbarium_records.first

    delete(:destroy, params: { id: rec.id, observation_id: obs.id })
    assert_true(obs.reload.herbarium_records.include?(rec))
  end

  def test_remove_from_observation_only_owner_can_remove
    obs = observations(:agaricus_campestris_obs)
    rec = obs.herbarium_records.first

    login("mary") # owner is rolf
    delete(:destroy, params: { id: rec.id, observation_id: obs.id })
    assert_true(obs.reload.herbarium_records.include?(rec))
  end

  def test_remove_from_observation_destroys_when_last_obs
    obs = observations(:agaricus_campestris_obs)
    rec = obs.herbarium_records.first

    login("rolf")
    delete(:destroy, params: { id: rec.id, observation_id: obs.id })
    assert_empty(obs.reload.herbarium_records)
    assert_nil(HerbariumRecord.safe_find(rec.id))
  end

  def test_remove_from_observation_keeps_when_other_obs_remain
    obs1 = observations(:agaricus_campestris_obs)
    obs2 = observations(:coprinus_comatus_obs)
    rec = obs2.herbarium_records.first
    rec.add_observation(obs1)

    login("rolf")
    delete(:destroy, params: { id: rec.id, observation_id: obs2.id })
    assert_true(obs1.reload.herbarium_records.include?(rec))
    assert_false(obs2.reload.herbarium_records.include?(rec))
    assert_not_nil(HerbariumRecord.safe_find(rec.id))
  end

  def test_remove_from_observation_turbo_stream
    obs = observations(:agaricus_campestris_obs)
    rec = obs.herbarium_records.first

    login("rolf")
    delete(:destroy, params: { id: rec.id, observation_id: obs.id },
                     format: :turbo_stream)
    assert_empty(obs.reload.herbarium_records)
    assert_response(:success)
    assert_select("turbo-stream[action=?][target=?]",
                  "replace", "observation_herbarium_records")
  end

  ##############################################################################

  private

  def herbarium_record_params
    {
      observation_id: observations(:strobilurus_diminutivus_obs).id,
      herbarium_record: {
        herbarium_name: rolf.preferred_herbarium.autocomplete_name,
        initial_det: "Strobilurus diminutivus det. Rolf Singer",
        accession_number: "1234567",
        notes: "Some notes about this herbarium record"
      }
    }
  end

  def herbarium_record_setup
    login("rolf")
    nybg_rec    = herbarium_records(:coprinus_comatus_nybg_spec)
    nybg_user   = nybg_rec.user
    rolf_herb   = rolf.personal_herbarium
    params      = herbarium_record_params
    params[:id] = nybg_rec.id
    params[:herbarium_record][:herbarium_name] = rolf_herb.name
    assert_not_equal(rolf_herb, nybg_rec.herbarium)

    { params:, nybg_rec:, nybg_user:, rolf_herb: }
  end

  def assert_record_updated(**args)
    args => { params:, nybg_rec:, nybg_user:, rolf_herb: }

    nybg_rec.reload
    assert_equal(rolf_herb, nybg_rec.herbarium)
    assert_equal(nybg_user, nybg_rec.user)
    assert_equal(params[:herbarium_record][:initial_det],
                 nybg_rec.initial_det)
    assert_equal(params[:herbarium_record][:accession_number],
                 nybg_rec.accession_number)
    assert_equal(params[:herbarium_record][:notes], nybg_rec.notes)
  end
end
