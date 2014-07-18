require 'rubygems'
require 'bundler/setup'

require 'json'
require 'redis'
require 'uuidtools'
require 'bcrypt'

require './config.rb'

#TODO: have CESCRE.Core and CESCRE.Auth use the same redis object

module CESCRE
    class Auth
        @@ssl_enabled = CESCRE::CONFIG[:ssl][:enabled]
        @@ssl_x509_path = CESCRE::CONFIG[:ssl][:certificate]
        @@ssl_rsa_path = CESCRE::CONFIG[:ssl][:key]
        @@cookie = 'cescre_session'
        @@user_cookie = 'username'
        @@token_cookie = 'sessionToken'

        @@TOKEN_TTL = 7 * 24 * 60 * 60
        @@PASSWORD_FIELD = 'password'
        @@EMAIL_FIELD = 'email'
        @@SESSION_TOKEN_FIELD = 'sessionToken'

        def Auth.SSL_ENABLED
            @@ssl_enabled
        end

        def Auth.SSL_X509_PATH
            @@ssl_x509_path
        end

        def Auth.SSL_RSA_PATH
            @@ssl_rsa_path
        end

        def Auth.USER_COOKIE
            @@user_cookie
        end

        def Auth.TOKEN_COOKIE
            @@token_cookie
        end

        def Auth.COOKIE
            @@cookie
        end

        # Determines if a username is valid; valid usernames can contain
        # alpha-numeric characters, periods, dashes, and underscores; length
        # must be between 1 and 256 characters
        #
        # @param [String] username
        # @return [Boolean] whether or not the username is valid
        def Auth.valid_username?(username)
            if username =~ /^[a-zA-Z0-9\.\-\_]+$/ and username.length <= 256 then
                return true
            end
            return false
        end

        # Determines if a password is valid; valid passwords require a length
        # between 8 and 256 characters
        #
        # @param [String] plain-text password
        # @return [Boolean] whether or not the password is valid
        def Auth.valid_password?(password)
            if password.length >= 8 and password.length <= 256 then
                return true
            end
            return false
        end

        # Returns a hash key for a user's general profile information
        #
        # @param [String] username
        # @return [String] the hash key
        def Auth.get_user_key(username)
            return "/users/#{username}"
        end

        # Returns the hash key for a user's current session token
        #
        # @param [String] username
        # @return [String] the hash key
        def Auth.get_user_token_key(username)
            return "/users/#{username}/session"
        end

        # Returns the hash key that stores the list of all user keys (stored as
        # a redis set)
        #
        # @return [String] the hash key
        def Auth.get_user_list_key
            return "/users"
        end

        def initialize
            @redis = Redis.new
        end

        # Creates a new user account (if one doesn't already exist)
        #
        # @param [String] username
        # @param [String] plain-text password
        # @param [String] email address
        # @return [Boolean] whether or not a new account was created
        def create_user(username, password, email)
            if !user_exists?(username) and Auth.valid_username?(username) and Auth.valid_password?(password) then
                user_key = Auth.get_user_key(username)
                secret = BCrypt::Password.create(password)
                status = @redis.hmset(user_key, @@PASSWORD_FIELD, secret.to_s, @@EMAIL_FIELD, email)

                if !@redis.sadd(Auth.get_user_list_key, user_key) then
                    $stderr.puts("WARNING: user profile #{user_key} not added to user list")
                end

                return (status == 'OK')
            end
            return false
        end

        # Checks a username/password pair and returns a session token
        # if successful
        #
        # @param [String] username
        # @param [String] plain-text password
        # @return [String] session token on success, nil on failure
        def login(username, password)
            key = Auth.get_user_key(username)
            user_data = user_exists?(username)
            if !user_data then
                return nil
            end
            
            secret = BCrypt::Password.new(user_data['password'])
            if secret != password then
                return nil
            end

            return touch_token(username)
        end

        # Same as authenticate_token(username, token) except that it pulls
        # the credentials from a JSON map
        #
        # @param [String] JSON blob containing the username and session token
        # @return [String] username if successful, otherwise nil
        def authenticate_token_json(blob)
            begin
                data = JSON.parse(blob)
                puts(data)
                if data['username'] and data['sessionToken'] then
                    return authenticate_token(data['username'], data['sessionToken'])
                end
            rescue JSON::ParserError
                return nil
            rescue TypeError
                return nil
            end
            return nil
        end

        # Checks if a username/token pair is valid and resets session token
        # expiration if successful
        #
        # @param [String] username
        # @param [String] session token
        # @return [String] username if successful, otherwise nil
        def authenticate_token(username, token)
            secret = get_token(username)
            if token == secret then
                touch_token(username)
                return username
            end
            return nil
        end

        def user_info(username)
            data = user_exists?(username)
            data.delete(@@PASSWORD_FIELD)
            return data
        end

        def clear_token(username)
            if username then
                key = Auth.get_user_token_key(username)
                @redis.del(key)
            end
        end

        private
        @@TYPE_ERROR_STRING = 'ERR Operation against a key holding the wrong kind of value'

        # Gets the current session token out of the database
        #
        # @param [String] username
        # @return [String] session token on success, nil on failure
        def get_token(username)
            key = Auth.get_user_token_key(username)
            begin
                return @redis.get(key)
            rescue Redis::CommandError => err
                if err.to_s == @@TYPE_ERROR_STRING then
                    $stderr.puts("WARNING: user token #{key} is not expected type string")
                else
                    raise
                end
            end
            return nil
        end

        # Updates the expiration on a session token or creates a new token if
        # one does not already exist
        #
        # @param [String] username
        # @return [String] session token
        def touch_token(username)
            key = Auth.get_user_token_key(username)
            token = UUIDTools::UUID.random_create.to_s
            success = @redis.setnx(key, token)
            @redis.expire(key, @@TOKEN_TTL)
            if !success then
                puts('token already exists')
                token = @redis.get(key)
            else
                puts('token does not exist')
            end
            return token
        end

        # Checks if a user exists in the database
        #
        # @param [String] username
        # @return [Map] user profile fields on success, nil on failure
        def user_exists?(username)
            key = Auth.get_user_key(username)
            begin
                data = @redis.hgetall(key)
                if data[@@PASSWORD_FIELD] and data[@@EMAIL_FIELD] then
                    return data
                end
                if !data[@@PASSWORD_FIELD] then
                    $stderr.puts("WARNING: user profile #{key} does not have a password")
                end
                if !data[@@EMAIL_FIELD] then
                    $stderr.puts("WARNING: user profile #{key} does not have an email address")
                end
            rescue Redis::CommandError => err
                if err.to_s == @@TYPE_ERROR_STRING then
                    $stderr.puts("WARNING: user token #{key} is not expected type hash")
                else
                    raise
                end
            end
            return nil
        end
    end
end