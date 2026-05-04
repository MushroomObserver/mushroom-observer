# iNat Import Rules

## API Requests

Always make iNat API requests via `app/classes/inat/api_request.rb`
(`Inat::APIRequest`). Never call `RestClient` or
`RestClient::Request.execute` directly in iNat import code.

Use `Inat::APIRequest.new(token).request(path: "...")` for authenticated
requests. For unauthenticated public endpoints (e.g. `/taxa`), pass
`nil` as the token — `Inat::APIRequest` skips the `Authorization`
header when the token is nil.
