# frozen_string_literal: true

# Rich-HTML page-title piece (id badge + title span) rendered into
# `content_for(:title)` by `Views::FullPageBase#add_show_title` /
# `#add_edit_title` for show and edit pages.
#
# `mode: :show` emits `<flex><IdBadge/> <span>{title}</span></flex>`;
# `mode: :edit` emits
# `<flex><IdBadge/> <span>Edit {Type}: {title}</span></flex>`.
# The title piece itself is:
# - Observation → `Views::Controllers::Observations::ConsensusNameLink`
#   (wraps the consensus name in a link to the name page).
# - Any model that exposes `#page_title` → that string (arity-aware so
#   models can alias to a zero-arg method).
# - Otherwise → the model's localized type-tag label.
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
        render(::Components::IdBadge.new(object: @object,
                                         extra_class: "mr-4"))
        plain(" ")
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
      elsif @object.respond_to?(:page_title)
        trusted_html(model_page_title)
      else
        plain(:"#{@object.type_tag.to_s.upcase}".l)
      end
    end

    # Models can alias `page_title` to a zero-arg accessor (e.g.
    # `alias page_title title`) instead of writing a one-line wrapper
    # that ignores `user`. The arity check lets both shapes work.
    def model_page_title
      if @object.method(:page_title).arity.zero?
        @object.page_title
      else
        @object.page_title(@user)
      end
    end
  end
end
