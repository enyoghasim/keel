module KeelMcp
  # Keel's MCP server (SPEC.md section 13), mounted at /mcp as a Rack app.
  # A personal access token in the Authorization header says who is asking;
  # the server is built per request around that person and served over a
  # stateless streamable-HTTP transport, so no session can ever outlive or
  # leak one person's identity into another's request. The transport's DNS
  # rebinding check is off: it only suits servers bound to loopback, Rails'
  # own host authorization covers the public host, and the credential is a
  # bearer token a rebinding page couldn't know, not an ambient cookie.
  class Endpoint
    def call(env)
      token = PersonalAccessToken.authenticate(bearer_token(env))
      return unauthorized unless token

      transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        Server.build(token.person, token: token), stateless: true, dns_rebinding_protection: false
      )
      transport.call(env)
    end

    private

    def bearer_token(env) = env["HTTP_AUTHORIZATION"].to_s[/\ABearer (.+)\z/, 1]

    def unauthorized
      body = { jsonrpc: "2.0", id: nil, error: { code: -32_001, message: "Unauthorized: send a Keel personal access token as a Bearer token." } }
      [ 401, { "content-type" => "application/json", "www-authenticate" => "Bearer" }, [ body.to_json ] ]
    end
  end
end
