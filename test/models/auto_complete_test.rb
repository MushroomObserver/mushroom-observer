require "test_helper"

require "auto_complete"

class AutoCompleteMock < AutoCompleteByString
  attr_accessor :rough_matches, :limit

  def truncate_matches
    super
  end

  def clean_matches
    super
  end
end

class AutoCompleteMockByWord < AutoCompleteByWord
  attr_accessor :rough_matches, :limit

  def truncate_matches
    super
  end

  def clean_matches
    super
  end
end

class AutoCompleteTest < UnitTestCase
  def test_subclass
    assert_equal("AutoCompleteName", AutoComplete.subclass("name").name)
    assert_equal("AutoCompleteMockByWord",
                 AutoComplete.subclass("mock_by_word").name)
    assert_raise(RuntimeError) { AutoComplete.subclass("bogus") }
  end

  def test_typical_use
    auto = AutoCompleteName.new("Agaricus")
    results = auto.matching_strings
    assert_equal("A", results.first)
    assert(results.include?("Agaricus"))
    assert(results.include?("Agaricus campestris"))
  end

  def test_truncate
    list = %w[b0 b1 b2 b3 b4 b5 b6 b7 b8 b9]
    auto = AutoCompleteMock.new("blah")
    auto.matches = list
    assert_equal(list, auto.matches)

    auto.limit = 10
    auto.truncate_matches
    assert_equal(list, auto.matches)

    auto.limit = 9
    auto.truncate_matches
    list[9] = "..."
    assert_equal(list, auto.matches)

    auto.limit = 1
    auto.truncate_matches
    assert_equal(["b0", "..."], auto.matches)
  end

  def test_multiline_matches
    list1 = [" line one \n line two\n  ", "good match", "  padded match  "]
    list2 = ["line one", "good match", "padded match"]
    auto = AutoCompleteMock.new("blah")
    auto.matches = list1
    assert_equal(list1, auto.matches)
    auto.clean_matches
    assert_equal(list2, auto.matches)
  end

  def test_refine_matches_by_string
    pattern = "one two three"
    @list = [
      "one two three four", # 1
      "one two threee",     # 2
      "one two three",      # 3
      "one two ten",        # 4
      "one two four",       # 5
      "one two-thirty",     # 6
      "only this",          # 7
      "o p q",              # 8
      "o",                  # 9
      "something",          # 10
      "else"                # 11
    ]
    [
      [10, 9, "o"],
      [9, 9, "o"],
      [8, 7, "on"],
      [7, 7, "on"],
      [6, 6, "one"],
      [5, 5, "one two "],
      [4, 4, "one two t"],
      [3, 3, "one two th"],
      [2, 3, "one two three"]
    ].each do |limit, expected_matches, expected_string|
      auto = AutoCompleteMock.new(pattern)
      auto.matches = @list.sort_by { rand }
      auto.limit = limit
      assert_refines_correctly(auto, expected_matches, expected_string)
    end
  end

  def test_refine_matches_by_word
    pattern = "one two shree"
    @list = [
      "one two shree four",  # 1 "one two shree"
      "shreee two one",      # 2 "one two shree"
      "two-shirty-one",      # 3 "one two sh"
      "one two four",        # 4 "one two "
      "twooo one shree one", # 5 "one two"
      "ten ten one twosies", # 6 "one two"
      "this is only five",   # 7 "on"
      "l m n o p q",         # 8 "o"
      "o",                   # 9 "o"
      "something",           # 10
      "else"                 # 11
    ]
    [
      [10, 9, "o"],
      [9, 9, "o"],
      [8, 7, "on"],
      [7, 7, "on"],
      [6, 6, "one"],
      [5, 4, "one two "],
      [4, 4, "one two "],
      [3, 3, "one two s"],
      [2, 2, "one two shr"],
      [1, 2, "one two shree"]
    ].each do |limit, expected_matches, expected_string|
      auto = AutoCompleteMockByWord.new(pattern)
      auto.matches = @list.sort_by { rand }
      auto.limit = limit
      assert_refines_correctly(auto, expected_matches, expected_string)
    end
  end

  def assert_refines_correctly(auto, expected_matches, expected_string)
    string = auto.refine_matches
    if string != expected_string || auto.matches.length != expected_matches
      msg = "Didn't refine matches correctly for limit = #{auto.limit}:\n"\
            "Refined string: #{string.inspect}, "\
            "expected: #{expected_string.inspect}\n #{show_matches(auto)}"
      flunk(msg)
    else
      pass
    end
  end

  def show_matches(auto)
    result = ""
    got = {}
    @list.each do |str|
      if auto.matches.include?(str)
        result += "#{got.length + 1}: #{str.inspect}\n"
        got[str] = true
      else
        result += "X: #{str.inspect}\n"
      end
    end
    auto.matches.each do |str|
      result += "UNEXPECTED!! #{str.inspect}\n" unless got[str]
    end
    result
  end
end
