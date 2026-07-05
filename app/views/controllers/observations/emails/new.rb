# frozen_string_literal: true

# Action template for `Observations::EmailsController#new` — the
# "ask the observer a question" page. Sets the page title and
# renders `Emails::Form` (the observer-question form).
module Views::Controllers::Observations::Emails
  class New < Views::FullPageBase
    prop :observation, ::Observation

    def view_template
      add_page_title(
        :ask_observation_question_title.t(
          name: viewer_aware_unique_format_name(@observation)
        )
      )

      render(Form.new(observation: @observation, local: true))
    end
  end
end
