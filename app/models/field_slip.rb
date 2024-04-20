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
    return result unless project && result.exclude?([project.title, project.id])

    result.unshift([project.title, project.id])
  end
end
