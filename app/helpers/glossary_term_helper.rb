# frozen_string_literal: true

# View Helpers for Glossary
module GlossaryTermHelper
  def destroy_button(term)
    button_to(
      :destroy_glossary_term.t,
      { action: "destroy", id: term.id },
      method: :delete, data: { confirm: "Are you sure?" }
    )
  end
end
