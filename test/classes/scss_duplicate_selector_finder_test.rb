# frozen_string_literal: true

require("test_helper")

class ScssDuplicateSelectorFinderTest < UnitTestCase
  def test_flags_exact_duplicate_rule
    findings = scan(<<~SCSS)
      .foo {
        color: red;
      }
      .foo {
        color: blue;
      }
    SCSS

    assert_equal(1, findings.size)
    assert_equal("color", findings.first.property)
  end

  def test_flags_duplicate_property_in_single_line_rules
    findings = scan(<<~SCSS)
      .foo { color: red; }
      .foo { color: blue; }
    SCSS

    assert_equal(1, findings.size)
    assert_equal("color", findings.first.property)
  end

  def test_handles_sass_interpolation_in_the_selector
    findings = scan(<<~SCSS)
      .btn-\#{$variant} {
        color: red;
      }
      .btn-\#{$variant} {
        color: blue;
      }
    SCSS

    assert_equal(1, findings.size)
  end

  def test_does_not_flag_different_properties_on_reopened_selector
    findings = scan(<<~SCSS)
      .foo {
        color: red;
      }
      .foo {
        background: blue;
      }
    SCSS

    assert_empty(findings)
  end

  def test_does_not_flag_same_selector_under_different_media_conditions
    findings = scan(<<~SCSS)
      .foo {
        font-size: 1rem;
      }
      @media screen and (min-width: 992px) {
        .foo {
          font-size: 1.5rem;
        }
      }
    SCSS

    assert_empty(findings)
  end

  def test_flags_same_selector_under_the_identical_media_condition
    findings = scan(<<~SCSS)
      @media screen and (min-width: 992px) {
        .foo {
          font-size: 1rem;
        }
      }
      @media screen and (min-width: 992px) {
        .foo {
          font-size: 1.5rem;
        }
      }
    SCSS

    assert_equal(1, findings.size)
  end

  def test_splits_comma_separated_selectors_independently
    findings = scan(<<~SCSS)
      .a,
      .b {
        color: red;
      }
      .a {
        color: blue;
      }
    SCSS

    assert_equal(1, findings.size)
    assert_match(/\.a\z/, findings.first.key)
  end

  def test_does_not_split_commas_inside_parens
    findings = scan(<<~SCSS)
      a:not(.clear-button, .btn),
      a:visited:not(.clear-button, .btn) {
        color: red;
        background-color: blue;
      }
    SCSS

    assert_empty(findings)
  end

  def test_handles_a_selector_spanning_multiple_lines
    findings = scan(<<~SCSS)
      .parent
      .child {
        color: red;
      }
      .parent .child {
        color: blue;
      }
    SCSS

    assert_equal(1, findings.size)
  end

  # The CI gate -- every .scss file under the theme tree stays free
  # of this pattern going forward.
  def test_no_duplicates_in_mo_stylesheets
    paths = Rails.root.glob("app/assets/stylesheets/mo/*.scss")
    findings = ScssDuplicateSelectorFinder.call(paths)

    assert_empty(
      findings.map do |f|
        "#{f.key} [#{f.property}] => #{f.locations.join(", ")}"
      end,
      "Found competing SCSS rules -- the same selector sets the same " \
      "property more than once in the same cascade position, so the " \
      "later declaration silently wins. Either it's an exact duplicate " \
      "to delete, or the two need merging into one non-overlapping rule."
    )
  end

  private

  def scan(scss)
    file = Tempfile.new(["scss_duplicate_selector_finder_test", ".scss"])
    file.write(scss)
    file.flush
    ScssDuplicateSelectorFinder.call([file.path])
  ensure
    file&.close
    file&.unlink
  end
end
