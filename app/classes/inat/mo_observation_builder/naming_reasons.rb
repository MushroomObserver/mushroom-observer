# frozen_string_literal: true

class Inat
  class MoObservationBuilder
    # How the importer explains each naming it creates (the reasons[2] text):
    # Species Name Override (#4533), Provisional Species Name, an iNat
    # suggester, or the Observation Taxon. Mixed into MoObservationBuilder.
    module NamingReasons
      private

      # Each explanation applies only to its own naming; override wins (#4533).
      def used_references_explanation(name)
        if same_name?(name, override_name)
          :naming_inat_name_override.l.to_str
        elsif same_name?(name, prov_name)
          provisional_explanation
        elsif suggested?(name)
          suggester_with_date(name)
        else
          "#{:inat_observation_taxon.l} #{Time.zone.today.strftime("%Y-%m-%d")}"
        end
      end

      def same_name?(name, other)
        other && name.id == other.id
      end

      def provisional_explanation
        nom_prov_adder = inat_obs.inat_prov_name_field[:user][:login]
        # force String not SafeBuffer (it errors later). jdc 20241126
        :naming_inat_provisional.l(user: nom_prov_adder).to_str
      end
    end
  end
end
