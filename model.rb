require "active_record"

class Gift < ActiveRecord::Base
    belongs_to :device
    def as_json(options={})
      super( :except => [:device_id], :methods => [:id] )
    end
end

class Device < ActiveRecord::Base
    has_many :gifts
    def as_json(options={})
      super( :include => [:gifts] )
    end
end
