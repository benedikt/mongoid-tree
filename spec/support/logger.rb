FileUtils.mkdir_p File.expand_path('../../../log', __FILE__)

logger = Logger.new('log/mongoid.log')

if Mongoid::Compatibility::Version.mongoid5_or_newer?
  Mongoid.logger = Mongo::Logger.logger = logger
else
  Mongoid.logger = logger
end
