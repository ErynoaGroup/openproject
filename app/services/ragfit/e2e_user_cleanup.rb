# frozen_string_literal: true

# RagFit patch 0004 (e2e-user-cleanup, 2026-10-13): delete end-to-end test users.
# GPLv3 §10 modification, see CHANGES-RAGFIT.md.
#
# Deletes only users whose login starts with a strict E2E prefix ("e2e-" or a longer prefix that starts
# with it, e.g. "e2e-plan-"). Refuses the whole run, deleting nothing, if any selected user is an admin,
# on the password-login bypass list, or does not match the prefix. Uses the upstream deletion
# (Principals::DeleteJob, run synchronously, after marking the user deleted like Users::DeleteService).
# Dry run by default. Logs and returns logins only. A failed deletion restores the user's status and
# stops the run with an error (rake exit code 1); a rerun is safe.
module Ragfit
  class E2eUserCleanup
    BASE_PREFIX = "e2e-"
    PREFIX_FORMAT = /\Ae2e-[a-z0-9-]*\z/

    Result = Struct.new(:selected, :deleted, :refused, :dry_run, :error, keyword_init: true) do
      def success? = error.nil?
    end

    attr_reader :prefix, :logins, :dry_run, :log

    # prefix: login prefix (default "e2e-"); logins: optional explicit list (each must match the prefix).
    def initialize(prefix: BASE_PREFIX, logins: nil, dry_run: true, log: ->(line) { Rails.logger.info(line) })
      @prefix = prefix.to_s.strip.downcase
      @logins = logins&.map { |l| l.to_s.strip }&.reject(&:empty?)
      @dry_run = dry_run
      @log = log
    end

    def self.from_env(prefix_arg, env: ENV, log: ->(line) { puts line })
      logins = env["RAGFIT_E2E_LOGINS"].to_s.split(",").map(&:strip).reject(&:empty?)
      new(prefix: prefix_arg.presence || BASE_PREFIX,
          logins: logins.presence,
          dry_run: env["DRY_RUN"].to_s != "0",
          log:)
    end

    def call
      return failure("refused: prefix must start with '#{BASE_PREFIX}' (only [a-z0-9-])") unless valid_prefix?

      if logins && (bad = logins.reject { |l| matches_prefix?(l) }).any?
        return failure("refused: logins outside prefix '#{prefix}': #{bad.join(', ')}")
      end

      users = selected_users.to_a
      refused = users.select { |u| protected?(u) }
      if refused.any?
        return failure("refused: protected users selected (admin or password-login bypass): " \
                       "#{refused.map(&:login).join(', ')}", selected: users, refused:)
      end

      users.each { |u| log.call("#{dry_run ? 'would delete' : 'deleting'}: #{u.login}") }
      deleted = []
      unless dry_run
        users.each do |user|
          error = delete(user)
          if error
            return failure("error: deleting #{user.login} failed (#{error}), status restored; " \
                           "#{deleted.size} user(s) deleted before. Fix the cause and run again.",
                           selected: users, deleted:)
          end
          deleted << user.login
        end
      end
      log.call("#{dry_run ? 'dry run' : 'done'}: #{users.size} user(s) with prefix '#{prefix}'" \
               "#{dry_run ? ' (set DRY_RUN=0 to delete)' : ''}")
      Result.new(selected: users.map(&:login), deleted:, refused: [], dry_run:, error: nil)
    end

    private

    # Principal's default scope hides users with status deleted; they are needed to finish and verify.
    def with_deleted
      User.unscope(where: :status)
    end

    def valid_prefix?
      prefix.match?(PREFIX_FORMAT)
    end

    def matches_prefix?(login)
      login.downcase.start_with?(prefix)
    end

    def selected_users
      # Users already marked deleted (e.g. an earlier run or a pending upstream deletion) are included,
      # so a rerun finishes them.
      scope = with_deleted.not_builtin
      scope = scope.where("LOWER(login) LIKE ?", "#{User.sanitize_sql_like(prefix)}%")
      scope = scope.where("LOWER(login) IN (?)", logins.map(&:downcase)) if logins
      scope.order(:login)
    end

    def protected?(user)
      user.admin? || ::Users::PasswordLogin.bypass?(user) || !matches_prefix?(user.login)
    end

    # Returns nil on success, otherwise a short error description. Principals::DeleteJob rolls back its
    # transaction silently on a failed reference replacement, so success is checked by the user being gone.
    # On failure the previous status is restored, so no user is left behind marked deleted.
    def delete(user)
      previous = user.status
      user.update_column(:status, User.statuses[:deleted])
      ::Principals::DeleteJob.perform_now(user)
      return nil unless with_deleted.exists?(user.id)

      restore_status(user, previous)
      "deletion rolled back"
    rescue StandardError => e
      restore_status(user, previous)
      e.class.name
    end

    def restore_status(user, previous)
      return if previous.nil? || !with_deleted.exists?(user.id)

      with_deleted.where(id: user.id).update_all(status: User.statuses[previous])
    end

    def failure(message, selected: [], refused: [], deleted: [])
      log.call(message)
      Result.new(selected: selected.map(&:login), deleted:, refused: refused.map(&:login), dry_run:,
                 error: message)
    end
  end
end
