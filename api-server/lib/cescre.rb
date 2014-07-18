require 'logger'
require 'set'
require 'timeout'
require 'rubygems'
require 'bundler/setup'
require 'aws-sdk'
require 'yajl/json_gem'
require 'redis'

require './config.rb'

module CESCRE

	class NoAvailableEIPsError < StandardError
	end

	class Core

		def initialize(workshop, ec2_config, redis)
			@WORKSHOP = workshop
			@EC2_CONFIG = ec2_config
			@REDIS = redis
			@logger = Logger.new(STDOUT)
			@instance_counter = 0
		end

		def publish_proc(channel)
			Proc.new { |message| @REDIS.publish(channel, message) }
		end

		# Returns the list of machine images available
		def products
			json = @REDIS.get("products")
			unless json
				images = []
				ec2.images.filter('tag:Workshop', @WORKSHOP).each { |image|
					valid_types = []
					inst_types_tag = image.tags['InstanceTypes']
					valid_types = inst_types_tag.split(/, ?/) if inst_types_tag
					images << {
						:id => image.id,
						:name => image.name,
						:description => image.description,
						:architecture => image.architecture,
						:valid_types => valid_types
					}
				}
				json = { "products" => images }.to_json
				@REDIS.setnx("products", json)
			end
			json
		end

		# Returns a list of available data snapshots
		def data
			json = @REDIS.get("data")
			unless json
				snapshots = []
				ec2.snapshots.filter('tag:Workshop', @WORKSHOP).each { |snapshot|
					snapshots << {
						:id => snapshot.id,
						:name => snapshot.tags['Name'],
						:description => snapshot.description,
						:size => snapshot.volume_size
					}
				}
				json = { "data" => snapshots }.to_json
				@REDIS.setnx("data", json)
			end
			json
		end

		# Returns a hash object representing the given instance
		def instance_obj user, instance
			instance_obj = {
				:id => instance.id,
				:name => instance.tags['Name'],
				:type => instance.instance_type,
				:status => instance.tags['Status'],
				:launch_time => instance.launch_time.strftime('%FT%TZ'),
				:source => instance.image_id,
				:url => "/users/#{user}/instances/#{instance.id}",
				:hostname => instance.public_dns_name,
				:volumes => get_attached_volume_objs(user, instance)
			}
			instance_obj
		end

		def instances user
			instances = []
			ec2.instances.filter('tag:User', user).filter('instance-state-name', 'pending', 'running', 'stopping').each { |instance|
				obj = instance_obj(user, instance)
				instances << obj unless obj[:status] == 'terminated'
			}
			instances
		end

		def instance user, instance_id
			instance = ec2.instances[instance_id]
			return nil unless instance.exists? and instance.tags['User'] == user
			return nil if instance.tags['Status'] == 'terminated'
			instance_obj user, instance
		end

		def resume_or_create_instance user, ami, instance_type, name, volume_snapshots, signal
			existing_instance = find_instance(user)
			if existing_instance.nil?
				return launch_instance(user, ami, instance_type, name, volume_snapshots, signal)
			end
			if existing_instance.status == :stopped
				return resume_instance(existing_instance, signal)
			else
				signal.call existing_instance.id
				return existing_instance.id
			end
		end

		def resume_instance(instance, signal)
			@logger.debug("instance [#{instance.id}]: resuming")
			instance.start()
			Thread.new do
				begin
					instance.tag('Status', :value => 'provisioning')
					signal.call(instance.id)
					@logger.debug("instance [#{instance.id}]: waiting for booting")
					until ec2.instances[instance.id].status == :running
						sleep(2)
					end
					instance.tag('Status', :value => 'booting')
					signal.call(instance.id)
					@logger.debug("instance [#{instance.id}]: waiting for connectivity")
					wait_for_connectivity(instance.public_ip_address)
					# Mount each EBS volume that was attached on boot time, except for /dev/sda
					instance.attachments.each_key { |device| mount(instance, :MOUNT, device) unless device == '/dev/sda' }
					instance.tag('Status', :value => 'ready')
					signal.call(instance.id)
					@logger.debug("instance [#{instance.id}]: ready")
				rescue => e
					@logger.error(e)
				end
			end
			instance.id
		end

		# Launches a new instance for the given user
		# Params:
		# +user+::
		# +ami+::
		# +instance_type+::
		# +name+::
		# +volume_snapshots+::
		# +signal+:: A Proc that accepts a single argument--a string that is the new instance id. This will be called multiple times as the instance initializes.
		def launch_instance user, ami, instance_type, name, volume_snapshots, signal
			args = {
				:image_id => ami,
				:instance_type => instance_type,
				:key_pair => ec2.key_pairs[@EC2_CONFIG[:key_pair]],
				:security_group_ids => [@EC2_CONFIG[:security_group]],
				:subnet => @EC2_CONFIG[:subnet]
			}
			# Build the block device mapping for volumes to attach on boot
			device_mapping = {}
			if volume_snapshots.size > 0
				devices = valid_devices.to_a
				volume_snapshots.each { |snapshot_id|
					device_mapping[devices.shift] = {
						:snapshot_id => snapshot_id,
						:delete_on_termination => false
					}
				}
				args[:block_device_mappings] = device_mapping
			end

			instance = ec2.instances.create(args)
			@instance_counter += 1
			# Tag the instance once it exists
			Thread.new {
				sleep(0.25) until ec2.instances[instance.id].exists?
				instance.tag('Workshop', :value => @WORKSHOP)
				instance.tag('Name', :value => "#{@WORKSHOP}-#{user}-#{@instance_counter}")
				instance.tag('Status', :value => 'provisioning')
				instance.tag('User', :value => user)
			  signal.call instance.id
				@logger.debug "instance [#{instance.id}]: waiting for booting"
				until ec2.instances[instance.id].status == :running
					sleep(2)
				end
				begin
					# TODO: really need to implement some sort of error reporting
					eip = associate_ip(instance)
				rescue Exception => e
					@logger.error e
				end
				instance.tag('Status', :value => 'booting')
				signal.call instance.id
				@logger.debug "instance [#{instance.id}]: waiting for connectivity"
				wait_for_connectivity eip.public_ip
				# Mount each EBS volume that was attached on boot time
				device_mapping.each_key { |device| mount(instance, :MOUNT, device) }
				instance.tag('Status', :value => 'ready')
				signal.call instance.id
				@logger.debug "instance [#{instance.id}]: ready"
			}
			instance.id
		end

		# Stops an instance rather than terminating it.
		def stop_instance user, instance_id, signal
			instance = ec2.instances[instance_id]
			return nil unless instance.exists? and instance.tags['User'] == user
			return nil if ['terminated', 'stopped'].include?(instance.tags['Status'])
			@logger.debug("instance [#{instance.id}]: stopping")
			instance.tag('Status', :value => 'stopping')
			instance.stop()
			Thread.new {
				signal.call(instance_id)
				@logger.debug("instance [#{instance.id}]: waiting for stopped...")
				sleep(1) until ec2.instances[instance.id].status == :stopped
				@logger.debug("instance [#{instance.id}]: stopped")
				instance.tag('Status', :value => 'stopped')
				signal.call(instance_id)
			}
		end

		def terminate_instance user, instance_id, signal
			instance = ec2.instances[instance_id]
			return nil unless instance.exists? and instance.tags['User'] == user
			return nil if instance.tags['Status'] == 'terminated'
			@logger.debug "instance [#{instance.id}]: releasing Elastic IP..."
			release_ip instance
			# Compile a list of this instances volumes
			Thread.new {
				volumes = []
				instance.attachments.each { |device, attachment|
					# Don't include root devices, if any exist, they get deleted automatically
					next if device =~ /\/dev\/sda/ #or attachment.delete_on_termination?
					volumes << attachment.volume
				}
				instance.tag('Status', :value => 'terminated')
				@logger.debug "instance [#{instance.id}]: terminating instance..."
				instance.terminate
				signal.call instance_id
				# Delete each volume that isn't automatically deleted
				volumes.each { |v|
					begin
						sleep(1) until ec2.volumes[v.id].status == :available
						@logger.debug "instance [#{instance.id}]: deleting #{v.size}GB volume #{v.id}"
						v.delete
					rescue Exception => e
						@logger.error e
					end
				}
				@logger.debug "instance [#{instance.id}] terminated"
			}
		end

		def volume user, instance_id, volume_id
			instance = ec2.instances[instance_id]
			return nil unless instance.exists? and instance.tags['Status'] != 'terminated' and instance.tags['User'] == user
			attachment = attachment_from_volume instance, volume_id
			return nil unless attachment and (attachment.status == :attached or attachment.status == :attaching)
			get_volume_obj(user, instance, attachment)
		end

		def volumes user, instance_id
			instance = ec2.instances[instance_id]
			return [] unless instance.exists? and instance.tags['Status'] != 'terminated' and instance.tags['User'] == user
			get_attached_volume_objs user, instance
		end

		# Creates a new volume based on a snapshot, attaches it to the given instance, and mounts it
		# Params:
		# +user+::
		# +instance_id+::
		# +volume_snapshots+::
		def create_volume user, instance_id, snapshot_id, signal
			# TODO: This method actually does take time. It takes a up to around 20s for the volume to become "attached"
			instance = ec2.instances[instance_id]
			return nil unless instance.exists? and instance.tags['Status'] == 'ready' and instance.tags['User'] == user
			snapshot = ec2.snapshots[snapshot_id]
			return nil unless snapshot.exists?
			# Get a list of possible devices for attachment points by removing any
			# existing device attachments from the valid devices.
			# This needs to be synchronized...
			volume = ec2.volumes.create(:snapshot => snapshot, :availability_zone => instance.availability_zone)
			Thread.new {
				possible_devices = valid_devices - get_used_devices(instance)
				device = possible_devices.to_a.first
				sleep(0.1) until volume.exists?
				volume.tag('Status', :value => 'creating')
				signal.call volume.id
				volume.tag('Workshop', :value => @WORKSHOP)
				volume.tag('User', :value => user)
				attachment = volume.attach_to(instance, device)
				sleep(0.25) until attachment.status == :attached
				mount instance, :MOUNT, device
				volume.tag('Status', :value => 'ready')
				signal.call volume.id
			}
			return volume.id
		end

		def delete_volume user, instance_id, volume_id
			# TODO: This method actually does take time. Almost 3 minutes...
			instance = ec2.instances[instance_id]
			return nil unless instance.exists? and instance.tags['Status'] != 'terminated' and instance.tags['User'] == user
			Thread.new {
				volume = ec2.volumes[volume_id]
				volume.tag('Status', :value => 'deleted')
				# This shouldn't mislead you... a volume can have at most one attachment
				volume.attachments.each do |attachment|
					next unless attachment.status == :attached
					mount instance, :UMOUNT, attachment.device
					attachment.delete(:force => true)
				end
				signal.call volume_id
				# TODO: For some reason attachment.status doesn't reflect "available" even though EC2 web console
				# shows the volume as available. This still succeeds eventually, but I'm not sure what the disconnect is.
				# That's why I am using the long form for volume status here (vs just volume.status)
				sleep(0.25) until volume.status == :available
				volume.delete
			}
		end


		private
		
		def find_instance(user)
			the_instance = nil
			ec2.instances.filter('tag:Workshop', @WORKSHOP).filter('tag:User', user).each do |instance|
				next if [:shutting_down, :terminated].include?(instance.status)
				the_instance = instance
				break
			end
			return the_instance
		end

		# Attempts to find an available EIP and associate it with the given instance
		# Returns the elastic IP object that was associated with the instance.
		def associate_ip instance
			# Loop until either we associate an EIP or we find out there are no available EIPs
			while true
				# Get all the current EIPs
				# TODO: Would be great to filter based on instance_id = '', but it seems like AWS doesn't support filtering for empty strings
				# For now, I get an array of hash representations of the EIPs, because getting the instance_id field of each actual EIP
				# object seems to query AWS, which is slow. Doing it this way I only query AWS once.
				all_eips = ec2.elastic_ips.each { }
				num_unavailable = 0
				all_eips.each { |eip|
					if eip[:instance_id] == nil
						begin
							eip_obj = ec2.elastic_ips[eip[:public_ip]]
							# Try to associate the instance, but catch the AlreadyAssociated exception
							# if some other entity already associated this EIP (that is, a race condition)
							instance.associate_elastic_ip eip_obj
							@logger.debug "instance [#{instance.id}]: allocated elastic IP #{eip[:public_ip]}"
							return eip_obj
						rescue AWS::EC2::Errors::Resource::AlreadyAssociated => e
							num_unavailable += 1
						end
					else
						num_unavailable += 1
					end
				}
				if num_unavailable == all_eips.size
					throw NoAvailableEIPsError("No available Elastic IPs found!")
				end
			end
		end

		def release_ip instance
			return false if instance.ip_address == nil
			instance.disassociate_elastic_ip
			true
		end

		def get_volume_obj user, instance, attachment
			volume = attachment.volume
			device = attachment.device
			volume_obj = {
				:id => volume.id,
				:device => device,
				:mount => device.sub(/dev/, 'mnt'),
				:size => volume.size,
				:status => volume.tags['Status'],
				:source => volume.snapshot.id,
				:create_time => volume.create_time.strftime('%FT%TZ'),
				:url => "/users/#{user}/instances/#{instance.id}/volumes/#{volume.id}"
			}
			return volume_obj
		end

		# Returns all attached or attaching volume objects for a given instance
		def get_attached_volume_objs user, instance
			volume_objs = []
			instance.attachments.each { |device, attachment|
				# Ignore root volumes as well as detaching/detached volumes
				next if device =~ /\/dev\/sda/ or attachment.status == :detaching or attachment.status == :detached
				volume_objs << get_volume_obj(user, instance, attachment)
			}
			volume_objs
		end

		# Returns a set of the devices currently in use on an instance
		def get_used_devices instance
			devices = Set.new
			instance.attachments.each { |device, attachment|
				# Only exclude detached, because "detaching" means it is still technically attached
				next if attachment.status == :detached
				devices << device
			}
			devices
		end

		def attachment_from_volume instance, volume_id
			instance.attachments.each { |device, attachment|
				if attachment.volume.id == volume_id
					return attachment
				end
			}
		end

		# Returns an EC2 client
		def ec2
			@ec2 ||= AWS::EC2.new(:access_key_id => ENV['AWS_ACCESS_KEY'],
								  :secret_access_key => ENV['AWS_SECRET_KEY']).regions[ENV['AWS_REGION']]
		end

		def s3
			@s3 ||= AWS::S3.new(:access_key_id => ENV['AWS_ACCESS_KEY'],
								  :secret_access_key => ENV['AWS_SECRET_KEY'])
		end

		# Mounts or unmounts a device on an instance.
		# 'action' can be :MOUNT or :UMOUNT
		def mount instance, action, dev
			s = TCPSocket.new instance.public_dns_name, 57775
			s.write "foobarkey:#{action}:#{dev}\n"
			while line = s.readline do
				if s.eof?
					# Should probably log this... or something
					break
				end
				break if line =~ /^OK/
			end
			s.close
		end

		# Returns a set of valid devices for attaching volumes to instances.
		# The valid devices are sd[f-p] and sd[f-p][1-6]
		def valid_devices
			unless @valid_devices
				devices = Set.new
				"fghijklmnop".each_char { |c| devices << "/dev/sd#{c}" }
				6.times { |i|
					"fghijklmnop".each_char { |c| devices << "/dev/sd#{c}#{i+1}" }
				}
				@valid_devices = devices
			end
			@valid_devices
		end

		# Waits for the specified host (instance) to be booted and for our daemon script to be accepting connections
		def wait_for_connectivity host
			# First wait for the remote mounter script to be running
			sock = nil
			while sock == nil
				begin
					timeout(2) do
						sock = TCPSocket.new(host, 57775)
					end
				rescue Timeout::Error, Errno::ECONNREFUSED
				end
			end
			sock.close
			# Now wait for tty.js to be active
			sock = nil
			while sock == nil
				begin
					timeout(2) do
						sock = TCPSocket.new(host, 8080)
					end
				rescue Timeout::Error, Errno::ECONNREFUSED
				end
			end
			sock.close
		end

	end

end