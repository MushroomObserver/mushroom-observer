# frozen_string_literal: true

# "All names" index link. No model — auto-derived selector class is
# the plain title-derived `<…>_link`; matches the original
# `names_index_tab` shape exactly.
class Tab::Name::Index < Tab::Base
  def title
    :all_objects.t(type: :name)
  end

  def path
    names_path
  end
end
