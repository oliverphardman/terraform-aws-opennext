function handler(event) {
  var request = event.request;
  var host = request.headers.host.value;

  // Redirect www to non-www
  if (host.startsWith('www.')) {
    var nonWwwHost = host.substring(4);
    var url = 'https://' + nonWwwHost + request.uri;

    // Preserve query string
    if (request.querystring) {
      var queryParams = [];
      for (var param in request.querystring) {
        var value = request.querystring[param].value;
        queryParams.push(param + '=' + value);
      }
      if (queryParams.length > 0) {
        url += '?' + queryParams.join('&');
      }
    }

    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: {
        'location': { value: url }
      }
    };
  }

  request.headers["x-forwarded-host"] = request.headers.host;
  return request;
}