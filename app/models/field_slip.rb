# frozen_string_literal: true

# Attributes:
# code:    string, unique code for field slip, starts with project prefix

class FieldSlip < AbstractModel
  attr_accessor :current_user

  belongs_to :observation
  belongs_to :project
  belongs_to :user

  validates :code, uniqueness: true
  validates :code, presence: true
  validate do |field_slip|
    unless field_slip.code.match?(/[^\d.-]/)
      errors.add(:code, :format, message: :field_slip_code_format_error.t)
    end
  end

  scope :order_by_default,
        -> { order_by(::Query::FieldSlips.default_order) }

  scope :projects, lambda { |projects|
    project_ids = Lookup::Projects.new(projects).ids
    where(project: project_ids).distinct
  }

  def code=(val)
    code = val.upcase
    return unless self[:code] != code

    self[:code] = code
    update_project
  end

  def update_project
    prefix_match = code.match(/(^.+)[ -]\d+$/)
    return unless prefix_match

    # Needs to get updated when Projects can share a field_slip_prefix
    candidate = Project.find_by(field_slip_prefix: prefix_match[1])
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
    return "" unless observation

    observation.notes[field] || ""
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

  def can_edit?(current_user)
    user.nil? || user == current_user ||
      (project&.is_admin?(current_user) && project.trusted_by?(user))
  end
end
