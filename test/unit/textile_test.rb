# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class TextileTest < UnitTestCase

  def do_name_links(str, label, name)
    obj = Textile.new(str)
    obj.check_name_links!
    assert_equal("x{NAME __#{label}__ }{ #{name} }x", obj.to_s)
  end

  def do_other_links(str)
    obj = Textile.new(str)
    obj.check_other_links!
    return obj.to_s
  end

  def test_name_lookup
    Textile.clear_textile_cache
    assert_equal({}, Textile.name_lookup)

    do_name_links('_Agaricus_', 'Agaricus', 'Agaricus')
    assert_equal({'A' => 'Agaricus'}, Textile.name_lookup)
    assert_equal(nil, Textile.last_species)

    do_name_links('_A. campestris_', 'A. campestris', 'Agaricus campestris')
    assert_equal({'A' => 'Agaricus'}, Textile.name_lookup)
    assert_equal('Agaricus campestris', Textile.last_species)

    do_name_links('_Amanita_', 'Amanita', 'Amanita')
    do_name_links('_A. campestris_', 'A. campestris', 'Amanita campestris')
    assert_equal({'A' => 'Amanita'}, Textile.name_lookup)
    assert_equal('Amanita campestris', Textile.last_species)
    assert_equal(nil, Textile.last_subspecies)
    assert_equal(nil, Textile.last_variety)

    do_name_links('_v. farrea_', 'v. farrea', 'Amanita campestris var. farrea')
    assert_equal('Amanita campestris', Textile.last_species)
    assert_equal('Amanita campestris', Textile.last_subspecies)
    assert_equal('Amanita campestris var. farrea', Textile.last_variety)

    do_name_links('_A. baccata sensu Borealis_', 'A. baccata sensu Borealis', 'Amanita baccata sensu Borealis')
    assert_equal({'A' => 'Amanita'}, Textile.name_lookup)
    assert_equal('Amanita baccata', Textile.last_species)
    assert_equal(nil, Textile.last_subspecies)
    assert_equal(nil, Textile.last_variety)

    do_name_links('_A. "fakename"_', 'A. "fakename"', 'Amanita "fakename"')
    do_name_links('_A. newname in ed._', 'A. newname in ed.', 'Amanita newname in ed.')
    do_name_links('_A. something sensu stricto_', 'A. something sensu stricto', 'Amanita something')
    do_name_links('_A. another van den Boom_', 'A. another van den Boom', 'Amanita another van den Boom')
    do_name_links('_A. another (Th.) Fr._', 'A. another (Th.) Fr.', 'Amanita another (Th.) Fr.')
    do_name_links('_A. another Culb. & Culb._', 'A. another Culb. & Culb.', 'Amanita another Culb. & Culb.')
    do_name_links('_A.   ignore    (Extra)   Space!_', 'A. ignore (Extra) Space!', 'Amanita ignore (Extra) Space!')

    do_name_links('_Fungi sp._', 'Fungi sp.', 'Fungi')
    assert_equal({'A' => 'Amanita', 'F' => 'Fungi'}, Textile.name_lookup)
  end

  def test_other_links
    assert_equal('', do_other_links(''))
    assert_equal('x{OBSERVATION __obs 123__ }{ 123 }x', do_other_links('_obs 123_'))
    assert_equal('x{IMAGE __iMg 765__ }{ 765 }x', do_other_links('_iMg 765_'))
    assert_equal('x{USER __phooey__ }{ phooey }x x{NAME __gar__ }{ gar }x', do_other_links('_user phooey_ _name gar_'))
  end
end
