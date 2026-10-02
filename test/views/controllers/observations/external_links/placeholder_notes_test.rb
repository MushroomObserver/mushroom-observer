# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::ExternalLinks
  class PlaceholderNotesTest < ComponentTestCase
    def test_lists_everything_not_imported_in_order
      omissions = omissions_with(images: 2, obs_fields: 3,
                                 description: true, sequences: true)

      html = render_notes(omissions)

      assert_html(html, ".reflection-placeholder-note",
                  text: :observation_placeholder_source.l(
                    login: omissions["login"]
                  ))
      items = [
        :observation_placeholder_images.l(count: omissions["images"]),
        :observation_placeholder_obs_fields.l(count: omissions["obs_fields"]),
        :observation_placeholder_description.l,
        :observation_placeholder_sequences.l
      ]
      assert_html(html, ".reflection-not-imported-note",
                  text: :observation_placeholder_not_imported.l(
                    items: items.join(", ")
                  ))
    end

    def test_lists_only_what_is_missing
      omissions = omissions_with(obs_fields: 1, sequences: true)

      html = render_notes(omissions)

      items = [
        :observation_placeholder_obs_fields.l(count: omissions["obs_fields"]),
        :observation_placeholder_sequences.l
      ]
      assert_html(html, ".reflection-not-imported-note",
                  text: :observation_placeholder_not_imported.l(
                    items: items.join(", ")
                  ))
    end

    def test_omits_not_imported_line_when_nothing_is_missing
      html = render_notes(omissions_with)

      assert_html(html, ".reflection-placeholder-note")
      assert_no_html(html, ".reflection-not-imported-note")
    end

    private

    def omissions_with(images: 0, obs_fields: 0, description: false,
                       sequences: false)
      { "login" => "inat_observer", "images" => images,
        "obs_fields" => obs_fields, "description" => description,
        "sequences" => sequences }
    end

    def render_notes(omissions)
      render(PlaceholderNotes.new(omissions: omissions))
    end
  end
end
