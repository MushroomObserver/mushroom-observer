# frozen_string_literal: true

# Action template for `HerbariumRecordsController#edit`. Wraps
# the existing `Form` Phlex component with page chrome + a
# side-column list of MatrixBox previews (one per associated obs).
module Views::Controllers::HerbariumRecords
  class Edit < Views::FullPageBase
    prop :herbarium_record, ::HerbariumRecord
    prop :user, ::User
    prop :back, _Nilable(String), default: nil
    prop :back_object, _Nilable(::AbstractModel), default: nil

    def view_template
      container_class(:wide)
      add_edit_title(@herbarium_record)
      add_context_nav(
        Tab::HerbariumRecord::FormEdit.new(
          back: @back, back_object: @back_object, q_param: q_param
        )
      )

      Row do
        div(class: Grid::SM7) { render_form }
        div(class: Grid::SM5) { render_observation_boxes }
      end
    end

    private

    def render_form
      render(Form.new(@herbarium_record, back: @back))
    end

    def render_observation_boxes
      Row(element: :ul, class: "list-unstyled") do
        @herbarium_record.observations.each do |obs|
          render(Components::Matrix::Box.new(
                   user: @user,
                   object: obs.rss_log || obs,
                   columns: Grid::FULL
                 ))
        end
      end
    end
  end
end
