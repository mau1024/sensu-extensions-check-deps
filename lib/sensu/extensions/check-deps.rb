require "sensu/extension"
require "timeout"
require "net/http"
require 'json'

module Sensu
  module Extension
    class CheckDeps < Filter
      def name
        "check_deps"
      end

      def description
        "filter events when an event exists and send to RabbitMQ event json"
      end

      # Will post Slack message to channel sensu
      @webhook = "T02B3AJ9B/BAYDG2VHN/jOVR3fy8AG5O7Y4ftTfNzon7"
      def writeToSlack(message, webhook=@webhook, err=false)
            webhookUrl = "https://hooks.slack.com/services/" + webhook
            channel = "#sensu"
            begin
            payload = {
                :channel  => channel,
                :text     => message,
            }.to_json
              cmd = "curl -X POST --data-urlencode 'payload=#{payload}' #{webhookUrl}"
              system(cmd)
            rescue
                    puts "failed to notify slack, proceeding..."
            end
      end

      # Make an HTTP GET request to the Sensu API, using the URI
      # path provided. Uses Sensu settings to determine how to
      # connect to the API.
      #
      # @param path [String]
      # @return [Object] http response object.

      def sensu_api_get_request(path)
        api = @settings[:api] || {}
        request = Net::HTTP::Get.new(path)
        if api[:user]
          request.basic_auth(api[:user], api[:password])
        end
        Net::HTTP.new(api[:host] || '127.0.0.1', api[:port] || 4567).start do |http|
          http.request(request)
        end
      end

      # Check to see if an event exists for a client/check pair. This
      # method is looking for a HTTP response code of `200`.
      #
      # @param client_name [String]
      # @param check_name [String]
      # @return [Boolean]
      def client_event_exists?(client_name, check_name)
        path = "/events/#{client_name}/#{check_name}"
        response = sensu_api_get_request(path)
        response.code.to_i == 200
      end

      # Check to see if an event exists for a subscription/check pair. This
      # method is looking for a HTTP response code of `200`.
      #
      # @param subscription_name [String]
      # @param check_name [String]
      # @return [Boolean]
      def subscription_event_exists?(subscription_name, check_name)
        path = "/events"
        response = sensu_api_get_request(path)
        events = JSON.load(response.body)
        !events.select { |event| event[:client][:subscriptions].include?(subscription_name) && event[:check][:name] == check_name}.empty?
      end

      # Determine if an event exists for any of the check
      # dependencies declared in the event data, specified in array,
      # check `dependencies`. A check dependency can be a check
      # executed by the same Sensu client (eg. `check_app`), a
      # client/check pair (eg.`i-424242/check_mysql`), or a
      # subscription/check pair (eg. `subscription:mysql/check_mysql`).
      #
      # @param event [Hash]
      # @return [Boolean]

      def dependency_events_exist?(event)
        if event[:check][:dependencies][:dependency].is_a?(Array)
          event[:check][:dependencies][:dependency].any? do |dependency|
            begin
              check_name, entity = dependency.split("/").reverse
              if entity =~ /^subscription:.*$/
                subscription_name = entity.split(":")[1]
                subscription_event_exists?(subscription_name, check_name)
              else
                client_name = entity
                client_name ||= event[:client][:name]
                client_event_exists?(client_name, check_name)
              end
            rescue => error
              @logger.error("failed to query api for a check dependency event", :error => error)
              false
            end
          end
        else
          false
        end
      end

      def run(event, &callback)
        filter = Proc.new do
          begin

            Timeout::timeout(10) do
              if dependency_events_exist?(event)
                writeToSlack(":no_entry: event exists for check dependency")
                writeToSlack(":no_entry: Event: #{event[:check][:name]} will be blocked Action: #{event[:action]}. Deps list: #{event[:check][:dependencies][:dependency]}")
                ["event exists for check dependency", 1]
              else
                writeToSlack(":arrow_up: no current events for check dependencies")
                writeToSlack(":arrow_up: Event: #{event[:check][:name]} will pass. Action: #{event[:action]}. Deps list: #{event[:check][:dependencies][:dependency]}")
                ["no current events for check dependencies", 1]
              end
            end
          rescue => error
            @logger.error("check dependencies filter error", :error => error.to_s)
            ["check dependencies filter error: #{error}", 1]
          end
        end
        EM.defer(filter, callback)
      end
    end
  end
end
