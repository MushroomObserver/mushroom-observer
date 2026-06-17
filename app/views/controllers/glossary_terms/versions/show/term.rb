# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  module Versions
    class Show
      # The name + description + thumbnail block for a past version
      # of a glossary term. Converted from
      # `glossary_terms/_glossary_term.html.erb` (which was only ever
      # rendered from the versions/show page).
      class Term < Views::Base
        prop :glossary_term, ::GlossaryTerm

        def view_template
          p(class: "mt-3") do
            b { trusted_html("#{:glossary_term_name.t}:") }
            plain(" ")
            trusted_html(@glossary_term.name.t)
          end

          p(class: "mt-3") do
            trusted_html(
              "*#{:glossary_term_description.t}:* " \
              "#{@glossary_term.description}".tpl
            )
          end

          render_thumbnail
        end

        private

        def render_thumbnail
          return unless @glossary_term&.thumb_image

          p(class: "mt-3") do
            render(::Components::Image::Interactive.new(
                     user: current_user,
                     image: @glossary_term.thumb_image,
                     votes: false
                   ))
          end
        end
      end
    end
  end
end
