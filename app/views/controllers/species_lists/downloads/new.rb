# frozen_string_literal: true

# Phlex view for the species-list downloads page. Renders three
# sibling forms — print-labels (`Form`), text-report (`ReportForm`),
# and the shared observations-download form
# (`Views::Controllers::Observations::Downloads::Form`).
module Views::Controllers::SpeciesLists::Downloads
  class New < Views::Base
    def initialize(list:, query:, type:, format:, encoding:)
      super()
      @list = list
      @query = query
      @type = type
      @format = format
      @encoding = encoding
    end

    def view_template
      add_page_title(:species_list_download_title.t)
      add_context_nav(Tab::Object::Return.new(object: @list))

      query_param = q_param(@query)

      render(Form.new(query_param: query_param))
      render(ReportForm.new(
               list: @list,
               query_param: query_param,
               selected: @type
             ))
      render(Views::Controllers::Observations::Downloads::Form.new(
               query_param: query_param,
               format: @format,
               encoding: @encoding
             ))
    end
  end
end
