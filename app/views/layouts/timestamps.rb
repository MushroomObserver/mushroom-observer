# frozen_string_literal: true

# `Created at` / `Updated at` block used at the bottom of many show
# pages. Defaults to wrapping itself in `Components::ContentPadded`
# (matching `VersionsFooter`'s visual padding); pass `wrap: false`
# to drop the wrap when the caller already supplies its own.
#
# Note: the dates-only format here is distinct from
# `VersionsFooter`'s non-versioned branch, which uses the
# `:footer_created_by` / `:footer_last_updated_by` translation
# keys and interpolates a rendered `UserLink`. Different keys,
# different content — `VersionsFooter` doesn't delegate to this
# component.
#
# @example
#   render(Views::Layouts::Timestamps.new(object: @collection_number))
# @example without the outer wrap
#   render(Views::Layouts::Timestamps.new(object: @sequence, wrap: false))
module Views::Layouts
  class Timestamps < Views::Base
    prop :object, ::AbstractModel
    prop :wrap, _Boolean, default: true

    def view_template
      if @wrap
        render(::Components::ContentPadded.new(class: "small")) { lines }
      else
        lines
      end
    end

    private

    def lines
      p do
        plain("#{:CREATED_AT.l}: #{@object.created_at.web_date}")
        br
        plain("#{:UPDATED_AT.l}: #{@object.updated_at.web_date}")
        br
      end
    end
  end
end
