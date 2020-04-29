module Devise
  module Models
    module RevocableSession
      extend ActiveSupport::Concern

        included do
          has_many :revocable_sessions, dependent: :destroy,
            as: :resource, class_name: "Devise::RevocableSession"
        end

        def has_revocable_sessions?
          true
        end

         #session
        def activate_session(request)
          new_session = revocable_sessions.new(attrs_for_login(request))
          new_session.session_id = SecureRandom.hex(64)
          new_session.device_id  = SecureRandom.uuid
          new_session.signed_in_ip = request.remote_ip
          new_session.save
          purge_old_sessions
          new_session
        end

        def exclusive_session(session_id)
          revocable_sessions.where('session_id != ?', session_id).delete_all
        end

        def session_active?(device_id, session_id)
          revocable_sessions.where(device_id: device_id, session_id: session_id).exists?
        end

        def deactivate_session!(session_id)
          revocable_sessions.where(session_id: session_id).delete_all
        end

        def purge_old_sessions
          revocable_sessions.order(last_seen_at: :desc).offset(10).destroy_all
        end

        def mark_last_seen!(device_id)
          login_record = revocable_sessions.find_by(device_id: device_id)
          #skip second to reduce database hit
          if login_record.last_seen_at < 5.minutes.ago
            login_record.update_column :last_seen_at, Time.now
          end
        end

        protected

        def attrs_for_login(request)
          t = Time.now
          { user_agent: request.user_agent,
            last_seen_ip: request.remote_ip,
            signed_in_at: t,
            last_seen_at: t }
        end

    end
  end
end
