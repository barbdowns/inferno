class ResourceInstance
  include DataMapper::Resource
  property :id, String, key: true, default: proc { SecureRandom.uuid}
  property :resource_type, String
  property :resource_id, Boolean, default: false

  belongs_to :testing_instance
end