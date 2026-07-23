# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  class Index
    # One row in the glossary terms index list. Two columns: name +
    # description on the left, admin destroy button + thumbnail on
    # the right.
    class Item < Views::Base
      prop :glossary_term, ::GlossaryTerm

      def view_template
        Row do
          Column(xs: 12, sm: 9) { render_left }
          Column(xs: 12, sm: 3) { render_right }
        end
      end

      private

      def render_left
        h4 do
          Link(type: :get, name: @glossary_term.name,
               target: glossary_term_path(@glossary_term.id))
          plain(":")
        end
        trusted_html(@glossary_term.description.tpl)
      end

      def render_right
        render_destroy_button if in_admin_mode?
        render_thumbnail
      end

      def render_destroy_button
        destroy_button(target: @glossary_term,
                       name: :destroy_object.t(type: :glossary_term),
                       variant: :strip)
      end

      def render_thumbnail
        return unless @glossary_term&.thumb_image_id&.nonzero?

        InteractiveImage(
          user: current_user,
          image: @glossary_term.thumb_image,
          votes: true
        )
      end
    end
  end
end
