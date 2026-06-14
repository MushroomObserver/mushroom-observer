# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  class Index
    # One row in the glossary terms index list. Two columns: name +
    # description on the left, admin destroy button + thumbnail on
    # the right. Converted from `glossary_terms/_object.html.erb`.
    class Item < Views::Base
      prop :glossary_term, ::GlossaryTerm

      def view_template
        div(class: "row") do
          div(class: "col-xs-12 col-sm-9") { render_left }
          div(class: "col-xs-12 col-sm-3") { render_right }
        end
      end

      private

      def render_left
        h4 do
          link_to(@glossary_term.name,
                  glossary_term_path(@glossary_term.id))
          plain(":")
        end
        trusted_html(@glossary_term.description.tpl)
      end

      def render_right
        render_destroy_button if in_admin_mode?
        render_thumbnail
      end

      # Inlined from the `glossary_term_destroy_button` helper —
      # `destroy_button` is the only call there, so the helper file
      # is deleted in this same PR.
      def render_destroy_button
        destroy_button(target: @glossary_term,
                       name: :destroy_object.t(type: :glossary_term),
                       btn: nil)
      end

      def render_thumbnail
        return unless @glossary_term&.thumb_image_id&.nonzero?

        render(::Components::InteractiveImage.new(
                 user: current_user,
                 image: @glossary_term.thumb_image,
                 votes: true
               ))
      end
    end
  end
end
