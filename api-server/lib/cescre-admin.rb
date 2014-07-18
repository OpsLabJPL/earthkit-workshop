require 'rubygems'
require 'bundler/setup'

require './lib/cescre-auth.rb'
require 'json'
require 'redis'
require 'uuidtools'
require 'bcrypt'

module CESCRE
    class Admin
        def initialize
            @redis = Redis.new
        end

        def delete_user(username)
            user_key = CESCRE::Auth.get_user_key(username)
            return @redis.del(user_key)
        end

        def list_users
            key = CESCRE::Auth.get_user_list_key
            return @redis.smembers(key)
        end

        def list_users_brute
            raw_list = @redis.keys('/users/*')
            raw_list.each do |k|
                if !(k =~ /^\/users\/[a-zA-Z0-9\.\-\_]+$/) then
                    raw_list.delete(k)
                end
            end
            return raw_list
        end
    end
end
