# frozen_string_literal: true

require("test_helper")

class PatternSearch::NameTest < UnitTestCase
  def test_name_search_created
    expect = Name.with_correct_spelling.where(Name[:created_at].year.eq(2010))
    assert_not_empty(expect)
    x = PatternSearch::Name.new("created:2010")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_modified
    expect = Name.with_correct_spelling.where(Name[:updated_at].year.eq(2007))
    assert_not_empty(expect)
    x = PatternSearch::Name.new("modified:2007")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_rank
    expect = Name.with_correct_spelling.with_rank("Genus")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("rank:genus")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_rank_above_genus
    assert_not_empty(expect)
    x = PatternSearch::Name.new("rank:family-domain")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_synonyms
    expect = Name.include_synonyms_of(names(:macrolepiota_rachodes))
    assert_not_empty(expect)
    x = PatternSearch::Name.new("Macrolepiota rachodes include_synonyms:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_subtaxa
    expect = Name.include_subtaxa_of(names(:agaricus))
    assert_not_empty(expect)
    x = PatternSearch::Name.new("Agaricus include_subtaxa:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_synonyms
    expect = Name.without_synonyms
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_synonyms:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_synonyms.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_synonyms:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_deprecated
    expect = Name.deprecated.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("deprecated:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.not_deprecated.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("deprecated:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_include_misspellings
    expect = Name.with_incorrect_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.all
    assert_not_empty(expect)
    x = PatternSearch::Name.new("include_misspellings:both")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_lichen
    expect = Name.with_correct_spelling.of_lichens
    assert_not_empty(expect)
    x = PatternSearch::Name.new("lichen:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.not_lichens
    assert_not_empty(expect)
    x = PatternSearch::Name.new("lichen:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_author
    expect = Name.with_correct_spelling.without_author
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_author:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_author
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_author:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_citation
    expect = Name.with_correct_spelling.without_citation
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_citation:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_citation
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_citation:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_classification
    expect = Name.with_correct_spelling.without_classification
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_classification:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_classification
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_classification:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_notes
    expect = Name.with_correct_spelling.without_notes
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_notes:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.with_notes
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_notes:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_comments
    expect = Name.with_correct_spelling.with_comments
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_comments:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_has_description
    expect = Name.with_correct_spelling.reorder(id: :asc).with_description
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_description:yes")
    assert_name_arrays_equal(expect, x.query.results, :sort)

    expect = Name.with_correct_spelling.reorder(id: :asc).without_description
    assert_not_empty(expect)
    x = PatternSearch::Name.new("has_description:no")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_author
    expect = Name.with_correct_spelling.author_contains("Vittad")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("author:vittad")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_citation
    expect = Name.with_correct_spelling.citation_contains("lichenes")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("citation:lichenes")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_classification
    expect = Name.with_correct_spelling.classification_contains("ascomycota")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("classification:Ascomycota")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_notes
    expect = Name.with_correct_spelling.notes_contain("lichen")
    assert_not_empty(expect)
    x = PatternSearch::Name.new("notes:lichen")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end

  def test_name_search_comments
    expect = [comments(:fungi_comment).target]
    assert_not_empty(expect)
    x = PatternSearch::Name.new("comments:\"do not change\"")
    assert_name_arrays_equal(expect, x.query.results, :sort)
  end
end
