library flutter_html_editor;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html_editor/local_server.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';

/*
 * Created by riyadi rb on 2/5/2020.
 * link  : https://github.com/xrb21/flutter-html-editor
 */

typedef void OnClik();

class HtmlEditor extends StatefulWidget {
  final String value;
  final double height;
  final BoxDecoration decoration;
  final bool useBottomSheet;
  final String widthImage;
  final bool showBottomToolbar;
  final String hint;

  HtmlEditor(
      {Key key,
      this.value,
      this.height = 380,
      this.decoration,
      this.useBottomSheet = false,
      this.widthImage = "100%",
      this.showBottomToolbar = false,
      this.hint})
      : super(key: key);

  @override
  HtmlEditorState createState() => HtmlEditorState();
}

class HtmlEditorState extends State<HtmlEditor> {
  WebViewController _controller;
  String text = "";
  final Key _mapKey = UniqueKey();

  int port = 5321;
  LocalServer localServer;

  @override
  void initState() {
    if (!Platform.isAndroid) {
      initServer();
    }
    super.initState();
  }

  initServer() {
    localServer = LocalServer(port);
    localServer.start(handleRequest);
  }

  void handleRequest(HttpRequest request) {
    try {
      if (request.method == 'GET' &&
          request.uri.queryParameters['query'] == "getRawTeXHTML") {
      } else {}
    } catch (e) {
      print('Exception in handleRequest: $e');
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller = null;
    }
    if (!Platform.isAndroid) {
      localServer.close();
    }
    super.dispose();
  }

  _loadHtmlFromAssets() async {
    final filePath = 'packages/flutter_html_editor/summernote/summernote.html';
    _controller.loadUrl("http://localhost:$port/$filePath");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: widget.decoration ??
          BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            border: Border.all(color: Color(0xffececec), width: 1),
          ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: WebView(
              key: _mapKey,
              onWebResourceError: (e) {
                print("error ${e.description}");
              },
              onWebViewCreated: (webViewController) {
                _controller = webViewController;

                if (Platform.isAndroid) {
                  final filename =
                      'packages/flutter_html_editor/summernote/summernote.html';
                  _controller.loadUrl(
                      "file:///android_asset/flutter_assets/" + filename);
                } else {
                  _loadHtmlFromAssets();
                }
              },
              javascriptMode: JavascriptMode.unrestricted,
              gestureNavigationEnabled: true,
              gestureRecognizers: [
                Factory(
                    () => VerticalDragGestureRecognizer()..onUpdate = (_) {}),
              ].toSet(),
              javascriptChannels: <JavascriptChannel>[
                getTextJavascriptChannel(context)
              ].toSet(),
              onPageFinished: (String url) {
                if (widget.hint != null) {
                  setHint(widget.hint);
                } else {
                  setHint("");
                }

                setFullContainer();
                if (widget.value != null) {
                  setText(widget.value);
                }
              },
            ),
          ),
          widget.showBottomToolbar
              ? Divider()
              : Container(
                  height: 1,
                ),
          widget.showBottomToolbar
              ? Padding(
                  padding: const EdgeInsets.only(
                      left: 4.0, right: 4, bottom: 8, top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      // widgetIcon(Icons.image, "Image", onKlik: () {
                      //   widget.useBottomSheet
                      //       ? bottomSheetPickImage(context)
                      //       : dialogPickImage(context);
                      // }),
                      widgetIcon(Icons.content_copy, "Copy", onKlik: () async {
                        String data = await getText();
                        Clipboard.setData(new ClipboardData(text: data));
                      }),
                      widgetIcon(Icons.content_paste, "Paste",
                          onKlik: () async {
                        ClipboardData data =
                            await Clipboard.getData(Clipboard.kTextPlain);

                        String txtIsi = data.text
                            .replaceAll("'", '\\"')
                            .replaceAll('"', '\\"')
                            .replaceAll("[", "\\[")
                            .replaceAll("]", "\\]")
                            .replaceAll("\n", "<br/>")
                            .replaceAll("\n\n", "<br/>")
                            .replaceAll("\r", " ")
                            .replaceAll('\r\n', " ");
                        String txt =
                            "\$('.note-editable').append( '" + txtIsi + "');";
                        _controller.evaluateJavascript(txt);
                      }),
                    ],
                  ),
                )
              : Container(
                  height: 1,
                )
        ],
      ),
    );
  }

  JavascriptChannel getTextJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'GetTextSummernote',
        onMessageReceived: (JavascriptMessage message) {
          String isi = message.message;
          if (isi.isEmpty ||
              isi == "<p></p>" ||
              isi == "<p><br></p>" ||
              isi == "<p><br/></p>") {
            isi = "";
          }
          setState(() {
            text = isi;
          });
        });
  }

  Future<String> getText() async {
    await _controller.evaluateJavascript(
        "GetTextSummernote.postMessage(document.getElementsByClassName('note-editable')[0].innerHTML);");
    return text;
  }

  setText(String v) async {
    String txtIsi = v
        .replaceAll("'", '\\"')
        .replaceAll('"', '\\"')
        .replaceAll("[", "\\[")
        .replaceAll("]", "\\]")
        .replaceAll("\n", "<br/>")
        .replaceAll("\n\n", "<br/>")
        .replaceAll("\r", " ")
        .replaceAll('\r\n', " ");
    String txt =
        "document.getElementsByClassName('note-editable')[0].innerHTML = '" +
            txtIsi +
            "';";
    _controller.evaluateJavascript(txt);
  }

  setFullContainer() {
    _controller.evaluateJavascript(
        '\$("#summernote").summernote("fullscreen.toggle");');
  }

  setFocus() {
    _controller.evaluateJavascript("\$('#summernote').summernote('focus');");
  }

  setEmpty() {
    _controller.evaluateJavascript("\$('#summernote').summernote('reset');");
  }

  setHint(String text) {
    String hint = '\$(".note-placeholder").html("$text");';
    _controller.evaluateJavascript(hint);
  }

  Widget widgetIcon(IconData icon, String title, {OnClik onKlik}) {
    return InkWell(
      onTap: () {
        onKlik();
      },
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: Colors.black38,
            size: 20,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title,
              style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w400),
            ),
          )
        ],
      ),
    );
  }


}
