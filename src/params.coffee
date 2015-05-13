parseParams = (params) ->
  raw_vars = params.split '&'

  parsed_params = {}

  for v in raw_vars
    [key, val] = v.split("=")
    parsed_params[key] = decodeURIComponent(val)

  parsed_params
