# frozen_string_literal: true

require("test_helper")

# Tests for the title-chrome utility methods on `Views::FullPageBase`:
# `document_title_for`, `show_document_title`, `edit_document_title`,
# `title_tag_contents`.
#
# The `add_*_title` side-effect setters that use these utilities are
# exercised end-to-end through the controller tests for each
# show/edit/new/index page they're called from (e.g.
# `Names::Descriptions::VersionsControllerTest#test_show_past_*`
# which checks `<title>` rendering after the full Application layout
# fires).
class Views::FullPageBase::TitleChromeTest < ComponentTestCase
  def setup
    super
    @page = page_subclass.new
  end

  # ----- title_tag_contents ---------------------------------------------

  def test_title_tag_contents_returns_title_when_present
    assert_equal("title present",
                 @page.send(:title_tag_contents, "title present",
                            action: "something_else"))
  end

  def test_title_tag_contents_falls_back_to_titleized_action
    assert_equal("Blah Blah",
                 @page.send(:title_tag_contents, "", action: "blah_blah"))
  end

  def test_title_tag_contents_strips_html_tags
    result = @page.send(:title_tag_contents,
                        "<i>Russula</i>",
                        action: "show")
    # `strip_html` removes the angle-bracketed tags; the textual
    # content survives. Textile source markers (`_underscores_`)
    # aren't HTML and are preserved here — the upstream protection
    # against textile leaking into `<title>` is `document_title_for`,
    # which routes through each model's plain-text `document_title`
    # instead of its rich textiled name.
    assert_no_match(/[<>]/, result)
    assert_equal("Russula", result)
  end

  # ----- document_title_for ---------------------------------------------
  #
  # Regression #4316 — the browser-tab `<title>` was showing literal
  # textile source ("_Russula_") or escaped HTML tags. Each model's
  # `document_title` method must return plain text (no textile, no HTML).

  def test_document_title_for_observation_returns_plain_text_name
    obs = observations(:minimal_unknown_obs)
    result = @page.send(:document_title_for, obs)

    assert_equal(obs.text_name, result)
    assert_no_match(/[_*<>]/, result)
  end

  def test_document_title_for_species_list_returns_title
    spl = species_lists(:first_species_list)
    assert_equal(spl.title, @page.send(:document_title_for, spl))
  end

  def test_document_title_for_falls_back_to_type_tag
    # An object without a `document_title` method gets
    # AbstractModel's default — the localized type-tag label.
    pub = publications(:one_pub)
    assert_equal(:PUBLICATION.l,
                 @page.send(:document_title_for, pub))
  end

  def test_document_title_for_handles_objects_without_document_title
    # Defensive `unless object.respond_to?(:document_title)` gate —
    # exercised by passing a stand-in that lacks the method. Real
    # AR models all inherit `AbstractModel#document_title`, so
    # this gate only ever fires for non-AR objects (a future
    # edge case, but worth keeping covered).
    fake = Struct.new(:type_tag).new(:observation)

    assert_equal(:OBSERVATION.l,
                 @page.send(:document_title_for, fake))
  end

  # ----- show_document_title / edit_document_title ----------------------

  def test_show_document_title_composes_type_id_and_plain_name
    obs = observations(:minimal_unknown_obs)
    title = @page.send(:show_document_title,
                       @page.send(:document_title_for, obs), obs)

    # "OBSERVATION <id>: <text_name>" — all plain text.
    assert_match(/\A#{:OBSERVATION.l} #{obs.id}: /, title)
    assert_no_match(/[_*<>]/, title)
  end

  def test_edit_document_title_prepends_edit_label
    obs = observations(:minimal_unknown_obs)
    title = @page.send(:edit_document_title,
                       @page.send(:document_title_for, obs), obs)

    assert_match(/\A#{:EDIT.l} #{:OBSERVATION.l} #{obs.id}: /, title)
  end

  private

  # A one-off `Views::FullPageBase` subclass — these utility methods
  # don't need a render context to test their return values.
  def page_subclass
    @page_subclass ||= Class.new(Views::FullPageBase) do
      def view_template
        # Intentionally empty; tests poke private methods via `send`.
      end
    end
  end
end
