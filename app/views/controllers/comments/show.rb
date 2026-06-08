# frozen_string_literal: true

# Single-comment show page. Linked from the per-show-page comment
# list and the comments index. Renders four lines: created-at,
# by-user link, summary, and the Textile-rendered body.
#
# Replaces `app/views/controllers/comments/show.html.erb`.
module Views::Controllers::Comments
  class Show < Views::Base
    prop :comment, ::Comment
    prop :target, ::AbstractModel
    prop :user, _Nilable(::User), default: nil

    def view_template
      register_target_names
      add_page_title(:comment_show_title.t(
                       name: @target.unique_format_name
                     ))
      add_pager_for(@comment)
      add_context_nav(::Tab::Comment::ShowActions.new(
                        comment: @comment, target: @target,
                        permission: permission?(@comment)
                      ))

      render_created_at
      render_author
      render_summary
      render_body
    end

    private

    # Register names appearing in the target so Textile can render
    # `_G. species_` correctly — for an Observation include all
    # proposed names + the consensus name; for a Name include all
    # synonyms + the name itself. Other targets need no registration.
    def register_target_names
      case @comment.target_type
      when "Observation"
        @comment.target.namings.each { |n| ::Textile.register_name(n.name) }
        ::Textile.register_name(@comment.target.name)
      when "Name"
        @comment.target.synonyms.each { |n| ::Textile.register_name(n) }
        ::Textile.register_name(@comment.target)
      end
    end

    def render_created_at
      p do
        plain("#{:comment_show_created_at.t}: ")
        plain(@comment.created_at.web_time)
      end
    end

    def render_author
      p do
        plain("#{:comment_show_by.t}: ")
        UserLink(user: @comment.user)
      end
    end

    def render_summary
      p do
        plain("#{:comment_show_summary.t}: ")
        trusted_html(@comment.summary.tl)
      end
    end

    def render_body
      # Legacy ERB joined the label, ": ", and the body in one
      # string then rendered with `.tpl` (Textile paragraph). Keep
      # that single-textile-render shape so paragraph break
      # placement matches.
      trusted_html(
        # rubocop:disable Rails/OutputSafety -- mirrors the legacy
        # ERB: textile rendering needs raw markup; comment author
        # input is sanitized upstream.
        "#{:comment_show_comment.l}: #{@comment.comment.to_s.html_safe}".tpl
        # rubocop:enable Rails/OutputSafety
      )
    end
  end
end
