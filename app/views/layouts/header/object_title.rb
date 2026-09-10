# frozen_string_literal: true

# Rich-HTML page-title piece (id badge + title span, plus an
# optional owner-naming line under the title) rendered into
# `content_for(:title)` by `Views::FullPageBase#add_show_title` /
# `#add_edit_title` for show and edit pages.
#
# `mode: :show` emits
# `<flex><IDBadge/> <div><span>{title}</span>{owner_naming}</div></flex>`;
# `mode: :edit` emits
# `<flex><IDBadge/> <span>Edit {Type}: {title}</span></flex>`.
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
    # under the title (still to the right of the id badge, not a
    # full-width line below the whole title bar). Pre-rendered HTML
    # from `Views::Controllers::Observations::OwnerNamingLine` --
    # `add_show_title` computes this so this view stays agnostic
    # about any one object type.
    prop :owner_naming, _Nilable(::String), default: nil

    def view_template
      div(class: "d-flex align-items-start") do
        IDBadge(object: @object, size: :md)
        whitespace
        div do
          span { render_title_span }
          if @owner_naming
            br
            span(id: "owner_naming", class: "h5") do
              trusted_html(@owner_naming)
            end
          end
        end
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
