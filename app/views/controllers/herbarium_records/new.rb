# frozen_string_literal: true

# Action template for `HerbariumRecordsController#new`. Replaces
# `app/views/controllers/herbarium_records/new.html.erb`. Wraps
# the existing `Form` Phlex component with page chrome + the
# observation header + a side-column MatrixBox preview.
module Views::Controllers::HerbariumRecords
  class New < Views::Base
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

      div(class: "row") do
        div(class: "col-xs-12 col-sm-7") { render_form_column }
        div(class: "col-xs-12 col-sm-5") { render_observation_box }
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
      ul(class: "row list-unstyled") do
        render(Components::Matrix::Box.new(
                 user: @user,
                 object: @observation.rss_log || @observation,
                 columns: "col-xs-12"
               ))
      end
    end
  end
end
