# frozen_string_literal: true

# Action template for `Names::SearchController#new`. Renders the
# `Components::SearchForm` inside a wide container.
class Views::Controllers::Names::Search::New < Views::Base
  # `@search = Query.create_query(query_model, @query_params)` per
  # the `Searchable` concern — a `Query::Names` in this context.
  prop :search, _Nilable(::Query::Names), default: nil
  prop :local, _Boolean, default: true

  def view_template
    add_new_title(:search_object, :NAMES)
    container_class(:wide)

    div(id: "names_search_container") do
      render(Components::SearchForm.new(
               @search, search_controller: controller, local: @local
             ))
    end
  end
end
