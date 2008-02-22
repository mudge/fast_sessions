# This mix-in could be used to create new connections to some 
# database w/o using model classes for it
#
# You just define some connection in your database.yml file:
#
# sessions:
#   adapter: mysql
#   username: root
#   database: sessions
#   password: pazzwd
#   host: localhost
#   encoding: utf8
#
# and then use it as 
# 
# ActiveRecord::Base.create_db_connection('sessions')
#
#

module ActiveRecord
  class Base
    def self.create_db_connection(db)
      # Generate an abstract class with our connecton
      klass = generate_db_connection_class(db)

      # Get connection from this class
      klass.connection
    end

  private

    def self.generate_db_connection_class(db)
      klass = "GeneratedARConnection#{db.camelize}"
      ar_klass = "ActiveRecord::#{klass}".constantize rescue nil

      unless ar_klass
        ActiveRecord.module_eval("
          class #{klass} < Base
            self.abstract_class = true
            establish_connection configurations['#{db}']
          end
        ")
      end

      ar_klass ||= "ActiveRecord::#{klass}".constantize
    end
  end
end
