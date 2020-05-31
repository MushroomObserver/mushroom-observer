# frozen_string_literal: true

require "test_helper"
require "textile"

class Textile
  def send_private(method, *args, &block)
    send(method, *args, &block)
  end
end

class TextileTest < UnitTestCase
  def assert_name_link_matches(str, label = nil, name = nil)
    obj = Textile.new(str)
    obj.send_private(:check_name_links!)
    assert_equal("x{NAME __#{label}__ }{ #{name} }x", obj.to_s)
  end

  def assert_name_link_fails(str)
    obj = Textile.new(str)
    obj.send_private(:check_name_links!)
    assert_equal(str, obj.to_s)
  end

  def do_other_links(str)
    obj = Textile.new(str)
    obj.send_private(:check_other_links!)
    obj.to_s
  end

  def assert_href_equal(url, str)
    result = str.tl
    assert_match(/href=.([^"']*)/, result,
                 "Expected an <a href='...'> tag for #{str.inspect}.\n" \
                 "Got: #{result.inspect}\n")
    result =~ /href=.([^"']*)/
    actual = Regexp.last_match(1)
    assert_equal(url, actual,
                 "URL for #{str.inspect} is wrong:\n" \
                 "url: #{url.inspect}\n" \
                 "actual: #{actual}\n")
  end

  def test_name_lookup
    Textile.clear_textile_cache
    assert_equal({}, Textile.name_lookup)

    assert_name_link_matches("_Agaricus_", "Agaricus", "Agaricus")
    assert_equal({ "A" => "Agaricus" }, Textile.name_lookup)
    assert_nil(Textile.last_species)

    assert_name_link_matches(
      "_A. campestris_", "A. campestris", "Agaricus campestris"
    )
    assert_equal({ "A" => "Agaricus" }, Textile.name_lookup)
    assert_equal("Agaricus campestris", Textile.last_species)

    assert_name_link_matches("_Amanita_", "Amanita", "Amanita")
    assert_name_link_matches(
      "_A. campestris_", "A. campestris", "Amanita campestris"
    )
    assert_equal({ "A" => "Amanita" }, Textile.name_lookup)
    assert_equal("Amanita campestris", Textile.last_species)
    assert_nil(Textile.last_subspecies)
    assert_nil(Textile.last_variety)

    assert_name_link_matches(
      "_v. farrea_", "v. farrea", "Amanita campestris var. farrea"
    )
    assert_equal("Amanita campestris", Textile.last_species)
    assert_equal("Amanita campestris", Textile.last_subspecies)
    assert_equal("Amanita campestris var. farrea", Textile.last_variety)

    assert_name_link_matches("_A. baccata sensu Borealis_",
                             "A. baccata sensu Borealis",
                             "Amanita baccata sensu Borealis")
    assert_equal({ "A" => "Amanita" }, Textile.name_lookup)
    assert_equal("Amanita baccata", Textile.last_species)
    assert_nil(Textile.last_subspecies)
    assert_nil(Textile.last_variety)

    assert_name_link_matches('_A. "fakename"_',
                             'A. "fakename"',
                             'Amanita "fakename"')
    assert_name_link_matches("_A. newname in ed._",
                             "A. newname in ed.",
                             "Amanita newname in ed.")
    assert_name_link_matches("_A. something sensu stricto_",
                             "A. something sensu stricto",
                             "Amanita something")
    assert_name_link_matches("_A. another van den Boom_",
                             "A. another van den Boom",
                             "Amanita another van den Boom")
    assert_name_link_matches("_A. another (Th.) Fr._",
                             "A. another (Th.) Fr.",
                             "Amanita another (Th.) Fr.")
    assert_name_link_matches("_A. another Culb. & Culb._",
                             "A. another Culb. & Culb.",
                             "Amanita another Culb. & Culb.")
    assert_name_link_matches("_A.   ignore    (Extra)   Space!_",
                             "A. ignore (Extra) Space!",
                             "Amanita ignore (Extra) Space!")

    assert_name_link_matches("_Fungi sp._", "Fungi sp.", "Fungi")
    assert_equal({ "A" => "Amanita", "F" => "Fungi" }, Textile.name_lookup)
  end

  def test_expand_infra_specific_names
    # Expand subspecies after Textile is told about species
    assert_name_link_matches("_Hydnum album_", "Hydnum album", "Hydnum album")
    assert_name_link_matches(
      "_subsp. alpha_", "subsp. alpha", "Hydnum album subsp. alpha"
    )

    # Expand variety
    # after Textile is told about species
    assert_name_link_matches("_Hydnum ikeni_", "Hydnum ikeni", "Hydnum ikeni")
    assert_name_link_matches(
      "_var. beta_", "var. beta", "Hydnum ikeni var. beta"
    )
    # after Textile is told about subspecies
    assert_name_link_matches(
      "_subsp. alpha_", "subsp. alpha", "Hydnum ikeni subsp. alpha"
    )
    assert_name_link_matches(
      "_var. beta_", "var. beta", "Hydnum ikeni subsp. alpha var. beta"
    )

    # Expand form
    # after Textile is told about species
    assert_name_link_matches("_Hydnum album_", "Hydnum album", "Hydnum album")
    assert_name_link_matches(
      "_f. gamma_", "f. gamma", "Hydnum album f. gamma"
    )
    # after Textile is  told about subspecies
    assert_name_link_matches(
      "_subsp. alpha_", "subsp. alpha", "Hydnum album subsp. alpha"
    )
    assert_name_link_matches(
      "_f. gamma_", "f. gamma", "Hydnum album subsp. alpha f. gamma"
    )
    # after Textile is told about variety
    assert_name_link_matches(
      "_var. delta_", "var. delta", "Hydnum album subsp. alpha var. delta"
    )
    assert_name_link_matches(
      "_f. gamma_", "f. gamma", "Hydnum album subsp. alpha var. delta f. gamma"
    )
  end

  # These should not be interpreted as names.
  def test_name_lookup_failures
    assert_name_link_fails("__arriba!__")
    assert_name_link_fails("__blah blah blah__")
    assert_name_link_fails("__A 5-6 inch__")
    assert_name_link_fails("__This should be close__")
    assert_name_link_fails("__Sonoran Flora__")
    assert_name_link_fails("__A. H. Smith__")
  end

  def test_other_links
    assert_equal("", do_other_links(""))
    assert_equal("x{OBSERVATION __obs 123__ }{ 123 }x",
                 do_other_links("_obs 123_"))
    assert_equal("x{IMAGE __iMg 765__ }{ 765 }x",
                 do_other_links("_iMg 765_"))
    assert_equal("x{USER __phooey__ }{ phooey }x x{NAME __gar__ }{ gar }x",
                 do_other_links("_user phooey_ _name gar_"))
  end

  def test_location_lookup
    # This loc has 2 all-caps words to insure we're stripping
    # some tags added by Redcloth
    loc = "OSU, Corvallis, Oregon, USA"
    textile = "_location #{loc}_".tpl
    assert_match(
      "#{MO.http_domain}/observer/lookup_location/#{CGI.escape(loc)}", # href
      textile
    )
    assert_match("<i>#{loc}</i>", textile) # anchor text
  end

  def test_url_formatting
    assert_href_equal(
      "#{MO.http_domain}/observer/lookup_name/Amanita+%22sp-O01%22",
      '_Amanita "sp-O01"_'
    )
    assert_href_equal("http://www.amanitaceae.org?Amanita+sp-O01",
                      "http://www.amanitaceae.org?Amanita+sp-O01")
  end

  def test_link_text_truncation
    url = "http://www.#{"x" * Textile::URL_TRUNCATION_LENGTH}abc/truncated"
    result = url.tl
    link_text = Nokogiri::HTML.parse(result).text
    assert(link_text.end_with?("abc/..."),
           "Link text should be truncated with 'x/...'")
  end

  def test_textile_div_safe
    str = "Xyz"
    assert_match(
      %r{<div class=\"textile\">.*#{str}.*</div>},
      Textile.textile_div_safe { Textile.textilize(str) },
      %("#{str}" should be within a <div class="textile>")
    )
  end
end
