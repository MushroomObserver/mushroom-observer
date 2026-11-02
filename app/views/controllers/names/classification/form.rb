# frozen_string_literal: true

# Form for editing a Name's classification. Rendered by
# `Names::ClassificationController#edit`. One plain-text field per
# rank above Genus (Domain down through Subtribe) -- no textile
# markup required from the user. The controller assembles the
# submitted fields into the stored "Rank: _Name_" lines.
module Views::Controllers::Names::Classification
  class Form < ::Components::ApplicationForm
    prop :name, ::Name

    def initialize(name, **)
      super(FormObject::NameClassification.new(**prefill(name)),
            name: name, id: "name_classification_form", **)
    end

    def view_template
      h4 { trusted_html(:form_names_classification.t) }
      p { trusted_html(classification_help) }

      FormObject::NameClassification::RANKS.each do |rank|
        render_rank_field(rank)
      end

      submit(:save.ti, center: true)
    end

    private

    def prefill(name)
      parsed = name.parse_classification.to_h
      FormObject::NameClassification::RANKS.to_h do |rank|
        [:"rank_#{rank.downcase}", parsed[rank]]
      end
    end

    def render_rank_field(rank)
      field_name = :"rank_#{rank.downcase}"
      text_field(field_name, label: rank_label(rank), inline: true,
                             wrap_class: "mb-1")
    end

    def rank_label(rank)
      :"rank_#{rank.downcase}".ti
    end

    def classification_help
      rank = :"rank_#{@name.rank.to_s.downcase}".l
      :form_names_classification_help.t(rank: rank)
    end

    def form_action
      classification_of_name_path(@name.id)
    end
  end
end
