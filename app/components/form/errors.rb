# frozen_string_literal: true

# Shared "N errors prohibited this X from being saved" alert. Replaces
# 4 near-duplicated `render_errors`-family methods that had
# independently diverged across field_slips/visual_groups/
# visual_models/projects::aliases forms (#4901) -- consolidating
# display first, before any model validators switch to deferred tag
# resolution, so there's exactly one place to update instead of
# several in lockstep with every model PR.
class Components::Form::Errors < Components::Base
  prop :model, ::AbstractModel

  def view_template
    return unless @model.errors.any?

    Alert(level: :danger, id: "error_explanation") do
      h2 { error_count_message }
      ul do
        @model.errors.each { |error| li { error.full_message } }
      end
    end
  end

  private

  def error_count_message
    count = @model.errors.count
    word = pluralize_tag(:error, count).t
    append_colon(
      "#{count} #{word} #{:errors_prohibited_save.t(type: @model.type_tag.ti)}"
    )
  end
end
