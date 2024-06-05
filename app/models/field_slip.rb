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
    self[:code] = val.upcase
    return if project

    prefix_match = code.match(/(^.+)[ -]\d+$/)
    return unless prefix_match

    self.project = Project.find_by(field_slip_prefix: prefix_match[1])
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
    ["Odor/Taste", "Substrate", "Plants", "Habit", "Other"].map do |field|
      NoteField.new(name: field)
    end
  end

  def location
    return "" unless observation

    return observation.place_name
  end

  def collector
    return "" unless observation

    observation.collector
  end

  def field_slip_id
    return "" unless observation

    observation.field_slip_id
  end

  def field_slip_id_by
    return "" unless observation

    observation.field_slip_id_by
  end
end
