# frozen_string_literal: true

module Views::Controllers::Sequences
  # Sequence-create page.
  class New < Views::Base
    prop :sequence, ::Sequence
    prop :observation, ::Observation

    def view_template
      container_class(:full)
      add_new_title(:add_object, :SEQUENCE)
      add_context_nav(::Tab::Sequence::Form.new(back_object: @observation))

      div(class: "row") do
        div(class: "col-xs-12 col-sm-7") { render_form_column }
        div(class: "col-xs-12 col-sm-5") { render_matrix_column }
      end
    end

    private

    def render_form_column
      render(ObservationTitle.new(observation: @observation))
      render(Form.new(@sequence, observation: @observation))
    end

    def render_matrix_column
      ul(class: "row list-unstyled") do
        render(::Components::MatrixBox.new(
                 user: current_user,
                 object: @observation.rss_log || @observation,
                 columns: "col-xs-12"
               ))
      end
    end
  end
end
