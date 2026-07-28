# frozen_string_literal: true

# Resolves project aliases typed into the observation form.
#
# A project alias is a short local name — "Barn", "Site 3" — that a
# project maps to a real Location or User. The field slip form resolved
# these on save; the observation form has to as well, now that a scanned
# slip lands there (#4932).
#
# Timing is not incidental. This runs *before* `validate_place_name`,
# because an alias is by design not a plausible place name, so
# `Location.dubious_reasons_for` would fail the save before the alias
# ever resolved. It also runs before `create_location_object_if_new`,
# which would otherwise offer to create a Location literally named
# "Barn".
#
# It overwrites `location_id` rather than reading it: the permitted-args
# list applies `location_id` *after* `place_name`, so a stale id beats
# the typed text. The autocompleter clears that id client-side when the
# text changes, but the form still supports `was_js_on`, so it has to be
# beaten server-side too.
module ObservationsController::ProjectAliases
  private

  def resolve_project_aliases
    resolve_alias_place_name
    resolve_alias_collector
  end

  def resolve_alias_place_name
    location = alias_target(params.dig(:observation, :place_name), Location)
    return unless location

    @observation.location = location
    @observation.where = location.name
    @location = location
  end

  def resolve_alias_collector
    user = alias_target(params.dig(:observation, :collector), User)
    return unless user

    attrs = Observation.collector_attrs(user)
    @observation.collector = attrs[:collector]
    @observation.collector_user_id = attrs[:collector_user_id]
  end

  # Aliases are unique per project, so more than one match means more than
  # one targeted project defines the same name. Expected to be very rare:
  # the most recently updated alias wins and the user is told which and
  # why, rather than the choice being silent.
  def alias_target(typed, target_type)
    typed = typed.to_s.strip
    return nil if typed.blank? || alias_project_ids.empty?

    matches = ProjectAlias.
              where(project_id: alias_project_ids, name: typed,
                    target_type: target_type.name).
              includes(:project, :target).
              order(updated_at: :desc, id: :desc).to_a
    return nil if matches.empty?

    flash_ambiguous_alias(typed, matches) if matches.many?
    matches.first.target
  end

  def flash_ambiguous_alias(typed, matches)
    flash_warning(
      :form_observations_ambiguous_alias.t(
        name: typed,
        project: matches.first.project.title,
        others: matches.drop(1).map { |a| a.project.title }.join(", ")
      )
    )
  end

  # Whose aliases apply: the projects checked on the form, the field
  # slip's own project whether or not it is checked (a scanned slip is
  # the whole point), and — for a slip that already has an occurrence —
  # the projects its observations belong to, since an occurrence's
  # members share project membership.
  def alias_project_ids
    @alias_project_ids ||= begin
                             slip = field_slip_for_code(params[:field_code])
                             ids = Array(params.dig(:observation,
                                                    :project_ids)).map(&:to_i)
                             ids << slip.project_id if slip&.project_id
                             ids.concat(occurrence_project_ids(slip))
                             ids.reject(&:zero?).uniq
                           end
  end

  def occurrence_project_ids(slip)
    occurrence = slip&.occurrence
    return [] unless occurrence

    occurrence.observations.flat_map(&:project_ids)
  end
end
