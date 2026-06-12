# frozen_string_literal: true

require("test_helper")

# Component tests for Views::Controllers::Checklists::Contents.
#
# Exercises the three branches of `observed_summary_text` directly so
# coverage is independent of whatever data the controller tests happen
# to render. Before this file existed, coverage of the higher-only
# branch (`elsif higher.positive?`) depended on whichever observation
# `Observation.joins(:name).find_by(name: { deprecated: true })` in
# `test_checklist_marks_deprecated` happened to return — an unordered
# `find_by` whose result varied with test seed / parallel-worker
# state. See PR #4301 for the diagnosis.
module Views::Controllers::Checklists
  class ContentsTest < ComponentTestCase
    SUMMARY_SELECTOR = "#checklist_contents .my-4 > div"

    # Both species and higher-level observed →
    # :checklist_observed_summary branch (lines 67-68 in contents.rb).
    def test_summary_both_species_and_higher_observed
      html = render_contents(num_species: 2, num_higher: 3)
      expected = :checklist_observed_summary.l(
        species: 2, higher: 3, taxa_word: :checklist_taxa.l
      )

      assert_html(html, "#checklist_contents")
      assert_html(html, SUMMARY_SELECTOR, text: expected)
    end

    # higher == 1 → :checklist_taxon (singular). Locks in the
    # singular/plural switch on line 65 of contents.rb.
    def test_summary_uses_singular_taxon_when_higher_is_one
      html = render_contents(num_species: 1, num_higher: 1)
      expected = :checklist_observed_summary.l(
        species: 1, higher: 1, taxa_word: :checklist_taxon.l
      )

      assert_html(html, SUMMARY_SELECTOR, text: expected)
    end

    # species > 0, higher == 0 → :checklist_observed_species_only branch
    # (line 70 in contents.rb).
    def test_summary_species_only
      html = render_contents(num_species: 3, num_higher: 0)
      expected = :checklist_observed_species_only.l(species: 3)

      assert_html(html, SUMMARY_SELECTOR, text: expected)
    end

    # species == 0, higher > 0 → :checklist_observed_higher_only branch
    # (line 72 in contents.rb). The whole reason this file exists.
    def test_summary_higher_only
      html = render_contents(num_species: 0, num_higher: 2)
      expected = :checklist_observed_higher_only.l(
        higher: 2, taxa_word: :checklist_taxa.l
      )

      assert_html(html, SUMMARY_SELECTOR, text: expected)
    end

    # Both counts zero → observed_summary_text returns nil and the
    # inner summary div is suppressed.
    def test_summary_omitted_when_no_observations
      html = render_contents(num_species: 0, num_higher: 0)

      assert_html(html, "#checklist_contents")
      # `for_project?` is false for our stub, so render_target_summary
      # is also skipped — `.my-4` has no inner divs at all.
      assert_html(html, SUMMARY_SELECTOR, count: 0)
    end

    # Stub responding to every method
    # `Views::Controllers::Checklists::Contents` touches when rendering
    # the summary + footnotes. `for_project?` in the component does
    # `@data.is_a?(::Checklist::ForProject)`, so this stub (which isn't
    # a ForProject) skips the target-summary and unobserved-targets
    # panel. We deliberately leave taxa arrays empty so
    # `render_panel_section` skips both observed panels — this test is
    # about the summary line, not panel rendering.
    ChecklistDataStub = Struct.new(
      :num_species_observed, :num_higher_level_observed,
      :species_level_observed_taxa, :higher_level_observed_taxa,
      :unobserved_target_taxa, :duplicate_synonyms,
      :any_deprecated_flag,
      keyword_init: true
    ) do
      def any_deprecated?
        any_deprecated_flag
      end
    end
    private_constant :ChecklistDataStub

    private

    def stub_data(num_species:, num_higher:)
      ChecklistDataStub.new(
        num_species_observed: num_species,
        num_higher_level_observed: num_higher,
        species_level_observed_taxa: [],
        higher_level_observed_taxa: [],
        unobserved_target_taxa: [],
        duplicate_synonyms: [],
        any_deprecated_flag: false
      )
    end

    # Sibling reference within the namespace — `Context` resolves to
    # `Views::Controllers::Checklists::Context`.
    def stub_context
      Context.new(
        user: users(:rolf), project: nil, show_user: nil,
        location: nil, species_list: nil
      )
    end

    # `Contents` likewise resolves to the sibling class.
    def render_contents(num_species:, num_higher:)
      render(Contents.new(
               data: stub_data(num_species: num_species,
                               num_higher: num_higher),
               context: stub_context
             ))
    end
  end
end
