# frozen_string_literal: true

require("test_helper")

# test the application-wide helpers
module Header
  class TitleHelperTest < ActionView::TestCase
    include LinkHelper

    def test_title_tag_contents
      # Prove that if title is present, <title> contents are @title
      title = "title present"
      action_name = "something_else"
      assert_equal(title, title_tag_contents(title, action: action_name))

      # Prove that if title is absent,
      # then <title> contents are action_name humanized
      title = ""
      action_name = "blah_blah"
      assert_equal("Blah Blah", title_tag_contents(title, action: action_name))
    end

    # Regression for #4316 — browser tab title was showing literal
    # textile source ("_Russula_") or escaped HTML tags
    # ("<i>Russula</i>") because the `<title>` element renders as
    # plain text. Fix textilizes first, then strips tags.

    def test_title_tag_contents_strips_textile_source
      assert_equal("Russula virescens",
                   title_tag_contents("_Russula virescens_"))
    end

    def test_title_tag_contents_strips_already_rendered_html
      assert_equal("Russula virescens Pers.",
                   title_tag_contents(
                     "<i>Russula virescens</i> Pers.".html_safe
                   ))
    end

    def test_title_tag_contents_passes_plain_text_through
      assert_equal("Cape Cod Specimens",
                   title_tag_contents("Cape Cod Specimens"))
    end

    def test_title_tag_contents_handles_mixed_markup
      # Pre-rendered <i> on the binomial + textile-source italics on
      # the author (the exact shape that lands in obs edit titles).
      assert_equal(
        "Russula virescens Pers.",
        title_tag_contents("<i>Russula virescens</i> _Pers._".html_safe)
      )
    end

    def test_title_tag_contents_decodes_entities
      assert_equal("Brachen & Co.",
                   title_tag_contents("Brachen &amp; Co."))
    end
  end
end
