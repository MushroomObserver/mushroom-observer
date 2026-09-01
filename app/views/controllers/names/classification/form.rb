# frozen_string_literal: true

# Form for editing a Name's classification. Rendered by
# `Names::ClassificationController#edit`.
module Views::Controllers::Names::Classification
  class Form < ::Components::ApplicationForm
    def view_template
      textarea_field(:classification, label: :form_names_classification,
                                      rows: 10,
                                      help_placement: :above,
                                      data: { autofocus: true }) do |f|
        f.with_help { classification_help }
      end

      submit(:save.ti, center: true)
    end

    private

    def classification_help
      rank = :"rank_#{model.rank.to_s.downcase}".l
      trusted_html(:form_names_classification_help.t(rank: rank))
    end

    def form_action
      classification_of_name_path(model.id)
    end
  end
end
