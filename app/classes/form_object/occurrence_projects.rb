# frozen_string_literal: true

# Form object for the project-membership confirmation modal posted by
# `Components::OccurrenceProjectsForm`. Represents the collection of
# projects spanning an occurrence's observations, plus the user's
# choice for resolving gaps (`"skip"` or `"add_all"`).
#
# Not an Occurrence — it's the data the confirmation modal needs to
# either create a new occurrence (replaying the new-form's selection)
# or to resolve gaps on an existing one. Param namespace is
# `occurrence_projects[*]` so the controller can tell which form
# posted (initial new-form post = `occurrence[*]`, modal repost =
# `occurrence_projects[*]`).
class FormObject::OccurrenceProjects < FormObject::Base
  attribute :resolution, :string
  attribute :primary_observation_id, :integer
  attribute :observation_ids, default: -> { [] }
end
