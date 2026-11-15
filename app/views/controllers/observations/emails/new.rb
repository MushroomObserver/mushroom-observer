# frozen_string_literal: true

# Action template for `Observations::EmailsController#new` — the
# "ask the observer a question" page. Sets the page title and
# renders `Emails::Form` (the observer-question form).
module Views::Controllers::Observations::Emails
  class New < Views::FullPageBase
    prop :observation, ::Observation

    def view_template
      add_title_with_name(:ask_observation_question_title, name: @observation)

      render(Form.new(observation: @observation))
    end
  end
end
