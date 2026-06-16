# frozen_string_literal: true

module Views::Controllers::Publications
  # Read-only publication detail page.
  class Show < Views::Base
    prop :publication, ::Publication

    def view_template
      add_page_title(:PUBLICATION.l)
      add_edit_icons(@publication, current_user) if current_user

      render_full
      render_link if @publication.link.present?
      render_flags
      render_how_helped
      render_added_by
    end

    private

    def render_full
      p do
        b { "#{:publication_full.l}:" }
        br
        trusted_html(@publication.full.t.strip_links)
      end
    end

    def render_link
      p(style: "word-break:break-all") do
        b { "#{:publication_link.l}:" }
        br
        link_to(@publication.link, @publication.link)
      end
    end

    def render_flags
      p do
        if @publication.peer_reviewed
          b { :publication_peer_reviewed.l }
          br
        end
        b { :publication_mo_mentioned.l } if @publication.mo_mentioned
      end
    end

    def render_how_helped
      p do
        b { :publication_how_helped.l }
        br
        trusted_html(@publication.how_helped.t)
      end
    end

    def render_added_by
      p do
        b { :show_publication_added_by.l }
        plain(": ")
        render(::Components::UserLink.new(user: @publication.user))
        plain(" #{@publication.created_at.web_date}")
        br
        render_updated_at_line
      end
    end

    def render_updated_at_line
      return if @publication.created_at.web_date ==
                @publication.updated_at.web_date

      plain(:footer_last_updated_at.t(date: @publication.updated_at.web_date))
    end
  end
end
