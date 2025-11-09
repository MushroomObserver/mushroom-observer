# frozen_string_literal: true

require("test_helper")

class ObservationsControllerShowTest < FunctionalTestCase
  tests ObservationsController

  ##############################################################################

  # ----------------------------
  #  General tests.
  # ----------------------------

  def test_show_no_login
    obs = observations(:deprecated_name_obs)
    get(:show, params: { id: obs.id })
    assert_response(:success)
  end

  def test_show_no_login_with_flow
    obs = observations(:deprecated_name_obs)
    get(:show, params: { id: obs.id, flow: "next" })
    assert_response(:redirect)
  end

  def test_show_login
    login
    obs = observations(:deprecated_name_obs)
    get(:show, params: { id: obs.id })
    assert_response(:success)
    # There won't be prev/next UI because there's no query.
    # assert(@response.body.include?("flow=next"))
  end

  def test_show_no_q_param_when_no_query
    login
    get(:show, params: { id: Observation.first.id })
    assert_response(:success)
    assert_nil(@controller.q_param)
  end

  # Test load a deprecated name obs, no strict_loading error
  def test_show_observation_deprecated_name
    obs = observations(:deprecated_name_obs)
    get(:show, params: { id: obs.id })
    assert_response(:success)
  end

  def test_show_observation_noteless_image
    obs = observations(:peltigera_mary_obs)
    img = images(:rolf_profile_image)
    assert_nil(img.notes)
    assert(obs.images.member?(img))
    get(:show, params: { id: obs.id })
    assert_response(:success)
  end

  def test_show_observation_noteful_image
    obs = observations(:detailed_unknown_obs)
    get(:show, params: { id: obs.id })
    assert_response(:success)
  end

  def test_show_observation_with_structured_notes
    login
    obs = observations(:template_and_orphaned_notes_scrambled_obs)
    get(:show, params: { id: obs.id })
    assert_match("+photo", @response.body)
    assert_match("/lookups/lookup_user/rolf", @response.body)
    assert_no_match("orphaned_caption_1", @response.body)
    assert_match("orphaned caption 1", @response.body)
  end

  def test_show_observation_with_simple_notes
    login
    obs = observations(:coprinus_comatus_obs)
    get(:show, params: { id: obs.id })
    assert_match("<p>Notes:<br />", @response.body)
  end

  def test_show_project_observation
    login
    obs = observations(:owner_accepts_general_questions)
    project = obs.projects[0]
    get(:show, params: { id: obs.id })
    assert_match(project.title, @response.body)
  end

  def test_show_observation_change_thumbnail_size
    user = users(:small_thumbnail_user)
    login(user.name)
    obs = observations(:detailed_unknown_obs)
    get(:show, params: { id: obs.id, set_thumbnail_size: "thumbnail" })
    user.reload
    assert_equal("thumbnail", user.thumbnail_size)
  end

  def test_show_observation_vague_location
    login
    obs1 = observations(:california_obs)
    get(:show, params: { id: obs1.id })
    assert_match(:show_observation_vague_location.l, @response.body)
    assert_no_match(:show_observation_improve_location.l, @response.body)

    # Make sure it suggests choosing a better location if owner is current user
    login("dick")
    get(:show, params: { id: obs1.id })
    assert_match(:show_observation_vague_location.l, @response.body)
    assert_match(:show_observation_improve_location.l, @response.body)

    # Make sure it doesn't show for observations with non-vague location
    obs2 = observations(:amateur_obs)
    get(:show, params: { id: obs2.id })
    assert_no_match(:show_observation_vague_location.l, @response.body)
  end

  def test_show_observation_hidden_gps
    obs = observations(:unknown_with_lat_lng)
    login
    get(:show, params: { id: obs.id })
    assert_match(/34.1622|118.3521/, @response.body)

    obs.update(gps_hidden: true)
    get(:show, params: { id: obs.id })
    assert_no_match(/34.1622|118.3521/, @response.body)

    login("mary")
    get(:show, params: { id: obs.id })
    assert_match(/34.1622|118.3521/, @response.body)
    assert_match(:show_observation_gps_hidden.t, @response.body)

    login("roy")
    get(:show, params: { id: obs.id })
    assert_match(/34.1622|118.3521/, @response.body)
    assert_match(:show_observation_gps_hidden.t, @response.body)
  end

  def test_show_obs_view_stats
    obs = observations(:minimal_unknown_obs)
    assert_empty(ObservationView.where(observation: obs))
    login
    get(:show, params: { id: obs.id })
    assert_equal(1, ObservationView.where(observation: obs).count)
    assert_select(".footer-view-stats") do |p|
      assert_includes(p.to_s, :footer_viewed.t(date: :footer_never.l,
                                               times: :many_times.l(num: 0)))
    end

    last_view = 1.hour.ago
    obs.update!(last_view: last_view)
    login("dick")
    get(:show, params: { id: obs.id })
    assert_equal(2, ObservationView.where(observation: obs).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
    assert_select(".footer-view-stats") do |p|
      assert_includes(p.to_s, :footer_viewed.t(date: last_view.web_time,
                                               times: :one_time.l))
      assert_includes(p.to_s, :footer_last_you_viewed.t(date: :footer_never.l))
    end

    last_view = 2.months.ago
    obs.update!(last_view: last_view)
    obs.observation_views.where(user: dick).first.update!(last_view: last_view)
    get(:show, params: { id: obs.id })
    assert_equal(2, ObservationView.where(observation: obs).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
    assert_select(".footer-view-stats") do |p|
      assert_includes(p.to_s, :footer_viewed.t(date: last_view.web_time,
                                               times: :many_times.l(num: 2)))
      assert_includes(p.to_s,
                      :footer_last_you_viewed.t(date: last_view.web_time))
    end
  end

  def test_show_observation_curator_with_mcp_link
    obs = observations(:agaricus_campestris_obs)
    herbarium_record = herbarium_records(:agaricus_campestris_spec)
    assert(
      herbarium_record&.herbarium&.mcp_searchable?,
      "Test needs Obs fixture with HerbariumRecord " \
      "that's searchable via MyCoPortal"
    )
    user = users(:dick)
    assert(user.curated_herbaria.any?,
           "Test needs User who's a Herbarium curator")

    login(user.login)
    get(:show, params: { id: obs.id })

    assert_match(:herbarium_record_collection.l, @response.body)
    assert_select("a[href=?]", herbarium_record.mcp_url, true,
                  "Missing link to MyCoPortal record")
  end

  def test_show_observation_non_curator_with_mcp_link
    obs = observations(:agaricus_campestris_obs)
    herbarium_record = herbarium_records(:agaricus_campestris_spec)
    assert(
      herbarium_record&.herbarium&.mcp_searchable?,
      "Test needs Obs fixture with HerbariumRecord " \
      "that's searchable via MyCoPortal"
    )
    user = users(:zero_user)
    assert(user.curated_herbaria.none?,
           "Test needs User who's not a Herbarium curator")

    login(user.login)
    get(:show, params: { id: obs.id })

    assert_match(:herbarium_record_collection.l, @response.body)
    assert_select("a[href=?]", herbarium_record.mcp_url, true,
                  "Missing link to MyCoPortal record")
  end

  def test_show_observation_unsearchable_coded_herbarium
    obs = observations(:agaricus_campestris_obs)
    herbarium_record = herbarium_records(:agaricus_campestris_spec)
    herbarium = herbarium_record&.herbarium
    herbarium.update(code: "notInMcp")

    user = users(:dick)
    assert(user.curated_herbaria.any?,
           "Test needs User who's a Herbarium curator")

    login(user.login)
    get(:show, params: { id: obs.id })

    assert_no_match(:herbarium_record_collection.l, @response.body)
    assert_select(
      "a[href=?]", herbarium_record.mcp_url, false,
      "Obs shouldn't link to MyCoPortal for Herbarium Record in a Herbarium " \
      "that's not in the MCP network"
    )
  end

  def test_show_observation_nil_user
    login
    obs = observations(:detailed_unknown_obs)
    obs.current_user = rolf
    obs.update(user: nil)

    get(:show, params: { id: obs.id })

    assert_response(:success)
    assert_template("observations/show")
  end

  ##############################################################################

  # ------ Show ----------------------------------------------- #

  def test_show_observation_num_views
    login
    obs = observations(:coprinus_comatus_obs)
    updated_at = obs.updated_at
    num_views = obs.num_views
    last_view = obs.last_view
    # obs.update_view_stats
    get(:show, params: { id: obs.id })
    obs.reload
    assert_equal(num_views + 1, obs.num_views)
    assert_not_equal(last_view, obs.last_view)
    assert_equal(updated_at, obs.updated_at)
  end

  def assert_show_observation
    assert_template("observations/show")
    assert_template("observations/show/_name_info")
    assert_template("observations/show/_observation_details")
    # assert_template("observations/show/_namings") now a helper
    assert_template("comments/_comments_for_object")
    assert_template("observations/show/_thumbnail_map")
  end

  # Refactored for CRUD routes in :collection_numbers or :herbarium_records
  def assert_show_obs(types, _id, items, can_add)
    type = types.to_s.chop
    selector = types == :collection_numbers && !can_add ? "i" : "li"
    assert_select("#observation_#{types} #{selector}",
                  items.count,
                  "Wrong number of #{types} shown.")
    if can_add
      assert(response.body.match(%r{href="/#{types}/new}),
             "Expected to find a create link for #{types}.")
    else
      assert_not(response.body.match(%r{href="/#{types}/new}),
                 "Expected not to find a create link for #{types}.")
    end

    items.each do |type_id, can_edit|
      if can_edit
        assert(response.body.match(%r{href="/#{types}/#{type_id}/edit}),
               "Expected to find an edit link for #{type} #{type_id}.")
      else
        assert_not(
          response.body.match(%r{href="/#{types}/#{type_id}/edit}),
          "Expected not to find an edit link for #{type} #{type_id}."
        )
      end
    end
  end

  def test_show_observation
    login
    assert_equal(0, QueryRecord.count)

    # Test it on obs with no namings first.
    obs = observations(:unknown_with_no_naming)
    get(:show, params: { id: obs.id })
    assert_show_observation

    # Test that comments appear for observation with comments
    obs = observations(:minimal_unknown_obs)
    get(:show, params: { id: obs.id })
    assert_show_observation
    assert_select("#comments") do
      assert_select(".comment-summary", text: "A comment on minimal unknown")
      assert_select(".comment-summary", /complicated/)
    end
    # Test that the panel title and new comment link appears.
    assert_select("#comments_for_object .panel-heading",
                  text: "#{:COMMENTS.l} #{:show_comments_add_comment.l}")

    # You must be logged in to get the show_obs naming table now.
    # Test it on obs with two namings (Rolf's and Mary's), with owner logged in.
    obs = observations(:coprinus_comatus_obs)
    rolf_nmg = obs.namings.first
    consensus = Observation::NamingConsensus.new(obs)
    get(:show, params: { id: obs.id })
    assert_show_observation
    assert_form_action(controller: "observations/namings/votes",
                       action: :update, naming_id: rolf_nmg.id,
                       observation_id: obs.id,
                       id: consensus.users_vote(rolf_nmg, rolf))

    # Test it on obs with two namings, with non-owner logged in.
    login("mary")
    obs = observations(:coprinus_comatus_obs)
    get(:show, params: { id: obs.id })
    assert_show_observation
    assert_form_action(controller: "observations/namings/votes",
                       action: :update, naming_id: rolf_nmg.id,
                       observation_id: obs.id,
                       id: consensus.users_vote(rolf_nmg, mary))

    # Test a naming owned by the observer but the observer has 'No Opinion'.
    # Ensure that rolf owns @obs_with_no_opinion.
    user = login("rolf")
    obs = observations(:strobilurus_diminutivus_obs)
    assert_equal(obs.user, user)
    get(:show, params: { id: obs.id })
    assert_show_observation

    # Make sure no queries created for show_image links.
    assert_empty(QueryRecord.where("description like '%model=:Image%'"))
  end

  def test_show_observation_change_vote_anonymity
    obs = observations(:coprinus_comatus_obs)
    user = login(users(:public_voter).name)

    get(:show, params: { id: obs.id, go_private: 1 })
    user.reload
    assert_equal("yes", user.votes_anonymous)

    get(:show, params: { id: obs.id, go_public: 1 })
    user.reload
    assert_equal("no", user.votes_anonymous)
  end

  def test_show_owner_naming
    login(user_with_view_owner_id_true)
    obs = observations(:owner_only_favorite_ne_consensus)
    consensus = Observation::NamingConsensus.new(obs)
    assert_not_equal(obs.name.id, consensus.owner_preference.id)

    get(:show, params: { id: obs.id })
    assert_select("#owner_naming",
                  { text: /#{consensus.owner_preference.text_name}/,
                    count: 1 },
                  "Observation should show owner's preferred naming")

    get(
      :show, params: { id: observations(:owner_multiple_favorites).id }
    )
    assert_equal(css_select("#owner_naming").length, 0)
  end

  def test_show_owner_naming_view_owner_id_false
    login(user_with_view_owner_id_false)
    get(
      :show, params: { id: observations(:owner_only_favorite_ne_consensus).id }
    )
    assert_select(
      "#owner_naming", { count: 0 },
      "Do not show owner's preferred naming when user has not opted for it"
    )
  end

  def user_with_view_owner_id_true
    users(:rolf).login
  end

  def user_with_view_owner_id_false
    users(:dick).login
  end

  def test_observation_external_links_exist
    login
    obs_id = observations(:coprinus_comatus_obs).id
    get(:show, params: { id: obs_id })

    assert_select("a[href *= 'images.google.com']")
    assert_select("a[href *= 'mycoportal.org']")

    # There is a MycoBank link which includes taxon name and MycoBank language
    assert_select("a[href *= 'mycobank.org']") do
      assert_select("a[href *= '/Coprinus%20comatus']")
    end
  end

  def test_show_observation_edit_links
    obs = observations(:detailed_unknown_obs)
    proj = projects(:bolete_project)
    assert_equal(mary.id, obs.user_id)  # owned by mary
    assert(obs.projects.include?(proj)) # owned by bolete project

    login("rolf") # Can't edit
    get(:show, params: { id: obs.id })
    assert_select("a:match('href',?)", edit_observation_path(obs.id), count: 0)
    assert_select(".destroy_observation_link_#{obs.id}", count: 0)
    assert_select("a:match('href',?)",
                  reuse_images_for_observation_path(obs.id), count: 0)
    get(:edit, params: { id: obs.id })
    assert_response(:redirect)
    get(:destroy, params: { id: obs.id })
    assert_flash_error

    login("mary") # Owner
    get(:show, params: { id: obs.id })
    assert_select("a[href=?]", edit_observation_path(obs.id), minimum: 1)
    # Destroy button is in a form, not a link_to
    assert_select(".destroy_observation_link_#{obs.id}", minimum: 1)
    assert_select("a[href=?]",
                  reuse_images_for_observation_path(obs.id), minimum: 1)
    get(:edit, params: { id: obs.id })
    assert_match(obs.location.name, response.body)
    assert_response(:success)

    login("dick") # Project permission
    get(:show, params: { id: obs.id })
    assert_select("a[href=?]", edit_observation_path(obs.id), minimum: 1)
    # Destroy button is in a form, not a link_to
    assert_select(".destroy_observation_link_#{obs.id}", minimum: 1)
    assert_select("a[href=?]",
                  reuse_images_for_observation_path(obs.id), minimum: 1)
    get(:edit, params: { id: obs.id })
    assert_response(:success)
    get(:destroy, params: { id: obs.id })
    assert_flash_success
  end

  def test_show_observation_specimen_stuff
    obs1 = observations(:strobilurus_diminutivus_obs)
    obs2 = observations(:minimal_unknown_obs)
    obs3 = observations(:detailed_unknown_obs)
    observations(:locally_sequenced_obs).sequences.
      first.update(observation: obs2)
    observations(:genbanked_obs).sequences.
      each { |s| s.update(observation: obs3) }
    obs2.reload
    obs3.reload

    # Obs1 has nothing, owned by rolf, not in project.
    assert_users_equal(rolf, obs1.user)
    assert_empty(obs1.projects)
    assert_empty(obs1.collection_numbers)
    assert_empty(obs1.herbarium_records)
    assert_empty(obs1.sequences)

    # Obs2 owned by mary, not in project,
    # one collection_number owned by mary,
    # one herbarium_record owned by rolf at NY (roy is curator),
    # one sequence owned by rolf.
    assert_users_equal(mary, obs2.user)
    assert_empty(obs2.projects)
    assert_operator(obs2.collection_numbers.count, :==, 1)
    assert_operator(obs2.herbarium_records.count, :==, 1)
    assert_operator(obs2.sequences.count, :==, 1)
    assert_false(obs2.herbarium_records.first.can_edit?(mary))
    assert_true(obs2.herbarium_records.first.can_edit?(rolf))
    assert_true(obs2.herbarium_records.first.can_edit?(roy))

    # Obs3 owned by mary, in bolete project (dick admin and member),
    # two collection_numbers owned by mary,
    # two herbarium_records, one owned by rolf at NY,
    #   one owned by mary at FunDiS,
    # several sequences all owned by dick.
    assert_users_equal(mary, obs3.user)
    assert_equal("Bolete Project", obs3.projects.first.title)
    assert_true(obs3.can_edit?(dick))
    assert_operator(obs3.collection_numbers.count, :>, 1)
    assert_operator(obs3.herbarium_records.count, :>, 1)
    assert_operator(obs3.sequences.count, :>, 1)

    # Katrina isn't associated in any way with any of these observations.
    login("katrina")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, obs1.id, [], false)
    assert_show_obs(:herbarium_records, obs1.id, [], false)
    # But any logged-in user can add sequence to any observation.
    assert_select("a[href ^= '#{new_sequence_path}']", { count: 1 },
                  "Observation page should show an Add Sequence link for " \
                  "any logged-in user")

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers, obs2.id,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records, obs2.id,
                    [[obs2.herbarium_records.first.id, false]],
                    false)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs2.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers, obs3.id,
                    obs3.collection_numbers.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:herbarium_records, obs3.id,
                    obs3.herbarium_records.map { |x| [x.id, false] },
                    false)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs3.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    # Roy is a curator at NY, so can add herbarium records, and modify existing
    # herbarium records attached to NY.
    login("roy")
    assert_true(roy.curated_herbaria.any?)
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, obs1.id, [], false)
    assert_show_obs(:herbarium_records, obs1.id, [], true)
    assert_select("a[href ^= '#{new_sequence_path}']", { count: 1 },
                  "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers, obs2.id,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records, obs2.id,
                    [[obs2.herbarium_records.first.id, true]],
                    true)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs2.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers, obs3.id,
                    obs3.collection_numbers.map { |x| [x.id, false] },
                    false)
    assert_show_obs(:herbarium_records, obs3.id,
                    obs3.herbarium_records.map { |x| [x.id, x.can_edit?(roy)] },
                    true)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs3.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    # Dick owns all of the sequences, is on obs3's project, and has a personal
    # herbarium.
    login("dick")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, obs1.id, [], false)
    assert_show_obs(:herbarium_records, obs1.id, [], true)
    assert_select("a[href ^= '#{new_sequence_path}']", { count: 1 },
                  "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers, obs2.id,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records, obs2.id,
                    [[obs2.herbarium_records.first.id, false]],
                    true)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs2.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers, obs3.id,
                    obs3.collection_numbers.map { |x| [x.id, true] },
                    true)
    assert_show_obs(:herbarium_records, obs3.id,
                    obs3.herbarium_records.map { |x| [x.id, false] },
                    true)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs3.id)}']",
                  { count: 1 },
                  "Observation page missing an Add Sequence link")

    # Rolf owns obs1 and owns one herbarium record for both obs2 and obs3,
    # and he is a curator at NYBG.
    login("rolf")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, obs1.id, [], true)
    assert_show_obs(:herbarium_records, obs1.id, [], true)
    assert_select("a[href ^= '#{new_sequence_path}']", { count: 1 },
                  "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs2.id })
    assert_show_obs(:collection_numbers, obs2.id,
                    [[obs2.collection_numbers.first.id, false]],
                    false)
    assert_show_obs(:herbarium_records, obs2.id,
                    [[obs2.herbarium_records.first.id, true]],
                    true)
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs2.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs3.id })
    assert_show_obs(:collection_numbers, obs3.id,
                    obs3.collection_numbers.map { |x| [x.id, false] }, false)
    assert_show_obs(
      :herbarium_records, obs3.id,
      obs3.herbarium_records.map { |x| [x.id, x.can_edit?(rolf)] },
      true
    )
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs3.id)}']",
                  { count: 1 },
                  "Observation page missing an Add Sequence link")

    # Mary owns obs2 and obs3, but has nothing to do with obs1.
    login("mary")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, obs1.id, [], false)
    assert_show_obs(:herbarium_records, obs1.id, [], false)
    assert_select("a[href ^= '#{new_sequence_path}']", { count: 1 },
                  "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs2.id })
    assert_show_obs(
      :collection_numbers, obs2.id,
      [[obs2.collection_numbers.first.id, true]],
      true
    )
    assert_show_obs(
      :herbarium_records, obs2.id,
      [[obs2.herbarium_records.first.id, false]],
      true
    )
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs2.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs3.id })
    assert_show_obs(
      :collection_numbers, obs3.id,
      obs3.collection_numbers.map { |x| [x.id, true] },
      true
    )
    assert_show_obs(
      :herbarium_records, obs3.id,
      obs3.herbarium_records.map { |x| [x.id, x.can_edit?(mary)] },
      true
    )
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs3.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    # Make sure admins can do everything.
    make_admin("katrina")
    get(:show, params: { id: obs1.id })
    assert_show_obs(:collection_numbers, obs1.id, [], true)
    assert_show_obs(:herbarium_records, obs1.id, [], true)
    assert_select("a[href ^= '#{new_sequence_path}']", { count: 1 },
                  "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs2.id })
    assert_show_obs(
      :collection_numbers, obs2.id,
      [[obs2.collection_numbers.first.id, true]],
      true
    )
    assert_show_obs(
      :herbarium_records, obs2.id,
      [[obs2.herbarium_records.first.id, true]],
      true
    )
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs2.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")

    get(:show, params: { id: obs3.id })
    assert_show_obs(
      :collection_numbers, obs3.id,
      obs3.collection_numbers.map { |x| [x.id, true] },
      true
    )
    assert_show_obs(
      :herbarium_records, obs3.id,
      obs3.herbarium_records.map { |x| [x.id, true] },
      true
    )
    assert_select("a[href ^= '#{new_sequence_path(observation_id: obs3.id)}']",
                  { count: 1 }, "Observation page missing an Add Sequence link")
  end

  def test_prev_and_next_observation_simple
    # Uses non-default observation query. :when is the default order
    o_chron = Observation.reorder(created_at: :desc, id: :desc)
    login
    # need to save a query here to get :next in a non-standard order
    Query.lookup_and_save(:Observation, order_by: :created_at)
    q = @controller.q_param(QueryRecord.last.query)

    get(:show, params: { id: o_chron.fourth.id, flow: :next, q: })
    assert_redirected_to(action: :show, id: o_chron.fifth.id, q:)

    get(:show, params: { id: o_chron.fourth.id, flow: :prev, q: })
    assert_redirected_to(action: :show, id: o_chron.third.id, q:)

    # Test that prev/next links do not have :q, and index link does
    get(:show, params: { id: o_chron.third.id })
    next_href = observation_path(o_chron.fourth.id)
    prev_href = observation_path(o_chron.second.id)
    index_href = observations_path(params: { id: o_chron.third.id, q: })
    assert_select("a.next_object_link[href='#{next_href}']")
    assert_select("a.prev_object_link[href='#{prev_href}']")
    assert_select("a.index_object_link[href='#{index_href}']")
  end

  def test_prev_and_next_observation_with_fancy_query
    n1 = names(:agaricus_campestras)
    n2 = names(:agaricus_campestris)
    n3 = names(:agaricus_campestros)
    n4 = names(:agaricus_campestrus)

    n2.transfer_synonym(n1)
    n2.transfer_synonym(n3)
    n2.transfer_synonym(n4)
    n1.correct_spelling = n2
    n1.save_without_our_callbacks

    o1 = n1.observations.first
    o2 = n2.observations.first
    o3 = n3.observations.first
    o4 = n4.observations.first

    # When requesting non-synonym observations of n2.  Does not include
    # n1 even though n1 was clearly intended to be an observation of
    # n2.
    query = Query.lookup_and_save(
      :Observation, names: { lookup: n2.id, include_synonyms: false },
                    order_by: :name
    )
    assert_equal(1, query.num_results)

    # Likewise, when requesting *synonym* observations, neither n1 nor n2
    # should be included.
    query = Query.lookup_and_save(
      :Observation, names: { lookup: n2.id, include_synonyms: true,
                             exclude_original_names: true },
                    order_by: :name
    )
    assert_equal(2, query.num_results)

    # But for our prev/next test, lets do the all-inclusive query.
    query = Query.lookup_and_save(
      :Observation, names: { lookup: n2.id, include_synonyms: true },
                    order_by: :name
    )
    assert_equal(4, query.num_results)
    params = { q: @controller.q_param(query) }

    o_id = observations(:minimal_unknown_obs).id

    login
    get(:show, params: params.merge({ id: o_id, flow: "next" }))
    assert_redirected_to(action: :show, id: o_id, params:)
    assert_flash_text(/can.*t find.*results.*index/i)
    get(:show, params: params.merge({ id: o1.id, flow: "next" }))
    assert_redirected_to(action: :show, id: o2.id, params:)
    get(:show, params: params.merge({ id: o2.id, flow: "next" }))
    assert_redirected_to(action: :show, id: o3.id, params:)
    get(:show, params: params.merge({ id: o3.id, flow: "next" }))
    assert_redirected_to(action: :show, id: o4.id, params:)
    get(:show, params: params.merge({ id: o4.id, flow: "next" }))
    assert_redirected_to(action: :show, id: o4.id, params:)
    assert_flash_text(/no more/i)

    get(:show, params: params.merge({ id: o4.id, flow: "prev" }))
    assert_redirected_to(action: :show, id: o3.id, params:)
    get(:show, params: params.merge({ id: o3.id, flow: "prev" }))
    assert_redirected_to(action: :show, id: o2.id, params:)
    get(:show, params: params.merge({ id: o2.id, flow: "prev" }))
    assert_redirected_to(action: :show, id: o1.id, params:)
    get(:show, params: params.merge({ id: o1.id, flow: "prev" }))
    assert_redirected_to(action: :show, id: o1.id, params:)
    assert_flash_text(/no more/i)
    get(:show, params: params.merge({ id: o_id, flow: "prev" }))
    assert_redirected_to(action: :show, id: o_id, params:)
    assert_flash_text(/can.*t find.*results.*index/i)
  end
  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_observation
    login("rolf")
    minimal_unknown = observations(:minimal_unknown_obs)

    # No interest in this observation yet.
    #
    # <img[^>]+watch.*\.png[^>]+>[\w\s]*
    get(:show, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /watch.*\.png/,
      set_interest_path(type: "Observation", id: minimal_unknown.id, state: 1)
    )
    assert_image_link_in_html(
      /ignore.*\.png/,
      set_interest_path(type: "Observation", id: minimal_unknown.id, state: -1)
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(target: minimal_unknown, user: rolf, state: true)
    get(:show, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /halfopen.*\.png/,
      set_interest_path(type: "Observation", id: minimal_unknown.id, state: 0)
    )
    assert_image_link_in_html(
      /ignore.*\.png/,
      set_interest_path(type: "Observation", id: minimal_unknown.id, state: -1)
    )

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.create(target: minimal_unknown, user: rolf, state: false)
    get(:show, params: { id: minimal_unknown.id })
    assert_response(:success)
    assert_image_link_in_html(
      /halfopen.*\.png/,
      set_interest_path(type: "Observation", id: minimal_unknown.id, state: 0)
    )
    assert_image_link_in_html(
      /watch.*\.png/,
      set_interest_path(type: "Observation", id: minimal_unknown.id, state: 1)
    )
  end

  ###################

  def test_index_observation_by_past_by
    login
    get(:index, params: { by: :modified })
    assert_response(:success)

    get(:index, params: { by: :created })
    assert_response(:success)
  end

  def test_external_sites_user_can_add_links_to_for_obs
    # not logged in
    do_external_sites_test([], nil, nil)
    # dick is neither owner nor member of any site's project
    do_external_sites_test([], dick, observations(:agaricus_campestris_obs))
    # rolf is owner
    do_external_sites_test(ExternalSite.all, rolf,
                           observations(:agaricus_campestris_obs))
    # mary is member some sites' project
    do_external_sites_test(mary.external_sites, mary,
                           observations(:agaricus_campestris_obs))
    # but there is already a link on this obs
    do_external_sites_test([], mary, observations(:coprinus_comatus_obs))
  end

  def do_external_sites_test(expect, user, obs)
    actual = ExternalSite.sites_user_can_add_links_to_for_obs(user, obs)
    assert_equal(expect.map(&:name), actual.map(&:name))
  end

  def test_show_observation_votes
    obs = observations(:coprinus_comatus_obs)
    naming1 = obs.namings.first
    naming2 = obs.namings.last
    vote1 = naming1.votes.find_by(user: rolf)
    vote2 = naming2.votes.find_by(user: rolf)
    login("rolf")
    get(:show, params: { id: obs.id })
    assert_response(:success)
    assert_template("show")
    assert_select("form#naming_vote_form_#{naming1.id} " \
                  "select#vote_value_#{naming1.id}>" \
                  "option[selected=selected][value='#{vote1.value}']")
    assert_select("form#naming_vote_form_#{naming2.id} " \
                  "select#vote_value_#{naming2.id}>" \
                  "option[selected=selected][value='#{vote2.value}']")
  end
end
