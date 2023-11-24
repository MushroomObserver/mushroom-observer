# frozen_string_literal: true

require("test_helper")
require("json")

class AutocompletersControllerTest < FunctionalTestCase
  def good_ajax_request(action, params = {})
    ajax_request(action, params, 200)
  end

  def bad_ajax_request(action, params = {})
    ajax_request(action, params, 500)
  end

  def ajax_request(action, params, status)
    get(action, params: params.dup)
    if @response.response_code == status
      pass
    else
      url = ajax_request_url(action, params)
      msg = "Expected #{status} from: #{url}\n"
      msg += "Got #{@response.response_code}:\n"
      msg += @response.body
      flunk(msg)
    end
  end

  def ajax_request_url(action, params)
    url = "/autocompleters/#{action}"
    url += "/#{params[:type]}" if params[:type]
    url += "/#{params[:id]}"   if params[:id]
    args = params.except(:type, :id)
    url += "?#{URI.encode_www_form(args)}" if args.any?
    url
  end

  ##############################################################################

  def test_auto_complete_location
    login("rolf")
    # names of Locations whose names have words starting with "m"
    m_loc_names = Location.where(Location[:name].matches_regexp("\\bM")).
                  map(&:name)
    # wheres of Observations whose wheres have words starting with "m"
    # need extra "observation" to avoid confusing sql with bare "where".
    m_obs_wheres = Observation.where(Observation[:where].
                   matches_regexp("\\bM")).map(&:where)
    m = m_loc_names + m_obs_wheres

    expect = m.sort.uniq
    expect.unshift("M")
    good_ajax_request(:new, type: :location, id: "Modesto")
    assert_equal(expect, JSON.parse(@response.body))

    login("roy") # prefers location_format: :scientific
    expect = m.map { |x| Location.reverse_name(x) }.sort.uniq
    expect.unshift("M")
    good_ajax_request(:new, type: :location, id: "Modesto")
    assert_equal(expect, JSON.parse(@response.body))

    login("mary") # prefers location_format: :postal
    good_ajax_request(:new, type: :location, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_herbarium
    login("rolf")
    # names of Herbariums whose names have words starting with "m"
    m = Herbarium.where(Herbarium[:name].matches_regexp("\\bD")).
        map(&:name)

    expect = m.sort.uniq
    expect.unshift("D")
    good_ajax_request(:new, type: :herbarium, id: "Dick")
    assert_equal(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_empty
    login("rolf")
    good_ajax_request(:new, type: :name, id: "")
    assert_equal([], JSON.parse(@response.body))
  end

  def test_auto_complete_name_above_genus
    login("rolf")
    expect = %w[F Fungi]
    good_ajax_request(:new, type: :clade, id: "Fung")
    assert_equal(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_name
    login("rolf")
    expect = Name.all.reject(&:correct_spelling).
             map(&:text_name).uniq.select { |n| n[0] == "A" }.sort
    expect_genera = expect.reject { |n| n.include?(" ") }
    expect_species = expect.select { |n| n.include?(" ") }
    expect = ["A"] + expect_genera + expect_species
    good_ajax_request(:new, type: :name, id: "Agaricus")
    assert_equal(expect, JSON.parse(@response.body))

    good_ajax_request(:new, type: :name, id: "Umbilicaria")
    assert_equal(["U"], JSON.parse(@response.body))
  end

  def test_auto_complete_project
    login("rolf")
    # titles of Projects whose titles have words starting with "p"
    b_titles = Project.where(Project[:title].matches_regexp("\\bB")).
               map(&:title).uniq
    good_ajax_request(:new, type: :project, id: "Babushka")
    assert_equal((["B"] + b_titles).sort, JSON.parse(@response.body).sort)

    p_titles = Project.where(Project[:title].matches_regexp("\\bP")).
               map(&:title).uniq
    good_ajax_request(:new, type: :project, id: "Perfidy")
    assert_equal((["P"] + p_titles).sort, JSON.parse(@response.body).sort)

    good_ajax_request(:new, type: :project, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_species_list
    login("rolf")
    list1, list2, list3, list4 = SpeciesList.all.order(:title).map(&:title)

    assert_equal("A Species List", list1)
    assert_equal("Another Species List", list2)
    assert_equal("List of mysteries", list3)
    assert_equal("lone_wolf_list", list4)

    good_ajax_request(:new, type: :species_list, id: "List")
    assert_equal(["L", list1, list2, list3, list4], JSON.parse(@response.body))

    good_ajax_request(:new, type: :species_list, id: "Mojo")
    assert_equal(["M", list3], JSON.parse(@response.body))

    good_ajax_request(:new, type: :species_list, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_user
    login("rolf")
    good_ajax_request(:new, type: :user, id: "Rover")
    assert_equal(
      ["R", "rolf <Rolf Singer>", "roy <Roy Halling>",
       "second_roy <Roy Rogers>"],
      JSON.parse(@response.body)
    )

    good_ajax_request(:new, type: :user, id: "Dodo")
    assert_equal(["D", "dick <Tricky Dick>"], JSON.parse(@response.body))

    good_ajax_request(:new, type: :user, id: "Komodo")
    assert_equal(["K", "#{katrina.login} <#{katrina.name}>"],
                 JSON.parse(@response.body))

    good_ajax_request(:new, type: :user, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_bogus
    login("rolf")
    bad_ajax_request(:new, type: :bogus, id: "bogus")
  end
end
