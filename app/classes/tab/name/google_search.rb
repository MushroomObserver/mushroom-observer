# frozen_string_literal: true

# Google web-search external-site link for a Name. For "Group"
# rank names, requires a quoted s.s. plus one of group/Clade/Complex
# for best results; otherwise just quoted s.s.
class Tab::Name::GoogleSearch < Tab::Name::ExternalBase
  def title
    :google_name_search.l
  end

  def path
    if @name.rank == "Group"
      "https://www.google.com/search?q=%2B%22#{@name.sensu_stricto}%22+" \
        "%28group+OR+Clade+OR+Complex%29&"
    else
      "https://www.google.com/search?q=%2B%22#{@name.sensu_stricto}%22"
    end
  end
end
