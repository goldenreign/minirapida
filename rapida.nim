import os, re, jester, asyncdispatch, htmlgen, asyncnet, strutils, parseopt2, parseutils

proc showUsageAndQuit(code: int) =
    let usageString = "Usage: rapida [dir] [--port:8001] [--sub:on]"
    echo usageString
    quit(code)

var boundDir = "."
var boundPort = 8001
var showSubdirs = true
for kind, key, val in getopt():
    case kind
    of cmdArgument:
        if not existsDir(key):
            echo format("Wrong directory: $1", key)
            showUsageAndQuit(QuitFailure)
        else:
            boundDir = key
    of cmdLongOption, cmdShortOption:
        case key
        of "port", "p":
            let convResult = parseutils.parseInt(val, boundPort)
            if convResult == 0:
                echo format("Wrong port: $1", val)
                showUsageAndQuit(QuitFailure)
        of "sub", "s":
            case val
            of "on":
                showSubdirs = true
            of "off":
                showSubdirs = false
            else:
                echo format("Wrong subdirectory option: $1, expected <on|off>", val)
                showUsageAndQuit(QuitFailure)
        of "help", "h":
            showUsageAndQuit(QuitSuccess)
        else:
            discard
    of cmdEnd:
        discard

setCurrentDir(boundDir)

settings:
  port = Port(boundPort)
  appName = ""
  bindAddr = ""

routes:
  get "/@name":
    var fileFound = false
    for file in walkFiles("*"):
      if existsFile(file):
        if file == @"name":
          fileFound = true
          if getFileSize(file) > 700*1024*1024:
            await response.sendHeaders(Http404, {"Content-Type": "text/html; charset=utf-8"}.newStringTable())
            await response.send("File too big (700MB limit), try another!")
          else :
            var contentType: string
            var (_, _, fileExt) = splitFile(@"name")
            case fileExt
            of ".png", ".PNG":
              contentType = "image/png"
            else:
              contentType = "application/octet-stream"
            var fileContent = readFile(@"name")
            await response.sendHeaders(Http200, {"Content-Type": contentType, "Content-Length": $fileContent.len}.newStringTable())
            await response.send(fileContent)
            echo format("Sent file \"$1\" to client", @"name")
          break
    if not fileFound:
      await response.sendHeaders(Http404, {"Content-Type": "text/html; charset=utf-8"}.newStringTable())
      await response.send("No such file!")
    response.client.close()

  get "/":
    var html = ""
    html.add format("<html>")
    html.add format("<head><title>$1</title></head>", "mini-rapida")
    html.add format("<h1>$1 $2</h1>", "Index of", getCurrentDir())
    html.add format("<hr>")
    html.add format("<pre>")

    for file in walkFiles("*"):
      if existsFile(file):
        let filename = extractFilename(file)
        html.add format("<a href=\"$1\">$1</a>$2$3<br>", filename, " ".repeat(80-filename.len), file.getFileSize.formatSize.align(10))

    html.add format("</pre>")
    html.add format("<hr>")
    html.add format("<form action=\"upload\" method=\"post\"enctype=\"multipart/form-data\">")
    html.add format("<input type=\"file\" name=\"file\"value=\"file\">")
    html.add format("<input type=\"submit\" value=\"$1\" name=\"submit\">", "Закачать")
    html.add format("</form>")
    html.add format("</body>")
    html.add format("</html>")

    await response.sendHeaders(Http200, {"Content-Type": "text/html; charset=utf-8"}.newStringTable())
    await response.send(html)
    response.client.close()

  post "/upload":
    if request.formData["file"].fields["filename"] == nil or request.formData["file"].body == nil or request.formData["file"].fields["filename"] == "":
      resp("Wrong upload request, please submit file!")
      echo format("Wrong upload request")
    else:
      writeFile(request.formData["file"].fields["filename"], request.formData["file"].body)
      resp("Got file, thanks!")
      echo format("Wrote file \"$1\"", request.formData["file"].fields["filename"])

runForever()
