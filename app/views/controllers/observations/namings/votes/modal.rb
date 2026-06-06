# frozen_string_literal: true

# Turbo-stream wrapper for the per-naming vote-breakdown modal —
# the response body for `votes#index` when requested with
# `format: :turbo_stream`. Composes `Components::Modal` with the
# `Table` in the body slot.
#
# Lives as a thin wrapper because `ActionController#render` treats
# a trailing `do |x| … end` block as a layout block rather than
# passing it through to the Phlex view's `view_template`; calling
# `Components::Modal` directly with slot setters from a controller
# action drops the slot configuration. This wrapper does the slot
# setup inside its own `view_template`, where the block IS
# forwarded.
module Views::Controllers::Observations::Namings::Votes
  class Modal < Views::Base
    prop :naming, _Union(::Naming, ::Observation::MergedNaming)
    prop :user, _Nilable(::User), default: nil
    prop :modal_id, String
    prop :title, String

    def view_template
      render(Components::Modal.new(
               id: @modal_id, user: @user
             )) do |modal|
        modal.with_title_content do
          trusted_html(@title)
          trusted_html(@naming.display_name_brief_authors.t.small_author)
        end
        modal.with_body do
          render(Table.new(naming: @naming))
        end
      end
    end
  end
end
