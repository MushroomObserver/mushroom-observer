# frozen_string_literal: true

# Phlex view for the "edit a naming" page. Same layout as `New`
# with a different page title; renders the existing naming + vote
# back into the same Form component.
module Views::Controllers::Observations::Namings
  class Edit < Views::FullPageBase
    # rubocop:disable Metrics/ParameterLists
    # See sibling `New#initialize` for the same param-list rationale.
    def initialize(observation:, naming:, vote:, given_name:, reasons:,
                   user: nil, feedback: {})
      super()
      @observation = observation
      @user = user
      @naming = naming
      @vote = vote
      @given_name = given_name
      @reasons = reasons
      @feedback = feedback
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      add_chrome
      Row do
        Column(xs: 12, sm: 8) do
          div(class: "mt-3") do
            render_observation_details
            render_specimen_panel
          end
          div(class: "mt-3") { render_naming_form }
        end
        Column(xs: 12, sm: 4) { render_images }
      end
    end

    private

    def add_chrome
      container_class(:double)
      add_page_title(:edit_naming_title.t(id: @observation.id))
      add_context_nav(Tab::Observation::NamingForm.new(
                        observation: @observation
                      ))
    end

    def render_observation_details
      render(Views::Controllers::Observations::Show::ObservationDetailsPanel.new(
               obs: @observation, user: @user
             ))
    end

    def render_specimen_panel
      render(Views::Controllers::Observations::Show::SpecimenPanel.new(
               obs: @observation, user: @user
             ))
    end

    def render_naming_form
      render(Form.new(
               @naming,
               observation: @observation,
               vote: @vote,
               given_name: @given_name,
               reasons: @reasons,
               feedback: @feedback,
               show_reasons: true,
               local: true
             ))
    end

    def render_images
      render(Views::Controllers::Observations::Show::ImagesPanel.new(
               obs: @observation,
               images: @observation.images_sorted,
               user: @user
             ))
    end
  end
end
