require File.dirname(__FILE__) + '/../boot'

class ExtensionTest < Test::Unit::TestCase

  ##############################################################################
  #
  #  :section: Symbol Tests
  #
  ##############################################################################

  def test_localize_postprocessing
    # Note these tests work because Symbol#localize makes a special check in
    # TEST mode to see if :x is in the args, and if so, bypasses Globalite.
    assert_equal('', :x.test_localize(:x => ''))
    assert_equal('blah', :x.test_localize(:x => 'blah'))
    assert_equal("one\n\ntwo", :x.test_localize(:x => 'one\n\ntwo'))
    assert_equal('bob', :x.test_localize(:x => '[user]', :user => 'bob'))
    assert_equal('bob and fred', :x.test_localize(:x => '[bob] and [fred]', :bob => 'bob', :fred => 'fred'))
    assert_equal('user', :x.test_localize(:x => '[:user]'))
    assert_equal('Show Name', :x.test_localize(:x => '[:show_object(type=:name)]'))
    assert_equal('Show Foo!', :x.test_localize(:x => '[:show_object(type=Foo!,blah=ignore me)]'))

    assert_equal('name', :name.test_localize)
    assert_equal('Name', :Name.test_localize)
    assert_equal('Name', :NAME.test_localize)

    assert_equal('species list', :species_list.test_localize)
    assert_equal('Species list', :Species_list.test_localize)
    assert_equal('Species List', :SPECIES_LIST.test_localize)

    assert_equal('species list', :x.test_localize(:x => '[type]', :type => :species_list))
    assert_equal('Species list', :x.test_localize(:x => '[Type]', :type => :species_list))
    assert_equal('Species list', :x.test_localize(:x => '[tYpE]', :type => :species_list))
    assert_equal('Species List', :x.test_localize(:x => '[TYPE]', :type => :species_list))
    assert_equal('species list', :x.test_localize(:x => '[:species_list]'))
    assert_equal('Species list', :x.test_localize(:x => '[:Species_list]'))
    assert_equal('Species list', :x.test_localize(:x => '[:sPeCiEs_lIsT]'))
    assert_equal('Species List', :x.test_localize(:x => '[:SPECIES_LIST]'))

    # Test recursion:
    #   :x  -->  [:y]
    #   :y  -->  'one'
    assert_equal('one', :x.test_localize(:x => '[:y]', :y => 'one'))

    # Test recursion two deep:
    #   :x  -->  [:y]
    #   :y  -->  [:z]
    #   :z  -->  'two'
    assert_equal('two', :x.test_localize(:x => '[:y]', :y => '[:z]', :z => 'two'))

    # Test recursion three deep: (should bail at :z)
    #   :x  -->  [:y]
    #   :y  -->  [:z]
    #   :z  -->  [:a]
    #   :a  -->  'three'
    assert_equal('three', :x.test_localize(:x => '[:y]', :y => '[:z]', :z => '[:a]',
                                     :a => 'three'))

    # Test recursion absurdly deep.  Should bail... I don't know...
    # somewhere long before it meets Bob..
    assert_not_equal('bob', :a.test_localize(
      :a => '[:b]',
      :b => '[:c]',
      :c => '[:d]',
      :d => '[:e]',
      :e => '[:f]',
      :f => '[:g]',
      :g => '[:h]',
      :h => '[:i]',
      :i => '[:j]',
      :j => '[:k]',
      :k => '[:l]',
      :l => '[:m]',
      :m => '[:n]',
      :n => '[:o]',
      :o => '[:p]',
      :p => '[:q]',
      :q => '[:r]',
      :r => '[:s]',
      :s => '[:t]',
      :t => '[:u]',
      :u => '[:v]',
      :v => '[:w]',
      :w => '[:x]',
      :x => '[:y]',
      :y => '[:z]',
      :z => 'bob'
    ))
  end
end
