# frozen_string_literal: true

require "dry-types"

module Tabami
  module Types
    include Dry.Types()

    # Reusable custom types & enums
    Adapter = String.enum("postgres", "postgresql", "sqlite", "sqlite3", "mysql", "mysql2")
    SortDirection = String.enum("asc", "desc", "ASC", "DESC")
  end
end
