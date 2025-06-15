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

  def test_autocomplete_location
    login("rolf")
    # names of Locations whose names have words starting with "m"
    locs = Location.where(Location[:name].matches_regexp("\\bModesto")).
           select(:name, :id, :north, :south, :east, :west)

    expect = locs.map do |loc|
      hash = loc.attributes.symbolize_keys
      hash.each { |k, v| hash[k] = v.to_s unless k == :id }
    end
    expect.unshift({ name: "M", id: 0 })
    expect.sort_by! { |loc| [loc[:name], -loc[:id]] }
    expect.uniq! { |loc| loc[:name] }
    good_autocompleter_request(type: :location, string: "Modesto")
    assert_equivalent(expect, JSON.parse(@response.body))

    login("roy") # prefers location_format: :scientific
    # Autocompleter's values for decimals parsed as json will be strings
    expect = locs.map do |loc|
      hash = loc.attributes.symbolize_keys
      hash.each { |k, v| hash[k] = v.to_s unless k == :id }
      hash[:name] = Location.reverse_name(hash[:name])
      hash
    end
    expect.unshift({ name: "M", id: 0 })
    expect.sort_by! { |loc| [loc[:name], -loc[:id]] }
    expect.uniq! { |loc| loc[:name] }
    good_autocompleter_request(type: :location, string: "Modesto")
    assert_equivalent(expect, JSON.parse(@response.body))
    login("mary") # prefers location_format: :postal
    good_autocompleter_request(type: :location, string: "Xystus")
    assert_equivalent([{ name: "X", id: 0 }], JSON.parse(@response.body))
  end

  def test_autocomplete_location_containing
    login("rolf")
    point_in_albion = { lat: 39.253, lng: -123.8 }
    locs = Location.where(id: locations(:albion).id).
           select(:name, :id, :north, :south, :east, :west)
    expect = locs.map do |loc|
      hash = loc.attributes.symbolize_keys
      hash.each { |k, v| hash[k] = v.to_s unless k == :id }
    end
    good_autocompleter_request(type: :location_containing, string: "",
                               all: true, **point_in_albion)
    assert_equivalent(expect, JSON.parse(@response.body))
  end

  def test_autocomplete_herbarium
    login("rolf")
    # names of Herbariums whose names have words starting with "m"
    herbs = Herbarium.where(Herbarium[:name].matches_regexp("\\bD")).
            select(:name, :id)

    expect = herbs.map { |hrb| hrb.attributes.symbolize_keys }
    expect.unshift({ name: "D", id: 0 })
    expect.sort_by! { |hrb| hrb[:name] }
    expect.uniq! { |hrb| hrb[:name] }
    good_autocompleter_request(type: :herbarium, string: "D")
    assert_equivalent(expect, JSON.parse(@response.body))
  end

  def test_autocomplete_empty
    login("rolf")
    good_autocompleter_request(type: :name, string: "")
    assert_equivalent([], JSON.parse(@response.body))
  end

  def test_autocomplete_name_above_genus
    login("rolf")
    expect = [{ name: "F", id: 0 },
              { name: "Fungi", id: names(:fungi).id, deprecated: false }]
    good_autocompleter_request(type: :clade, string: "Fung")
    assert_equivalent(expect, JSON.parse(@response.body))
  end

  def test_autocomplete_name_a
    login("rolf")
    good_autocompleter_request(type: :name, string: "A")
    assert_equivalent(expected_name_matches("A"), JSON.parse(@response.body))
  end

  def expected_name_matches(substring)
    names = Name.with_correct_spelling.
            select(:text_name, :id, :deprecated).distinct.
            where(Name[:text_name].matches("#{substring}%"))

    expect = names.map do |name|
      name = name.attributes.symbolize_keys
      name[:deprecated] = name[:deprecated] || false
      name[:name] = name[:text_name]
      name.delete(:text_name) # faster than `except`
      name
    end
    expect.sort_by! do |name|
      [(name[:name].match?(" ") ? "b" : "a") + name[:name], name[:deprecated]]
    end
    expect.uniq! { |name| name[:name] }
    expect.unshift({ name: substring[0], id: 0 })
  end

  def test_autocomplete_name_agaricus
    login("rolf")
    good_autocompleter_request(type: :name, string: "Agaricus")
    assert_equivalent(expected_name_matches("Agaricus"),
                      JSON.parse(@response.body))
  end

  def test_autocomplete_name_no_match
    login("rolf")
    good_autocompleter_request(type: :name, string: "Umbilicaria")
    assert_equivalent([{ name: "U", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_autocomplete_project
    login("rolf")
    # titles of Projects whose titles have words starting with "p"
    b_titles = Project.where(Project[:title].matches_regexp("\\bB")).
               pluck(:title, :id).uniq.map do |name, id|
      { name:, id: }
    end
    good_autocompleter_request(type: :project, string: "B")
    assert_equivalent([{ name: "B", id: 0 }] + b_titles,
                      JSON.parse(@response.body))

    p_titles = Project.where(Project[:title].matches_regexp("\\bP")).
               pluck(:title, :id).uniq.map do |name, id|
      { name:, id: }
    end
    good_autocompleter_request(type: :project, string: "P")
    assert_equivalent([{ name: "P", id: 0 }] + p_titles,
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :project, string: "X")
    assert_equivalent([{ name: "X", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_autocomplete_species_list
    login("rolf")
    list1, list2, list3, list4 = SpeciesList.order(:title).select(:title, :id).
                                 take(4).map do |list|
                                   list = list.attributes.symbolize_keys
                                   { name: list[:title], id: list[:id] }
                                 end

    assert_equal("An Observation List", list1[:name])
    assert_equal("Another Observation List", list2[:name])
    assert_equal("List of mysteries", list3[:name])
    assert_equal("lone_wolf_list", list4[:name])

    good_autocompleter_request(type: :species_list, string: "L")
    assert_equivalent([{ name: "L", id: 0 }, list1, list2, list3, list4],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :species_list, string: "M")
    assert_equivalent([{ name: "M", id: 0 }, list3],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :species_list, string: "X")
    assert_equivalent([{ name: "X", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_autocomplete_user
    login("rolf")
    good_autocompleter_request(type: :user, string: "R")
    assert_equivalent(
      [{ name: "R", id: 0 },
       { name: "Rolf Singer (rolf)", id: rolf.id },
       { name: "Roy Halling (roy)", id: roy.id },
       { name: "Roy Rogers (second_roy)", id: users(:second_roy).id }],
      JSON.parse(@response.body)
    )

    good_autocompleter_request(type: :user, string: "D")
    assert_equivalent([{ name: "D", id: 0 },
                       { name: "#{dick.name} (#{dick.login})",
                         id: dick.id }],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :user, string: "K")
    assert_equivalent([{ name: "K", id: 0 },
                       { name: "#{katrina.name} (#{katrina.login})",
                         id: katrina.id }],
                      JSON.parse(@response.body))

    good_autocompleter_request(type: :user, string: "X")
    assert_equivalent([{ name: "X", id: 0 }],
                      JSON.parse(@response.body))
  end

  def test_autocomplete_bogus
    login("rolf")
    bad_autocompleter_request(type: :bogus, string: "bogus")
  end
end
