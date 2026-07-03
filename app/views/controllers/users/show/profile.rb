# frozen_string_literal: true

module Views::Controllers::Users
  class Show
    # User profile panel — bio, mailing address, herbarium link,
    # action links, life-list footer.
    class Profile < Views::Base
      prop :show_user, ::User
      prop :user, _Nilable(::User), default: nil
      prop :life_list, ::Checklist::ForUser

      def view_template
        render(::Components::Panel.new(panel_id: "user_profile")) do |panel|
          panel.with_heading { render_heading }
          links = capture { render_heading_links }
          panel.with_heading_links { trusted_html(links) } if links.present?
          panel.with_body { render_body }
          footer = capture { render_footer }
          panel.with_footer { trusted_html(footer) } if footer.present?
        end
      end

      private

      def render_heading
        strong { :show_user_joined.l }
        plain(": ")
        # `verified` is nil for unverified users (#4551 fix from main).
        span(
          data: { time: @show_user.verified&.strftime("%Y-%m-%dT%H:%M:%S") }
        ) { @show_user.verified&.strftime("%Y-%m-%d") }
      end

      def render_heading_links
        return if @show_user == @user || @show_user.no_emails
        return unless @show_user.email_general_question

        render(::Components::Button.new(
                 type: :modal,
                 name: :show_user_email_to.t(
                   name: @show_user.unique_text_name
                 ),
                 target: new_question_for_user_path(@show_user.id),
                 modal_id: "user_question_email",
                 variant: :strip, icon: :email
               ))
      end

      def render_body
        render_profile_image if @show_user.image
        render_primary_location if @show_user.location
        render_mailing_address if @show_user.mailing_address.present?
        render_personal_herbarium if @show_user.personal_herbarium.present?
        trusted_html(@show_user.notes.tpl) if @show_user.notes.present?
        render_action_links
      end

      def render_profile_image
        div(class: "float-left mr-5 mb-3") do
          render(::Components::Image::Interactive.new(
                   user: @user, image: @show_user.image, size: :small,
                   votes: false, id_prefix: "profile_image"
                 ))
        end
      end

      def render_primary_location
        p do
          strong { "#{:show_user_primary_location.l}:" }
          whitespace
          Link(type: :location, location: @show_user.location)
        end
      end

      def render_mailing_address
        p do
          strong { "#{:show_user_mailing_address.l}:" }
          plain(" #{@show_user.mailing_address}")
        end
      end

      def render_personal_herbarium
        p do
          strong { "#{:show_user_personal_herbarium.l}:" }
          whitespace
          link_to(@show_user.personal_herbarium.show_link_args) do
            trusted_html(@show_user.personal_herbarium.name.t)
          end
        end
      end

      include ::Components::LinkRendering

      def render_action_links
        div(class: "mt-3") do
          ul(class: "list-unstyled mb-0") do
            ::Tab::User::ProfileActions.new(
              show_user: @show_user, user: @user, admin: in_admin_mode?
            ).each do |tab|
              li { render_action_link(tab.to_a) }
            end
          end
        end
      end

      # `tuple` is `[text, url, args]`. The block emits one
      # link / button into the surrounding `<li>` via the same
      # `Components::LinkRendering` dispatch the two
      # `Views::Layouts::*::ContextNav` views use. The conditional
      # `d-block` strip mirrors the legacy
      # `Header::ContextNavHelper#context_nav_link` behaviour: for
      # `button:` tuples that ALSO came in with `d-block` in their
      # class list, drop it so the form/button isn't laid out as a
      # block — `button_to`'s wrapping `<form>` already provides the
      # block-level container. Plain anchor tuples keep `d-block`.
      def render_action_link(tuple)
        str, url, args = tuple
        args ||= {}
        kwargs = merge_context_nav_link_args(args, {})
        if args[:button].present? && kwargs[:class].present?
          kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
        end
        render_crud_button_or_link(str, url, args, kwargs.compact_blank)
      end

      def render_footer
        return unless @life_list.num_taxa.positive?

        link_to(checklist_path(id: @show_user.id)) do
          strong { :app_life_list.l }
        end
        plain(": ")
        trusted_html(life_list_text)
      end

      def life_list_text
        species = @life_list.num_species_observed
        higher = @life_list.num_higher_level_observed
        taxa_word = higher == 1 ? :checklist_taxon.l : :checklist_taxa.l
        if species.positive? && higher.positive?
          :show_user_life_list.t(species: species, higher: higher,
                                 taxa_word: taxa_word)
        elsif species.positive?
          :show_user_life_list_species.t(species: species)
        else
          :show_user_life_list_higher.t(higher: higher, taxa_word: taxa_word)
        end
      end
    end
  end
end
