require "test_helper"

class MarkupControllerTest < FunctionalTestCase

  # ------------------------------------------------------------
  #  Markup
  #  Markup_controller
  # ------------------------------------------------------------

  # ----------------------------
  #  Lookup's.
  #  These are links like /lookup_name/Amanita+muscaria
  #  They can be created by the Textile Sandbox, and should always redirect
  #  to the appropriate model.
  # /lookup_accepted_name is intended for use by other web sites
  # ----------------------------

  def test_lookup_comment
    c_id = comments(:minimal_unknown_obs_comment_1).id
    get(:lookup_comment, params: { id: c_id })
    assert_redirected_to(
      controller: :comments,
      action: :show,
      id: c_id
    )
    get(:lookup_comment, params: { id: 10_000 })
    assert_redirected_to(
      controller: :comments,
      action: :index_comment
    )
    assert_flash_error
  end

  def test_lookup_image
    i_id = images(:in_situ_image).id
    get(:lookup_image, params: { id: i_id })
    assert_redirected_to(
      controller: :images,
      action: :show, id: i_id
    )
    get(:lookup_image, params: { id: 10_000 })
    assert_redirected_to(
      controller: :images,
      action: :index_image
    )
    assert_flash_error
  end

  def test_lookup_location
    l_id = locations(:albion).id
    get(:lookup_location, params: { id: l_id })
    assert_redirected_to(
      controller: :locations,
      action: :show, id: l_id
    )
    get(:lookup_location, params: { id: "Burbank, California" })
    assert_redirected_to(
      controller: :locations,
      action: :show,
      id: locations(:burbank).id
    )
    get(:lookup_location, params: { id: "California, Burbank" })
    assert_redirected_to(
      controller: :locations,
      action: :show,
      id: locations(:burbank).id
    )
    get(:lookup_location, params: { id: "Zyzyx, Califonria" })
    assert_redirected_to(
      controller: :locations,
      action: :index_location
    )
    assert_flash_error
    get(:lookup_location, params: { id: "California" })
    # assert_redirected_to(controller: :locations, action: :index_location)
    assert_redirected_to(%r{/locations/index_location})
    assert_flash_warning
  end

  def test_lookup_accepted_name
    get(:lookup_accepted_name,
        params: { id: names(:lactarius_subalpinus).text_name })
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: names(:lactarius_alpinus)
    )
  end

  def test_lookup_name
    n_id = names(:fungi).id
    get(:lookup_name, params: { id: n_id })
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: n_id
    )

    get(:lookup_name, params: { id: names(:coprinus_comatus).id })
    assert_redirected_to(%r{/names/show_name/#{names(:coprinus_comatus).id}})

    get(:lookup_name, params: { id: "Agaricus campestris" })
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: names(:agaricus_campestris).id
    )

    get(:lookup_name, params: { id: "Agaricus newname" })
    assert_redirected_to(
      controller: :names,
      action: :index_name
    )
    assert_flash_error

    get(:lookup_name, params: { id: "Amanita baccata sensu Borealis" })
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: names(:amanita_baccata_borealis).id
    )

    get(:lookup_name, params: { id: "Amanita baccata" })
    assert_redirected_to(
      %r{/names/index_name}
    )
    assert_flash_warning

    get(:lookup_name, params: { id: "Agaricus campestris L." })
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: names(:agaricus_campestris).id
    )

    get(:lookup_name, params: { id: "Agaricus campestris Linn." })
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: names(:agaricus_campestris).id
    )

    # Prove that when there are no hits and exactly one spelling suggestion,
    # it gives a flash warning and shows the page for the suggestion.
    get(:lookup_name, params: { id: "Fungia" })
    assert_flash_text(:runtime_suggest_one_alternate.t(type: :name,
                                                       match: "Fungia"))
    assert_redirected_to(
      controller: :names,
      action: :show,
      id: names(:fungi).id
    )

    # Prove that when there are no hits and >1 spelling suggestion,
    # it flashes a warning and shows the name index
    get(:lookup_name, params: { id: "Verpab" })
    assert_flash_text(:runtime_suggest_multiple_alternates.t(type: :name,
                                                             match: "Verpab"))
    assert_redirected_to(
      %r{/names/index_name}
    )

    # Prove that lookup_name adds flash message when it hits an error,
    # stubbing a method called by lookup_name in order to provoke an error.
    ObservationsController.any_instance.stubs(:fix_name_matches).
      raises(RuntimeError)
    get(:lookup_name, params: { id: names(:fungi).text_name })
    assert_flash_text("RuntimeError")
  end

  def test_lookup_observation
    get(:lookup_observation,
        params: { id: observations(:minimal_unknown_obs).id })
    assert_redirected_to(
      controller: :observations,
      action: :show,
      id: observations(:minimal_unknown_obs).id
    )
  end

  def test_lookup_project
    p_id = projects(:eol_project).id
    get(:lookup_project, params: { id: p_id })
    assert_redirected_to(
      controller: :projects,
      action: :show,
      id: p_id
    )
    get(:lookup_project, params: { id: "Bolete" })
    assert_redirected_to(
      controller: :projects,
      action: :show,
      id: projects(:bolete_project).id
    )
    get(:lookup_project, params: { id: "Bogus" })
    assert_redirected_to(
      controller: :projects,
      action: :index_project
    )
    assert_flash_error
    get(:lookup_project, params: { id: "project" })
    assert_redirected_to(
      %r{/projects/index_project}
    )
    assert_flash_warning
  end

  def test_lookup_species_list
    sl_id = species_lists(:first_species_list).id
    get(:lookup_species_list, params: { id: sl_id })
    assert_redirected_to(
      controller: :species_lists,
      action: :show,
      id: sl_id
    )
    get(:lookup_species_list, params: { id: "Mysteries" })
    assert_redirected_to(
      controller: :species_lists,
      action: :show,
      id: species_lists(:unknown_species_list).id
    )
    get(:lookup_species_list, params: { id: "species list" })
    assert_redirected_to(
      %r{/species_lists/index_species_list}
    )
    assert_flash_warning
    get(:lookup_species_list, params: { id: "Flibbertygibbets" })
    assert_redirected_to(
      controller: :species_lists,
      action: :index_species_list
    )
    assert_flash_error
  end

  def test_lookup_user
    get(:lookup_user, params: { id: rolf.id })
    assert_redirected_to(
      controller: :users,
      action: :show,
      id: rolf.id
    )
    get(:lookup_user, params: { id: "mary" })
    assert_redirected_to(
      controller: :users,
      action: :show,
      id: mary.id
    )
    get(:lookup_user, params: { id: "Einstein" })
    assert_redirected_to(
      controller: :rss_logs,
      action: :index_rss_log
    )
    assert_flash_error
    # This caused router to crash in the wild.
    assert_recognizes(
      { controller: :users,
        action: :lookup_user,
        id: "I.+G.+Saponov" },
      "/users/lookup_user/I.+G.+Saponov"
    )
  end

end
