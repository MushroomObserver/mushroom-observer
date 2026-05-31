# frozen_string_literal: true

# A composed group of `Tab::Base` POROs — typically rendered as a
# `Components::NavTabs` strip or as the action-nav links for a
# controller action. Subclasses define `#tabs` (private) returning an
# Array of Tab::Base instances; the base provides Enumerable behavior
# and bridges to the legacy `[title, url, opts]` array shape.
#
# Conditional inclusion (e.g. "show admin tab iff user is admin",
# "show update tab iff project has targets AND user is admin") lives
# in `#tabs` so it's unit-testable without rendering a view.
#
# @example
#   class Tab::Project::Banner < Tab::Collection
#     def initialize(project:, user:)
#       @project = project
#       @user = user
#     end
#
#     private
#
#     def tabs
#       [Tab::Project::Summary.new(project: @project),
#        *body_tabs,
#        admin_tab].compact
#     end
#
#     def admin_tab
#       return unless @project.is_admin?(@user)
#       Tab::Project::Admin.new(project: @project)
#     end
#     # ...
#   end
#
#   Tab::Project::Banner.new(project: p, user: u).to_a
#   # => [<Tab::Project::Summary …>, <Tab::Project::Observations …>, …]
#
#   Tab::Project::Banner.new(project: p, user: u).to_internal_links
#   # => [<InternalLink …>, <InternalLink …>, …]
class Tab::Collection
  include Enumerable

  def each(&block)
    tabs.each(&block)
  end

  def to_internal_links
    tabs.map(&:to_internal_link)
  end

  private

  def tabs
    raise(NotImplementedError.new("#{self.class}#tabs"))
  end
end
