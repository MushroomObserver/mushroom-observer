# frozen_string_literal: true

# Builds the row + path data that `Views::Controllers::Users::Show::UserStats`
# renders. Inlined from the now-deleted `UserStatsHelper` so the
# `Language.pluck(:locale, :name)` DB query lives on the controller side
# (per the project's "no AR queries in Phlex views" rule) and route-helper
# calls stay out of the view too.
module UsersController::UserStatsBuilder
  private

  def user_stats_rows(user_stats)
    return [] unless user_stats

    rows = UserStats.fields_with_weight.each_key.map do |field|
      weighted_field_row(field, user_stats[field].to_i)
    end
    rows << languages_summary_row(user_stats) if user_stats[:languages]
    user_stats.bonuses&.each do |points, reason|
      rows << { label: reason.to_s.t, points: points.to_i }
    end
    rows
  end

  def weighted_field_row(field, count)
    weight = UserStats::ALL_FIELDS[field][:weight]
    { field: field, label: :"user_stats_#{field}".t,
      count: count, weight: weight, points: count * weight }
  end

  def languages_summary_row(user_stats)
    lang_name_by_locale = Language.pluck(:locale, :name).to_h
    lang_summary = user_stats[:languages].map do |locale, count|
      view_context.tag.span(class: "ml-3 text-nowrap") do
        "[#{lang_name_by_locale[locale]}: #{count}]"
      end
    end
    { label: view_context.safe_join(lang_summary) }
  end
end
