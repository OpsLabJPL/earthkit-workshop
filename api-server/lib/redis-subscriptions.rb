require 'rubygems'
require 'bundler/setup'
require 'monitor'
require 'hiredis'
require 'redis'
require 'set'

class Redis
  # Open up the Subscription class and add an error callback handler
  class Subscription
    def error(&block)
      @callbacks['error'] = block
    end
  end

  # This method instantiates a new SubscriberDaemon that is bound to this Redis client
  # and returns it.
  # @param [Proc] callback block for callback registration. See redis-rb documentation on how to initialize a Subscriber.
  # @return [SubscriberDaemon]
  def subscriberDaemon(&block)
    SubscriberDaemon.new(self, &block)
  end

  private

  # This class provides all the logic for subscribing and unsubscribing from channels.  It allows you to do
  # so dynamically, unlike the normal behavior for the redis-rb pubsub model.  For this to be used, you must
  # invoke SubscriberDaemon.start! in a new thread.
  class SubscriberDaemon
    def initialize(redis, &block)
      @redis = redis
      @channels = Set.new
      @subscription = Subscription.new(&block)
      @stop = false
    end

    # @param [String] channel to subscribe to
    def subscribe(channel)
      @redis.synchronize do |client|
        return false if @channels.include? channel
        client.process([['subscribe', channel]])
        @channels.add(channel)
        return true
      end
    end

    # @param [String] channel to unsubscribe from
    def unsubscribe(channel)
      @redis.synchronize do |client|
        return false unless @channels.include? channel
        client.process([['unsubscribe', channel]])
        @channels.delete(channel)
        return true
      end
    end

    # Begins an "infinite" loop.  This main loop acts as the read loop that constantly reads new messages
    # from the redis client and passes them to the callback handlers.
    def start!
      begin
        until @stop
          try_to_read do |reply|
            if reply.is_a? CommandError
              @subscription.callbacks['error'].call(reply)
            else
              type, *rest = reply
              @subscription.callbacks[type].call(*rest)
            end
          end
        end
      ensure
        @redis.unsubscribe unless @channels.empty?
      end
    end

    # Tells the daemon to stop
    def stop!
      @stop = true
    end

    private

    def try_to_read
      @redis.synchronize do |client|
        # Don't wait too long for messages. We need to give other threads a chance to subscribe/unsubscribe.
        client.with_socket_timeout(0.005) do
          begin
            yield client.read
          rescue Redis::TimeoutError
            # Just continue
          end
        end
      end
      # Sleep briefly to allow other threads to grab the @Redis lock
      sleep(0.005)
    end
  end
end

# sd = Redis.new.subscriberDaemon do |on|
#   on.subscribe do |channel, subscriptions|
#     puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
#   end

#   on.message do |channel, message|
#     puts "##{channel}: #{message}"
#   end

#   on.unsubscribe do |channel, subscriptions|
#     puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
#   end

#   on.error do |error|
#     puts error
#   end
# end

# Thread.new do
#   sd.start!
# end

# puts 'subscribing'
# sd.subscribe(:one)
# sd.subscribe(:two)
# sd.subscribe(:three)

# puts 'publishing'
# r = Redis.new
# r.publish(:one, 'hello!')

# puts 'waiting'
# sleep(1) while true
