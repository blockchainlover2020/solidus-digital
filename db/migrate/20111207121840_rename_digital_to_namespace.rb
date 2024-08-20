# frozen_string_literal: true

class RenameDigitalToNamespace < ActiveRecord::Migration[4.2]
  def change
    rename_table :digitals, :spree_digitals
    rename_table :digital_links, :spree_digital_links
  end
end
