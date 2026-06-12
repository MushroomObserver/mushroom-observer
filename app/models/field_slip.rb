# frozen_string_literal: true

# Attributes:
# code:    string, unique code for field slip, starts with project prefix

class FieldSlip < AbstractModel
  attr_reader :current_user

  has_one :occurrence, dependent: :nullify
  belongs_to :project
  belongs_to :user

  validates :user_id, presence: true
  validates :code, uniqueness: true
  validates :code, presence: true
  validate do |field_slip|
    unless field_slip.code.match?(/[^\d.-]/)
      errors.add(:code, :format, message: :field_slip_code_format_error.t)
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

  # Eager-load trees for `FieldSlipPanel` / `Components::MatrixBox`.
  # Reuses `Observation.matrix_box_includes` so the obs subtree
  # matches observations#index and collection_numbers#show.
  def self.show_includes_tree
    [{ occurrence: { observations: Observation.matrix_box_includes } }]
  end

  # Index variant: the page renders one panel per slip and also
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

  def notes_fields
    # Should we figure out a way to internationalize these tags?
    [:"Odor/Taste", TREES_SHRUBS, :Substrate, :Habit, :Other].map do |field|
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

  def calc_location
    result = observation&.location || users_last_location
    return result if result

    project&.location
  end

  def users_last_location
    user = @current_user
    return nil unless user

    field_slip = user.field_slips.where(project:).
                 order(updated_at: :desc).last
    obs = field_slip&.observation
    obs&.location
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

  def can_edit?(editor)
    return false unless editor

    user.nil? || user == editor ||
      (project&.is_admin?(editor) && project.trusted_by?(user))
  end
end
