# frozen_string_literal: true

# Attributes:
# code:    string, unique code for field slip, starts with project prefix

class FieldSlip < AbstractModel
  attr_reader :current_user

  has_one :occurrence, dependent: :nullify
  belongs_to :project
  belongs_to :user

  # A slip's project implies its observations are in that project, so
  # changing the project has to move them. Both `code=` (which re-derives
  # the project from the new prefix) and the form's project dropdown get
  # here. See #4932.
  after_update :cascade_project_change, if: :saved_change_to_project_id?

  validates :user_id, presence: true
  validates :code, uniqueness: true
  validates :code, presence: true
  validate do |field_slip|
    unless field_slip.code.match?(/[^\d.-]/)
      errors.add(:code, :field_slip_code_format_error)
    end
  end

  # The project-prefix portion of a code: everything before the trailing
  # " 123" / "-123" sequence number. Returns nil when the code has no
  # such suffix (so it can't belong to a prefixed project).
  def self.prefix_for_code(code)
    match = code.to_s.match(/(^.+)[ -]\d+$/)
    match && match[1]
  end

  # Find an existing field slip by code, or create a new one.
  # Returns nil if the code is invalid (fails validation).
  def self.find_or_create_by_code(code, user)
    code = code.to_s.strip.upcase
    slip = find_by(code: code)
    return slip if slip

    slip = new
    slip.current_user = user
    # `code=` derives the project from the code prefix (e.g. "RINHS-00108"
    # -> the RINHS project); current_user is set first so that lookup can
    # check membership. This is what makes a lazily-created slip — one built
    # when an observation with a field_code is saved, rather than up front
    # in the field-slip form — still land in its project.
    slip.code = code
    slip.save ? slip : nil
  end

  scope :order_by_default,
        -> { order_by(::Query::FieldSlips.default_order) }

  scope :code, lambda { |codes|
    codes = [codes] unless codes.is_a?(Array)
    where(code: codes.map(&:upcase))
  }

  scope :code_has, lambda { |code_patterns|
    code_patterns = [code_patterns] unless code_patterns.is_a?(Array)
    sanitized = code_patterns.map do |pattern|
      sanitize_sql_like(pattern.upcase, "\\")
    end
    arel = arel_table
    upper_code = Arel::Nodes::NamedFunction.new("UPPER", [arel[:code]])
    predicates = sanitized.map { |pattern| upper_code.matches("%#{pattern}%") }
    where(predicates.reduce(:or))
  }

  scope :observation, lambda { |observation|
    observation_ids = Lookup::Observations.new(observation).ids
    joins(occurrence: :observations).
      where(observations: { id: observation_ids }).distinct
  }

  scope :project, lambda { |project|
    project_ids = Lookup::Projects.new(project).ids
    where(project: project_ids)
  }

  scope :projects, lambda { |projects|
    project_ids = Lookup::Projects.new(projects).ids
    where(project: project_ids).distinct
  }

  # Orphaned (no project) slips whose code begins with the given prefix.
  # A SQL pre-filter — callers must still confirm an exact prefix match
  # via prefix_for_code (LIKE "FOO%" also matches "FOOBAR-1").
  scope :orphaned_with_code_prefix, lambda { |prefix|
    where(project_id: nil).
      where("code LIKE ?", "#{sanitize_sql_like(prefix.to_s.upcase)}%")
  }

  # Eager-load trees for `FieldSlipPanel` / `Components::Matrix::Box`.
  # Reuses `Observation.matrix_box_includes` so the obs subtree
  # matches observations#index and collection_numbers#show.
  def self.show_includes_tree
    [{ occurrence: { observations: Observation.matrix_box_includes } }]
  end

  # Index style: the page renders one panel per slip and also
  # walks `occurrence.primary_observation`; the panel's `:project`
  # and `:user` lines need those preloaded too.
  def self.index_includes_tree
    [{ occurrence: [:primary_observation,
                    { observations: Observation.matrix_box_includes }] },
     :project, :user]
  end

  scope :show_includes, -> { includes(show_includes_tree) }
  scope :index_includes, -> { includes(index_includes_tree) }

  def current_user=(a_user)
    @current_user = a_user
    return if user

    self.user = a_user
  end

  def code=(val)
    code = val.upcase
    return unless self[:code] != code

    self[:code] = code
    update_project
  end

  # All observations through the occurrence.
  def observations
    occurrence&.observations || Observation.none
  end

  # Observation IDs through the occurrence.
  def observation_ids
    occurrence&.observation_ids || []
  end

  # The primary observation, used as the default reference.
  # Only returns observations that actually belong to the occurrence.
  def observation
    @observation ||= find_primary_observation
  end

  def find_primary_observation
    occ = occurrence
    return nil unless occ

    obs = observations.to_a
    return nil if obs.empty?

    primary = occ.primary_observation
    obs.include?(primary) ? primary : obs.first
  end

  def reload(*)
    @observation = nil
    super
  end

  # Adopt the observation's user if we don't already have one.
  # Call this after associating an observation with this field slip.
  def adopt_user_from(obs)
    return if user

    update(user: obs.user)
  end

  # The event this slip was printed for: its own project, or -- once a
  # spare-slip release has cleared that -- the project its printed
  # prefix names. Alias resolution and prompt building key off the
  # event, which is a fact of the printed slip, not of current project
  # membership.
  def event_project
    return project if project

    prefix = FieldSlip.prefix_for_code(code)
    prefix && Project.find_by(field_slip_prefix: prefix)
  end

  def update_project
    prefix = self.class.prefix_for_code(code)
    return unless prefix

    # Needs to get updated when Projects can share a field_slip_prefix
    candidate = Project.find_by(field_slip_prefix: prefix)
    self.project = candidate if candidate&.can_add_field_slip?(@current_user)
  end

  def project=(project)
    return unless project != self.project

    self[:project_id] = if project&.can_add_field_slip?(@current_user)
                          project.id
                        end
  end

  def title
    code
  end

  def projects
    @projects ||= find_projects
  end

  def find_projects
    result = Project.includes(:project_members).where(
      project_members: { user: @current_user }
    ).order(:title).pluck(:title, :id)
    if project && result.exclude?([project.title, project.id])
      result.unshift([project.title, project.id])
    end
    result.unshift([:field_slip_nil_project.t, nil])
  end

  # Used by Mycoportal report
  TREES_SHRUBS = :"Trees/Shrubs"

  # The standard headings printed on a field slip, in slip order. The
  # observation form injects these too whenever a field code is in play,
  # so a slip's data has somewhere to go there (#4932).
  # Should we figure out a way to internationalize these tags?
  NOTE_HEADINGS = [:"Odor/Taste", TREES_SHRUBS, :Substrate, :Habit,
                   :Other].freeze

  def notes_fields
    NOTE_HEADINGS.map do |field|
      NoteField.new(name: field, value: field_value(field))
    end
  end

  def field_value(field)
    obs = observation
    return "" unless obs

    obs.notes[field] || ""
  end

  def location
    @location ||= calc_location
  end

  def location_name
    location&.display_name
  end

  def location_id
    location&.id
  end

  # Default location, strongest signal first: this slip's own
  # observation, then the user's latest slip in this project, then the
  # project location, then their latest located observation. The
  # project outranks the observation because a user traveling to a
  # foray likely hasn't entered anything located at the foray site
  # yet, while the project location should contain it (issue #4907).
  def calc_location
    observation&.location || users_last_location ||
      project&.location || users_last_observation_location
  end

  # Location of the user's most recently updated field slip in this
  # project that has a located observation (slips without one are
  # skipped). Requires a project: a nil here would match every
  # project-less slip the user owns -- an orphaned-spares bucket, not
  # an event cohort -- and resurrect whatever location a batch job
  # last touched (a fresh "2026-NAMA-0001" slip once defaulted to a
  # year-old spare's site this way).
  def users_last_location
    return nil unless @current_user && project

    Location.joins(observations: { occurrence: :field_slip }).
      where(field_slips: { user_id: @current_user.id,
                           project_id: project.id }).
      order(FieldSlip.arel_table[:updated_at].desc,
            FieldSlip.arel_table[:id].desc).first
  end

  def users_last_observation_location
    return nil unless @current_user

    @current_user.observations.where.not(location_id: nil).
      order(created_at: :desc, id: :desc).first&.location
  end

  # Plain collector string for the form's autocompleter input (the
  # observation's `collector` column, in "Name (login)" form). Display
  # views use Observation#collector_textile for markup/links. See #4211.
  def collector
    observation&.collector
  end

  def date
    observation&.when || created_at
  end

  def field_slip_name
    observation&.field_slip_name || @default_field_slip_name || ""
  end

  def field_slip_name=(value)
    @default_field_slip_name = value
  end

  def field_slip_id_by
    observation&.field_slip_id_by || ""
  end

  def other_codes
    observation&.other_codes || ""
  end

  # Leaving a project takes the observations out; joining one brings them
  # in.
  #
  # `Project#remove_observation` also clears a slip's project, but only
  # when the slip still points at *that* project, so the value we just
  # saved survives. It uses `update_all`, which skips callbacks, so this
  # can't re-enter.
  def cascade_project_change
    members = occurrence&.observations&.to_a
    return if members.blank?

    old_id, new_id = saved_change_to_project_id
    Project.find_by(id: old_id)&.remove_observation(members.first)
    join_project(Project.find_by(id: new_id), members)
  end

  # All or nothing. Adding only the members a project's constraints
  # accept would leave the slip claiming a project some of its own
  # observations aren't in — the exact gap this cascade exists to
  # prevent. A project that can't take every member is declined instead,
  # which leaves the slip project-less, and a project-less slip confers
  # nothing. `update_column` skips callbacks, so declining can't
  # re-enter this.
  def join_project(project, members)
    return unless project

    if members.any? { |obs| project.violates_constraints?(obs) }
      update_column(:project_id, nil)
      return
    end

    members.each { |obs| project.add_observation(obs) }
  end

  def can_edit?(editor)
    return false unless editor

    user.nil? || user == editor ||
      (project&.is_admin?(editor) && project.trusted_by?(user))
  end
end
