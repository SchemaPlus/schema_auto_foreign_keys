require 'schema_plus/core'

require_relative 'schema_auto_foreign_keys/version'

# Load any mixins to ActiveRecord modules, such as:
#
#require_relative 'schema_auto_foreign_keys/active_record/base'

# Load any middleware, such as:
#
# require_relative 'schema_auto_foreign_keys/middleware/model'

SchemaMonkey.register SchemaAutoForeignKeys
