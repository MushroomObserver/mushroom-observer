# frozen_string_literal: true

# Form for editing a Name's classification. Rendered by
# `Names::ClassificationController#edit`.
module Views::Controllers::Names::Classification
  class Form < ::Components::ApplicationForm
    def view_template
      textarea_field(:classification, label: :form_names_classification,
                                      rows: 10,
                                      between: classification_help,
                                      data: { autofocus: true })

      submit(:save.ti, center: true)
    end

    private

    def classification_help
      rank = :"rank_#{model.rank.to_s.downcase}".l
      Help(element: :p, content: :form_names_classification_help.t(rank: rank))
    end

    def form_action
      classification_of_name_path(model.id)
    end
  end
end
