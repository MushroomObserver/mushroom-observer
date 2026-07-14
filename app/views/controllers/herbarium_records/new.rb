# frozen_string_literal: true

# Action template for `HerbariumRecordsController#new`. Wraps
# the existing `Form` Phlex component with page chrome + the
# observation header + a side-column MatrixBox preview.
module Views::Controllers::HerbariumRecords
  class New < Views::FullPageBase
    prop :herbarium_record, ::HerbariumRecord
    prop :observation, ::Observation
    prop :user, ::User

    def view_template
      container_class(:full)
      add_new_title(:add_object, :HERBARIUM_RECORD)
      add_context_nav(
        Tab::HerbariumRecord::FormNew.new(
          observation: @observation, q_param: q_param
        )
      )

      Row do
        div(class: Grid::SM7) { render_form_column }
        div(class: Grid::SM5) { render_observation_box }
      end
    end

    private

    def render_form_column
      span(class: "text-larger mb-3") do
        trusted_html(:Observation.t)
        plain(" ##{@observation.id}")
      end
      render(Form.new(@herbarium_record, observation: @observation))
    end

    def render_observation_box
      Row(element: :ul, class: "list-unstyled") do
        render(Components::Matrix::Box.new(
                 user: @user,
                 object: @observation.rss_log || @observation,
                 columns: Grid::FULL
               ))
      end
    end
  end
end
