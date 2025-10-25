# frozen_string_literal: true

require("test_helper")

class NameFieldTest < UnitTestCase
  def test_standard_case
    textile_text = "**__Agaricus__** **__campestris__** L."
    assert_equal([["Agaricus", [:bold, :italic]],
                  ["campestris", [:bold, :italic]], ["L.", []]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end

  def test_just_bold
    textile_text = "**Agaricus**"
    assert_equal([["Agaricus", [:bold]]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end

  def test_broken_bold
    textile_text = "**Agaricus"
    assert_equal([["*", []], ["*Agaricus", []]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end

  def test_broken_italics
    textile_text = "__Agaricus"
    assert_equal([["_", []], ["_Agaricus", []]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end

  def test_opposite_nesting
    textile_text = "__**Agaricus**__ **__campestris__** L."
    assert_equal([["Agaricus", [:italic, :bold]],
                  ["campestris", [:bold, :italic]], ["L.", []]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end

  def test_broken_nesting_bold
    textile_text = "__**Agaricus__"
    assert_equal([["*", [:italic]], ["*Agaricus", [:italic]]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end

  def test_broken_nesting_italic
    textile_text = "**__Agaricus**"
    assert_equal([["_", [:bold]], ["_Agaricus", [:bold]]],
                 ObservationLabels::NameField.new("Name", textile_text).tokens)
  end
end
