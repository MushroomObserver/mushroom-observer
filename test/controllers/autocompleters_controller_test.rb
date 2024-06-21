# frozen_string_literal: true

require("test_helper")
require("json")

class AutocompletersControllerTest < FunctionalTestCase
  def good_autocompleter_request(params = {})
    autocompleter_request(params, 200)
  end

  def bad_autocompleter_request(params = {})
    autocompleter_request(params, 500)
  end

  def autocompleter_request(params, status)
    get(:new, params: params.dup)
    if @response.response_code == status
      pass
    else
      url = autocompleter_request_url(params)
      msg = "Expected #{status} from: #{url}\n"
      msg += "Got #{@response.response_code}:\n"
      msg += @response.body
      flunk(msg)
    end
  end

  def autocompleter_request_url(params)
    url = "/autocompleters/new"
    url += "/#{params[:type]}" if params[:type]
    args = params.except(:type)
    url += "?#{URI.encode_www_form(args)}" if args.any?
    url
  end

  # have to do this because it's saying the arrays of hashes are not equal with
  # `assert_equal`, even though they are
  def assert_equivalent(array1, array2)
    array1 = array1.map(&:symbolize_keys)
    array2 = array2.map(&:symbolize_keys)
    diff = (array1 - array2) + (array2 - array1)
    assert(diff.empty?, diff.inspect)
    # assert_equal(array1.sort_by { |r| r[:name] },
    #              array2.sort_by { |r| r[:name] })
  end

  ##############################################################################

  def test_auto_complete_location
    login("rolf")
    # names of Locations whose names have words starting with "m"
    m_loc_names = Location.where(Location[:name].
                  matches_regexp("\\bM")).pluck(:name, :id)
    # wheres of Observations whose wheres have words starting with "m"
    # need extra "observation" to avoid confusing sql with bare "where".
    m_obs_wheres = Observation.where(Observation[:where].
                   matches_regexp("\\bM")).pluck(:where, :location_id)
    locs = m_loc_names + m_obs_wheres
    locs.unshift(["M", 0])

    expect = locs.map { |name, id| { name:, id: id.nil? ? 0 : id } }
    expect.sort_by! { |loc| [loc[:name], -loc[:id]] }
    expect.uniq! { |loc| loc[:name] }
    good_autocompleter_request(type: :location, string: "Modesto")
    assert_equivalent(expect, JSON.parse(@response.body))

    login("roy") # prefers location_format: :scientific
    expect = locs.map do |name, id|
      { name: Location.reverse_name(name), id: id.nil? ? 0 : id }
    end
    expect.sort_by! { |loc| [loc[:name], -loc[:id]] }
    expect.uniq! { |loc| loc[:name] }
    good_autocompleter_request(type: :location, string: "Modesto")
    assert_equivalent(expect, JSON.parse(@response.body))

    login("mary") # prefers location_format: :postal
    good_autocompleter_request(type: :location, string: "Xystus")
    assert_equivalent([{ name: "X", id: 0 }], JSON.parse(@response.body))
  end

  def test_auto_complete_herbarium
    login("rolf")
    # names of Herbariums whose names have words starting with "m"
    herbs = Herbarium.where(Herbarium[:name].matches_regexp("\\bD")).
            pluck(:name, :id)
    herbs.unshift(["D", 0])

    expect = herbs.map { |name, id| { name:, id: } }
    expect.sort_by! { |hrb| hrb[:name] }
    expect.uniq! { |hrb| hrb[:name] }
    good_autocompleter_request(type: :herbarium, string: "Dick")
    assert_equivalent(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_empty
    login("rolf")
    good_autocompleter_request(type: :name, string: "")
    assert_equivalent([], JSON.parse(@response.body))
  end

  def test_auto_complete_name_above_genus
    login("rolf")
    expect = [{ name: "F", id: 0 },
              { name: "Fungi", id: names(:fungi).id, deprecated: false }]
    good_autocompleter_request(type: :clade, string: "Fung")
    assert_equivalent(expect, JSON.parse(@response.body))
  end

  def test_auto_complete_name
    login("rolf")
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(Name[:text_name].matches("A%")).
            pluck(:text_name, :id, :deprecated)

    expect = names.map do |name, id, deprecated|
      dep_string = deprecated.nil? ? "false" : deprecated.to_s
      { name: name, id: id, deprecated: dep_string }
    end
    expect.sort_by! do |name|
      [(name[:name].match?(" ") ? "b" : "a") + name[:name], name[:deprecated]]
    end
    expect.uniq! { |name| name[:name] }
    expect.unshift({ name: "A", id: 0 })

    good_autocompleter_request(type: :name, string: "Agaricus")
    assert_equivalent(expect, JSON.parse(@response.body))

    good_autocompleter_request(type: :name, string: "Umbilicaria")
    assert_equivalent([{ name: "U", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_auto_complete_project
    login("rolf")
    # titles of Projects whose titles have words starting with "p"
    b_titles = Project.where(Project[:title].matches_regexp("\\bB")).
               pluck(:title, :id).uniq.map do |name, id|
      { name:, id: }
    end
    good_autocompleter_request(type: :project, string: "Babushka")
    assert_equivalent(([{ name: "B", id: 0 }] + b_titles),
                      JSON.parse(@response.body))

    p_titles = Project.where(Project[:title].matches_regexp("\\bP")).
               pluck(:title, :id).uniq.map do |name, id|
      { name:, id: }
    end
    good_autocompleter_request(type: :project, string: "Perfidy")
    assert_equivalent(([{ name: "P", id: 0 }] + p_titles),
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :project, string: "Xystus")
    assert_equivalent([{ name: "X", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_auto_complete_species_list
    login("rolf")
    list1, list2, list3, list4 = SpeciesList.order(:title).pluck(:title, :id).
                                 take(4).map { |name, id| { name:, id: } }

    assert_equal("A Species List", list1[:name])
    assert_equal("Another Species List", list2[:name])
    assert_equal("List of mysteries", list3[:name])
    assert_equal("lone_wolf_list", list4[:name])

    good_autocompleter_request(type: :species_list, string: "List")
    assert_equivalent([{ name: "L", id: 0 }, list1, list2, list3, list4],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :species_list, string: "Mojo")
    assert_equivalent([{ name: "M", id: 0 }, list3],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :species_list, string: "Xystus")
    assert_equivalent([{ name: "X", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_auto_complete_user
    login("rolf")
    good_autocompleter_request(type: :user, string: "Rover")
    assert_equivalent(
      [{ name: "R", id: 0 },
       { name: "rolf <Rolf Singer>", id: rolf.id },
       { name: "roy <Roy Halling>", id: roy.id },
       { name: "second_roy <Roy Rogers>", id: users(:second_roy).id }],
      JSON.parse(@response.body)
    )

    good_autocompleter_request(type: :user, string: "Dodo")
    assert_equivalent([{ name: "D", id: 0 },
                       { name: "dick <Tricky Dick>", id: dick.id }],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :user, string: "Komodo")
    assert_equivalent([{ name: "K", id: 0 },
                       { name: "#{katrina.login} <#{katrina.name}>",
                         id: katrina.id }],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :user, string: "Xystus")
    assert_equivalent([{ name: "X", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_auto_complete_bogus
    login("rolf")
    bad_autocompleter_request(type: :bogus, string: "bogus")
  end
end
