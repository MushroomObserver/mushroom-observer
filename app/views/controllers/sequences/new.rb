# frozen_string_literal: true

module Views::Controllers::Sequences
  # Sequence-create page.
  class New < Views::FullPageBase
    prop :sequence, ::Sequence
    prop :observation, ::Observation

    def view_template
      container_class(:full)
      add_new_title(:add_object, :SEQUENCE)
      add_context_nav(::Tab::Sequence::Form.new(back_object: @observation))

      Row do
        div(class: Grid::SM7) { render_form_column }
        div(class: Grid::SM5) { render_matrix_column }
      end
    end

    private

    def render_form_column
      render(ObservationTitle.new(observation: @observation))
      render(Form.new(@sequence, observation: @observation))
    end

    def render_matrix_column
      Row(element: :ul, class: "list-unstyled") do
        render(::Components::Matrix::Box.new(
                 user: current_user,
                 object: @observation.rss_log || @observation,
                 columns: Grid::FULL
               ))
      end
    end
  end
end
