require 'rubygems'
require 'bundler/setup'
require './lib/redis-subscriptions.rb'
require 'set'
require 'monitor'

##
# This class acts as a bridge between Redis channels and Websockets.  In other words, it manages
# "binding" websockets to any pubsub channels on a Redis server. For an example use case, suppose
# you want a client Bob's websocket (bobsock) to receive any messages published to the
# Redis channel, "poke-bob".  You would perform the following:
#
# redis_sockets = RedisSockets.new
# redis_sockets.attach('poke-bob', bobsock)
#
# Bob's websocket will now receive any messages published to 'poke-bob'.  To publish a message, just
# use another Redis client like so:
#
# Redis.new.publish('poke-bob', 'poke!')
#
# To detach a websocket from a channel (so it no longer received messages published to the channel),
# use the detach() method.
#
# When instantiating an instance of this class, a new Redis client is created so that it can enter
# pubsub mode (in which the client can only subscribe/unsubscribe).  It also launches a thread to
# poll Redis for new messages.
class RedisSockets
  # @param [Hash] options to pass to Redis initializer
  def initialize(options={})
    @channels = {}.extend(MonitorMixin)
    redis = Redis.new(:options => options)
    @subscriber = redis.subscriberDaemon do |on|
      on.message do |channel, message|
        @channels.synchronize do
          chan = @channels[channel]
          chan.broadcast(message) if chan
        end
      end
    end
    @subscriberThread = Thread.new { @subscriber.start! }
  end

  # Attach a websocket to the given Redis channel.  This will result in a Redis channel
  # subscription if no such subscription exists yet.
  # @param [String] channel
  # @param [SinatraWebsocket::Connection] socket
  # @return [SinatraWebsocket::Connection]
  def attach(channel, socket)
    chan = nil
    @channels.synchronize do
      chan = @channels[channel]
      if chan.nil?
        chan = @channels[channel] = Channel.new(channel)
      end
      # Order matters here.  Add the socket to the channel before subscribing (if we have to subscribe)
      chan.add(socket)
      @subscriber.subscribe(channel) if chan.size == 1
    end
    socket
  end

  # Detaches a websocket from the given Redis channel.  If there are no more sockets attached
  # to the channel, then the channel will be unsubscribed.
  # @param [String] channel
  # @param [SinatraWebsocket::Connection] socket
  # @return [SinatraWebsocket::Connection]
  def detach(channel, socket)
    @channels.synchronize do
      chan = @channels[channel]
      chan.delete(socket)
      if chan.empty?
        # Order matters here.  Unsubscribe THEN delete the channel mapping
        @subscriber.unsubscribe(channel)
        @channels.delete(channel)
      end
    end
    socket
  end

  private

  ##
  # The Channel class is a one-to-many mapping of a channel to websockets.  Channels
  # are arbitrary strings and correspond directly to Redis channels.
  class Channel

    def initialize(channel)
      @channel = channel
      @sockets = Set.new.extend(MonitorMixin)
    end

    # Sends the given message to each websocket currently attached to this channel
    # @param [String] message to send
    def broadcast(message)
      @sockets.synchronize do
        @sockets.each do |socket|
          begin
            socket.send(message)
          rescue Exception => e
            # TODO
            #logger.error e
          end
        end
      end
    end

    # Adds a websocket to this channel
    # @param [SinatraWebsocket::Connection] websocket to add
    def add(socket)
      @sockets.synchronize do
        @sockets.add(socket)
      end
      socket
    end

    # Deletes a websocket from this channel
    # @param [SinatraWebsocket::Connection] websocket to delete
    def delete(socket)
      @sockets.synchronize do
        @sockets.delete(socket)
        puts "socket deleted"
      end
      socket
    end

    # @param [Boolean] whether or not there are any sockets attached
    def empty?
      return @sockets.empty?
    end

    # @return [Number]
    def size
      return @sockets.size
    end

  end

end

private

##
# This class is just used for testing out the pubsub model without real websockets.
# It implements a send method which is good enough to act like a websocket.
class DummySocket
  @@id = 0

  # @param [IO] some object that implements a write method
  def initialize(io)
    @id = @@id
    @@id += 1
    @io = io
  end

  def send(message)
    @io.write("#{@id}: #{message}\n")
  end
end

# Testing
if __FILE__ == $PROGRAM_NAME
  require 'redis'
  sockets = RedisSockets.new
  redis = Redis.new

  socks = 3.times.collect{DummySocket.new($stdout)}
  socks.each { |sock| sockets.open('foo', sock) }

  t = Thread.new do
    i = 0
    while i < 10
      redis.publish('foo', "mic check #{i}...")
      i += 1
      sleep(1)
    end
  end
  t.join

  socks.each { |sock| sockets.close('foo', sock) }
end
