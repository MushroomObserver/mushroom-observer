# frozen_string_literal: true

module Views::Controllers::Images
  class Show
    # Vote panel — current vote heading + (when logged in) the
    # vote-action grid + the per-user vote table.
    class VotePanel < Views::Base
      prop :image, ::Image
      prop :size, _Nilable(_Union(::Symbol, ::String)), default: nil
      prop :default_size, _Nilable(_Union(::Symbol, ::String)), default: nil

      def view_template
        render(::Components::Panel.new(
                 panel_id: "image_vote_content"
               )) do |panel|
          panel.with_heading { render_current_vote_heading }
          render_user_vote_body(panel) if current_user
          panel.with_body(classes: "p-0") { render_vote_table_container }
        end
      end

      private

      def current_vote_value
        @current_vote_value ||= (@image.vote_cache.to_f + 0.5).to_i
      end

      def render_current_vote_heading
        b { plain(:image_show_quality.t) }
        plain(": ")
        span(class: "font-weight-normal") do
          # `image_vote_as_long_string` returns text with embedded
          # textile (e.g. `*Good*`), `.t` then html-safes it; use
          # `trusted_html` so the `<b>` tag isn't escaped.
          trusted_html(image_vote_as_long_string(current_vote_value).t)
        end
      end

      # --- Your-vote section ----------------------------------------

      def render_user_vote_body(panel)
        panel.with_body do
          div(class: "text-center mb-3") do
            render_your_vote_summary
            render_vote_grid
          end
        end
      end

      def render_your_vote_summary
        current = current_user_vote
        p do
          plain("#{:image_show_your_vote.t}: ")
          span(class: "font-weight-normal") do
            trusted_html(image_vote_as_long_string(current).t)
          end
        end
      end

      def current_user_vote
        @image.users_vote(current_user).to_i
      end

      def render_vote_grid
        current = current_user_vote
        ([0] + ::Image.all_votes).each do |value|
          render_vote_row(value, current)
        end
      end

      def render_vote_row(value, current)
        css = current == value ? "font-weight-bold" : ""
        Row do
          Column(xs: 12, sm: 6) { render_vote_link(value, css) }
          Column(xs: 12, sm: 6, class: "hidden-xs") do
            render_vote_and_next_link(value, css)
          end
        end
      end

      def vote_link_args
        args = { id: @image.id }
        args[:size] = @size if @size && @size != @default_size
        args
      end

      def render_vote_link(value, css)
        short = image_vote_as_short_string(value)
        help = image_vote_as_help_string(value)
        text = value.zero? ? help : short
        div(class: "pt-2") do
          link_to(text, vote_link_args.merge(vote: value),
                  class: css, title: help,
                  data: { toggle: "tooltip", placement: "left",
                          role: "image_vote", val: value, id: @image.id })
        end
      end

      def render_vote_and_next_link(value, css)
        short = image_vote_as_short_string(value)
        help = image_vote_as_help_string(value)
        text = :image_show_vote_and_next.t(value: short)
        div(class: "pt-2") do
          link_to(text, vote_link_args.merge(vote: value, next: true),
                  class: css, title: help,
                  data: { toggle: "tooltip" })
        end
      end

      # --- Per-user vote table --------------------------------------

      def sorted_votes
        @image.image_votes.sort_by do |vote|
          (vote.anonymous ? :anonymous.l : vote.user.unique_text_name).downcase
        rescue StandardError
          "?"
        end
      end

      def render_vote_table_container
        div(id: "show_votes_container") do
          render_vote_table if sorted_votes.any?
        end
      end

      def render_vote_table
        Table(sorted_votes,
              variant: :striped, identifier: "show-votes",
              class: "mt-3 mb-0") do |t|
          t.column(:user.ti) { |vote| render_vote_user_cell(vote) }
          t.column(:vote.ti) { |vote| image_vote_as_short_string(vote.value) }
        end
      end

      def render_vote_user_cell(vote)
        if vote.anonymous
          plain(:anonymous.t)
        else
          Link(type: :user, user: vote.user)
        end
      end
    end
  end
end
