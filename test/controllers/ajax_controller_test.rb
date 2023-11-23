# frozen_string_literal: true

require("test_helper")
require("json")

class AjaxControllerTest < FunctionalTestCase
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
    url = "/ajax/#{action}"
    url += "/#{params[:type]}" if params[:type]
    url += "/#{params[:id]}"   if params[:id]
    args = params.except(:type, :id)
    url += "?#{URI.encode_www_form(args)}" if args.any?
    url
  end

  ##############################################################################

  # This is a good place to test this stuff, since the filters are simplified.
  def test_filters
    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,pt;q=0.5"
    good_ajax_request(:test)
    assert_nil(@controller.instance_variable_get(:@user))
    assert_nil(User.current)
    assert_equal(:pt, I18n.locale)
    assert_equal(0, cookies.count)
    assert_equal({ "locale" => "pt" }, session.to_hash)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,xx-xx;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "xx-xx,pt-pt"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "en-xx,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:en, I18n.locale)

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "zh-*"
    good_ajax_request(:test)
    assert_equal(:en, I18n.locale)
  end

  def test_auto_complete_location
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
    good_ajax_request(:auto_complete, type: :location, id: "Modesto")
    assert_equal(expect, JSON.parse(@response.body))

    login("roy") # prefers location_format: :scientific
    expect = m.map { |x| Location.reverse_name(x) }.sort.uniq
    expect.unshift("M")
    good_ajax_request(:auto_complete, type: :location, id: "Modesto")
    assert_equal(expect, JSON.parse(@response.body))

    login("mary") # prefers location_format: :postal
    good_ajax_request(:auto_complete, type: :location, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_herbarium
    # names of Herbariums whose names have words starting with "m"
    m = Herbarium.where(Herbarium[:name].matches_regexp("\\bD")).
        map(&:name)

    expect = m.sort.uniq
    expect.unshift("D")
    good_ajax_request(:auto_complete, type: :herbarium, id: "Dick")
    assert_equal(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_empty
    good_ajax_request(:auto_complete, type: :name, id: "")
    assert_equal([], JSON.parse(@response.body))
  end

  def test_auto_complete_name_above_genus
    expect = %w[F Fungi]
    good_ajax_request(:auto_complete, type: :clade, id: "Fung")
    assert_equal(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_name
    expect = Name.all.reject(&:correct_spelling).
             map(&:text_name).uniq.select { |n| n[0] == "A" }.sort
    expect_genera = expect.reject { |n| n.include?(" ") }
    expect_species = expect.select { |n| n.include?(" ") }
    expect = ["A"] + expect_genera + expect_species
    good_ajax_request(:auto_complete, type: :name, id: "Agaricus")
    assert_equal(expect, JSON.parse(@response.body))

    good_ajax_request(:auto_complete, type: :name, id: "Umbilicaria")
    assert_equal(["U"], JSON.parse(@response.body))
  end

  def test_auto_complete_project
    # titles of Projects whose titles have words starting with "p"
    b_titles = Project.where(Project[:title].matches_regexp("\\bB")).
               map(&:title).uniq
    good_ajax_request(:auto_complete, type: :project, id: "Babushka")
    assert_equal((["B"] + b_titles).sort, JSON.parse(@response.body).sort)

    p_titles = Project.where(Project[:title].matches_regexp("\\bP")).
               map(&:title).uniq
    good_ajax_request(:auto_complete, type: :project, id: "Perfidy")
    assert_equal((["P"] + p_titles).sort, JSON.parse(@response.body).sort)

    good_ajax_request(:auto_complete, type: :project, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_species_list
    list1, list2, list3, list4 = SpeciesList.all.order(:title).map(&:title)

    assert_equal("A Species List", list1)
    assert_equal("Another Species List", list2)
    assert_equal("List of mysteries", list3)
    assert_equal("lone_wolf_list", list4)

    good_ajax_request(:auto_complete, type: :species_list, id: "List")
    assert_equal(["L", list1, list2, list3, list4], JSON.parse(@response.body))

    good_ajax_request(:auto_complete, type: :species_list, id: "Mojo")
    assert_equal(["M", list3], JSON.parse(@response.body))

    good_ajax_request(:auto_complete, type: :species_list, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_user
    good_ajax_request(:auto_complete, type: :user, id: "Rover")
    assert_equal(
      ["R", "rolf <Rolf Singer>", "roy <Roy Halling>",
       "second_roy <Roy Rogers>"],
      JSON.parse(@response.body)
    )

    good_ajax_request(:auto_complete, type: :user, id: "Dodo")
    assert_equal(["D", "dick <Tricky Dick>"], JSON.parse(@response.body))

    good_ajax_request(:auto_complete, type: :user, id: "Komodo")
    assert_equal(["K", "#{katrina.login} <#{katrina.name}>"],
                 JSON.parse(@response.body))

    good_ajax_request(:auto_complete, type: :user, id: "Xystus")
    assert_equal(["X"], JSON.parse(@response.body))
  end

  def test_auto_complete_bogus
    bad_ajax_request(:auto_complete, type: :bogus, id: "bogus")
  end

  # Primers used by the mobile app
  def test_name_primer
    # This name is not deprecated and is used by an observation or two.
    name1 = names(:boletus_edulis)
    item1 = build_name_primer_item(name1)

    # This name is not deprecated and not used by an observation, but a
    # synonym *is* used by an observation, so it should be included.
    name2 = names(:chlorophyllum_rhacodes)
    item2 = build_name_primer_item(name2)

    # This name is deprecated but is used by an observation so it should
    # be included.
    name3 = names(:coprinus_comatus)
    name3.update_attribute(:deprecated, true)
    name3.reload
    item3 = build_name_primer_item(name3)

    get(:name_primer)
    # These assertions may not be stable, in which case we may need to parse
    # the respond body as JSON structure, and test that the structure contains
    # the right elements.
    assert(@response.body.include?(item1),
           "Expected #{@response.body} to include #{item1}.")
    assert(@response.body.include?(item2),
           "Expected #{@response.body} to include #{item2}.")
    assert(@response.body.include?(item3),
           "Expected #{@response.body} to include #{item3}.")
    assert_not(@response.body.include?("Lactarius alpigenes"),
               "Didn't expect primer to include Lactarius alpigenes.")
  end

  def build_name_primer_item(name)
    { id: name.id,
      text_name: name.text_name,
      author: name.author,
      deprecated: name.deprecated,
      synonym_id: name.synonym_id }.to_json
  end

  def test_location_primer
    loc = locations(:burbank)
    item = { id: loc.id, name: loc.name }.to_json
    get(:location_primer)
    assert(@response.body.include?(item),
           "Expected #{@response.body} to include #{item}.")
  end
end
