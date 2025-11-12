# frozen_string_literal: true

# Form for creating/editing publications
class Components::PublicationForm < Components::ApplicationForm
  def view_template
    render_full_field
    render_link_field
    render_peer_reviewed_field
    render_how_helped_field
    render_mo_mentioned_field
    render_submit_button
  end

  private

  def render_full_field
    textarea_field(
      :full,
      rows: 10,
      label: "#{:publication_full.t}:",
      between: render(Components::HelpNote.new(
                        element: :span,
                        content: :publication_full_help.t
                      ))
    )
  end

  def render_link_field
    text_field(:link, label: "#{:publication_link.t}:")
  end

  def render_peer_reviewed_field
    checkbox_field(:peer_reviewed, label: :publication_peer_reviewed.t)
  end

  def render_how_helped_field
    textarea_field(:how_helped, rows: 10,
                                label: "#{:publication_how_helped.t}:")
  end

  def render_mo_mentioned_field
    checkbox_field(:mo_mentioned, label: :publication_mo_mentioned.t)
  end

  def render_submit_button
    submit(submit_text, center: true)
  end

  def submit_text
    @model.persisted? ? :SAVE.t : :CREATE.t
  end
end
