#
# Author:: Rad Gruchalski (<radek@gruchalski.com>)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'

class Chef
  class Knife
    module Route53Base

      # :nodoc:
      # Would prefer to do this in a rational way, but can't be done b/c of
      # Mixlib::CLI's design :(
      def self.included(includer)
        includer.class_eval do

          deps do
            require 'fog'
            require 'readline'
            require 'chef/json_compat'
          end

          option :aws_access_key_id,
            :short => "-A ID",
            :long => "--aws-access-key-id KEY",
            :description => "Your AWS Access Key ID",
            :proc => Proc.new { |key| Chef::Config[:knife][:aws_access_key_id] = key }

          option :aws_secret_access_key,
            :short => "-K SECRET",
            :long => "--aws-secret-access-key SECRET",
            :description => "Your AWS API Secret Access Key",
            :proc => Proc.new { |key| Chef::Config[:knife][:aws_secret_access_key] = key }
          
        end
      end

      def connection
        @connection ||= begin
          connection = Fog::DNS.new(
            :provider => 'AWS',
            :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
            :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key]
          )
        end
      end

      def locate_config_value(key)
        key = key.to_sym
        config[key] || Chef::Config[:knife][key]
      end

      def msg_pair(label, value, color=:cyan)
        if value && !value.to_s.empty?
          puts "#{ui.color(label, color)}: #{value}"
        end
      end

      def validate!(keys=[:aws_access_key_id, :aws_secret_access_key])
        errors = []

        keys.each do |k|
          pretty_key = k.to_s.gsub(/_/, ' ').gsub(/\w+/){ |w| (w =~ /(ssh)|(aws)/i) ? w.upcase  : w.capitalize }
          if Chef::Config[:knife][k].nil?
            errors << "You did not provide a valid '#{pretty_key}' value."
          end
        end

        if errors.each{|e| ui.error(e)}.any?
          exit 1
        end
      end
      
      def get_element
        element = nil
        if config[:zone_id]
          element = config[:zone_id]
        else
          if config[:domain]
            element = config[:domain]
          end
          if config[:caller_reference]
            element = config[:caller_reference]
          end
        end
        element
      end
      
      def zone_by_element(element)
        zone = connection.zones.get( element )
        if zone.nil?
          connection.zones.all.each do |current_zone|
            if current_zone.domain.to_s == element || current_zone.domain.to_s == "#{element}."
              zone = current_zone
            end
            if current_zone.caller_reference.to_s == element
              zone = current_zone
            end
          end
        end
        zone
      end

    end
  end
end

