FileUtils.mkdir_p File.expand_path('../../../log', __FILE__)

Mongoid.logger = Mongo::Logger.logger = Logger.new('log/mongoid.log')
