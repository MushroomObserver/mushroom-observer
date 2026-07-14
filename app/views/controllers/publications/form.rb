# frozen_string_literal: true

module Views::Controllers::Publications
  # Form for creating/editing publications. Rendered directly by the
  # publications controller's `new.rb` and `edit.rb`.
  class Form < ::Components::ApplicationForm
    def view_template
      render_full_field
      render_link_field
      render_peer_reviewed_field
      render_how_helped_field
      render_mo_mentioned_field
      submit(submit_text, center: true)
    end

    private

    # Automatically determine action URL based on whether record is
    # persisted.
    def form_action
      return publications_path if model.nil? || !model.persisted?

      publication_path(model)
    end

    def render_full_field
      textarea_field(:full, rows: 10, label: :publication_full,
                            wrap_class: "mt-3") do |f|
        f.with_between do
          Help(element: :span, content: :publication_full_help.t)
        end
      end
    end

    def render_link_field
      text_field(:link, label: :publication_link)
    end

    def render_peer_reviewed_field
      checkbox_field(:peer_reviewed, label: :publication_peer_reviewed)
    end

    def render_how_helped_field
      textarea_field(:how_helped, rows: 10,
                                  label: :publication_how_helped)
    end

    def render_mo_mentioned_field
      checkbox_field(:mo_mentioned, label: :publication_mo_mentioned)
    end

    def submit_text
      @model.persisted? ? :SAVE.t : :CREATE.t
    end
  end
end
