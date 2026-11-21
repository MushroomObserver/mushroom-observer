# frozen_string_literal: true

require("test_helper")

class ScssCrossFileSelectorFinderTest < UnitTestCase
  def test_flags_a_top_level_selector_opened_in_two_files
    findings = scan(
      <<~SCSS,
        .foo {
          color: red;
        }
      SCSS
      <<~SCSS
        .foo {
          background: blue;
        }
      SCSS
    )

    assert_equal(1, findings.size)
    assert_equal(".foo", findings.first.selector)
  end

  def test_does_not_flag_a_selector_only_opened_in_one_file
    findings = scan(
      <<~SCSS,
        .foo {
          color: red;
        }
      SCSS
      <<~SCSS
        .bar {
          color: blue;
        }
      SCSS
    )

    assert_empty(findings)
  end

  def test_does_not_flag_a_selector_reopened_within_one_file
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

  def test_does_not_flag_a_selector_only_nested_inside_another_in_one_file
    findings = scan(
      <<~SCSS,
        .foo {
          .shared {
            color: red;
          }
        }
      SCSS
      <<~SCSS
        .bar {
          .shared {
            color: blue;
          }
        }
      SCSS
    )

    assert_empty(findings)
  end

  def test_splits_comma_separated_selectors_independently
    findings = scan(
      <<~SCSS,
        .a, .b {
          color: red;
        }
      SCSS
      <<~SCSS
        .a {
          color: blue;
        }
      SCSS
    )

    assert_equal(1, findings.size)
    assert_equal(".a", findings.first.selector)
  end

  def test_does_not_split_commas_inside_parens
    findings = scan(
      <<~SCSS,
        a:not(.x, .y) {
          color: red;
        }
      SCSS
      <<~SCSS
        a:not(.x, .y) {
          background: blue;
        }
      SCSS
    )

    assert_equal(1, findings.size)
    assert_equal("a:not(.x, .y)", findings.first.selector)
  end

  def test_handles_a_selector_spanning_multiple_lines
    findings = scan(
      <<~SCSS,
        .parent
        .child {
          color: red;
        }
      SCSS
      <<~SCSS
        .parent .child {
          color: blue;
        }
      SCSS
    )

    assert_equal(1, findings.size)
  end

  # The CI gate -- every top-level selector under the theme tree
  # belongs to one file going forward.
  def test_every_selector_has_one_file_in_mo_stylesheets
    paths = Rails.root.glob("app/assets/stylesheets/mo/*.scss")
    findings = ScssCrossFileSelectorFinder.call(paths)

    assert_empty(
      findings.map { |f| "#{f.selector} => #{f.files.join(", ")}" },
      "Found a selector opened in more than one file -- its behavior " \
      "would depend on which other files happen to be loaded. Move it " \
      "into the one file that owns it, or give the other context its " \
      "own class name."
    )
  end

  private

  def scan(*scss_snippets)
    files = scss_snippets.map do |scss|
      file = Tempfile.new(["scss_cross_file_selector_finder_test", ".scss"])
      file.write(scss)
      file.flush
      file
    end
    ScssCrossFileSelectorFinder.call(files.map(&:path))
  ensure
    files&.each { |f| f.close && f.unlink }
  end
end
