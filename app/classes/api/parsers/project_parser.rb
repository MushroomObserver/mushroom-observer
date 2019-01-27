class API
  module Parsers
    # Parse projects for API.
    class ProjectParser < ObjectBase
      def model
        Project
      end

      def try_finding_by_string(str)
        Project.find_by_title(str)
      end

      def parse(str)
        val = super
        check_if_admin!(val)  if args[:must_be_admin]
        check_if_member!(val) if args[:must_be_member]
        val
      end

      def check_if_admin!(proj)
        return if api.user.projects_admin.include?(proj)

        raise MustBeAdmin.new(proj)
      end

      def check_if_member!(proj)
        return if api.user.projects_member.include?(proj)

        raise MustBeMember.new(proj)
      end
    end
  end
end
