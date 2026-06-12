# frozen_string_literal: true

# "Project that owns this description" icon-link — shown on
# project-sourced descriptions only. Caller is responsible for the
# `source_type == "project"` check (and for ensuring
# `description.source_object` is present) before instantiating.
class Tab::Description::Project < Tab::Base
  def initialize(description:)
    super()
    @description = description
  end

  def title
    :show_object.t(type: :project)
  end

  def path
    @description.source_object.show_link_args
  end

  def html_options
    { icon: :project }
  end

  def model
    @description
  end
end
