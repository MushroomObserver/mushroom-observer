require "test_helper"

class SpecimenControllerTest < FunctionalTestCase
  def assert_specimen_index
    assert_template(:specimen_index)
  end

  def test_show_specimen_without_notes
    specimen = specimens(:coprinus_comatus_nybg_spec)
    assert(specimen)
    get_with_dump(:show_specimen, params: { id: specimen.id })
    assert_template(:show_specimen, partial: "_rss_log")
  end

  def test_show_specimen_with_notes
    specimen = specimens(:interesting_unknown)
    assert(specimen)
    get_with_dump(:show_specimen, params: { id: specimen.id })
    assert_template(:show_specimen, partial: "_rss_log")
  end

  def test_herbarium_index
    get_with_dump(:herbarium_index,
                  params: { id: herbaria(:nybg_herbarium).id })
    assert_specimen_index
  end

  def test_herbarium_with_one_specimen_index
    get_with_dump(:herbarium_index,
                  params: { id: herbaria(:rolf_herbarium).id })
    assert_response(:redirect)
    assert_no_flash
  end

  def test_herbarium_with_no_specimens_index
    get_with_dump(:herbarium_index,
                  params: { id: herbaria(:dick_herbarium).id })
    assert_response(:redirect)
    assert_flash(/no specimens/)
  end

  def test_observation_index
    get_with_dump(:observation_index,
                  params: { id: observations(:coprinus_comatus_obs).id })
    assert_specimen_index
  end

  def test_observation_with_one_specimen_index
    get_with_dump(:observation_index,
                  params: { id: observations(:detailed_unknown_obs).id })
    assert_response(:redirect)
    assert_no_flash
  end

  def test_observation_with_no_specimens_index
    get_with_dump(:observation_index,
                  params: { id: observations(:strobilurus_diminutivus_obs).id })
    assert_response(:redirect)
    assert_flash(/no specimens/)
  end

  def test_add_specimen
    get(:add_specimen, params: { id: observations(:coprinus_comatus_obs).id })
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:add_specimen,
                  params: { id: observations(:coprinus_comatus_obs).id })
    # assert_template(action: "add_specimen", partial: "_rss_log")
    assert_template("add_specimen", partial: "_rss_log")
    assert(assigns(:herbarium_label))
  end

  def add_specimen_params
    {
      id: observations(:strobilurus_diminutivus_obs).id,
      specimen: {
        herbarium_name: rolf.preferred_herbarium_name,
        herbarium_label:
          "Strobilurus diminutivus det. Rolf Singer - NYBG 1234567",
        "when(1i)"      => "2012",
        "when(2i)"      => "11",
        "when(3i)"      => "26",
        notes: "Some notes about this specimen"
      }
    }
  end

  def test_add_specimen_post
    login("rolf")
    specimen_count = Specimen.count
    params = add_specimen_params
    obs = Observation.find(params[:id])
    assert(!obs.specimen)
    post(:add_specimen, params: params)
    assert_equal(specimen_count + 1, Specimen.count)
    # specimen = Specimen.find(:all, order: "created_at DESC")[0] # Rails 3
    specimen = Specimen.all.order("created_at DESC")[0]
    assert_equal(params[:specimen][:herbarium_name], specimen.herbarium.name)
    assert_equal(params[:specimen][:herbarium_label], specimen.herbarium_label)
    assert_equal(params[:specimen]["when(1i)"].to_i, specimen.when.year)
    assert_equal(params[:specimen]["when(2i)"].to_i, specimen.when.month)
    assert_equal(params[:specimen]["when(3i)"].to_i, specimen.when.day)
    assert_equal(rolf, specimen.user)
    obs = Observation.find(params[:id])
    assert(obs.specimen)
    assert_response(:redirect)
  end

  def test_add_specimen_post_new_herbarium
    mary = login("mary")
    herbarium_count = mary.curated_herbaria.count
    # Count the number of herbaria that mary is a curator for
    params = add_specimen_params
    params[:specimen][:herbarium_name] = mary.preferred_herbarium_name
    post(:add_specimen, params: params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count + 1, mary.curated_herbaria.count)
    # herbarium = Herbarium.find(:all, order: "created_at DESC")[0] # Rails 3
    herbarium = Herbarium.all.order("created_at DESC")[0]
    assert(herbarium.curators.member?(mary))
  end

  def test_add_specimen_post_duplicate
    login("rolf")
    specimen_count = Specimen.count
    params = add_specimen_params
    existing_specimen = specimens(:coprinus_comatus_nybg_spec)
    params[:specimen][:herbarium_name] = existing_specimen.herbarium.name
    params[:specimen][:herbarium_label] = existing_specimen.herbarium_label
    post(:add_specimen, params: params)
    assert_equal(specimen_count, Specimen.count)
    assert_flash(/already exists/i)
    assert_response(:success)
  end

  # I keep thinking only curators should be able to add specimens.
  # However, for now anyone can.
  def test_add_specimen_post_not_curator
    user = login("mary")
    nybg = herbaria(:nybg_herbarium)
    assert(!nybg.curators.member?(user))
    specimen_count = Specimen.count
    params = add_specimen_params
    params[:specimen][:herbarium_name] = nybg.name
    post(:add_specimen, params: params)
    nybg = Herbarium.find(nybg.id) # Reload herbarium
    assert(!nybg.curators.member?(user))
    assert_equal(specimen_count + 1, Specimen.count)
    assert_response(:redirect)
  end

  def assert_edit_specimen
    assert_template(:edit_specimen)
  end

  def test_edit_specimen
    nybg = specimens(:coprinus_comatus_nybg_spec)
    get_with_dump(:edit_specimen, params: { id: nybg.id })
    assert_response(:redirect)

    login("mary") # Non-curator
    get_with_dump(:edit_specimen, params: { id: nybg.id })
    assert_flash(/unable to update specimen/i)
    assert_response(:redirect)

    login("rolf")
    get_with_dump(:edit_specimen, params: { id: nybg.id })
    assert_edit_specimen

    make_admin("mary") # Non-curator, but an admin
    get_with_dump(:edit_specimen, params: { id: nybg.id })
    assert_edit_specimen
  end

  def test_edit_specimen_post
    login("rolf")
    nybg = specimens(:coprinus_comatus_nybg_spec)
    herbarium = nybg.herbarium
    user = nybg.user
    params = add_specimen_params
    params[:id] = nybg.id
    post(:edit_specimen, params: params)
    specimen = Specimen.find(nybg.id)
    assert_equal(herbarium, specimen.herbarium)
    assert_equal(user, specimen.user)
    assert_equal(params[:specimen][:herbarium_label], specimen.herbarium_label)
    assert_equal(params[:specimen]["when(1i)"].to_i, specimen.when.year)
    assert_equal(params[:specimen]["when(2i)"].to_i, specimen.when.month)
    assert_equal(params[:specimen]["when(3i)"].to_i, specimen.when.day)
    assert_equal(params[:specimen][:notes], specimen.notes)
    assert_equal(nybg.user, specimen.user)
    assert_response(:redirect)
  end

  def test_edit_specimen_post_no_specimen
    login("rolf")
    nybg = specimens(:coprinus_comatus_nybg_spec)
    post(:edit_specimen, params: { id: nybg.id })
    assert_edit_specimen
  end

  def test_delete_specimen
    login("rolf")
    params = delete_specimen_params
    specimen_count = Specimen.count
    specimen = Specimen.find(params[:id])
    observations = specimen.observations
    obs_spec_count = observations.map { |o| o.specimens.count }.
                     reduce { |a, b| a + b }
    post(:delete_specimen, params: params)
    assert_equal(specimen_count - 1, Specimen.count)
    observations.map(&:reload)
    assert_true(obs_spec_count > observations.map { |o| o.specimens.count }.
                                 reduce { |a, b| a + b })
    assert_response(:redirect)
  end

  def test_delete_specimen_not_curator
    login("mary")
    params = delete_specimen_params
    specimen_count = Specimen.count
    post(:delete_specimen, params: params)
    assert_equal(specimen_count, Specimen.count)
    assert_response(:redirect)
  end

  def test_delete_specimen_admin
    make_admin("mary")
    params = delete_specimen_params
    specimen_count = Specimen.count
    post(:delete_specimen, params: params)
    assert_equal(specimen_count - 1, Specimen.count)
    assert_response(:redirect)
  end

  def delete_specimen_params
    {
      id: specimens(:interesting_unknown).id
    }
  end

  def test_specimen_search
    # Two specimens match this pattern.
    pattern = "Coprinus comatus"
    get(:specimen_search, params: { pattern: pattern })

    assert_response(:success)
    assert_template("list_specimens")
    # In results, expect 1 row per specimen
    assert_select(".results tr", 2)
  end

  def test_index_specimen
    get(:index_specimen)
    assert_response(:success)
    assert_template("list_specimens")
    # In results, expect 1 row per specimen
    assert_select(".results tr", Specimen.all.size)
  end
end
