# helpers for add Sequence view
module SequenceHelper
  # title for add_sequence page, e.g.:
	#   Add Sequence to Observation 123456
	#   Polyporus badius (Pers.) Schwein. (Consensus)
	#   Polyporus melanopus group (Observer Preference)
  def add_sequence_title(obs)
    capture do
      concat(:sequence_add_title.t)
      concat(" #{obs.id || "?"} ")
      concat(obs.name.format_name.t)
    end
  end
end
