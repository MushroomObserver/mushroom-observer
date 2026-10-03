# frozen_string_literal: true

# Rich-HTML page-title piece (title span, plus an optional
# owner-naming line under the title) rendered into
# `content_for(:title)` by `Views::FullPageBase#add_show_title` /
# `#add_edit_title` for show and edit pages. The id badge is a
# separate `content_for(:id_badge)` slot (see `Views::FullPageBase::
# Title#add_id_badge`) -- `Header::PageTitle` places it next to this
# title on desktop and again in its mobile-only top row, so this view
# doesn't render it directly.
#
# `mode: :show` emits `<span>{title}</span>{owner_naming}`;
# `mode: :edit` emits `<span>Edit {Type}: {title}</span>`.
# The title piece itself is:
# - Observation → `Views::Controllers::Observations::ConsensusNameLink`
#   (wraps the consensus name in a link to the name page).
# - Any other model → `Title.for(object).page_title` (see
#   app/classes/title.rb). Models with no `Title::` subclass get
#   `Title`'s own default, the type-tag label, so models that don't
#   need bespoke title logic still get a sensible string.
module Views::Layouts
  class Header::ObjectTitle < Views::Base
    prop :object, ::AbstractModel
    prop :user, _Nilable(::User), default: nil
    prop :mode, _Union(:show, :edit), default: :show
    # Precomputed title-piece override. Modal-edit callers
    # (`herbaria_controller`, `sequences_controller`, etc.) pass an
    # object-specific format like `@sequence.unique_format_name`
    # instead of letting the view dispatch through `page_title`.
    prop :title, _Nilable(::String), default: nil
    # Show-obs only: the observer's preferred naming, a second line
    # under the title. Pre-rendered HTML from `Views::Controllers::
    # Observations::OwnerNamingLine` -- `add_show_title` computes
    # this so this view stays agnostic about any one object type.
    prop :owner_naming, _Nilable(::String), default: nil

    def view_template
      span { render_title_span }
      return unless @owner_naming

      br
      span(id: "owner_naming", class: "h5") do
        trusted_html(@owner_naming)
      end
    end

    private

    def render_title_span
      if @mode == :edit
        trusted_html(append_colon(:edit_object.t(type: @object.type_tag)))
      end
      render_title
    end

    def render_title
      return trusted_html(@title) if @title

      if @object.is_a?(::Observation)
        render(::Views::Controllers::Observations::ConsensusNameLink.new(
                 observation: @object, user: @user
               ))
      else
        trusted_html(model_page_title)
      end
    end

    def model_page_title
      Title.for(@object).page_title(@user)
    end
  end
end
