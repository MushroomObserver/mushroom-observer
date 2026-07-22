# frozen_string_literal: true

# Names-search help block. Rendered by `Names::Search::Show` and
# (in a future Phlex conversion) by `Names::Search::New`'s search
# form footer. Pulls localized help text + the
# `PatternSearch::Name` term reference.
class Views::Controllers::Names::Search::Help < Views::Base
  def view_template
    p(class: "mt-3 font-weight-bold") do
      plain("#{:names.ti} #{:searches.ti}")
    end
    trusted_html(:pattern_search_terms_help.tp)
    trusted_html(::PatternSearch::Name.terms_help.tp)
  end
end
