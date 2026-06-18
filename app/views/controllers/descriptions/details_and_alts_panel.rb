# frozen_string_literal: true

# Top panel on every name / location description show page (and on
# the version-history show pages too). Renders the description's
# core metadata in the left column, the parent's alt-description
# list + per-project draft links in the right column, and (on the
# regular show — not on versions) an export-status + review-status
# footer.
#
# Inlines the full chain that the pre-Phlex
# `_description_details_and_alts_panel.erb` composed across:
#
#   - `DescriptionsHelper#show_description_details` + #show_alt_descriptions
#     + #add_list_of_projects + #show_description_export_and_review +
#     #show_description_export_status + #show_name_description_review +
#     #show_name_description_review_status + #show_name_description_review_ui +
#     #show_name_description_latest_review + #description_title
#
# The heading-links icon strip is extracted to
# `Components::Description::ModLinks` (sibling-in-spirit to
# `Components::Link::InlineMod`), which replaces all of
# `DescriptionIconsHelper`. The "Version: N / Previous Version" line
# is `Components::Description::PreviousVersion`, replacing
# `VersionsHelper#show_previous_version`. The license-badge block
# (used by `AuthorsAndEditorsPanel`) is `Components::Image::LicenseBadge`,
# replacing the shared `_form_license_badge.erb` partial. Both
# description helper files are deleted in the same commit.
module Views::Controllers::Descriptions
  class DetailsAndAltsPanel < Views::Base
    # `review_as_string` lives in `app/helpers/localization_helper.rb`
    # and is also called from the description list view.
    register_value_helper :review_as_string

    prop :description, ::Description
    prop :user, _Nilable(::User), default: nil
    prop :versions, _Array(_Interface(:user_id))
    prop :projects, _Nilable(_Array(::Project)), default: nil
    # Show pages pass `review: true`; versions pages omit it.
    prop :review, _Boolean, default: false

    def view_template
      render(Components::Panel.new(
               panel_id: "description_details_and_alts"
             )) do |panel|
        panel.with_heading { :show_observation_details.l }
        panel.with_heading_links do
          render(Components::Description::ModLinks.new(
                   description: @description, user: @user
                 ))
        end
        panel.with_body { render_two_columns }
        panel.with_footer { render_export_and_review } if @review
      end
    end

    private

    # -- body: two columns ------------------------------------------

    def render_two_columns
      div(class: "row") do
        div(class: "col-xs-12 col-md-6") { render_details_column }
        div(class: "col-xs-12 col-md-6") { render_alts_column }
      end
    end

    # -- details column ---------------------------------------------

    def render_details_column
      render_title_row
      br
      render_parent_row
      br
      plain("#{:show_description_read_permissions.l}: #{read_perm}")
      br
      plain("#{:show_description_write_permissions.l}: #{write_perm}")
      br
      render(Components::Description::PreviousVersion.new(
               obj: @description, versions: @versions
             ))
    end

    def render_title_row
      plain("#{:TITLE.l}: ")
      trusted_html(description_title)
    end

    def render_parent_row
      parent = @description.parent
      plain("#{parent.type_tag.to_s.upcase.to_sym.t}: ")
      a(href: url_for(parent.show_link_args)) do
        trusted_html(parent.format_name.t)
      end
    end

    # Else branch (`:private.l`) is unreachable — the controller
    # bounces non-readers via
    # `user_has_permission_to_see_description?` before this view
    # ever renders.
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

    # -- alt-descriptions column ------------------------------------

    def render_alts_column
      object = @description.parent
      type = object.type_tag

      b { plain(:show_name_descriptions.l) }
      plain(": ")
      render(create_icon_link(object))
      div(class: "ml-3") do
        render(List.new(
                 user: @user, object: object, type: type,
                 current: @description,
                 empty_text: alts_empty_text(type)
               ))
      end
      render_project_drafts(object) if @projects.present?
    end

    def create_icon_link(object)
      content, path, opts = ::Tab::Description::Create.new(
        parent: object
      ).to_a
      Components::Link::Icon.new(content, path, **(opts || {}))
    end

    def alts_empty_text(type)
      :"show_#{type}_no_descriptions".t
    end

    # "Create New Draft For: <project1> <project2> ..."
    def render_project_drafts(object)
      p do
        plain("#{:show_name_create_draft.l}: ")
        br
        @projects.each do |project|
          span(class: "ml-3") do
            tab = ::Tab::Description::NewForProject.new(
              parent: object, project: project
            )
            content, path, opts = tab.to_a
            a(href: path, **(opts || {})) { trusted_html(content) }
          end
          br
        end
      end
    end

    # -- footer: export + review status -----------------------------

    def render_export_and_review
      # Same gate as `render_review_block` — name descriptions are
      # the only kind exposed to the reviewer export/review flow.
      div do
        if @description.is_a?(::NameDescription)
          render(Components::Image::ExportStatusControls.new(
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
        plain("#{:show_name_content_status.l}: ")
        plain(review_as_string(@description.review_status))
        render_review_ui_row if reviewer?
      end
    end

    def render_review_ui_row
      span(class: "reviewers-only") do
        span { plain(" | ") }
        %w[unvetted vetted inaccurate].each_with_index do |w, idx|
          span { plain(" | ") } if idx.positive?
          render(Components::CrudButton::Put.new(
                   target: review_status_name_description_path(
                     @description.id, value: w
                   ),
                   name: :"review_#{w}".l
                 ))
        end
      end
    end

    def render_latest_review_row
      span(class: "help-note") do
        span(class: "ml-3") { trusted_html("&nbsp;".html_safe) }
        plain("(")
        trusted_html(:show_name_latest_review.t(
                       date: latest_review_date, user: reviewer_link
                     ))
        plain(")")
      end
    end

    def latest_review_date
      @description.last_review&.web_time || :UNKNOWN.l
    end

    def reviewer_link
      reviewer = @description.reviewer
      capture do
        render(Components::Link::Object::User.new(user: reviewer,
                                                  name: reviewer.login))
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
  end
end
