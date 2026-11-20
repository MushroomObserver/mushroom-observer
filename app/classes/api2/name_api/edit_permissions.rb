# frozen_string_literal: true

class API2
  class NameAPI < ModelAPI
    # Checks run before an API user may edit a Name.
    module EditPermissions
      # Our restrictions on edit permissions for the API are much more strict
      # than on the website.  Revoke permission if anyone other than the
      # creator owns any attached objects: name versions, descriptions,
      # observations or name proposals.
      def must_have_edit_permission!(name)
        must_be_creator!(name)
        must_be_only_editor!(name)
        must_own_all_descriptions!(name)
        must_own_all_observations!(name)
        must_own_all_namings!(name)
      end

      private

      def must_be_creator!(name)
        return if name.user == @user

        raise(MustBeCreator.new(:name))
      end

      def must_be_only_editor!(name)
        return unless name.versions.any? { |x| x.user_id != @user.id }

        raise(MustBeOnlyEditor.new(:name))
      end

      def must_own_all_descriptions!(name)
        return unless name.descriptions.any? { |x| x.user != @user }

        raise(MustOwnAllDescriptions.new(:name))
      end

      def must_own_all_observations!(name)
        return unless name.observations.any? { |x| x.user != @user }

        raise(MustOwnAllObservations.new(:name))
      end

      def must_own_all_namings!(name)
        return unless name.namings.any? { |x| x.user != @user }

        raise(MustOwnAllNamings.new(:name))
      end

      # The website lets only admins change a locked Name's icn_id;
      # the API has no admin mode.
      def must_be_unlocked_to_set_icn_id!(name, params)
        return unless params.key?(:icn_id) && name.locked

        raise(NameLocked.new(name))
      end
    end
  end
end
