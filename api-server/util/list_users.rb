require 'rubygems'
require 'bundler/setup'

require './lib/cescre-admin.rb'

admin = CESCRE::Admin.new
user_keys = admin.list_users_brute

user_keys.each do |k|
    puts(k)
end
puts("number of users = #{user_keys.length}")