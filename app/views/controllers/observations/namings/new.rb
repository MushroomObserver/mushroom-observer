# frozen_string_literal: true

# Phlex view for the "propose a name" page on an observation. Two
# columns: a left column with the observation details + the naming
# form, and a right column with the observation's images.
module Views::Controllers::Observations::Namings
  class New < Views::FullPageBase
    # rubocop:disable Metrics/ParameterLists
    # Forwards every prop the Form component needs — `observation`
    # for chrome (title + context-nav + observation_details +
    # images), the rest for the Form itself. Not a candidate for
    # the parameter-list refactor lever; this is the form's data.
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
      div(class: "row") do
        div(class: Grid::SM8) do
          div(class: "mt-3") { render_observation_details }
          div(class: "mt-3") { render_naming_form }
        end
        div(class: Grid::SM4) { render_images }
      end
    end

    private

    def add_chrome
      container_class(:double)
      add_page_title(:create_naming_title.t(id: @observation.id))
      add_context_nav(Tab::Observation::NamingForm.new(
                        observation: @observation
                      ))
    end

    def render_observation_details
      render(Views::Controllers::Observations::Show::Details.new(
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
