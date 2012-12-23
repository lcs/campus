var wsUri;
var output;
var websocket;
var input_history = [];
var history_pointer = 0;

function connect_to_world()
{
  wsUri = $('#wsUri').val();
  websocket = new WebSocket(wsUri);
  websocket.onopen = function(evt) { onOpen(evt) };
  websocket.onclose = function(evt) { onClose(evt) };
  websocket.onmessage = function(evt) { onMessage(evt) };
  websocket.onerror = function(evt) { onError(evt) };    
}

function close_connection()
{
  websocket.close();  
}

function onOpen(evt) {}

function onClose(evt) {}

function onMessage(evt)
{
  var lines = evt.data.split("\n");
  $.each(lines, function(index, value) { 
    the_term.echo(value);
  });
}

function onError(evt)
{
  return the_term.echo('ERROR:' + Campus.error + ' ' + evt.data).css("color","red");
}

function doSend(message)
{
  websocket.send(message);
}

