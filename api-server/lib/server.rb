require './lib/cescre.rb'
require './lib/redis-sockets.rb'
require './lib/cescre-auth.rb'
require './lib/cescre-blobs.rb'
require './config.rb'
require 'thread'
require 'rubygems'
require 'bundler/setup'
# Bundler gems:
require 'sinatra'
# require 'sinatra/base'
require 'sinatra-websocket'
require 'yajl/json_gem'
require 'sinatra/cross_origin'
require 'openssl'

#TODO:  Error handling in general...

module Sinatra
	class Application
		def self.run!
			server_options = {
				:Host => bind,
				:Port => port
			}
			Rack::Handler::Thin.run(self, server_options) do |server|
				server.ssl = CESCRE::Auth.SSL_ENABLED
				server.ssl_options = {
					:cert_chain_file => CESCRE::Auth.SSL_X509_PATH,
					:private_key_file => CESCRE::Auth.SSL_RSA_PATH,
					:verify_peer => false
				}
				[:INT, :TERM].each { |sig| trap(sig) { server.stop } }
				server.threaded = settings.threaded if server.respond_to? :threaded=
				set :running, true
			end
		end
	end
end

# class CescreApiServer < Sinatra::Base
	configure do
		set :protection, :origin_whitelist => ['http://localhost:9000', 'https://localhost:9000', 'http://earthkit.jpl.net', 'https://earthkit.jpl.net']
		set :server, :thin
		set :sockets, RedisSockets.new(CESCRE::CONFIG[:redis])
		enable :cross_origin
		set :allow_origin, :any
		set :allow_methods, [:get, :post, :delete, :options]
	end

	before do
		content_type :json

		# short-circuit HTTP options requests made by browsers to test CORS
		if request.request_method == 'OPTIONS'
			puts "************ Options request from origin [#{env['HTTP_ORIGIN']}] referrer [#{request.referrer}]"
			request_origin = env['HTTP_ORIGIN']
			valid_origins = ['http://localhost:9000', 'https://localhost:9000', 'http://earthkit.jpl.net', 'https://earthkit.jpl.net']
			allowed_origin = '*'
			unless request_origin.nil?
				valid_origins.each do |o|
					if request_origin == o
						allowed_origin = o
						break
					end
				end
			end
		
			puts "************ Allowing origin = #{allowed_origin}"
			response.headers['Access-Control-Allow-Origin'] = allowed_origin
			response.headers['Access-Control-Allow-Methods'] = 'GET,POST,DELETE,OPTIONS'
			response.headers['Access-Control-Allow-Headers'] = '*,Content-Type,Accept,Authorization,Cache-Control'
			halt 200
		end

		# require username and session token for all paths except /session*
		unless request.path.start_with?('/session') then
			unless session_valid?(request.cookies[CESCRE::Auth.USER_COOKIE], request.cookies[CESCRE::Auth.TOKEN_COOKIE]) then
				halt(401, 'Invalid Session')
			end
		end
	end

	helpers do
		def user_channel(user)
			"/users/#{user}"
		end

		def login_only
			creds = authenticate()
			if creds then
				yield(creds[0], creds[1])
			else
				headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
				halt(401, CESCRE::Blobs.error('user/password combination does not exist'))
			end
		end

		def callback(user, path)
			channel = user_channel(user)
			proc = cescre.publish_proc(channel)
			Proc.new { |id| proc.call(path % id) }
		end

		def session_only(json_blob)
			username = auth.authenticate_token_json(json_blob)
			if username then
				yield(username)
			end
		end

		def session_only(username, token)
			if auth.authenticate_token(username, token) then
				yield(username)
			end
		end

		def session_valid?(username, token)
			return !auth.authenticate_token(username, token).nil?()
		end

		def authenticate
			@basic_auth ||= Rack::Auth::Basic::Request.new(request.env)
			if @basic_auth.provided? and @basic_auth.basic? and @basic_auth.credentials then
				session = auth.login(@basic_auth.username, @basic_auth.credentials[1])
				if session then
					return [@basic_auth.username, session]
				end
			end
			return nil
		end
	end # helpers

	def cescre
		@cescre ||= CESCRE::Core.new(CESCRE::CONFIG[:workshop], CESCRE::CONFIG[:ec2], Redis.new(CESCRE::CONFIG[:redis]))
	end

	def auth
		@auth ||= CESCRE::Auth.new
	end

	# --- Websockets ------

	get '/users/:user/socket' do |user|
		halt 404 unless request.websocket?
		channel = user_channel(user)
		request.websocket do |ws|
			ws.onopen do
				settings.sockets.attach(channel, ws)
				logger.warn("Socket [#{ws}] opened on channel: #{channel}")
			end
			ws.onclose do
				settings.sockets.detach(channel, ws)
				logger.warn("Socket [#{ws}] closed on channel: #{channel}")
			end
		end
	end

	# --- Instances ------

	get '/users/:user/instances' do |user|
		{ :instances => cescre.instances(user) }.to_json
	end

	post '/users/:user/instances' do |user|
		data = JSON::parse(request.body.read)
		# TODO:  Check arguments
		cescre.resume_or_create_instance(user, data['ami'], data['instance_type'], data['name'], data['volume_snapshots'], callback(user, "#{request.path}/%s"))
		# cescre.launch_instance user, data['ami'], data['instance_type'], data['name'], data['volume_snapshots'], callback(user, "#{request.path}/%s")
		'{}'
	end

	get '/users/:user/instances/:instance_id' do |user, instance_id|
		instance_obj = cescre.instance(user, instance_id)
		# Possiby just return empty object if not found.
		halt 404, "Instance '#{instance_id}' not found for user '#{user}'" unless instance_obj
		instance_obj.to_json
	end

	delete '/users/:user/instances/:instance_id' do |user, instance_id|
		cescre.stop_instance(user, instance_id, callback(user, "#{request.path}"))
		# cescre.terminate_instance user, instance_id, callback(user, "#{request.path}")
		'{}'
	end

	options '/users/:user/instances/:instance_id' do
		headers['Allow'] = 'OPTIONS, GET, DELETE'
		''
	end

	options '/users/:user/instances' do
		headers['Allow'] = 'OPTIONS, GET, DELETE'
		''
	end

	# --- Volumes ------

	get '/users/:user/instances/:instance_id/volumes' do |user, instance_id|
		volumes = cescre.volumes(user, instance_id)
		{ :volumes => volumes }.to_json
	end

	post '/users/:user/instances/:instance_id/volumes' do |user, instance_id|
		data = JSON::parse(request.body)
		# TODO:  Check arguments
		volume_id = cescre.create_volume(user, instance_id, data['snapshot_id']), callback(user, "#{request.path}/%s")
		'{}'
	end

	get '/users/:user/instances/:instance_id/volumes/:volume_id' do |user, instance_id, volume_id|
		volume_obj = cescre.volume(user, instance_id, volume_id)
		halt 404, "No volume '#{volume_id}' attached to instance '#{instance_id}'" unless volume_obj
		volume_obj.to_json
	end

	delete '/users/:user/instances/:instance_id/volumes/:volume_id' do |user, instance_id, volume_id|
		cescre.delete_volume user, instance_id, volume_id, callback(user, "#{request.path}")
		'{}'
	end

	get '/products' do
		cescre.products
	end

	get '/data' do
		cescre.data
	end

	# --- Authentication ------

	post '/session' do
		login_only do |username, token|
			return CESCRE::Blobs.session_token(username, token)
		end
		return "You've done a bad thing."
	end

	get '/session' do
		session_only(request.cookies[CESCRE::Auth.USER_COOKIE], request.cookies[CESCRE::Auth.TOKEN_COOKIE]) do |username|
			return "Hello, #{username}. You are currently logged in!"
		end
		return "You are not logged in."
	end

	delete '/session' do
		session_only(request.cookies[CESCRE::Auth.USER_COOKIE], request.cookies[CESCRE::Auth.TOKEN_COOKIE]) do |username|
			auth.clear_token(request.cookies[CESCRE::Auth.USER_COOKIE])
			response.delete_cookie(CESCRE::Auth.COOKIE, :path => '/')
		end
		return "You are no longer logged in."
	end
# end

# CescreApiServer.run! do |server|
# 	# server.ssl = true
# 	server.ssl = false
# 	server.ssl_options = {
# 		:cert_chain_file => CESCRE::Auth.SSL_X509_PATH,
# 		:private_key_file => CESCRE::Auth.SSL_RSA_PATH,
# 		:verify_peer => false
# 	}
# end
