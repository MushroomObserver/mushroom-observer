# frozen_string_literal: true

# View Helpers for Projects
module ProjectsHelper
  def field_slip_link(tracker, user)
    if tracker.status == "Done" && user == tracker.user
      link_to(tracker.filename, tracker.link)
    else
      tracker.filename
    end
  end

  def edit_project_alias_link(project_id, name, id)
    tag.span(id: "project_alias_#{id}") do
      modal_link_to(
        "project_alias_#{id}",
        *edit_project_alias_tab(project_id, name, id)
      )
    end
  end

  def new_project_alias_link(project_id, target_id, target_type)
    tag.span(id: "project_alias") do
      modal_link_to(
        "project_alias",
        *new_project_alias_tab(project_id, target_id, target_type)
      )
    end
  end

  def project_alias_headers
    [:NAME.t, :TARGET_TYPE.t, :TARGET.t, :ACTIONS.t]
  end

  def project_alias_rows(project_aliases)
    project_aliases.includes(:target).map do |project_alias|
      project_alias_row(project_alias)
    end
  end

  #########

  private

  def project_alias_row(project_alias)
    [
      project_alias.name,
      project_alias.target_type,
      link_to(project_alias.target.try(:format_name), project_alias.target),
      project_alias_actions(project_alias.id, project_alias.project_id)
    ]
  end

  def project_alias_actions(id, project_id)
    capture do
      concat(edit_button(target: edit_project_alias_path(project_id:, id:),
                         icon: :edit))
      concat(tag.span(class: "mx-2"))
      concat(destroy_button(target: project_alias_path(project_id:, id:),
                            icon: :delete))
    end
  end

  def edit_project_alias_tab(project_id, name, id)
    InternalLink::Model.new(
      name, ProjectAlias,
      edit_project_alias_path(project_id:, id:),
      alt_title: :EDIT.t
    ).tab
  end

  def new_project_alias_tab(project_id, target_id, target_type)
    InternalLink::Model.new(
      :ADD.t, ProjectAlias,
      new_project_alias_path(project_id:, target_id:, target_type:),
      html_options: { class: "btn btn-default" }
    ).tab
  end
end
