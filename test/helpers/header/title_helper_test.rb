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

    # Regression for #4316 — browser tab `<title>` was showing
    # literal textile source ("_Russula_") or escaped HTML tags
    # ("<i>Russula</i>"). Fixed by routing each model's
    # `document_title` method through `document_title_for`, which
    # returns plain text (no textile, no HTML).

    def test_document_title_for_observation_returns_plain_text_name
      obs = observations(:minimal_unknown_obs)
      # No textile markers, no HTML tags.
      assert_equal(obs.text_name, document_title_for(obs))
      assert_no_match(/[_*<>]/, document_title_for(obs))
    end

    def test_document_title_for_species_list_returns_title
      spl = species_lists(:first_species_list)
      assert_equal(spl.title, document_title_for(spl))
    end

    def test_document_title_for_falls_back_to_type_tag
      # An object without a `document_title` method gets
      # AbstractModel's default — the localized type-tag label.
      pub = publications(:one_pub)
      assert_equal(:PUBLICATION.l, document_title_for(pub))
    end

    def test_show_document_title_composes_type_id_and_plain_name
      obs = observations(:minimal_unknown_obs)
      title = show_document_title(document_title_for(obs), obs)
      # "OBSERVATION <id>: <text_name>" — all plain text.
      assert_match(/\A#{:OBSERVATION.l} #{obs.id}: /, title)
      assert_no_match(/[_*<>]/, title)
    end
  end
end
