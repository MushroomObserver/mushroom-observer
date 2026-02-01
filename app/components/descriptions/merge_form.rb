# frozen_string_literal: true

# Form for merging a description into another description of the same parent.
# Used for both NameDescription and LocationDescription.
class Components::Descriptions::MergeForm < Components::ApplicationForm
  def initialize(description, user:)
    @description = description
    @user = user
    super(FormObject::DescriptionMerge.new, id: "merge_descriptions_form")
  end

  def view_template
    h4 { "#{:merge_descriptions_merge_header.t}:" }
    p(class: "help-note") { :merge_descriptions_merge_help.t }

    div(class: "form-group") { render_merge_options }

    render_delete_checkbox if merges.any?
    render_submit if merges.any?
  end

  private

  def render_merge_options
    if merges.any?
      merges.each_with_index do |desc, idx|
        radio_field(:target, value: desc.id, label: description_title(desc),
                             checked: idx.zero? && default_checked?)
      end
    else
      p { :merge_descriptions_no_others.t }
    end
  end

  def render_delete_checkbox
    checkbox_field(:delete, label: :merge_descriptions_delete_after.t,
                            checked: @description.is_admin?(@user))
  end

  def render_submit
    submit(:SUBMIT.l, center: true)
  end

  def merges
    @merges ||= @description.parent.descriptions - [@description]
  end

  def moves
    @moves ||=
      begin
        result = @description.parent.synonyms - [@description.parent]
        result.reject!(&:is_misspelling?)
        result
      end
  end

  def default_checked?
    merges.length == 1 && moves.empty?
  end

  def description_title(desc)
    desc.partial_format_name
  end

  def name_description?
    @description.is_a?(NameDescription)
  end

  def form_action
    if name_description?
      url_for(controller: "/names/descriptions/merges", action: :create,
              id: @description.id, only_path: true)
    else
      url_for(controller: "/locations/descriptions/merges", action: :create,
              id: @description.id, only_path: true)
    end
  end

  def form_method
    :post
  end
end
