class CreateAuditLogs < ActiveRecord::Migration
  def self.up
    create_table :audit_logs do |t|
      t.integer  "user_id"
      t.string   "class_name"
      t.integer  "object_id"
      t.text     "description"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "ip_address"
      t.string   "session_id"
    end
  end

  def self.down
    drop_table :audit_logs
  end
end
