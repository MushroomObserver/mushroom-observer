# frozen_string_literal: true

module Views::Controllers::Images
  class Show
    # Top-right info panel: when / owner / projects / observations /
    # profile-users / glossary-terms / notes.
    class InfoPanel < Views::Base
      prop :image, ::Image

      def view_template
        render(::Components::Panel.new(
                 panel_id: "info_panel", panel_class: "py-2"
               )) do |panel|
          panel.with_heading { "#{:NOTES.t}:" }
          panel.with_body { render_body }
        end
      end

      private

      def render_body
        info_row(:WHEN.t, @image.when.web_date)
        owner_row
        render_associated_rows
        render_notes if @image.notes.present?
      end

      def render_associated_rows
        @image.projects.each { |proj| project_row(proj) }
        @image.observations.each { |obs| observation_row(obs) }
        @image.profile_users.each { |user| profile_user_row(user) }
        @image.glossary_terms.each { |term| glossary_term_row(term) }
      end

      def info_row(label, value)
        div { plain("#{label}: #{value}") }
      end

      def owner_row
        div do
          plain("#{:OWNER.t}: ")
          Link(type: :user, user: @image.user)
        end
      end

      def project_row(proj)
        div do
          plain("#{:PROJECT.t}: ")
          Link(type: :object, object: proj)
        end
      end

      def observation_row(obs)
        div do
          plain("#{:OBSERVATION.t}: ")
          link_to(viewer_aware_unique_format_name(obs).t, obs.show_link_args)
        end
      end

      def profile_user_row(user)
        div do
          plain("#{:USER.t}: ")
          link_to(user.format_name.t, user.show_link_args)
        end
      end

      def glossary_term_row(term)
        div do
          plain("#{:GLOSSARY_TERM.t}: ")
          link_to(term.format_name.t, term.show_link_args)
        end
      end

      def render_notes
        notes = "#{:image_show_notes.l}: #{@image.notes}"
        trusted_html(notes.tpl)
      end
    end
  end
end
