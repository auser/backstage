#
# Copyright 2011 Red Hat, Inc.
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

require 'json'

module Backstage
  class Destination
    include Enumerable
    include HasMBean
    include Resource
    
    attr_accessor :enumerable_options
    
    def self.filter
      "org.hornetq:address=\"#{jms_prefix}\",*,type=Queue"
    end

    def self.to_hash_attributes
      super + [:display_name, :app, :app_name, :status, :message_count, :delivering_count, :scheduled_count, :messages_added, :consumer_count]
    end

    def jms_destination
      TorqueBox::Messaging::Queue.new( jndi_name, nil, enumerable_options )
    end
    
    def each
      jms_destination.each do |message|
        message = Message.new( message )
        message.parent = self
        yield message
      end
    end
    
    def display_name
      self.class.display_name( name )
    end

    def jndi_name
      jndi_name = name.gsub( self.class.jms_prefix, '' )
      jndi_name = "/queue/#{jndi_name}" if %w{ DLQ ExpiryQueue }.include?( jndi_name )
      jndi_name
    end

    def self.display_name(name)
      display_name = name.gsub( /jms\..*?\./, '' )
      display_name = 'Backgroundable' if display_name =~ %r{/queues/torquebox/.*/backgroundable}
      display_name = "#{$1.classify}Task" if display_name =~ %r{/queues/torquebox/.*/tasks/(.*)$}
      display_name
    end

    def app
      name =~ %r{/queues/torquebox/(.*?)/} ? App.find( "torquebox.apps:app=#{$1}" ) : nil
    end
    
    def app_name
      name =~ %r{/queues/torquebox/(.*)} ? $1 : 'n/a'
    end

    def status
      mbean.paused ? 'Paused' : 'Running'
    end

    def available_actions
      status == 'Running' ? %w{ pause } : %w{ resume }
    end
  end
end
