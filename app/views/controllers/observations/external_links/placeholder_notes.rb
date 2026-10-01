# frozen_string_literal: true

# Notes under a placeholder's iNat link in the "On iNaturalist" panel:
# It's a placeholder; what was not imported.
module Views::Controllers::Observations::ExternalLinks
  class PlaceholderNotes < Views::Base
    prop :omissions, Hash

    def view_template
      div(class: "reflection-placeholder-note text-muted small mt-1") do
        plain(:observation_placeholder_source.l(login: @omissions["login"]))
      end
      items = not_imported_items
      return if items.empty?

      div(class: "reflection-not-imported-note text-muted small mt-1") do
        plain(:observation_placeholder_not_imported.l(
                items: items.join(", ")
              ))
      end
    end

    private

    def not_imported_items
      [images_item, obs_fields_item, description_item, sequences_item].
        compact
    end

    def images_item
      count = @omissions["images"].to_i
      return unless count.positive?

      :observation_placeholder_images.l(count: count)
    end

    def obs_fields_item
      count = @omissions["obs_fields"].to_i
      return unless count.positive?

      :observation_placeholder_obs_fields.l(count: count)
    end

    def description_item
      return unless @omissions["description"]

      :observation_placeholder_description.l
    end

    def sequences_item
      return unless @omissions["sequences"]

      :observation_placeholder_sequences.l
    end
  end
end
