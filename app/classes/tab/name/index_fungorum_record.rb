# frozen_string_literal: true

# Index Fungorum record-by-ID external-site link for a Name.
# Title is `[##{icn_id}]`; assumes `name.icn_id?` (the nomenclature
# panel gates calling this).
class Tab::Name::IndexFungorumRecord < Tab::Name::ExternalBase
  def title
    "[##{@name.icn_id}]"
  end

  def alt_title
    "index_fungorum_record"
  end

  def path
    "http://www.indexfungorum.org/Names/NamesRecord.asp" \
      "?RecordID=#{@name.icn_id}"
  end
end
