# frozen_string_literal: true

# Form for creating/editing comments
class Components::CommentForm < Components::ApplicationForm
  def initialize(model, local: false, **)
    @local = local
    super(model, id: "comment_form", **)
  end

  def around_template
    # Set turbo data attribute only when not local
    unless @local
      @attributes[:data] ||= {}
      @attributes[:data][:turbo] = true
    end
    super
  end

  def view_template
    render_summary_field
    render_comment_field
    render_submit_button
  end

  private

  def form_action
    if @model.persisted?
      comment_path(id: @model.id)
    else
      comments_path(target: @model.target_id, type: @model.target_type)
    end
  end

  def render_summary_field
    text_field(:summary, label: "#{:form_comments_summary.t}:",
                         size: 80,
                         data: { autofocus: true })
  end

  def render_comment_field
    textarea_field(:comment, label: "#{:form_comments_comment.t}:",
                             rows: 10,
                             help: :shared_textile_help.l)
  end

  def render_submit_button
    submit(submit_text, center: true)
  end

  def submit_text
    @model.persisted? ? :SAVE_EDITS.l : :CREATE.l
  end
end
