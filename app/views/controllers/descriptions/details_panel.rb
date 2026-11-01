# frozen_string_literal: true

# Left-column panel on every name / location description show page
# (and on the version-history show pages too): the description's
# core metadata (title, parent link, permissions), plus (on the
# regular show -- not on versions) an export-status + review-status
# footer.
#
# The heading-links icon strip is extracted to
# `Components::Description::ModLinks` (sibling-in-spirit to
# `Components::InlineCRUDLinks`). The parent's other descriptions +
# new-draft UI live in the separate `OtherDescriptionsPanel`, not
# here -- they're a different concept from this description's
# detail, not part of "Detail" (#5527 review).
module Views::Controllers::Descriptions
  class DetailsPanel < Views::Base
    prop :description, ::Description
    prop :user, _Nilable(::User), default: nil
    # Show pages pass `review: true`; versions pages omit it.
    prop :review, _Boolean, default: false

    def view_template
      Panel(panel_id: "description_details") do |panel|
        panel.with_heading { :show_observation_details.l }
        panel.with_heading_links do
          render(Components::Description::ModLinks.new(
                   description: @description, user: @user
                 ))
        end
        panel.with_body { render_details }
        panel.with_footer { render_export_and_review } if @review
      end
    end

    private

    def render_details
      render_title_row
      br
      render_parent_row
      br
      plain("#{:show_description_read_permissions.l}: #{read_perm}")
      br
      plain("#{:show_description_write_permissions.l}: #{write_perm}")
    end

    def render_title_row
      trusted_html(append_colon(:title.ti))
      trusted_html(description_title)
    end

    def render_parent_row
      parent = @description.parent
      trusted_html(append_colon(parent.type_tag.ti))
      a(href: url_for(parent.show_link_args)) do
        trusted_html(parent.format_name.t)
      end
    end

    # Else branch (`:private.l`) is unreachable — the controller
    # bounces non-readers via
    # `user_has_permission_to_see_description?` before this view
    # renders.
    def read_perm
      if @description.reader_groups.include?(::UserGroup.all_users)
        :public.l
      else
        :restricted.l
      end
    end

    def write_perm
      if @description.writer_groups.include?(::UserGroup.all_users)
        :public.l
      elsif in_admin_mode? || @description.writer?(@user)
        :restricted.l
      else
        :private.l
      end
    end

    # -- footer: export + review status -----------------------------

    def render_export_and_review
      # Same gate as `render_review_block` — name descriptions are
      # the only kind exposed to the reviewer export/review flow.
      div do
        if @description.is_a?(::NameDescription)
          render(Views::Controllers::Export::StatusControls.new(
                   object: @description
                 ))
        end
      end
      div { render_review_block }
    end

    def render_review_block
      # Only name descriptions have a review-status workflow.
      return unless @description.parent.type_tag == :name

      render_review_status_row
      render_latest_review_row if @description.reviewer
    end

    def render_review_status_row
      div do
        trusted_html(append_colon(:show_name_content_status.l))
        plain(review_as_string(@description.review_status))
        render_review_ui_row if reviewer?
      end
    end

    def render_review_ui_row
      span(class: "reviewers-only") do
        span { plain(" | ") }
        %w[unvetted vetted inaccurate].each_with_index do |w, idx|
          span { plain(" | ") } if idx.positive?
          Button(
            type: :put,
            variant: :strip,
            target: review_status_name_description_path(
              @description.id, value: w
            ),
            name: :"review_#{w}".l
          )
        end
      end
    end

    def render_latest_review_row
      Help(element: :span) do
        span(class: "ml-3") { nbsp }
        plain("(")
        trusted_html(:show_name_latest_review.t(
                       date: latest_review_date, user: reviewer_link
                     ))
        plain(")")
      end
    end

    def latest_review_date
      @description.last_review&.web_time || :unknown.ti
    end

    def reviewer_link
      reviewer = @description.reviewer
      capture do
        Link(type: :user, user: reviewer, name: reviewer.login)
      end
    end

    # -- description title (with permission suffix) -----------------

    def description_title
      result = @description.partial_format_name
      permit = title_permission_label
      result += " (#{permit})" unless
        /(^| )#{permit}( |$)/i.match?(result)
      result.t
    end

    def title_permission_label
      if @description.parent.description_id == @description.id
        :default.l
      elsif @description.public
        :public.l
      elsif @description.is_reader?(@user) || in_admin_mode?
        :restricted.l
      else
        :private.l
      end
    end

    # `Description#review_status` → translation key lookup, e.g.
    # `:unvetted` → "Needs Review".
    def review_as_string(val)
      :"review_#{val}".l
    end
  end
end
