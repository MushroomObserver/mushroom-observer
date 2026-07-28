# frozen_string_literal: true

# Rich-HTML page-title piece (id badge + title span) rendered into
# `content_for(:title)` by `Views::FullPageBase#add_show_title` /
# `#add_edit_title` for show and edit pages.
#
# `mode: :show` emits `<flex><IDBadge/> <span>{title}</span></flex>`;
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

    def view_template
      div(class: "d-flex align-items-center") do
        IDBadge(object: @object, size: :sm)
        whitespace
        span { render_title_span }
      end
    end

    private

    def render_title_span
      plain("#{:edit_object.t(type: @object.type_tag)}: ") if @mode == :edit
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
