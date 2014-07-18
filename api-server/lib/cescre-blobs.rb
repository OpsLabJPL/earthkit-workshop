require 'rubygems'
require 'bundler/setup'

require 'json'

module CESCRE
    class Blobs
        @@TYPE_FIELD = 'type'
        @@VERSION_FIELD = 'version'

        @@ERROR_TYPE = 'cescre-error'
        @@ERROR_VER = 1.0

        @@SESSION_TOKEN_TYPE = 'cescre-session-token'
        @@SESSION_TOKEN_VER = 1.0

        @@USER_INFO_TYPE = 'cescre-user-info'
        @@USER_INFO_VER = 1.0

        @@ERROR_FIELD = 'error'        
        @@SESSION_TOKEN_FIELD = 'sessionToken'
        @@USERNAME_FIELD = 'username'
        @@EMAIL_FIELD = 'email'
        @@FIRST_NAME_FIELD = 'firstName'
        @@LAST_NAME_FIELD = 'lastName'
        @@INSTITUTION_FIELD = 'institution'

        def Blobs.error(message)
            return {
                @@TYPE_FIELD => @@ERROR_TYPE,
                @@VERSION_FIELD => @@ERROR_VER,
                @@ERROR_FIELD => message
            }.to_json
        end

        def Blobs.session_token(username, token)
            return {
                @@TYPE_FIELD => @@SESSION_TOKEN_TYPE,
                @@VERSION_FIELD => @@SESSION_TOKEN_VER,
                @@USERNAME_FIELD => username,
                @@SESSION_TOKEN_FIELD => token
            }.to_json
        end

        def Blobs.user_info(username, email)
            return {
                @@TYPE_FIELD => @@USER_INFO_TYPE,
                @@VERSION_FIELD => @@USER_INFO_VER,
                @@USERNAME_FIELD => username,
                @@EMAIL_FIELD => email
            }.to_json
        end
    end
end
