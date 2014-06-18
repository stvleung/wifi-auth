class AuditLog < ActiveRecord::Base
  has_one  :user

  def object_name
  	Kernel.const_get(self.class_name).simple_record_name(self.object_id)
  end
end