# frozen_string_literal: true

module Projects
  # Shared helper for project sub-controllers that mutate state which
  # changes the visible counts in the project banner's tab strip
  # (e.g. add/remove a target location, exclude an observation from
  # the updates queue). Each turbo_stream response from those actions
  # includes a `project_tabs` replacement so the user sees the
  # refreshed counts without a full page reload.
  module TabCountsRefreshable
    private

    # Turbo-stream op that replaces the project tab strip with a
    # freshly-rendered Banner. Pass to `render(turbo_stream: [...])`.
    def turbo_stream_project_tabs(current_tab)
      turbo_stream.replace(
        "project_tabs",
        Components::NavTabs.new(
          current: current_tab, link_class: "mt-3",
          tabs: Tab::Project::Banner.new(project: @project, user: @user)
        )
      )
    end
  end
end
