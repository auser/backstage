module Backstage
  module HasMBean
    java_import javax.management.ObjectName
    
    def self.included(base)
      base.send( :attr_accessor, :mbean_name, :mbean )
      base.extend( ClassMethods )
    end

    def initialize(mbean_name, mbean)
      self.mbean_name = mbean_name
      self.mbean = mbean
    end

    def full_name
      mbean_name.to_string
    end
    
    def method_missing(method, *args, &block)
      mbean.send( method, args, block )
    rescue NoMethodError => ex
      super
    end

    module ClassMethods
      def jmx_server
        @jmx_server ||= JMX::MBeanServer.new
      end
      
      def all
        jmx_server.query_names( filter ).collect { |name| new( name, jmx_server[name] ) }
      end

      def find(name)
        name = ObjectName.new( name ) unless name.is_a?( ObjectName )
        mbean = jmx_server[name]
        mbean ? new( name, mbean ) : nil
      end

    end
  end
end
