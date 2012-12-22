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

function clear_history()
{
  $("#conlog").html("");  
}

function onOpen(evt)
{
  writeToScreen('<div class="line"><span class="response system">CONNECTED</span></div>');
}

function onClose(evt)
{
  writeToScreen('<div class="line"><span class="response system">DISCONNECTED</span></div>');
}

function onMessage(evt)
{
  writeToScreen(evt.data);
}

function onError(evt)
{
  writeToScreen('<div class="line"><span class="response error">ERROR:' + Campus.error + '</span> ' + evt.data + '</div>');
}

function doSend()
{
  message = $("#sendMessage").val();
  if (message.length == 0)
  {
    writeToScreen('<div class="line">What of it, then?!?</div>'); 
  }
  else
  {
    writeToScreen('<div class="line"><span class="request">> ' + message + "</span></div>"); 
    websocket.send(message);
  }
}

function singleLineInputHandler(e)
{
  var code = (e.keyCode ? e.keyCode : e.which);
  if(code == 13) {
    doSend()
    input_history.unshift($('#sendMessage').val())
    $('#sendMessage').val("");
    history_pointer = 0;
  } else if(code == 38) {
    if (history_pointer < input_history.length) {
      $('#sendMessage').val(input_history[history_pointer]);
      setCaretToPos($('#sendMessage'), $('#sendMessage').val().length)
      history_pointer += 1;
    }
  } else if(code == 40) {
    if (history_pointer > 0) {
      history_pointer -= 1;
      $('#sendMessage').val(input_history[history_pointer]);
    } else {
      $('#sendMessage').val("");      
    }
  }  
}


function writeToScreen(message)
{
  if ($("#conlog").html().length > 0)  { message = message; }
  $("#conlog").append(message);
  $("#conlog").scrollTop($("#conlog")[0].scrollHeight);
}

function setSelectionRange(input, selectionStart, selectionEnd)
{
  if (input.setSelectionRange) {
    input.focus();
    input.setSelectionRange(selectionStart, selectionEnd);
  }
  else if (input.createTextRange) {
    var range = input.createTextRange();
    range.collapse(true);
    range.moveEnd('character', selectionEnd);
    range.moveStart('character', selectionStart);
    range.select();
  }
}

function setCaretToPos (input, pos) 
{
  setSelectionRange(input, pos, pos);
}

