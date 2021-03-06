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

require 'util'
require 'authentication'
require 'sinatra/url_for'

module Backstage
  class Application < Sinatra::Base
    
    helpers do
      include Backstage::Authentication
      include Sinatra::UrlForHelper

      def json_url_for(fragment, options = { })
        options[:format] = 'json'
        url_for( fragment, :full, options )
      end
      
      def object_path(object)
        object_action_or_collection_path(*(object.association_chain << nil))
      end

      def object_action_or_collection_path(*objects)
        collection_or_action = objects.pop
        paths = []
        objects.each do |object|
          paths << "#{simple_class_name( object )}/#{Util.encode_name( object.full_name )}"
        end
        paths << collection_or_action if collection_or_action
        '/' + paths.join( '/' )
      end
      alias_method :object_action_path, :object_action_or_collection_path
      alias_method :collection_path, :object_action_or_collection_path
      
      def redirect_to(location)
        redirect url_for(location, :full)
      end

      def link_to(path, text, options = {})
        "<a href='#{url_for path}' class='#{options[:class]}'>#{text}</a>"
      end

      def data_row(name, value)
        dom_class = ['value']
        dom_class << 'status' << value.downcase if name.to_s.downcase == 'status' # hack
        "<tr class='data-row'><td class='label'>#{name}</td><td class='#{dom_class.join(' ')}'>#{value}</td></tr>"
      end
      
      def simple_class_name(object)
        object.class.name.split( "::" ).last.underscore
      end
      
      def truncate(text, length = 30)
        text.length > length ? text[0...length] + '...' : text
      end
      
      def class_for_body
        klass = request.path_info.split('/').reverse.select { |part| part =~ /^[A-Za-z_]*$/ }
        klass.empty? ? 'root' : klass
      end

      def action_button(object, action, text=nil)
        text ||= action.capitalize
        accum = <<-EOF
<form method="post" action="#{url_for object_action_path(object, action)}">
  <input type="submit" value="#{text}"/>
</form>
        EOF
      end

      def html_requested?
        params[:format] != 'json' && env['rack-accept.request'].media_type?( 'text/html' )
      end
      
      def collection_to_json( collection )
        JSON.generate( collection.collect { |object| object_to_hash( object ) } )
      end

      def object_to_json(object)
        JSON.generate( object_to_hash( object ) )  
      end
      
      def object_to_hash(object)
        response = object.to_hash
        response[:actions] = object.available_actions.inject({}) do |actions, action|
          actions[action] = json_url_for( object_action_path( response[:resource], action ) )
          actions
        end
        response.each do |key, value|
          if value.kind_of?( Resource )
            response[key] = json_url_for( object_path( value ) )
          end
        end
        response
      end

    end
  end
end

class String
  def classify
    if self =~ %r{/}
      split( '/' ).collect( &:classify ).join( '::' )
    elsif self =~ %r{_}
      split( '_' ).collect( &:classify ).join( '' )
    else
      capitalize
    end
  end

  def constantize
    eval( classify )
  end
  
  def underscore
    gsub(/([a-zA-Z])([A-Z])/, '\1_\2').downcase
  end
  
  def humanize
    split( '_' ).collect( &:capitalize ).join( ' ' )
  end

  #poor man's...
  def pluralize
    "#{self}s"
  end
end
