# frozen_string_literal: true

# Helpers for user view
module UserStatsHelper
  # Rows are roughly in decreasing order of importance.
  def user_stats_rows(user_stats)
    rows = []
    return rows unless user_stats

    UserStats.fields_with_weight.each_key do |field|
      rows << {
        field: field,
        label: :"user_stats_#{field}".t,
        count: (count = user_stats[field].to_i),
        weight: (weight = UserStats::ALL_FIELDS[field][:weight]),
        points: count * weight
      }
    end

    # Show a breakdown of translations
    if user_stats[:languages]
      lang_name_by_locale = Language.pluck(:locale, :name).to_h
      user_stats[:languages].each do |locale, count|
        rows << {
          label: tag.span(lang_name_by_locale[locale], class: "ml-3"),
          count: count
        }
      end
    end

    # Add bonuses at the bottom.
    user_stats&.bonuses&.each do |points, reason|
      rows << {
        label: reason.to_s.t,
        points: points.to_i
      }
    end

    rows
  end

  # NOTE: This just helps create a keyed hash to access the paths.
  def user_stats_link_paths(user)
    user_stats_links_table(user).each_with_object({}) do |row, links|
      links[row[0]] = row[1]
    end
  end

  #########################################################

  private

  def user_stats_links_table(user)
    [
      [:comments, comments_path(by_user: user.id)],
      [:comments_for, comments_path(for_user: user.id)],
      [:images, images_path(by_user: user.id)],
      [:location_description_authors,
       location_descriptions_path(by_author: user.id)],
      [:location_description_editors,
       location_descriptions_path(by_editor: user.id)],
      [:locations, locations_path(by_user: user.id)],
      [:location_versions, locations_path(by_editor: user.id)],
      [:name_description_authors,
       name_descriptions_path(by_author: user.id)],
      [:name_description_editors,
       name_descriptions_path(by_editor: user.id)],
      [:names, names_path(by_user: user.id)],
      [:name_versions, names_path(by_editor: user.id)],
      [:observations, observations_path(user: user.id)],
      [:species_lists, species_lists_path(by_user: user.id)],
      [:life_list, checklist_path(id: user.id)]
    ]
  end
end
