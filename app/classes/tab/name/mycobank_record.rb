# frozen_string_literal: true

# MycoBank record-by-ID external-site link for a Name. Title is
# `[##{icn_id}]`; assumes `name.icn_id?`.
class Tab::Name::MycobankRecord < Tab::Name::ExternalBase
  MYCOBANK_HOST = "https://www.mycobank.org/"

  def title
    "[##{@name.icn_id}]"
  end

  def alt_title
    :mycobank.t
  end

  def path
    "#{MYCOBANK_HOST}MB/#{@name.icn_id}"
  end
end
