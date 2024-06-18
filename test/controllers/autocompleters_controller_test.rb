# frozen_string_literal: true

require("test_helper")
require("json")

class AutocompletersControllerTest < FunctionalTestCase
  def good_autocompleter_request(action, params = {})
    autocompleter_request(action, params, 200)
  end

  def bad_autocompleter_request(action, params = {})
    autocompleter_request(action, params, 500)
  end

  def autocompleter_request(action, params, status)
    get(action, params: params.dup)
    if @response.response_code == status
      pass
    else
      url = autocompleter_request_url(action, params)
      msg = "Expected #{status} from: #{url}\n"
      msg += "Got #{@response.response_code}:\n"
      msg += @response.body
      flunk(msg)
    end
  end

  def autocompleter_request_url(action, params)
    url = "/autocompleters/#{action}"
    url += "/#{params[:type]}" if params[:type]
    args = params.except(:type)
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
    good_autocompleter_request(:new, type: :location, string: "Modesto")
    assert_equal(expect, JSON.parse(@response.body))

    login("roy") # prefers location_format: :scientific
    expect = m.map { |x| Location.reverse_name(x) }.sort.uniq
    expect.unshift("M")
    good_autocompleter_request(:new, type: :location, string: "Modesto")
    assert_equal(expect, JSON.parse(@response.body))

    login("mary") # prefers location_format: :postal
    good_autocompleter_request(:new, type: :location, string: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_herbarium
    login("rolf")
    # names of Herbariums whose names have words starting with "m"
    m = Herbarium.where(Herbarium[:name].matches_regexp("\\bD")).
        map(&:name)

    expect = m.sort.uniq
    expect.unshift("D")
    good_autocompleter_request(:new, type: :herbarium, string: "Dick")
    assert_equal(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_empty
    login("rolf")
    good_autocompleter_request(:new, type: :name, string: "")
    assert_equal([], JSON.parse(@response.body))
  end

  def test_auto_complete_name_above_genus
    login("rolf")
    expect = %w[F Fungi]
    good_autocompleter_request(:new, type: :clade, string: "Fung")
    assert_equal(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_name
    login("rolf")
    expect = Name.all.reject(&:correct_spelling).
             map(&:text_name).uniq.select { |n| n[0] == "A" }.sort
    expect_genera = expect.reject { |n| n.include?(" ") }
    expect_species = expect.select { |n| n.include?(" ") }
    expect = ["A"] + expect_genera + expect_species
    good_autocompleter_request(:new, type: :name, string: "Agaricus")
    assert_equal(expect, JSON.parse(@response.body))

    good_autocompleter_request(:new, type: :name, string: "Umbilicaria")
    assert_equal(["U"], JSON.parse(@response.body))
  end

  def test_auto_complete_project
    login("rolf")
    # titles of Projects whose titles have words starting with "p"
    b_titles = Project.where(Project[:title].matches_regexp("\\bB")).
               map(&:title).uniq
    good_autocompleter_request(:new, type: :project, string: "Babushka")
    assert_equal((["B"] + b_titles).sort, JSON.parse(@response.body).sort)

    p_titles = Project.where(Project[:title].matches_regexp("\\bP")).
               map(&:title).uniq
    good_autocompleter_request(:new, type: :project, string: "Perfidy")
    assert_equal((["P"] + p_titles).sort, JSON.parse(@response.body).sort)

    good_autocompleter_request(:new, type: :project, string: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_species_list
    login("rolf")
    list1, list2, list3, list4 = SpeciesList.order(:title).map(&:title)

    assert_equal("A Species List", list1)
    assert_equal("Another Species List", list2)
    assert_equal("List of mysteries", list3)
    assert_equal("lone_wolf_list", list4)

    good_autocompleter_request(:new, type: :species_list, string: "List")
    assert_equal(["L", list1, list2, list3, list4], JSON.parse(@response.body))

    good_autocompleter_request(:new, type: :species_list, string: "Mojo")
    assert_equal(["M", list3], JSON.parse(@response.body))

    good_autocompleter_request(:new, type: :species_list, string: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_user
    login("rolf")
    good_autocompleter_request(:new, type: :user, string: "Rover")
    assert_equal(
      ["R", "rolf <Rolf Singer>", "roy <Roy Halling>",
       "second_roy <Roy Rogers>"],
      JSON.parse(@response.body)
    )

    good_autocompleter_request(:new, type: :user, string: "Dodo")
    assert_equal(["D", "dick <Tricky Dick>"], JSON.parse(@response.body))

    good_autocompleter_request(:new, type: :user, string: "Komodo")
    assert_equal(["K", "#{katrina.login} <#{katrina.name}>"],
                 JSON.parse(@response.body))

    good_autocompleter_request(:new, type: :user, string: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_bogus
    login("rolf")
    bad_autocompleter_request(:new, type: :bogus, string: "bogus")
  end
end
