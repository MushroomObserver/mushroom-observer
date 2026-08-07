# frozen_string_literal: true

require("test_helper")

class Naming::NameResolverTest < UnitTestCase
  def setup
    super
    @user = users(:rolf)
    @name = names(:coprinus_comatus)
  end

  def resolve(given, **)
    Naming::NameResolver.new(@user, given_name: given, **)
  end

  def test_resolves_a_well_formed_name
    resolver = resolve(@name.text_name)

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  # Field slips are written by hand, and the writing is often all one
  # case. `parse_name` wants a capitalized genus and returns nil first,
  # so the lookup never ran even though the columns are
  # case-insensitive and the row was there.
  def test_resolves_a_name_written_in_lower_case
    resolver = resolve(@name.text_name.downcase)

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  def test_resolves_a_name_written_in_upper_case
    resolver = resolve(@name.text_name.upcase)

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  def test_resolves_a_name_written_in_mixed_case
    scrambled = @name.text_name.chars.each_with_index.map do |char, i|
      i.even? ? char.upcase : char.downcase
    end.join

    resolver = resolve(scrambled)

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  # The author the writer supplied is kept rather than dropped, so the
  # match stays unambiguous instead of asking them to pick an author.
  def test_resolves_a_name_with_its_author_in_the_wrong_case
    with_author = names(:coprinus_comatus).search_name

    resolver = resolve(with_author.downcase)

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  def test_leaves_an_unknown_name_unresolved
    resolver = resolve("xyzzy plughia")

    assert_not(resolver.success)
    assert_nil(resolver.name)
  end

  # A slip reading "coprinus comatus?" records the writer's doubt about
  # the name, not a different name. No name in MO holds a question
  # mark, so the mark only ever blocks a match.
  def test_resolves_a_name_written_with_a_question_mark
    resolver = resolve("#{@name.text_name}?")

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  def test_resolves_a_name_written_with_a_detached_question_mark
    resolver = resolve("#{@name.text_name} ?")

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  # Both hand-writing habits at once -- the common field-slip case.
  def test_resolves_a_lower_case_name_written_with_a_question_mark
    resolver = resolve("#{@name.text_name.downcase}?")

    assert(resolver.success)
    assert_equal(@name, resolver.name)
  end

  def test_leaves_an_unknown_name_with_a_question_mark_unresolved
    resolver = resolve("xyzzy plughia?")

    assert_not(resolver.success)
    assert_nil(resolver.name)
  end

  # Only reached once the ordinary lookup comes up empty, so a name
  # that already resolves cannot start resolving to something else.
  def test_canonical_case_lookup_is_skipped_when_the_name_resolves
    calls = 0
    Name.stub(:canonical_name_string, lambda { |str|
      calls += 1
      str
    }) do
      resolve(@name.text_name)
    end

    assert_equal(0, calls)
  end

  def test_canonical_name_string_returns_the_stored_spelling
    assert_equal(@name.text_name,
                 Name.canonical_name_string(@name.text_name.upcase))
    assert_equal(@name.search_name,
                 Name.canonical_name_string(@name.search_name.downcase))
  end

  def test_canonical_name_string_passes_through_what_it_cannot_match
    assert_equal("xyzzy plughia", Name.canonical_name_string("xyzzy plughia"))
    assert_equal("", Name.canonical_name_string(""))
  end
end
