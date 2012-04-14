# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class SpeciesListTest < UnitTestCase

  def test_project_ownership

    # NOT owned by Bolete project, but owned by Rolf
    spl = species_lists(:first_species_list)
    assert_true(spl.has_edit_permission?(@rolf))
    assert_false(spl.has_edit_permission?(@mary))
    assert_false(spl.has_edit_permission?(@dick))

    # IS owned by Bolete project, AND owned by Mary (Dick is member of Bolete project)
    spl = species_lists(:unknown_species_list)
    assert_false(spl.has_edit_permission?(@rolf))
    assert_true(spl.has_edit_permission?(@mary))
    assert_true(spl.has_edit_permission?(@dick))
  end
end
