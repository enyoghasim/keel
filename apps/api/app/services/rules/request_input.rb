module Rules
  # The engine's input shape: requester_id + payload. Deliberately plain
  # rather than an ActiveRecord model — the Request model doesn't exist yet
  # (it belongs to the runtime work), and the engine only needs these two
  # fields regardless of what eventually constructs it.
  RequestInput = Data.define(:requester_id, :payload)
end
