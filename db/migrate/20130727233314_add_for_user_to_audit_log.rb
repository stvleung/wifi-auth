class AddForUserToAuditLog < ActiveRecord::Migration
  def change
    add_column :audit_logs, :for_user, :string
  end
end
