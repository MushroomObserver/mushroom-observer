# frozen_string_literal: true

# Attributes:
# code:    string, unique code for field slip, starts with project prefix

class FieldSlip < AbstractModel
  belongs_to :observation
  belongs_to :project
  belongs_to :user
  default_scope { order(:code) }

  validates :code, uniqueness: true
  validates :code, presence: true
  validate do |field_slip|
    unless field_slip.code.match?(/[^\d.-]/)
      errors.add(:code, :format, message: :field_slip_code_format_error.t)
    end
  end

  def code=(val)
    code = val.upcase
    return unless self[:code] != code

    self[:code] = code
    prefix_match = code.match(/(^.+)[ -]\d+$/)
    return unless prefix_match

    candidate = Project.find_by(field_slip_prefix: prefix_match[1])
    self.project = candidate if candidate&.can_add_field_slip(User.current)
  end

  def project=(project)
    return unless project != self.project

    self[:project_id] = if project&.can_add_field_slip(User.current)
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
      project_members: { user: User.current }
    ).order(:title).pluck(:title, :id)
    if project && result.exclude?([project.title, project.id])
      result.unshift([project.title, project.id])
    end
    result.unshift([:field_slip_nil_project.t, nil])
  end

  def notes_fields
    # Should we figure out a way to internationalize these tags?
    [:"Odor/Taste", :Substrate, :Plants, :Habit, :Other].map do |field|
      NoteField.new(name: field, value: field_value(field))
    end
  end

  def field_value(field)
    return "" unless observation

    observation.notes[field] || ""
  end

  def location
    observation&.place_name || ""
  end

  def collector
    observation.collector if observation&.collector

    "_user #{(user || User.current).login}_"
  end

  def field_slip_id
    observation&.field_slip_id || ""
  end

  def field_slip_id_by
    observation&.field_slip_id_by || ""
  end

  def other_codes
    observation&.other_codes || ""
  end

  def can_edit?
    user == User.current ||
      project&.is_admin?(User.current)
  end
end
