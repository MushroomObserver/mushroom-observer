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
#   render(Components::Timestamps.new(object: @collection_number))
# @example without the outer wrap
#   render(Components::Timestamps.new(object: @sequence, wrap: false))
class Components::Timestamps < Components::Base
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
      trusted_html(:CREATED_AT.t)
      plain(": #{@object.created_at.web_date}")
      br
      trusted_html(:UPDATED_AT.t)
      plain(": #{@object.updated_at.web_date}")
      br
    end
  end
end
